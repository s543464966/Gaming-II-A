import { cp, mkdir, readFile, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { brotliDecompressSync } from 'node:zlib';
import { buildMinigame, execute } from './minigame.mjs';

export function validateAppId(appid) {
  if (appid === '') return; // 只准备工具时允许未绑定平台项目，报告会明确标记。
  if (typeof appid !== 'string' || !/^tt[0-9a-zA-Z]+$/.test(appid)) {
    throw new Error('抖音 AppID 应为 tt 开头的本项目 ID；尚未创建项目时保持空字符串。');
  }
}

export function launcherConfig(engine) {
  return {
    mainPack: 'godot/main.bin', executable: 'godot/godot', canvasResizePolicy: 2, args: [],
    mainWasm: 'godot/godot.wasm.br', godotModule: 'godot/godot.js', godotVersion: engine,
    godotTemplate: 'web', subpackages: ['godot'], forceTTAudioContext: true,
  };
}

async function assemble({ game, platform, artifacts, lock }) {
  const engine = join(game, 'godot');
  await mkdir(engine);
  execute('unzip', ['-oq', artifacts[0], ...lock.files, '-d', engine]);
  const wasm = brotliDecompressSync(await readFile(join(engine, 'godot.wasm.br')));
  if (!WebAssembly.validate(wasm)) throw new Error('Invalid Douyin engine WebAssembly template.');
  await cp(artifacts[1], join(game, 'godot.launcher.js'));
  await cp(join(platform, 'runtime/game.js'), join(game, 'game.js'));
  await writeFile(join(engine, 'game.js'), '// Engine and resources are loaded by the official launcher.\n');
  await writeFile(join(game, 'godot.config.js'), `module.exports = ${JSON.stringify(launcherConfig(lock.engine), null, 2)};\n`);
}

async function main(args) {
  const usage = 'Usage: node Tooling/export/douyin.mjs [--prepare] [--help]';
  if (args.includes('--help')) { console.log(usage); return; }
  if (args.some(arg => arg !== '--prepare') || new Set(args).size !== args.length) throw new Error(usage);
  await buildMinigame({
    target: 'douyin', label: '抖音', preset: 'Douyin Resources', packPath: 'godot/main.bin',
    entryPath: fileURLToPath(import.meta.url), validateAppId, assemble,
  }, { prepareOnly: args.includes('--prepare') });
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).catch(error => { console.error(error.message); process.exitCode = 1; });
}
