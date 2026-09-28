// 注册窄宿主接口供 Godot 直接调用；小游戏禁止 eval，因此不动态执行脚本文本。
module.exports = function installHostViewport(host, target) {
  target.__donutHostViewport = {
    read() {
      if (!host) return '{}';
      let info;
      try {
        info = typeof host.getWindowInfo === 'function' ? host.getWindowInfo() : host.getSystemInfoSync();
      } catch (_) { return '{}'; }
      let menu = {};
      try {
        if (typeof host.getMenuButtonBoundingClientRect === 'function') menu = host.getMenuButtonBoundingClientRect();
        else if (typeof host.getMenuButtonLayout === 'function') menu = host.getMenuButtonLayout();
      } catch (_) {}
      return JSON.stringify({
        width: info.windowWidth || info.screenWidth,
        height: info.windowHeight || info.screenHeight,
        safeArea: info.safeArea || {}, statusBarHeight: info.statusBarHeight || 0, menu: menu || {},
      });
    },
  };
};
