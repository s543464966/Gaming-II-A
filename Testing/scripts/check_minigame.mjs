import { spawnSync } from 'node:child_process';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { brotliDecompressSync } from 'node:zlib';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { selectEngine } from '../../Tooling/environment/engine.mjs';

const workspace = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
let run;
try {
  if (process.argv.length !== 3) throw new Error('Usage: node Testing/scripts/check_minigame.mjs <exported-pack-file>');
  let pack = resolve(process.argv[2]);
  const runtime = join(workspace, 'Testing/.runtime');
  await mkdir(runtime, { recursive: true });
  run = await mkdtemp(join(runtime, 'minigame-pack-test-'));
  if (pack.endsWith('.br')) {
    const unpacked = brotliDecompressSync(await readFile(pack));
    if (unpacked.subarray(0, 4).toString() !== 'GDPC') throw new Error('Brotli resource pack has no Godot signature.');
    pack = join(run, 'main.pck');
    await writeFile(pack, unpacked);
  }
  const engine = await selectEngine(workspace);
  const log = join(run, 'pack_test.log');
  const result = spawnSync(engine, [
    '--headless', '--path', run, '--main-pack', pack,
    '--log-file', log, '--script', join(workspace, 'Testing/integration/minigame/pack_test.gd'), '--quit-after', '180',
  ], { encoding: 'utf8', timeout: 60_000, maxBuffer: 4 * 1024 * 1024 });
  const output = (result.stdout ?? '') + (result.stderr ?? '');
  process.stdout.write(output);
  const diagnostic = output + await readFile(log, 'utf8').catch(() => '');
  if (result.error || result.status !== 0 || /SCRIPT ERROR:|(?:^|\n)ERROR:|Parse Error:|resources still in use/i.test(diagnostic)
      || !diagnostic.includes('PASS: minigame exported pack')) throw new Error('Exported pack smoke test failed.');
  await rm(run, { recursive: true });
} catch (error) {
  console.error(error.message);
  if (run) console.error(`Diagnostics: ${run}`);
  process.exitCode = 1;
}
