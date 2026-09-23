import assert from 'node:assert/strict';
import fs, { mkdir, mkdtemp, readFile, readdir, rm, stat, writeFile } from 'node:fs/promises';
import { syncBuiltinESMExports } from 'node:module';
import { join, resolve } from 'node:path';
import { test } from 'node:test';
import { packageSizes, updateProject } from '../../../Tooling/export/minigame.mjs';

const root = resolve(import.meta.dirname, '../../..');

test('package accounting includes each subpackage and rejects oversized content', async () => {
  const parent = join(root, 'Testing/.runtime');
  await mkdir(parent, { recursive: true });
  const run = await mkdtemp(join(parent, 'wechat-size-test-'));
  try {
    await mkdir(join(run, 'engine'));
    await mkdir(join(run, 'content'));
    await writeFile(join(run, 'game.js'), 'main');
    await writeFile(join(run, 'engine/runtime.bin'), Buffer.alloc(10));
    await writeFile(join(run, 'content/pack.bin'), Buffer.alloc(20));
    assert.deepEqual(await packageSizes(run, { budgets: { main: 4, subpackage: 20, total: 34 } }),
      { main: 4, engine: 10, content: 20, total: 34 });
    await assert.rejects(packageSizes(run, { budgets: { main: 4, subpackage: 19, total: 34 } }), /content/);
    await assert.rejects(packageSizes(run, { budgets: { main: 3, subpackage: 20, total: 34 } }), /main/);
    await assert.rejects(packageSizes(run, { budgets: { main: 4, subpackage: 20, total: 33 } }), /total/);
  } finally { await rm(run, { recursive: true, force: true }); }
});

test('rebuild replaces the same project, removes stale output and preserves local IDE settings', async () => {
  const parent = join(root, 'Testing/.runtime');
  await mkdir(parent, { recursive: true });
  const run = await mkdtemp(join(parent, 'wechat-update-test-'));
  const destination = join(run, 'wechat');
  try {
    for (const version of ['first', 'second']) {
      const staged = join(run, version);
      await mkdir(join(staged, 'content'), { recursive: true });
      await writeFile(join(staged, 'game.js'), version);
      await writeFile(join(staged, 'project.config.json'), JSON.stringify({ version }));
      await writeFile(join(staged, 'content/game_pack.bin'), version);
    }
    await updateProject(join(run, 'first'), destination, join(run, 'backup_first'));
    const inode = (await stat(destination)).ino;
    await writeFile(join(destination, 'project.private.config.json'), '{"libVersion":"3.16.3"}');
    await mkdir(join(destination, 'obsolete'));
    await writeFile(join(destination, 'obsolete/stale.js'), 'old');
    await updateProject(join(run, 'second'), destination, join(run, 'backup_second'));
    assert.equal((await stat(destination)).ino, inode, 'IDE-watched project root must stay in place');
    assert.equal(await readFile(join(destination, 'game.js'), 'utf8'), 'second');
    assert.equal(await readFile(join(destination, 'content/game_pack.bin'), 'utf8'), 'second');
    assert.equal(await readFile(join(destination, 'project.private.config.json'), 'utf8'), '{"libVersion":"3.16.3"}');
    assert.deepEqual((await readdir(destination)).sort(), ['content', 'game.js', 'project.config.json', 'project.private.config.json']);
    await assert.rejects(updateProject(join(run, 'second'), destination, join(run, 'backup_bad')), /Incomplete/);
    assert.equal(await readFile(join(destination, 'game.js'), 'utf8'), 'second');
  } finally { await rm(run, { recursive: true, force: true }); }
});

test('a write failure during replacement restores the entire previous project', async context => {
  const parent = join(root, 'Testing/.runtime');
  await mkdir(parent, { recursive: true });
  const run = await mkdtemp(join(parent, 'wechat-rollback-test-'));
  const destination = join(run, 'wechat');
  const staged = join(run, 'incoming');
  const originalRename = fs.rename;
  try {
    await mkdir(destination);
    await mkdir(staged);
    await writeFile(join(destination, 'game.js'), 'working game');
    await writeFile(join(destination, 'project.config.json'), 'working config');
    await writeFile(join(staged, 'game.js'), 'new game');
    await writeFile(join(staged, 'project.config.json'), 'new config');
    context.mock.method(fs, 'rename', async (from, to) => {
      if (from === join(staged, 'project.config.json')) throw new Error('simulated filesystem failure');
      return originalRename(from, to);
    });
    syncBuiltinESMExports();
    await assert.rejects(updateProject(staged, destination, join(run, 'backup')), /simulated filesystem failure/);
    assert.equal(await readFile(join(destination, 'game.js'), 'utf8'), 'working game');
    assert.equal(await readFile(join(destination, 'project.config.json'), 'utf8'), 'working config');
    assert.deepEqual((await readdir(staged)).sort(), ['game.js', 'project.config.json']);
  } finally {
    context.mock.restoreAll();
    syncBuiltinESMExports();
    await rm(run, { recursive: true, force: true });
  }
});
