# 工作区工具

使用 Node.js 20 或更新版本、Godot 4.5.1。`environment/engine.mjs` 读取工程 `tooling/engine.json`，优先使用 `GODOT_BIN`，再查找已准备的本地引擎，最后使用系统 Godot；不会自动下载依赖。

```sh
node Tooling/preview/preview.mjs
node Tooling/preview/preview.mjs home
node Tooling/preview/preview.mjs --check
```

默认运行完整 App，`home` 独立运行首页，`--check` 委托 `Testing/scripts/run_godot.mjs`。双击 `preview.command` 委托同一入口。关闭游戏窗口或按 Ctrl+C 结束预览；日志位于唯一 `Testing/.runtime/preview-*/`，成功退出清理，失败时保留并打印精确路径。

`data/`、`export/` 保留目录占位。旧数据制作、资源服务器、CDN 测试和导出入口已移除；当前没有导出或上传能力。`Tooling/.runtime/godot-platform/` 只保留已下载的 Godot 引擎，旧项目预览和导出缓存已清理。
