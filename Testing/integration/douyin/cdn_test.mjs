import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { test } from 'node:test';
import { deliverySettings } from '../../../Tooling/export/douyin.mjs';
import { rebuildRunningCdn, startCdnControl } from '../../../Tooling/export/douyin_cdn_session.mjs';
import { startDouyinResourceServer, verifyDouyinResource } from '../../../Tooling/export/douyin_resource_server.mjs';

const root = resolve(import.meta.dirname, '../../..');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');

test('ordinary export uses CDN automatically; offline output requires explicit selection', () => {
  assert.equal(deliverySettings([]).mode, 'local-cdn');
  assert.equal(deliverySettings([], { cdn_base_url: 'https://cdn.example/game/' }).mode, 'cdn');
  assert.equal(deliverySettings(['--delivery', 'embedded']).mode, 'embedded');
  assert.equal(deliverySettings(['--delivery', 'cloudflare-cdn']).mode, 'cloudflare-cdn');
  assert.equal(deliverySettings([], { delivery_mode: 'cloudflare-cdn' }).mode, 'cloudflare-cdn');
  assert.equal(deliverySettings(['--prepare']).prepareOnly, true);
  assert.throws(() => deliverySettings(['--delivery', 'cdn']), /HTTPS/);
  assert.throws(() => deliverySettings(['--delivery', 'cdn', '--cdn-base-url', 'http://cdn.example/']), /HTTPS/);
});

test('local CDN serves multiple exact chunks and rejects unregistered or modified resources', async () => {
  const server = await startDouyinResourceServer();
  try {
    const bodies = [Buffer.from('first texture pack'), Buffer.from('second texture pack')];
    const names = bodies.map(body => hash(body) + '.pck');
    const base = server.origin + server.prefix;
    for (let index = 0; index < bodies.length; index++) {
      server.install(names[index], bodies[index]);
      assert.equal(await verifyDouyinResource(base, names[index], bodies[index]), bodies[index].length);
    }
    assert.throws(() => server.install(names[0], bodies[1]), /invalid/);
    assert.equal((await fetch(base + '../project.godot')).status, 404);
    server.retain([names[1]]);
    assert.equal((await fetch(base + names[0])).status, 404);
    assert.equal((await fetch(base + names[1])).status, 200);
    assert.equal((await fetch(base + names[1], { method: 'POST' })).status, 405);
  } finally { await server.close(); }
});

test('repeated launch rebuilds through the same owned CDN service; stale locks recover', async () => {
  await mkdir(join(root, 'Testing/.runtime'), { recursive: true });
  const run = await mkdtemp(join(root, 'Testing/.runtime/douyin-session-test-'));
  const lock = join(run, 'cdn-test.lock');
  await mkdir(lock);
  let count = 0;
  let control;
  try {
    control = await startCdnControl({ workspace: root, state: () => 'ready',
      rebuild: async () => ({ build: ++count, baseUrl: 'https://same.example/' }) });
    const owner = { ...control.identity, controlUrl: control.url, run };
    await writeFile(join(lock, 'owner.json'), JSON.stringify(owner));
    assert.deepEqual(await rebuildRunningCdn(lock, root), { build: 1, baseUrl: 'https://same.example/' });
    assert.deepEqual(await rebuildRunningCdn(lock, root), { build: 2, baseUrl: 'https://same.example/' });
    await assert.rejects(rebuildRunningCdn(lock, root, 'cloudflare'), /模式不同/);
    assert.equal(count, 2);
    assert.equal((await fetch(control.url + '/build', { method: 'POST', headers: { Origin: 'https://unrelated.example' } })).status, 403);
    await writeFile(join(lock, 'owner.json'), JSON.stringify({ ...owner, workspace: run }));
    await assert.rejects(rebuildRunningCdn(lock, root), /归属/);
    assert.equal(count, 2);
    const dead = spawnSync(process.execPath, ['-e', '']);
    assert.equal(dead.status, 0);
    await writeFile(join(lock, 'owner.json'), JSON.stringify({ ...owner, pid: dead.pid }));
    assert.equal(await rebuildRunningCdn(lock, root), null);
    await assert.rejects(readFile(join(lock, 'owner.json')), { code: 'ENOENT' });
  } finally {
    await control?.close();
    await rm(run, { recursive: true, force: true });
  }
});
