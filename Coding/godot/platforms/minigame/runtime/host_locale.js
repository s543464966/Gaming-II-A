// 读取宿主真实语言，避免小游戏启动器的固定 navigator.language 覆盖玩家设置。
module.exports = function installHostLocale(host, target) {
  target.__donutHostLocale = {
    read() {
      if (!host) return '';
      for (const api of ['getAppBaseInfo', 'getSystemInfoSync']) {
        try {
          const info = typeof host[api] === 'function' ? host[api]() : null;
          if (info && typeof info.language === 'string' && info.language.trim()) return info.language.trim();
        } catch (_) {}
      }
      return '';
    },
  };
};
