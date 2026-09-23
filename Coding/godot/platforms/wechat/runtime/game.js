require('./weapp-adapter.js');
require('./godot-loader.js');

// 将宿主前后台事件交给引擎已有的焦点处理，取消页面中的未完成操作。
wx.onHide(() => document.dispatchEvent({ type: 'blur' }));
wx.onShow(() => document.dispatchEvent({ type: 'focus' }));
wx.onWindowResize(() => document.dispatchEvent({ type: 'resize' }));

GameGlobal.reportStartupFailure = function (error) {
  console.error('[wechat] startup failed', error);
  wx.showModal({
    title: '加载失败',
    content: '游戏资源未能加载，请退出后重试。',
    showCancel: false,
  });
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

GameGlobal.godotLoader = new GodotLoader(canvas, config);
