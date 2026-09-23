function reportStartupFailure(error) {
  console.error('[douyin] startup failed', error);
  tt.showModal({ title: '加载失败', content: '游戏资源未能加载，请退出后重试。', showCancel: false });
}

// 使用随包的官方启动器，版本与构建锁定文件一致。
Promise.resolve().then(() => {
  const info = tt.getSystemInfoSync();
  const canvas = tt.createCanvas();
  canvas.width = info.screenWidth * info.pixelRatio;
  canvas.height = info.screenHeight * info.pixelRatio;
  // Godot 在画布上监听焦点，用宿主事件取消后台期间的未完成输入。
  tt.onHide(() => canvas.dispatchEvent?.({ type: 'blur' }));
  tt.onShow(() => canvas.dispatchEvent?.({ type: 'focus' }));
  const launcher = require('./godot.launcher.js');
  const startup = launcher.start({ canvas, config: require('./godot.config.js') });
  if (!startup || typeof startup.then !== 'function') throw new Error('Godot launcher did not start.');
  return startup;
}).then(() => console.log('[douyin] game started')).catch(reportStartupFailure);
