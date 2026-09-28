import { cp, mkdir, readFile, readdir, rename, rm, writeFile } from 'node:fs/promises';
import { createHash, randomUUID } from 'node:crypto';
import { createRequire } from 'node:module';
import { dirname, extname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { brotliCompressSync, brotliDecompressSync, constants } from 'node:zlib';
import { buildMinigame, execute, workspace } from './minigame.mjs';

const transpiler = join(dirname(fileURLToPath(import.meta.url)), 'douyin_js');
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');

async function compatibleScript(source, destination, patch = value => value) {
  const wanted = JSON.parse(await readFile(join(transpiler, 'package.json'), 'utf8')).dependencies.esbuild;
  const installed = await readFile(join(transpiler, 'node_modules/esbuild/package.json'), 'utf8')
    .then(value => JSON.parse(value).version).catch(() => null);
  if (installed !== wanted) {
    execute('npm', ['ci', '--prefix', transpiler, '--cache', join(workspace, 'Tooling/.runtime/douyin/npm-cache'),
      '--no-audit', '--no-fund']);
  }
  const require = createRequire(join(transpiler, 'package.json'));
  const { code } = require('esbuild').transformSync(patch(await readFile(source, 'utf8')), {
    target: 'es2017', charset: 'utf8', minifyWhitespace: true,
  });
  await writeFile(destination, code);
}

// 1.1.27 把屏幕高度同时作为宽度；固定锚点补丁避免引擎创建正方形画布后被宿主挤压。
export function patchLauncherViewport(source) {
  const anchor = 'screenWidth:e.screenHeight,screenHeight:e.screenHeight,';
  if (source.split(anchor).length !== 2) throw new Error('Pinned Douyin viewport contract changed.');
  return source.replace(anchor, 'screenWidth:e.windowWidth||e.screenWidth,screenHeight:e.windowHeight||e.screenHeight,');
}

export function validateAppId(appid) {
  if (appid === '') return; // 只准备工具时允许未绑定平台项目，报告会明确标记。
  if (typeof appid !== 'string' || !/^tt[0-9a-zA-Z]+$/.test(appid)) {
    throw new Error('抖音 AppID 应为 tt 开头的本项目 ID；尚未创建项目时保持空字符串。');
  }
}

export function launcherConfig(engine) {
  return {
    mainPack: 'godot/main.br', executable: 'godot/godot', canvasResizePolicy: 2, args: [],
    mainWasm: 'godot/godot.wasm.br', godotModule: 'godot/godot.js', godotVersion: engine,
    godotTemplate: 'web', subpackages: ['godot'], forceTTAudioContext: true,
  };
}

// 只从当前工程选择可运行的场景、脚本及其静态引用，避免历史美术进入小游戏包。
async function prepareProject(project) {
  const selected = new Set();
  const scripts = [];
  async function scan(directory) {
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      if (entry.name.startsWith('.') || ['tooling', 'addons'].includes(entry.name)) continue;
      const path = join(directory, entry.name);
      if (entry.isDirectory()) { await scan(path); continue; }
      if (!entry.isFile()) continue;
      const extension = extname(path);
      if (extension !== '.gd' && extension !== '.tscn') continue;
      selected.add(`res://${relative(project, path).split(sep).join('/')}`);
      if (extension === '.gd') scripts.push(path);
    }
  }
  await scan(project);
  for (const script of scripts) {
    const source = await readFile(script, 'utf8');
    for (const match of source.matchAll(/\b(?:preload|load)\(\s*["'](res:\/\/[^"']+)["']/g)) {
      const asset = match[1];
      if (!(await readFile(join(project, asset.slice(6))).catch(() => null))) {
        throw new Error(`Douyin export references a missing resource: ${asset}`);
      }
      selected.add(asset);
    }
  }
  if (!selected.has('res://bootstrap/app.tscn')) throw new Error('Douyin export has no startup scene.');
  const preset = join(project, 'export_presets.cfg');
  const source = await readFile(preset, 'utf8');
  const marker = 'name="Douyin Resources"';
  if (source.split(marker).length !== 2) throw new Error('Douyin export preset is missing or ambiguous.');
  const [head, section] = source.split(marker);
  const filter = 'export_filter="all_resources"';
  if (section.split(filter).length !== 2) throw new Error('Douyin export filter has changed.');
  const files = `export_filter="resources"\nexport_files=PackedStringArray(${[...selected].sort().map(JSON.stringify).join(', ')})`;
  await writeFile(preset, head + marker + section.replace(filter, files));
}

function encodePack(pack) {
  const compressed = brotliCompressSync(pack, { params: { [constants.BROTLI_PARAM_QUALITY]: 11 } });
  if (!brotliDecompressSync(compressed).equals(pack)) throw new Error('Douyin Brotli pack verification failed.');
  return compressed;
}

async function assemble({ game, platform, artifacts, lock }) {
  const engine = join(game, 'godot');
  await mkdir(engine);
  execute('unzip', ['-oq', artifacts[0], ...lock.files, '-d', engine]);
  const wasm = brotliDecompressSync(await readFile(join(engine, 'godot.wasm.br')));
  if (!WebAssembly.validate(wasm)) throw new Error('Invalid Douyin engine WebAssembly template.');
  await compatibleScript(join(engine, 'godot.js'), join(engine, 'godot.js'));
  await compatibleScript(artifacts[1], join(game, 'godot.launcher.js'), patchLauncherViewport);
  await cp(join(platform, 'runtime/game.js'), join(game, 'game.js'));
  await cp(join(platform, '../minigame/runtime/host_viewport.js'), join(game, 'host_viewport.js'));
  await writeFile(join(engine, 'game.js'), '// Engine and resources are loaded by the official launcher.\n');
  await writeFile(join(game, 'godot.config.js'), `module.exports = ${JSON.stringify(launcherConfig(lock.engine), null, 2)};\n`);
}

function deliveryBaseUrl(value) {
  let url;
  try { url = new URL(value); } catch { throw new Error('CDN 模式需要 HTTPS 资源目录地址。'); }
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash
      || !value.endsWith('/') || url.href !== value) {
    throw new Error('CDN 地址必须是以 / 结尾、不含凭据和查询参数的 HTTPS 目录。');
  }
  return value;
}

