# Gaming-II-A

新项目的 Godot 工程骨架。仓库根统一管理工程、工具、测试和项目规则；Godot 内暂用名称 `New Project`，当前不包含玩法或游戏素材。

## 运行

使用 Godot 4.5.1 打开 `Coding/godot/project.godot`，按 F5 运行空白首页。工程保留 Compatibility 渲染和 720×1280 竖屏设置。

安装 Node.js 20 或更新版本后，可从仓库根执行：

```sh
node Tooling/preview/preview.mjs
node Testing/scripts/run_godot.mjs architecture home
```

可通过 `GODOT_BIN` 指定 Godot 可执行文件；工具不会自动下载安装引擎。macOS 也可双击 `Tooling/preview.command`。

## 目录

| 目录 | 内容 |
| --- | --- |
| `Coding/godot/` | Godot 工程、App/Home 场景和业务分类占位 |
| `Tooling/` | 预览与引擎选择工具 |
| `Testing/` | 场景装配检查和隔离测试入口 |
| `Archive/` | 策划数据、参考图和构建产物的目录框架 |
| `.agents/`、`AGENTS.md` | 项目技能与协作规则 |

缓存、日志、构建包、本机设置和凭据由根 `.gitignore` 排除。旧平台 SDK 和导出流程已移除，后续按新项目需求接入。

工程说明见 [Godot README](Coding/godot/README.md)，仓库边界见 [GIT.md](Coding/godot/GIT.md)。
