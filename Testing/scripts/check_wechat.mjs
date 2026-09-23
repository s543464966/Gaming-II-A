import { resolve } from 'node:path';

// 保留原微信检查入口，统一委托平台无关的真实资源包检查。
if (process.argv.length !== 3) {
  console.error('Usage: node Testing/scripts/check_wechat.mjs <exported-game-directory>');
  process.exitCode = 1;
} else {
  process.argv[2] = resolve(process.argv[2], 'content/game_pack.bin');
  await import('./check_minigame.mjs');
}
