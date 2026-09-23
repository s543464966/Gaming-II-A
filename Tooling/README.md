# 工作区工具

使用 Node.js 20 或更新版本、Godot 4.5.1。`environment/engine.mjs` 读取工程 `tooling/engine.json`，优先使用 `GODOT_BIN`，再查找已准备的本地引擎，最后使用系统 Godot；不会自动下载依赖。

```sh
node Tooling/preview/preview.mjs
node Tooling/preview/preview.mjs home
node Tooling/preview/preview.mjs --check
```

默认运行完整 App，`home` 独立运行首页，`--check` 委托 `Testing/scripts/run_godot.mjs`。双击 `preview.command` 委托同一入口。关闭游戏窗口或按 Ctrl+C 结束预览；日志位于唯一 `Testing/.runtime/preview-*/`，成功退出清理，失败时保留并打印精确路径。

微信小游戏双击 `wechat.command` 打包，或执行唯一入口 `node Tooling/export/wechat.mjs`。每次更新固定项目 `Archive/Builds/wechat/`，保留本地调试设置；开发者工具只导入一次，以后打包后点击“编译”。可选 `--open` 委托开发者工具打开同一路径，双击打包本身不依赖服务端口。首次下载并校验固定版本微信模板，之后使用 `Tooling/.runtime/wechat/` 缓存；本机 Godot 不自动下载。完整操作与真机验收见 [微信测试说明](../Coding/godot/platforms/wechat/README.md)，无上传入口。

抖音小游戏双击 `douyin.command`，或运行 `node Tooling/export/douyin.mjs`，更新唯一的 `Archive/Builds/douyin/`。当前支持 AppID 留空的本地打包准备，不创建开发者工具项目；操作、官方依赖与验收边界见 [抖音打包说明](../Coding/godot/platforms/douyin/README.md)。

每个平台有一个 `Tooling/<平台>.command` 薄入口，委托 `Tooling/export/<平台>.mjs`。微信和抖音通过 `export/minigame.mjs` 共用资源导出、验证与固定目录替换；各自的模板和宿主配置保持独立。TapTap 接入时沿用固定目录约定，当前尚未实现。

`data/subset_ui_font.py` 只在维护随包中文字体时使用；字体来源、依赖与再生成方法见 [字体说明](../Coding/godot/ui/design_system/fonts/README.md)。
