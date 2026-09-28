import { spawn } from 'node:child_process';
import { watch } from 'node:fs';
import { mkdir, mkdtemp, readFile, rm } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { selectEngine } from '../environment/engine.mjs';

const workspace = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const args = process.argv.slice(2);
const target = args.find(arg => !arg.startsWith('--')) ?? 'app';
const usage = 'Usage: node Tooling/preview/preview.mjs [app|home] [--check]';
const project = join(workspace, 'Coding/godot');
const ignoredParts = new Set(['.godot', '.git', '.runtime', '.DS_Store', 'node_modules', 'exports']);
let child;
let interrupted = false;
let killTimer;
let watcher;
let restartTimer;
let changeWaiter;
let changeVersion = 0;
let previewVersion = 0;
let phase = 'idle';
let restartRequested = false;

function terminateChild() {
  if (!child) return;
  child.kill('SIGTERM');
  clearTimeout(killTimer);
  killTimer = setTimeout(() => child?.kill('SIGKILL'), 5000);
  killTimer.unref();
}

function stop() {
  interrupted = true;
  watcher?.close();
  watcher = undefined;
  clearTimeout(restartTimer);
  changeWaiter?.();
  changeWaiter = undefined;
  terminateChild();
}

function sourceChanged(_event, filename) {
  if (interrupted) return;
  if (filename) {
    const parts = String(filename).split(/[\\/]/);
    if (parts.some(part => ignoredParts.has(part)) || /\.(?:uid|import|md)$/.test(parts.at(-1))) return;
  }
  changeVersion++;
  changeWaiter?.();
  changeWaiter = undefined;
  clearTimeout(restartTimer);
  restartTimer = setTimeout(() => {
    restartTimer = undefined;
    if (phase === 'preview' && changeVersion > previewVersion) {
      restartRequested = true;
      console.log('工程文件已更新，正在重新启动本地预览…');
      terminateChild();
    }
  }, 900);
}

function waitForChange(version) {
  if (interrupted || changeVersion > version) return Promise.resolve();
  return new Promise(resolve => { changeWaiter = resolve; });
}

function launch(binary, command, timeout) {
  return new Promise((resolveResult, reject) => {
    let timedOut = false;
    child = spawn(binary, command, { stdio: 'inherit' });
    const timer = timeout ? setTimeout(() => {
      timedOut = true;
      terminateChild();
    }, timeout) : undefined;
    function cleanup() {
      clearTimeout(timer);
      clearTimeout(killTimer);
      child = undefined;
    }
    child.once('error', error => {
      cleanup();
      reject(error);
    });
    child.once('close', (code, signal) => {
      cleanup();
      if (timedOut) {
        reject(new Error('Godot import timed out.'));
        return;
      }
      resolveResult({ code, signal });
    });
  });
}

if (args.includes('--help')) {
  console.log(usage);
} else if (!['app', 'home'].includes(target) || args.some(arg => ![target, '--check'].includes(arg))
    || args.filter(arg => !arg.startsWith('--')).length > 1 || new Set(args).size !== args.length) {
  console.error(usage);
  process.exitCode = 2;
} else {
  for (const signal of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(signal, stop);
  let run;
  try {
    if (args.includes('--check')) {
      const suites = target === 'app' ? ['architecture', 'home'] : ['home'];
      const result = await launch(process.execPath, [join(workspace, 'Testing/scripts/run_godot.mjs'), ...suites]);
      process.exitCode = result.code ?? 1;
    } else {
      const engine = await selectEngine(workspace);
      const runtime = join(workspace, 'Testing/.runtime');
      await mkdir(runtime, { recursive: true });
      run = await mkdtemp(join(runtime, 'preview-'));
      watcher = watch(project, { recursive: true }, sourceChanged);
      let retainDiagnostics = false;
      console.log(`Project: ${project}\nEngine: ${engine}\nDiagnostics: ${run}\n正在监听本地工程；保存后自动重新启动预览。`);
      for (let cycle = 1; !interrupted; cycle++) {
        const importedVersion = changeVersion;
        phase = 'import';
        const importLog = join(run, `import-${cycle}.log`);
        const imported = await launch(engine, ['--path', project, '--log-file', importLog,
          '--headless', '--editor', '--import', '--quit'], 60_000);
        phase = 'idle';
        if (interrupted) break;
        const importDiagnostic = await readFile(importLog, 'utf8').catch(() => '');
        if (imported.code !== 0 || /SCRIPT ERROR:|(?:^|\n)ERROR:|Parse Error:/i.test(importDiagnostic)) {
          retainDiagnostics = true;
          console.error(`Godot 导入失败：${importLog}\n修复工程文件并保存后自动重试。`);
          await waitForChange(importedVersion);
          continue;
        }
        if (changeVersion > importedVersion) continue;

        const previewLog = join(run, `preview-${cycle}.log`);
        const command = ['--path', project, '--log-file', previewLog];
        if (target === 'home') command.push('res://features/home/ui/home_screen.tscn');
        restartRequested = false;
        previewVersion = changeVersion;
        phase = 'preview';
        const result = await launch(engine, command);
        phase = 'idle';
        if (interrupted) break;
        if (restartRequested) continue;
        const diagnostic = await readFile(previewLog, 'utf8').catch(() => '');
        if (result.code !== 0 || /SCRIPT ERROR:|(?:^|\n)ERROR:|Parse Error:|ObjectDB instances leaked|resources still in use/i.test(diagnostic)) {
          retainDiagnostics = true;
          console.error(`本地预览出错：${previewLog}\n修复工程文件并保存后自动重试。`);
          await waitForChange(previewVersion);
          continue;
        }
        break;
      }
      if (interrupted) process.exitCode = 130;
      if (retainDiagnostics) console.log(`Diagnostics retained: ${run}`);
      else {
        await rm(run, { recursive: true });
        console.log('Preview stopped; temporary logs removed.');
      }
    }
  } catch (error) {
    console.error(error.message);
    if (run) console.error(`Diagnostics: ${run}`);
    process.exitCode = 1;
  } finally {
    watcher?.close();
    clearTimeout(restartTimer);
    for (const signal of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.off(signal, stop);
  }
}
