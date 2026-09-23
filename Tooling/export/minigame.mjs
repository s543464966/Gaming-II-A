import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { cp, mkdir, mkdtemp, open, readFile, readdir, rename, rm, stat, writeFile } from 'node:fs/promises';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { selectEngine } from '../environment/engine.mjs';

export const workspace = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const sourceProject = join(workspace, 'Coding/godot');
const errors = /SCRIPT ERROR:|(?:^|\n)ERROR:|Parse Error:|Export failed/i;
const excluded = new Set(['.git', '.godot', '.runtime', 'node_modules', 'exports', '.DS_Store']);
const digest = bytes => createHash('sha256').update(bytes).digest('hex');

export function execute(binary, args, options = {}) {
  const result = spawnSync(binary, args, {
    encoding: 'utf8', timeout: 120_000, maxBuffer: 16 * 1024 * 1024, ...options,
  });
  const output = (result.stdout ?? '') + (result.stderr ?? '');
  if (result.error || result.status !== 0) {
    throw new Error(`${binary} failed: ${result.error?.message ?? `exit ${result.status}`}\n${output}`);
  }
  return output;
}

async function filesIn(directory) {
  const files = [];
  for (const item of await readdir(directory, { withFileTypes: true })) {
    if (excluded.has(item.name)) continue;
    const path = join(directory, item.name);
    if (item.isDirectory()) files.push(...await filesIn(path));
    else if (item.isFile()) files.push(path);
    else throw new Error(`Unexpected non-regular file: ${path}`);
  }
  return files.sort();
}

export async function prepareArtifact(target, lock) {
  const cache = join(workspace, 'Tooling/.runtime', target);
  await mkdir(cache, { recursive: true });
  const archive = join(cache, lock.file);
  let bytes = await readFile(archive).catch(() => null);
  if (!bytes || digest(bytes) !== lock.sha256) {
    console.log(`Downloading pinned minigame dependency: ${lock.url}`);
    const download = await mkdtemp(join(cache, 'download-'));
    try {
      const incoming = join(download, lock.file);
      execute('curl', ['--fail', '--location', '--retry', '2', '--max-time', '110',
        '--output', incoming, lock.url]);
      bytes = await readFile(incoming);
      if (digest(bytes) !== lock.sha256) throw new Error('Minigame dependency SHA-256 mismatch; refusing to use it.');
      await rename(incoming, archive);
    } finally {
      await rm(download, { recursive: true, force: true });
    }
  }
  return archive;
}

export async function packageSizes(directory, lock) {
  const roots = lock.subpackages ?? ['engine', 'content'];
  const sizes = Object.fromEntries(['main', ...roots, 'total'].map(name => [name, 0]));
  for (const file of await filesIn(directory)) {
    const name = relative(directory, file).split(sep).join('/');
    const bucket = roots.find(root => name.startsWith(`${root}/`)) ?? 'main';
    const { size } = await stat(file);
    sizes[bucket] += size;
    sizes.total += size;
  }
  for (const [name, size] of Object.entries(sizes)) {
    const limit = lock.budgets[name] ?? lock.budgets.subpackage;
    if (size > limit) throw new Error(`${name} exceeds project package budget: ${size} > ${limit} bytes.`);
  }
  return sizes;
}

// 保持项目根目录不变，让开发者工具继续监听；替换失败则恢复上一版文件。
export async function updateProject(staged, destination, backup) {
  const incoming = await readdir(staged);
  if (!incoming.includes('game.js') || !incoming.includes('project.config.json')) {
    throw new Error('Incomplete minigame project; current package was not changed.');
  }
  const privateConfig = 'project.private.config.json';
  if (incoming.includes(privateConfig)) throw new Error('Build output must not overwrite local IDE settings.');
  await mkdir(destination, { recursive: true });
  await mkdir(backup);
  const previous = (await readdir(destination)).filter(name => name !== privateConfig);
  const saved = [];
  const installed = [];
  try {
    for (const name of previous) {
      await rename(join(destination, name), join(backup, name));
      saved.push(name);
    }
    for (const name of incoming) {
      await rename(join(staged, name), join(destination, name));
      installed.push(name);
    }
  } catch (error) {
    for (const name of installed.reverse()) await rename(join(destination, name), join(staged, name));
    for (const name of saved.reverse()) await rename(join(backup, name), join(destination, name));
    throw error;
  }
}

