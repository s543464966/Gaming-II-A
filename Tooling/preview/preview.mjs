import { spawn } from 'node:child_process';
import { mkdir, mkdtemp, readFile, rm } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { selectEngine } from '../environment/engine.mjs';

const workspace = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const args = process.argv.slice(2);
const target = args.find(arg => !arg.startsWith('--')) ?? 'app';
const usage = 'Usage: node Tooling/preview/preview.mjs [app|home] [--check]';
let child;
let interrupted = false;
let killTimer;

function terminateChild() {
  if (!child) return;
  child.kill('SIGTERM');
  clearTimeout(killTimer);
  killTimer = setTimeout(() => child?.kill('SIGKILL'), 5000);
  killTimer.unref();
}

function stop() {
  interrupted = true;
  terminateChild();
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
      const project = join(workspace, 'Coding/godot');
      const runtime = join(workspace, 'Testing/.runtime');
      await mkdir(runtime, { recursive: true });
      run = await mkdtemp(join(runtime, 'preview-'));
      console.log(`Project: ${project}\nEngine: ${engine}\nDiagnostics: ${run}`);
      for (const phase of ['import', 'preview']) {
        const log = join(run, `${phase}.log`);
        const command = ['--path', project, '--log-file', log];
        if (phase === 'import') command.push('--headless', '--editor', '--import', '--quit');
        else if (target === 'home') command.push('res://features/home/ui/home_screen.tscn');
        const result = await launch(engine, command, phase === 'import' ? 60_000 : undefined);
        const diagnostic = await readFile(log, 'utf8').catch(() => '');
        if (/SCRIPT ERROR:|(?:^|\n)ERROR:|Parse Error:|ObjectDB instances leaked|resources still in use/i.test(diagnostic)
            || (result.code !== 0 && !interrupted)) throw new Error(`${phase} failed.`);
        if (interrupted) {
          process.exitCode = 130;
          break;
        }
      }
      await rm(run, { recursive: true });
      console.log('Preview stopped; temporary logs removed.');
    }
  } catch (error) {
    console.error(error.message);
    if (run) console.error(`Diagnostics: ${run}`);
    process.exitCode = 1;
  } finally {
    for (const signal of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.off(signal, stop);
  }
}
