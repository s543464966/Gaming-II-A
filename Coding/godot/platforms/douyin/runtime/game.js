function reportStartupFailure(error) {
  console.error('[douyin] startup failed', error);
  tt.showModal({ title: '加载失败', content: '游戏资源未能加载，请退出后重试。', showCancel: false });
}

let gameCanvas;
require('./host_viewport.js')(tt, globalThis);
require('./host_locale.js')(tt, globalThis);

// 画布像素尺寸与逻辑窗口保持同一宽高比；设备切换后同步启动器模拟的浏览器窗口。
function resizeCanvas(event) {
  if (!gameCanvas) return;
  const info = tt.getSystemInfoSync();
  const size = event && (event.size || event) || {};
  const width = size.windowWidth || info.windowWidth || info.screenWidth;
  const height = size.windowHeight || info.windowHeight || info.screenHeight;
  const ratio = info.pixelRatio || 1;
  if (gameCanvas.width !== Math.round(width * ratio)) gameCanvas.width = Math.round(width * ratio);
  if (gameCanvas.height !== Math.round(height * ratio)) gameCanvas.height = Math.round(height * ratio);
  if (typeof window !== 'undefined') {
    window.innerWidth = width;
    window.innerHeight = height;
    window.devicePixelRatio = ratio;
    gameCanvas.clientWidth = width;
    gameCanvas.clientHeight = height;
    if (typeof window.dispatchEvent === 'function') window.dispatchEvent({ type: 'resize' });
  }
}
if (typeof tt.onWindowResize === 'function') tt.onWindowResize(resizeCanvas);
const sidebar = {
  available: typeof tt.navigateToScene === 'function',
  open() {
    if (!this.available) return false;
    tt.navigateToScene({
      scene: 'sidebar',
      fail: error => {
        console.warn('[douyin] sidebar navigation failed', error);
        tt.showToast({ title: '暂时无法打开侧边栏', icon: 'none' });
      },
    });
    return true;
  },
};
globalThis.__donutDouyinSidebar = sidebar;
if (typeof tt.checkScene === 'function') {
  tt.checkScene({
    scene: 'sidebar',
    success: result => { sidebar.available = !!result.isExist; },
    fail: error => { console.warn('[douyin] sidebar availability check failed', error); },
  });
}
// 在游戏入口同步监听前后台与侧边栏回访，保证热启动也能恢复画布焦点。
tt.onHide(() => {
  if (gameCanvas && typeof gameCanvas.dispatchEvent === 'function') gameCanvas.dispatchEvent({ type: 'blur' });
});
tt.onShow(options => {
  sidebar.fromSidebar = !!options && options.launch_from === 'homepage' && options.location === 'sidebar_card';
  resizeCanvas();
  if (gameCanvas && typeof gameCanvas.dispatchEvent === 'function') gameCanvas.dispatchEvent({ type: 'focus' });
});

// 使用随包的官方启动器，版本与构建锁定文件一致。
Promise.resolve().then(() => {
  const canvas = tt.createCanvas();
  gameCanvas = canvas;
  resizeCanvas();
  const launcher = require('./godot.launcher.js');
  const startup = launcher.start({ canvas, config: require('./godot.config.js') });
  if (!startup || typeof startup.then !== 'function') throw new Error('Godot launcher did not start.');
  return startup;
}).then(() => console.log('[douyin] game started')).catch(reportStartupFailure);