// 两个平台共用资源导出、校验和固定目录更新；平台适配只负责组装宿主文件。
export async function buildMinigame(profile, { prepareOnly = false } = {}) {
  const { target, label } = profile;
  const lockPath = join(workspace, `Tooling/export/${target}_template.json`);
  const lock = JSON.parse(await readFile(lockPath, 'utf8'));
  const baseline = JSON.parse(await readFile(join(sourceProject, 'tooling/engine.json'), 'utf8'));
  if (baseline.engine !== lock.engine) throw new Error('Engine baseline and template must match exactly.');
  let config = JSON.parse(await readFile(join(sourceProject, `platforms/${target}/project.config.json`), 'utf8'));
  profile.validateAppId(config.appid);
  const engine = await selectEngine(workspace);
  const version = execute(engine, ['--version']).trim();
  if (!version.startsWith(`${lock.engine}.`)) throw new Error(`Expected Godot ${lock.engine}, got ${version}`);
  const dependencies = lock.artifacts ?? [lock];
  const artifacts = [];
  for (const dependency of dependencies) artifacts.push(await prepareArtifact(target, dependency));
  if (prepareOnly) { console.log(`READY: ${label}; Godot ${version}; verified ${artifacts.length} dependencies`); return; }

  const runtime = join(workspace, 'Testing/.runtime');
  await mkdir(runtime, { recursive: true });
  const lockFile = join(workspace, `Tooling/.runtime/${target}/export.lock`);
  const exportLock = await open(lockFile, 'wx').catch(error => {
    if (error.code === 'EEXIST') throw new Error(`${label}打包正在运行，请勿重复启动。若上次被强制终止，确认没有打包进程后删除锁文件：${lockFile}`);
    throw error;
  });
  await exportLock.close();
  let run;
  let retained = true;
  try {
    run = await mkdtemp(join(runtime, `${target}-export-`));
    const project = join(run, 'project');
    await cp(sourceProject, project, {
      recursive: true,
      filter: path => !relative(sourceProject, path).split(sep).some(part => excluded.has(part)),
    });
    const platform = join(project, `platforms/${target}`);
    config = JSON.parse(await readFile(join(platform, 'project.config.json'), 'utf8'));
    profile.validateAppId(config.appid);
    const game = join(run, 'game');
    await mkdir(game);
    for (const name of ['game.json', 'project.config.json', 'third_party_notices.txt']) {
      await cp(join(platform, name), join(game, name));
    }
    await cp(join(project, 'ui/design_system/fonts/LICENSE.txt'), join(game, 'font_license.txt'));
    await profile.assemble({ game, platform, artifacts, lock });

    for (const [phase, command] of [
      ['import', ['--editor', '--import', '--quit']],
      ['pack', ['--export-pack', profile.preset, join(run, 'game.pck')]],
    ]) {
      console.log(`${label} ${phase}: Godot ${version}`);
      const log = join(run, `${phase}.log`);
      const output = execute(engine, ['--headless', '--path', project, '--log-file', log, ...command]);
      const diagnostic = output + await readFile(log, 'utf8').catch(() => '');
      if (errors.test(diagnostic)) throw new Error(`${phase} reported a Godot error; inspect ${log}`);
    }
    const packPath = join(game, profile.packPath);
    await rename(join(run, 'game.pck'), packPath);
    const pack = await readFile(packPath);
    if (pack.length < 32 || pack.subarray(0, 4).toString() !== 'GDPC') throw new Error('Missing or invalid Godot resource pack.');
    console.log(execute(process.execPath, [join(workspace, 'Testing/scripts/check_minigame.mjs'), packPath]));
    const fingerprint = createHash('sha256');
    for (const input of await filesIn(project)) fingerprint.update(relative(project, input)).update(await readFile(input));
    for (const input of [fileURLToPath(import.meta.url), profile.entryPath, lockPath]) fingerprint.update(await readFile(input));
    const report = {
      target, mode: 'local-test', appid: config.appid, appidConfigured: Boolean(config.appid),
      engine: version,
      dependencies: dependencies.map(({ file, sha256 }) => ({ file, sha256 })),
      sourceSha256: fingerprint.digest('hex'), packSha256: digest(pack),
      createdAt: new Date().toISOString(),
    };
    const reportPath = join(game, 'build_report.json');
    await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`);
    let sizes = await packageSizes(game, lock);
    for (;;) {
      report.sizes = sizes;
      await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`);
      const measured = await packageSizes(game, lock);
      if (JSON.stringify(measured) === JSON.stringify(sizes)) break;
      sizes = measured;
    }
    const destination = join(workspace, `Archive/Builds/${target}`);
    await updateProject(game, destination, join(run, 'previous_project'));
    await rm(run, { recursive: true });
    retained = false;
    console.log(`PASS: ${label}测试包已更新\nProject: ${destination}\nReport: ${join(destination, 'build_report.json')}`);
    console.log(`Bytes: ${JSON.stringify(sizes)}`);
    if (!config.appid) console.log(`AppID 待配置：请在 Coding/godot/platforms/${target}/project.config.json 填入本项目 AppID 后重新打包。`);
    return destination;
  } catch (error) {
    if (retained && run) console.error(`Export diagnostics: ${run}`);
    throw error;
  } finally {
    await rm(lockFile, { force: true });
  }
}
