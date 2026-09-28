import { cp, mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildMinigame, execute } from './minigame.mjs';

export function validateAppId(appid) {
  if (!/^wx[0-9a-f]{16}$/.test(appid ?? '')) throw new Error('Set a real new-project WeChat AppID in platforms/wechat/project.config.json.');
}

async function assemble({ game, platform, artifacts, lock }) {
  await mkdir(join(game, 'content'));
  execute('unzip', ['-oq', artifacts[0], ...lock.files, '-d', game]);
  await cp(join(platform, 'runtime/game.js'), join(game, 'game.js'));
  await cp(join(platform, '../minigame/runtime/host_viewport.js'), join(game, 'host_viewport.js'));
  await cp(join(platform, 'runtime/start_game.js'), join(game, 'start_game.js'));
  await writeFile(join(game, 'engine/game.js'), '// Engine resources are started by the main package.\n');
  await writeFile(join(game, 'content/game.js'), '// Resource-only subpackage.\n');
  await rename(join(game, 'engine/godot-sdk.js'), join(game, 'godot-sdk.js'));
  await rename(join(game, 'engine/godot.js'), join(game, 'godot.js'));
  // 固定模板没有真机分包进度与失败阶段；只补入诊断回调，不改动上游渲染逻辑。
  const loaderPath = join(game, 'godot-loader.js');
  let loader = await readFile(loaderPath, 'utf8');
  for (const [anchor, replacement] of [
    ['name: "engine",', 'name: "engine",\n                fail: GameGlobal.reportStartupFailure,'],
    ['get: () => gameGlobal.__godotMinigamePixelRatio || ratio,',
      'value: gameGlobal.__godotMinigamePixelRatio || ratio,\n                        writable: true,'],
    ['this.updateProgress(this.progress, this.config.textConfig.initText);',
      `this.updateProgress(this.progress, this.config.textConfig.initText);
                    GameGlobal.setStartupPhase('引擎分包已下载，正在加载脚本');
                    GameGlobal.startEngine();`],
    ['this.updateProgress(progress, this.config.textConfig.downloadingText[0]);',
      `this.updateProgress(progress, this.config.textConfig.downloadingText[0]);
                    if (GameGlobal.startupPhase.startsWith('正在加载引擎分包')) {
                        GameGlobal.setStartupPhase(\`正在加载引擎分包 \${progress}%\`);
                    }`],
  ]) {
    if (loader.split(anchor).length !== 2) throw new Error('Pinned loader contract changed.');
    loader = loader.replace(anchor, replacement);
  }
  await writeFile(loaderPath, loader);

  // 固定模板的嵌套 Promise 没有向外传递 WASM / 文件系统初始化错误，真机只会等到总超时。
  const godotPath = join(game, 'godot.js');
  let godot = await readFile(godotPath, 'utf8');
  const begin = godot.indexOf('function doInit(promise) {');
  const end = godot.indexOf('preloader.setProgressFunc(this.config.onProgress);', begin);
  if (begin < 0 || end < 0) throw new Error('Pinned Godot initialization contract changed.');
  const init = godot.slice(begin, end);
  const unhandled = [8, 7, 6].map(count => `${'\t'.repeat(count)}});`).join('\n');
  if (init.split(unhandled).length !== 2) throw new Error('Pinned Godot Promise contract changed.');
  const handled = [8, 7, 6].map(count => `${'\t'.repeat(count)}}).catch(reject);`).join('\n');
  godot = godot.slice(0, begin) + init.replace(unhandled, handled) + godot.slice(end);
  // 模板的两条 WASM 实例化分支也会吞掉异步异常，真机需直接显示原始错误。
  for (const anchor of [
    'WebAssembly.instantiateStreaming(Promise.resolve(r), imports).then(done);',
    'WebAssembly.instantiate(loadPath + ".wasm.br", imports).then(done);',
  ]) {
    if (godot.split(anchor).length !== 2) throw new Error('Pinned WASM initialization contract changed.');
    godot = godot.replace(anchor, anchor.replace('.then(done);', '.then(done).catch(GameGlobal.reportStartupFailure);'));
  }
  for (const [anchor, phase] of [
    ['const wasm_buffer = response.data;', 'WASM 文件已读取，等待实例化'],
    ["onSuccess(result['instance'], result['module']);", 'WASM 已实例化，正在初始化引擎'],
    ['const paths = me.config.persistentPaths;', '引擎已初始化，正在挂载文件系统'],
    ["me.rtenv = module;", '文件系统已挂载，正在启动场景'],
  ]) {
    if (godot.split(anchor).length !== 2) throw new Error('Pinned Godot startup phase contract changed.');
    godot = godot.replace(anchor, `GameGlobal.setStartupPhase('${phase}');\n${anchor}`);
  }
  const wasmStart = "'instantiateWasm': function (imports, onSuccess) {";
  if (godot.split(wasmStart).length !== 2) throw new Error('Pinned WASM startup phase contract changed.');
  godot = godot.replace(wasmStart, `${wasmStart}\nGameGlobal.setStartupPhase('正在实例化 WASM');`);
  await writeFile(godotPath, godot);
  execute(process.execPath, ['--check', loaderPath]);
  execute(process.execPath, ['--check', godotPath]);
}

async function main(args) {
  const usage = 'Usage: node Tooling/export/wechat.mjs [--open] [--prepare] [--help]';
  if (args.includes('--help')) { console.log(usage); return; }
  if (args.some(arg => !['--open', '--prepare'].includes(arg)) || new Set(args).size !== args.length) throw new Error(usage);
  const destination = await buildMinigame({
    target: 'wechat', label: '微信', preset: 'WeChat Resources', packPath: 'content/game_pack.bin',
    entryPath: fileURLToPath(import.meta.url), validateAppId, assemble,
  }, { prepareOnly: args.includes('--prepare') });
  if (!destination) return;
  console.log('在微信开发者工具中打开此固定项目，点击“编译”即可测试；无需重新导入。');
  if (args.includes('--open')) {
    const cli = process.env.WECHAT_CLI ?? (process.platform === 'darwin'
      ? '/Applications/wechatwebdevtools.app/Contents/MacOS/cli' : 'cli');
    try { console.log(execute(cli, ['open', '--project', destination])); }
    catch (error) { console.warn(`打包已成功，但未能自动打开开发者工具。请打开已有项目并点击“编译”。\n${error.message}`); }
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).catch(error => { console.error(error.message); process.exitCode = 1; });
}
