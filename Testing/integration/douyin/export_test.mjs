import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { test } from 'node:test';
import vm from 'node:vm';
import { launcherConfig, patchLauncherViewport, validateAppId } from '../../../Tooling/export/douyin.mjs';
import { packageSizes } from '../../../Tooling/export/minigame.mjs';
import installHostViewport from '../../../Coding/godot/platforms/minigame/runtime/host_viewport.js';

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
  assert.equal(config.mainPack, 'godot/main.br');
  assert.equal(config.mainWasm, 'godot/godot.wasm.br');
  assert.equal(config.godotModule, 'godot/godot.js');
});

test('pinned launcher uses actual window width instead of forming a square on portrait phones', () => {
  const original = '(function(e){return {screenWidth:e.screenHeight,screenHeight:e.screenHeight,devicePixelRatio:e.pixelRatio}})(info)';
  for (const info of [
    { screenWidth: 393, screenHeight: 852, pixelRatio: 3 },
    { screenWidth: 360, screenHeight: 800, pixelRatio: 2 },
    { screenWidth: 768, screenHeight: 1024, windowWidth: 600, windowHeight: 900, pixelRatio: 2 },
  ]) {
    const broken = vm.runInNewContext(original, { info });
    assert.equal(broken.screenWidth, broken.screenHeight, 'Regression fixture no longer reproduces the square canvas');
    const fixed = vm.runInNewContext(patchLauncherViewport(original), { info });
    assert.equal(fixed.screenWidth, info.windowWidth || info.screenWidth);
    assert.equal(fixed.screenHeight, info.windowHeight || info.screenHeight);
  }
  assert.throws(() => patchLauncherViewport('changed upstream code'), /contract changed/);
  assert.throws(() => patchLauncherViewport(original + original), /contract changed/);
});

test('launcher receives a pixel-sized canvas; startup errors and host focus are handled', async () => {
  const source = await readFile(join(platform, 'runtime/game.js'), 'utf8');
  for (const mode of ['success', 'throws', 'rejects', 'unsupported']) {
    const events = [];
    const handlers = {};
    const errors = [];
    const messages = [];
    const navigations = [];
    const canvas = { dispatchEvent: event => events.push(event.type) };
    const windowEvents = [];
    let info = { screenWidth: 390, screenHeight: 844, pixelRatio: 3 };
    let startCount = 0;
    const scope = {
      console: { log: value => messages.push(value), error() {} },
      window: { dispatchEvent: event => windowEvents.push(event.type) },
      tt: {
        getSystemInfoSync: () => info,
        createCanvas: () => canvas,
        onHide: fn => { handlers.hide = fn; }, onShow: fn => { handlers.show = fn; },
        onWindowResize: fn => { handlers.resize = fn; },
        checkScene: options => options.success({ isExist: true }),
        navigateToScene: options => navigations.push(options.scene),
        showModal: options => errors.push(options),
      },
      require(name) {
        if (name === './host_viewport.js') return installHostViewport;
        if (name === './godot.config.js') return launcherConfig('4.5.1');
        assert.equal(name, './godot.launcher.js');
        return { start(options) {
          startCount++;
          assert.equal(options.canvas.width, 1170);
          assert.equal(options.canvas.height, 2532);
          assert.equal(options.config.mainPack, 'godot/main.br');
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
    assert.equal(scope.__donutDouyinSidebar.available, true);
    assert.equal(scope.__donutDouyinSidebar.open(), true);
    assert.deepEqual(navigations, ['sidebar']);
    handlers.show({ launch_from: 'homepage', location: 'sidebar_card' });
    assert.equal(scope.__donutDouyinSidebar.fromSidebar, true);
    info = { screenWidth: 768, screenHeight: 1024, windowWidth: 600, windowHeight: 900, pixelRatio: 2 };
    handlers.resize({ windowWidth: 600, windowHeight: 900 });
    assert.equal(canvas.width, 1200);
    assert.equal(canvas.height, 1800);
    assert.equal(canvas.clientWidth, 600);
    assert.equal(canvas.clientHeight, 900);
    assert.equal(scope.window.innerWidth, 600);
    assert.equal(scope.window.innerHeight, 900);
    assert.equal(scope.window.devicePixelRatio, 2);
    assert.ok(windowEvents.includes('resize'));
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
