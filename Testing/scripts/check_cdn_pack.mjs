import { spawnSync } from 'node:child_process';
import { mkdir, mkdtemp, readFile, rm } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { selectEngine } from '../../Tooling/environment/engine.mjs';

const workspace = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
let run;
try {
  if (process.argv.length !== 4) throw new Error('Usage: node Testing/scripts/check_cdn_pack.mjs <core-pck> <remote-directory>');
  const core = resolve(process.argv[2]);
  const remote = resolve(process.argv[3]);
  const runtime = join(workspace, 'Testing/.runtime');
  await mkdir(runtime, { recursive: true });
  run = await mkdtemp(join(runtime, 'cdn-pack-test-'));
  const engine = await selectEngine(workspace);
  const log = join(run, 'pack_test.log');
  const result = spawnSync(engine, [
    '--headless', '--path', run, '--main-pack', core, '--log-file', log,
    '--script', join(workspace, 'Testing/integration/minigame/cdn_pack_test.gd'),
    '--quit-after', '180', '--', remote,
  ], { encoding: 'utf8', timeout: 60_000, maxBuffer: 4 * 1024 * 1024 });
  const diagnostic = (result.stdout ?? '') + (result.stderr ?? '') + await readFile(log, 'utf8').catch(() => '');
  process.stdout.write((result.stdout ?? '') + (result.stderr ?? ''));
  if (result.error || result.status !== 0 || /SCRIPT ERROR:|(?:^|\n)ERROR:|Parse Error:/i.test(diagnostic)
      || !diagnostic.includes('PASS: minigame CDN core and remote packs')) {
    throw new Error('CDN split-pack smoke test failed.');
  }
  const cachedLog = join(run, 'cached_delivery.log');
  const cached = spawnSync(engine, [
    '--headless', '--path', run, '--main-pack', core, '--log-file', cachedLog,
    '--script', join(workspace, 'Testing/integration/minigame/cdn_delivery_test.gd'),
    '--quit-after', '180', '--', remote, join(run, 'cache'),
  ], { encoding: 'utf8', timeout: 60_000, maxBuffer: 4 * 1024 * 1024 });
  const cachedDiagnostic = (cached.stdout ?? '') + (cached.stderr ?? '') + await readFile(cachedLog, 'utf8').catch(() => '');
  process.stdout.write((cached.stdout ?? '') + (cached.stderr ?? ''));
  if (cached.error || cached.status !== 0 || /SCRIPT ERROR:|(?:^|\n)ERROR:|Parse Error:/i.test(cachedDiagnostic)
      || !cachedDiagnostic.includes('PASS: minigame CDN cached delivery')) {
    throw new Error('CDN cached delivery smoke test failed.');
  }
  await rm(run, { recursive: true });
} catch (error) {
  console.error(error.message);
  if (run) console.error(`Diagnostics: ${run}`);
  process.exitCode = 1;
}
