require('./godot-sdk.js');
require('./godot.js');

// 引擎和关卡资源分别下载，所有资源随测试包提供，无需外部资源服务器。
wx.loadSubpackage({
  name: 'content',
  success() {
    Promise.resolve()
      .then(() => {
        const startup = GODOTSDK.startGame('/engine/godot', '/content/game_pack.bin');
        if (!startup || typeof startup.then !== 'function') throw new Error('WebGL engine could not start.');
        return startup;
      })
      .then(() => console.log('[wechat] game started'))
      .catch(GameGlobal.reportStartupFailure);
  },
  fail: GameGlobal.reportStartupFailure,
});
