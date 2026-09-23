import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { test } from 'node:test';
import vm from 'node:vm';
import { launcherConfig, validateAppId } from '../../../Tooling/export/douyin.mjs';
import { packageSizes } from '../../../Tooling/export/minigame.mjs';

const root = resolve(import.meta.dirname, '../../..');
const platform = join(root, 'Coding/godot/platforms/douyin');

test('tools-only export allows an unbound AppID and rejects WeChat IDs', () => {
  for (const value of ['', 'tt0123456789abcdef', 'tt0123456789abcdef01']) assert.doesNotThrow(() => validateAppId(value));
  for (const value of [null, undefined, 123, 'tt', 'wx0123456789abcdef', 'tt bad']) assert.throws(() => validateAppId(value));
});

test('official launcher paths and the declared subpackage agree', async () => {
  const lock = JSON.parse(await readFile(join(root, 'Tooling/export/douyin_template.json')));
  const game = JSON.parse(await readFile(join(platform, 'game.json')));
  const config = launcherConfig(lock.engine);
  assert.deepEqual(config.subpackages, game.subpackages.map(item => item.name));
  assert.deepEqual(lock.subpackages, game.subpackages.map(item => item.root));
  assert.equal(game.deviceOrientation, 'portrait');
  assert.equal(game.enableWebGL2, true);
  assert.equal(config.mainPack, 'godot/main.bin');
  assert.equal(config.mainWasm, 'godot/godot.wasm.br');
  assert.equal(config.godotModule, 'godot/godot.js');
});

test('launcher receives a pixel-sized canvas; startup errors and host focus are handled', async () => {
  const source = await readFile(join(platform, 'runtime/game.js'), 'utf8');
  for (const mode of ['success', 'throws', 'rejects', 'unsupported']) {
    const events = [];
    const handlers = {};
    const errors = [];
    const messages = [];
    const canvas = { dispatchEvent: event => events.push(event.type) };
    let startCount = 0;
    const scope = {
      console: { log: value => messages.push(value), error() {} },
      tt: {
        getSystemInfoSync: () => ({ screenWidth: 390, screenHeight: 844, pixelRatio: 3 }),
        createCanvas: () => canvas,
        onHide: fn => { handlers.hide = fn; }, onShow: fn => { handlers.show = fn; },
        showModal: options => errors.push(options),
      },
      require(name) {
        if (name === './godot.config.js') return launcherConfig('4.5.1');
        assert.equal(name, './godot.launcher.js');
        return { start(options) {
          startCount++;
          assert.equal(options.canvas.width, 1170);
          assert.equal(options.canvas.height, 2532);
          assert.equal(options.config.mainPack, 'godot/main.bin');
          if (mode === 'throws') throw new Error('sync error');
          if (mode === 'rejects') return Promise.reject(new Error('async error'));
          if (mode === 'unsupported') return undefined;
          return Promise.resolve();
        } };
      },
    };
    vm.runInNewContext(source, scope);
    await new Promise(done => setImmediate(done));
    assert.equal(startCount, 1);
    handlers.hide(); handlers.show();
    assert.deepEqual(events, ['blur', 'focus']);
    assert.equal(errors.length, mode === 'success' ? 0 : 1, mode);
    assert.equal(messages.includes('[douyin] game started'), mode === 'success');
  }
});

test('Douyin accounts for its godot subpackage and enforces the 20 MiB total budget', async () => {
  const parent = join(root, 'Testing/.runtime');
  await mkdir(parent, { recursive: true });
  const run = await mkdtemp(join(parent, 'douyin-budget-test-'));
  try {
    const lock = JSON.parse(await readFile(join(root, 'Tooling/export/douyin_template.json')));
    assert.equal(lock.budgets.total, 20 * 1024 * 1024);
    await mkdir(join(run, 'godot'));
    await writeFile(join(run, 'game.js'), 'main');
    await writeFile(join(run, 'godot/main.bin'), Buffer.alloc(20));
    assert.deepEqual(await packageSizes(run, lock), { main: 4, godot: 20, total: 24 });
    await assert.rejects(packageSizes(run, { ...lock, budgets: { ...lock.budgets, total: 23 } }), /total/);
  } finally { await rm(run, { recursive: true, force: true }); }
});

test('Douyin packaging offers no IDE creation, open or upload command', () => {
  for (const option of ['--open', '--upload']) {
    const result = spawnSync(process.execPath, [join(root, 'Tooling/export/douyin.mjs'), option], { encoding: 'utf8' });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /Usage:/);
  }
});
