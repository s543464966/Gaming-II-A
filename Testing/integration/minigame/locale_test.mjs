import assert from 'node:assert/strict';
import { test } from 'node:test';
import installHostLocale from '../../../Coding/godot/platforms/minigame/runtime/host_locale.js';

const readLocale = host => {
  const target = { navigator: { language: 'zh_CN' } };
  installHostLocale(host, target);
  return target.__donutHostLocale.read();
};

test('host language takes precedence over the launcher default for Chinese and English', () => {
  for (const language of ['zh_CN', 'zh-Hans', 'en', 'en-US']) {
    assert.equal(readLocale({ getAppBaseInfo: () => ({ language }), getSystemInfoSync: () => ({ language: 'zh_CN' }) }), language);
    assert.equal(readLocale({ getSystemInfoSync: () => ({ language }) }), language);
  }
});

test('missing or failed modern API falls back to the legacy host without preventing startup', () => {
  assert.equal(readLocale({ getAppBaseInfo() { throw new Error('unsupported'); }, getSystemInfoSync: () => ({ language: 'en' }) }), 'en');
  assert.equal(readLocale({ getAppBaseInfo: () => ({ language: ' ' }), getSystemInfoSync: () => ({ language: ' zh_CN ' }) }), 'zh_CN');
  for (const host of [null, {}, { getSystemInfoSync() { throw new Error('unavailable'); } }, { getAppBaseInfo: () => ({ language: 123 }) }]) {
    assert.equal(readLocale(host), '');
  }
});
