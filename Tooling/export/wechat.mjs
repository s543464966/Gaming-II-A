import { cp, mkdir, readFile, writeFile } from 'node:fs/promises';
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
  await cp(join(platform, 'runtime/engine_game.js'), join(game, 'engine/game.js'));
  await writeFile(join(game, 'content/game.js'), '// Resource-only subpackage.\n');
  // 上游加载器只处理成功回调；在固定模板上补齐下载失败反馈。
  const loaderPath = join(game, 'godot-loader.js');
  const loader = await readFile(loaderPath, 'utf8');
  const anchor = 'name: "engine",';
  if (loader.split(anchor).length !== 2) throw new Error('Pinned loader contract changed.');
  await writeFile(loaderPath, loader.replace(anchor, `${anchor}\n                fail: GameGlobal.reportStartupFailure,`));
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
