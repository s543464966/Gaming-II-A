# New Project

用于新项目的可运行 Godot 骨架。暂用名称 `New Project`，保留 Godot 4.5.1、Compatibility 渲染和 720×1280 竖屏设置。

使用 Godot 打开 `project.godot`，F5 运行 App，显示空白 Home 页和项目标题。Home 场景也可直接用 F6 预览。当前没有玩法、账号、存档读写、素材、数据管线或平台 SDK。

App 持续拥有 `Services`、`SceneContainer` 和 `Overlay`；Home 位于 `SceneContainer`。服务和浮层容器当前为空，不挂载 Autoload。基础 Theme 使用 Godot 自带字体。

`bootstrap/`、`features/`、`game_content/`、`services/`、`platforms/`、`ui/`、`tooling/`、`addons/` 保留原有职责分层；原业务分类通过 `.gitkeep` 留下目录，目录存在不表示对应功能已实现。新玩法明确后再调整这些分类。

从工作区根运行：

```sh
node Tooling/preview/preview.mjs
node Tooling/preview/preview.mjs home
node Testing/scripts/run_godot.mjs architecture home
```

双击 `Tooling/preview.command` 也可启动。`GODOT_BIN` 可以指定引擎；默认优先使用工作区已有的 4.5.1，其次使用本机 Godot。检查使用独立项目副本，诊断位于 `Testing/.runtime/`。

旧数据、导出预设、抖音 SDK 和上传入口已移除，当前没有可用导出流程。平台目录仅保留位置。Git 边界见 [GIT.md](GIT.md)。