async function deliverySettings(args) {
  const usage = 'Usage: node Tooling/export/douyin.mjs [--prepare] [--delivery embedded|cdn] [--cdn-base-url https://资源目录/]';
  if (args.includes('--help')) return { help: usage };
  const localPath = join(workspace, 'Tooling/export/douyin.local.json');
  const local = await readFile(localPath, 'utf8').then(JSON.parse).catch(error => {
    if (error.code === 'ENOENT') return {};
    throw error;
  });
  let mode = local.delivery_mode ?? 'embedded';
  let baseUrl = local.cdn_base_url ?? '';
  let prepareOnly = false;
  for (let index = 0; index < args.length; index++) {
    const option = args[index];
    if (option === '--prepare') prepareOnly = true;
    else if (option === '--delivery' && args[index + 1]) mode = args[++index];
    else if (option === '--cdn-base-url' && args[index + 1]) baseUrl = args[++index];
    else throw new Error(usage);
  }
  if (!['embedded', 'cdn'].includes(mode)) throw new Error('delivery_mode 必须为 embedded 或 cdn。');
  if (mode === 'cdn') deliveryBaseUrl(baseUrl);
  return { mode, baseUrl, prepareOnly };
}

async function partitionPack({ engine, project, run, rawPackPath }, baseUrl) {
  const output = join(run, 'cdn_candidate');
  const diagnostic = execute(engine, ['--headless', '--path', project,
    '--script', 'res://tooling/export/partition_douyin.gd', '--', rawPackPath, output, baseUrl]);
  const marker = 'DOUYIN PARTITION PASS: ';
  if (!diagnostic.includes(marker) || /SCRIPT ERROR:|(?:^|\n)ERROR:/m.test(diagnostic)) {
    throw new Error(`Douyin CDN partition failed:\n${diagnostic}`);
  }
  const result = JSON.parse(diagnostic.slice(diagnostic.indexOf(marker) + marker.length).trim());
  const remotePath = join(output, 'remote.pck');
  const corePath = join(output, 'core.pck');
  const remote = await readFile(remotePath);
  if (remote.length !== result.remote_bytes || sha256(remote) !== result.sha256) {
    throw new Error('Douyin CDN remote resource checksum does not match its manifest.');
  }
  const core = await readFile(corePath);
  if (core.length !== result.core_bytes || core.subarray(0, 4).toString() !== 'GDPC') {
    throw new Error('Douyin CDN core pack does not match partition output.');
  }
  console.log(execute(process.execPath, [join(workspace, 'Testing/scripts/check_cdn_pack.mjs'), corePath, remotePath]));
  return {
    corePath, remotePath, sha256: result.sha256, bytes: remote.length,
    report: { mode: 'cdn', baseUrl, remoteFile: `${result.sha256}.pck`,
      remoteSha256: result.sha256, remoteBytes: remote.length, deferredPaths: result.deferred_paths },
  };
}

