import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { test } from 'node:test';
import vm from 'node:vm';
import { validateAppId } from '../../../Tooling/export/wechat.mjs';
import installHostViewport from '../../../Coding/godot/platforms/minigame/runtime/host_viewport.js';

const root = resolve(import.meta.dirname, '../../..');
const runtime = join(root, 'Coding/godot/platforms/wechat/runtime');

test('new-project AppID must be explicit and well formed', () => {
  for (const invalid of ['', 'touristappid', 'wx000', null]) assert.throws(() => validateAppId(invalid));
  assert.doesNotThrow(() => validateAppId('wx0123456789abcdef'));
});

test('host background and foreground reach engine focus listeners', async () => {
  const events = [];
  const handlers = {};
  const modals = [];
  let watchdog;
  let cancelled = false;
  const scope = {
    require(name) { if (name === './host_viewport.js') return installHostViewport; },
    window: {}, GameGlobal: {}, canvas: {}, console: { error() {}, log() {} },
    document: { dispatchEvent: event => events.push(event.type) },
    GodotLoader: class { progress = 0; updateProgress(_progress, phase) { events.push(phase); } },
    setTimeout: (callback, delay) => { assert.equal(delay, 90_000); watchdog = callback; return 1; },
    clearTimeout: () => { cancelled = true; },
    wx: {
      onHide: fn => { handlers.hide = fn; },
      onShow: fn => { handlers.show = fn; },
      onWindowResize: fn => { handlers.resize = fn; },
      onError: fn => { handlers.error = fn; },
      onUnhandledRejection: fn => { handlers.rejection = fn; },
      showModal: options => modals.push(options),
    },
  };
  vm.runInNewContext(await readFile(join(runtime, 'game.js'), 'utf8'), scope);
  handlers.hide(); handlers.show(); handlers.resize();
  assert.deepEqual(events, ['blur', 'focus', 'resize']);
  scope.GameGlobal.setStartupPhase('正在下载关卡资源');
  scope.GameGlobal.reportStartupFailure(new Error('startup timeout'));
  scope.GameGlobal.reportStartupFailure(new Error('duplicate error'));
  assert.equal(modals.length, 1);
  assert.match(modals[0].content, /正在下载关卡资源/);
  assert.match(modals[0].content, /startup timeout/);
  assert.equal(cancelled, true);

  const stalled = { ...scope, GameGlobal: {}, wx: scope.wx };
  vm.runInNewContext(await readFile(join(runtime, 'game.js'), 'utf8'), stalled);
  watchdog();
  assert.match(modals.at(-1).content, /正在加载引擎分包/);
});

test('main package starts engine scripts once after engine resources load', async () => {
  const mainSource = await readFile(join(runtime, 'game.js'), 'utf8');
  const startSource = await readFile(join(runtime, 'start_game.js'), 'utf8');
  for (const mode of ['success', 'download-failed', 'engine-throws', 'engine-rejects', 'unsupported-webgl', 'script-throws']) {
    let request;
    let starts = 0;
    const loaded = [];
    const phases = [];
    const modals = [];
    let completed = false;
    const scope = {
      require(path) {
        loaded.push(path);
        if (path === './host_viewport.js') return installHostViewport;
        if (path === './start_game.js') vm.runInNewContext(startSource, scope);
        if (path === './godot.js' && mode === 'script-throws') throw new Error('engine module unavailable');
      },
      window: {}, GameGlobal: {}, canvas: {}, console: { log() {}, error() {} },
      document: { dispatchEvent() {} },
      GodotLoader: class {
        progress = 0;
        updateProgress(_progress, phase) { phases.push(phase); }
      },
      setTimeout: () => 1,
      clearTimeout: () => { completed = true; },
      wx: {
        onHide() {}, onShow() {}, onWindowResize() {},
        showModal: options => modals.push(options),
        loadSubpackage: options => { request = options; },
      },
      GODOTSDK: { startGame: (engine, pack) => {
        starts++;
        assert.equal(engine, '/engine/godot');
        assert.equal(pack, '/content/game_pack.bin');
        if (mode === 'engine-throws') throw new Error('sync failure');
        if (mode === 'engine-rejects') return Promise.reject(new Error('async failure'));
        if (mode === 'unsupported-webgl') return undefined;
        return Promise.resolve();
      } },
    };
    vm.runInNewContext(mainSource, scope);
    assert.equal(starts, 0);
    scope.GameGlobal.startEngine();
    scope.GameGlobal.startEngine();
    if (mode !== 'script-throws') {
      assert.equal(request.name, 'content');
      if (mode === 'download-failed') request.fail(new Error('download failure'));
      else request.success();
    }
    await new Promise(resolveDone => setImmediate(resolveDone));
    assert.equal(loaded.filter(path => path === './start_game.js').length, 1, mode);
    assert.equal(starts, ['download-failed', 'script-throws'].includes(mode) ? 0 : 1);
    assert.equal(modals.length, mode === 'success' ? 0 : 1, mode);
    assert.equal(completed, true);
    assert.deepEqual(phases.slice(0, mode === 'script-throws' ? 2 : 3),
      mode === 'script-throws'
        ? ['正在载入引擎适配脚本', '正在载入 Godot 脚本']
        : ['正在载入引擎适配脚本', '正在载入 Godot 脚本', '正在下载关卡资源']);
    if (!['download-failed', 'script-throws'].includes(mode)) {
      assert.equal(phases.at(-1), '正在检查 WebGL 并启动引擎');
    }
    if (mode === 'script-throws') assert.match(modals[0].content, /engine module unavailable/);
  }
});
