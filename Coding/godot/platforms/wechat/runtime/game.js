require('./weapp-adapter.js');
require('./host_viewport.js')(wx, window);
require('./host_locale.js')(wx, window);
require('./godot-loader.js');

// 将宿主前后台事件交给引擎已有的焦点处理，取消页面中的未完成操作。
wx.onHide(() => document.dispatchEvent({ type: 'blur' }));
wx.onShow(() => document.dispatchEvent({ type: 'focus' }));
wx.onWindowResize(() => document.dispatchEvent({ type: 'resize' }));

let startupTimeout = setTimeout(() => {
  GameGlobal.reportStartupFailure(new Error('Startup exceeded 90 seconds.'));
}, 90_000);

GameGlobal.startupPhase = '正在加载引擎分包';
GameGlobal.setStartupPhase = function (phase) {
  GameGlobal.startupPhase = phase;
  console.log('[wechat] startup phase:', phase);
  if (GameGlobal.godotLoader) {
    GameGlobal.godotLoader.updateProgress(GameGlobal.godotLoader.progress, phase);
  }
};
GameGlobal.finishStartup = function () {
  clearTimeout(startupTimeout);
  console.log('[wechat] game started');
};
GameGlobal.reportStartupFailure = function (error) {
  if (GameGlobal.startupFailed) return;
  GameGlobal.startupFailed = true;
  clearTimeout(startupTimeout);
  const phase = GameGlobal.startupPhase;
  const reason = error && (error.errMsg || error.message) || String(error);
  const capabilities = `高性能=${!!GameGlobal.isIOSHighPerformanceMode}，WASM=${typeof GameGlobal.WXWebAssembly}`;
  console.error('[wechat] startup failed at', phase, error);
  wx.showModal({
    title: '加载失败',
    content: `游戏停在“${phase}”。${capabilities}。原因：${reason}`,
    showCancel: false,
  });
};
if (typeof wx.onError === 'function') wx.onError(GameGlobal.reportStartupFailure);
if (typeof wx.onUnhandledRejection === 'function') {
  wx.onUnhandledRejection(({ reason }) => GameGlobal.reportStartupFailure(reason));
}

// 由主包在引擎分包下载完成后明确启动脚本，避免依赖分包入口的自动执行时机。
let engineStarted = false;
GameGlobal.startEngine = function () {
  if (engineStarted || GameGlobal.startupFailed) return;
  engineStarted = true;
  try {
    require('./start_game.js');
  } catch (error) {
    GameGlobal.reportStartupFailure(error);
  }
};

const config = {
  textConfig: {
    firstStartText: '正在准备甜甜圈小铺',
    downloadingText: ['正在加载资源'],
    compilingText: '正在启动',
    initText: '正在打开小铺',
    completeText: '准备完成',
    textDuration: 1500,
    style: { color: '#ffffff', fontSize: 14 },
  },
  barConfig: {
    style: {
      width: 240, height: 16, backgroundColor: '#563b40',
      foregroundColor: '#f7baa1', borderRadius: 8, padding: 2,
    },
  },
  iconConfig: { visible: false, style: { width: 0, height: 0, bottom: 0 } },
  materialConfig: {},
};

try {
  GameGlobal.godotLoader = new GodotLoader(canvas, config);
} catch (error) {
  GameGlobal.reportStartupFailure(error);
}