async function publishDelivery(delivery, directory) {
  await mkdir(directory, { recursive: true });
  const destination = join(directory, `${delivery.sha256}.pck`);
  const previous = await readFile(destination).catch(error => {
    if (error.code === 'ENOENT') return null;
    throw error;
  });
  if (previous) {
    if (sha256(previous) !== delivery.sha256) throw new Error(`CDN resource was modified: ${destination}`);
    return;
  }
  const temporary = join(directory, `.incoming-${randomUUID()}`);
  try {
    await cp(delivery.remotePath, temporary);
    if (sha256(await readFile(temporary)) !== delivery.sha256) throw new Error('CDN resource copy failed verification.');
    await rename(temporary, destination);
  } finally { await rm(temporary, { force: true }); }
}

export async function createDouyinExport({ mode = 'embedded', baseUrl = '', prepareOnly = false, destination,
  testDomainBypass = false } = {}) {
  if (!['embedded', 'cdn'].includes(mode)) throw new Error('delivery mode must be embedded or cdn.');
  if (mode === 'cdn') deliveryBaseUrl(baseUrl);
  if (testDomainBypass && mode !== 'cdn') throw new Error('Domain bypass only applies to the local CDN test.');
  const assembleForMode = async input => {
    await assemble(input);
    if (!testDomainBypass) return;
    const path = join(input.game, 'project.config.json');
    const config = JSON.parse(await readFile(path, 'utf8'));
    config.setting.urlCheck = false;
    await writeFile(path, `${JSON.stringify(config, null, 2)}\n`);
  };
  return buildMinigame({
    target: 'douyin', label: '抖音', preset: 'Douyin Resources', packPath: 'godot/main.br',
    entryPath: fileURLToPath(import.meta.url), sourceFiles: [join(transpiler, 'package-lock.json')],
    validateAppId, assemble: assembleForMode, prepareProject, encodePack,
    partitionPack: mode === 'cdn' ? input => partitionPack(input, baseUrl) : null,
    publishDelivery,
  }, { prepareOnly, destinationOverride: destination });
}

async function main(args) {
  const settings = await deliverySettings(args);
  if (settings.help) { console.log(settings.help); return; }
  await createDouyinExport({ mode: settings.mode, baseUrl: settings.baseUrl, prepareOnly: settings.prepareOnly });
  if (settings.mode === 'cdn' && !settings.prepareOnly) {
    console.log(`CDN 资源：Archive/Builds/douyin.cdn/（请按 build_report.json 的 remoteFile 原名上传至 ${settings.baseUrl}，并配置 request 合法域名）`);
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).catch(error => { console.error(error.message); process.exitCode = 1; });
}
