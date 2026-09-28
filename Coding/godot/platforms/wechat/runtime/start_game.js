GameGlobal.setStartupPhase('正在载入引擎适配脚本');
require('./godot-sdk.js');
GameGlobal.setStartupPhase('正在载入 Godot 脚本');
require('./godot.js');

// 引擎和关卡资源分别下载，所有资源随测试包提供，无需外部资源服务器。
GameGlobal.setStartupPhase('正在下载关卡资源');
console.log('[wechat] iOS high performance:', !!GameGlobal.isIOSHighPerformanceMode);
const contentTask = wx.loadSubpackage({
  name: 'content',
  success() {
    GameGlobal.setStartupPhase('正在初始化游戏引擎');
    Promise.resolve()
      .then(() => {
        GameGlobal.setStartupPhase('正在检查 WebGL 并启动引擎');
        const startup = GODOTSDK.startGame('/engine/godot', '/content/game_pack.bin');
        if (!startup || typeof startup.then !== 'function') throw new Error('WebGL engine could not start.');
        return startup;
      })
      .then(GameGlobal.finishStartup)
      .catch(GameGlobal.reportStartupFailure);
  },
  fail: GameGlobal.reportStartupFailure,
});
if (contentTask && typeof contentTask.onProgressUpdate === 'function') {
  let lastStep = -1;
  contentTask.onProgressUpdate(({ progress }) => {
    const step = Math.floor(progress / 10);
    if (step !== lastStep && progress < 100) {
      lastStep = step;
      GameGlobal.setStartupPhase(`正在下载关卡资源 ${progress}%`);
    }
  });
}
