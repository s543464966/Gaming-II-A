import { spawnSync } from 'node:child_process';
import { cp, mkdir, mkdtemp, readFile, rm } from 'node:fs/promises';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { selectEngine } from '../../Tooling/environment/engine.mjs';

const workspace = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const requested = process.argv.slice(2);
const suites = requested.length ? [...new Set(requested)] : ['architecture', 'home'];
const errorPattern = /SCRIPT ERROR:|(?:^|\n)ERROR:|Parse Error:|ObjectDB instances leaked|resources still in use/i;

if (suites.some(suite => !['architecture', 'home'].includes(suite))) {
  console.error('Usage: node Testing/scripts/run_godot.mjs [architecture] [home]');
  process.exitCode = 2;
} else {
  let run;
  try {
    const engine = await selectEngine(workspace);
    const runtime = join(workspace, 'Testing/.runtime');
    await mkdir(runtime, { recursive: true });
    run = await mkdtemp(join(runtime, 'godot-test-'));
    const project = join(run, 'project');
    const sourceProject = join(workspace, 'Coding/godot');
    const excluded = new Set(['.git', '.godot', '.runtime', 'node_modules', 'exports', '.DS_Store']);
    await cp(sourceProject, project, {
      recursive: true,
      filter: source => !relative(sourceProject, source).split(sep).some(part => excluded.has(part)),
    });

    async function execute(name, args, markers = []) {
      const log = join(run, `${name}.log`);
      const result = spawnSync(engine, ['--headless', '--path', project, '--log-file', log, ...args], {
        encoding: 'utf8', timeout: 60_000, maxBuffer: 8 * 1024 * 1024,
      });
      const output = (result.stdout ?? '') + (result.stderr ?? '');
      process.stdout.write(output);
      const diagnostic = output + await readFile(log, 'utf8').catch(() => '');
      if (result.error || result.status !== 0 || errorPattern.test(diagnostic)
          || markers.some(marker => !diagnostic.includes(marker))) {
        throw new Error(`${name} failed: ${result.error?.message ?? `exit ${result.status}, signal ${result.signal ?? 'none'}`}`);
      }
    }

    await execute('import', ['--editor', '--import', '--quit']);
    await execute('skeleton', ['--script', join(workspace, 'Testing/integration/architecture/skeleton_test.gd'), '--', ...suites],
      suites.map(suite => `PASS: ${suite}`));
    await rm(run, { recursive: true });
    console.log(`PASS: ${suites.join(', ')}; isolated project and logs removed.`);
  } catch (error) {
    console.error(error.message);
    if (run) console.error(`Diagnostics: ${run}`);
    process.exitCode = 1;
  }
}
