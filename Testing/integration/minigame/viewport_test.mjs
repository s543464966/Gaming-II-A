import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import vm from 'node:vm';

const source = await readFile(new URL('../../../Coding/godot/platforms/minigame/runtime/host_viewport.js', import.meta.url), 'utf8');
const readMetrics = scope => {
  const sandbox = { module: { exports: {} }, eval: undefined };
  vm.runInNewContext(source, sandbox);
  const target = {};
  sandbox.module.exports(scope.tt || scope.wx, target);
  return JSON.parse(target.__donutHostViewport.read());
};

test('Godot host bridge reads window units, safe area and menu on both mini-game platforms', () => {
  const info = { screenWidth: 393, screenHeight: 852, windowWidth: 390, windowHeight: 844,
    pixelRatio: 3, safeArea: { left: 0, top: 59, right: 390, bottom: 810 }, statusBarHeight: 54 };
  const menu = { left: 300, top: 60, width: 80, height: 32, bottom: 92 };
  for (const scope of [
    { tt: { getSystemInfoSync: () => info, getMenuButtonLayout: () => menu } },
    { wx: { getWindowInfo: () => info, getMenuButtonBoundingClientRect: () => menu } },
  ]) {
    assert.deepEqual(readMetrics(scope), { width: 390, height: 844, safeArea: info.safeArea, statusBarHeight: 54, menu });
  }
});

test('unavailable host APIs fall back without blocking startup', () => {
  assert.deepEqual(readMetrics({}), {});
  assert.deepEqual(readMetrics({ tt: { getSystemInfoSync() { throw new Error('unsupported'); } } }), {});
  const result = readMetrics({ wx: { getSystemInfoSync: () => ({ screenWidth: 360, screenHeight: 640 }),
    getMenuButtonBoundingClientRect() { throw new Error('unsupported'); } } });
  assert.deepEqual(result, { width: 360, height: 640, safeArea: {}, statusBarHeight: 0, menu: {} });
});
