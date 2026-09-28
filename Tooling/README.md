# 工作区工具

使用 Node.js 20 或更新版本、Godot 4.5.1。`environment/engine.mjs` 读取工程 `tooling/engine.json`，优先使用 `GODOT_BIN`，再查找已准备的本地引擎，最后使用系统 Godot；不会自动下载依赖。

```sh
node Tooling/preview/preview.mjs
node Tooling/preview/preview.mjs home
node Tooling/preview/preview.mjs --check
```

默认运行完整 App，`home` 独立运行首页，`--check` 委托 `Testing/scripts/run_godot.mjs`。双击 `preview.command` 委托同一入口。本地预览运行时监听 Godot 工程；保存脚本、场景或素材后自动重新导入并启动游戏，当前关卡状态会重置。关闭游戏窗口或按 Ctrl+C 结束预览；日志位于唯一 `Testing/.runtime/preview-*/`，成功退出清理，失败时保留并打印精确路径。

微信小游戏双击 `wechat.command` 打包，或执行唯一入口 `node Tooling/export/wechat.mjs`。每次更新固定项目 `Archive/Builds/wechat/`，保留本地调试设置；开发者工具只导入一次，以后打包后点击“编译”。可选 `--open` 委托开发者工具打开同一路径，双击打包本身不依赖服务端口。首次下载并校验固定版本微信模板，之后使用 `Tooling/.runtime/wechat/` 缓存；本机 Godot 不自动下载。完整操作与真机验收见 [微信测试说明](../Coding/godot/platforms/wechat/README.md)，无上传入口。

抖音小游戏双击 `douyin.command`，或运行 `node Tooling/export/douyin.mjs`，更新唯一的 `Archive/Builds/douyin/`。非启动贴图自动分块放到 `Archive/Builds/douyin.cdn/`，避免持续挤占 20 MiB 小游戏包。`auto` 在没有正式 CDN 时使用仅本机模拟器服务；手机测试可在被 Git 忽略的 `export/douyin.local.json` 中设置 `delivery_mode: cloudflare-cdn`，让同一个打包入口启动或复用 Cloudflare 临时 HTTPS，资源会经 Cloudflare 对外提供。也可双击 `douyin_cdn_test.command` 显式选择该模式。保持电脑和服务窗口运行，在原有抖音开发者工具项目编译、扫码测试；重复双击复用同一模式服务并重新打包。当前 AppID 为 `tt0da47b1993dcc5c602`，域名测试设置、正式 CDN 和显式离线模式见 [抖音打包说明](../Coding/godot/platforms/douyin/README.md)。

每个平台有一个 `Tooling/<平台>.command` 薄入口，委托 `Tooling/export/<平台>.mjs`。微信和抖音通过 `export/minigame.mjs` 共用资源导出、验证与固定目录替换；各自的模板和宿主配置保持独立。TapTap 接入时沿用固定目录约定，当前尚未实现。

`data/subset_ui_font.py` 只在维护随包中文字体时使用；字体来源、依赖与再生成方法见 [字体说明](../Coding/godot/design_system/fonts/README.md)。
