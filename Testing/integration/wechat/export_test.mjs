import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { test } from 'node:test';
import vm from 'node:vm';
import { validateAppId } from '../../../Tooling/export/wechat.mjs';

const root = resolve(import.meta.dirname, '../../..');
const runtime = join(root, 'Coding/godot/platforms/wechat/runtime');

test('new-project AppID must be explicit and well formed', () => {
  for (const invalid of ['', 'touristappid', 'wx000', null]) assert.throws(() => validateAppId(invalid));
  assert.doesNotThrow(() => validateAppId('wx0123456789abcdef'));
});

test('host background and foreground reach engine focus listeners', async () => {
  const events = [];
  const handlers = {};
  const scope = {
    require() {}, GameGlobal: {}, canvas: {}, console,
    document: { dispatchEvent: event => events.push(event.type) },
    GodotLoader: class {},
    wx: {
      onHide: fn => { handlers.hide = fn; },
      onShow: fn => { handlers.show = fn; },
      onWindowResize: fn => { handlers.resize = fn; },
    },
  };
  vm.runInNewContext(await readFile(join(runtime, 'game.js'), 'utf8'), scope);
  handlers.hide(); handlers.show(); handlers.resize();
  assert.deepEqual(events, ['blur', 'focus', 'resize']);
});

test('resource download gates engine startup; both startup failure paths are visible', async () => {
  const source = await readFile(join(runtime, 'engine_game.js'), 'utf8');
  for (const mode of ['success', 'download-failed', 'engine-throws', 'engine-rejects', 'unsupported-webgl']) {
    let request;
    let starts = 0;
    const failures = [];
    const scope = {
      require() {}, console: { log() {} },
      GameGlobal: { reportStartupFailure: error => failures.push(error) },
      wx: { loadSubpackage: options => { request = options; } },
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
    vm.runInNewContext(source, scope);
    assert.equal(starts, 0);
    assert.equal(request.name, 'content');
    if (mode === 'download-failed') request.fail(new Error('download failure'));
    else request.success();
    await new Promise(resolveDone => setImmediate(resolveDone));
    assert.equal(starts, mode === 'download-failed' ? 0 : 1);
    assert.equal(failures.length, mode === 'success' ? 0 : 1, mode);
  }
});

