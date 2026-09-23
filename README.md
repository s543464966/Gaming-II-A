# Gaming-II-A

甜甜圈小铺的 Godot 工程，已实现三关完整排序、独立需求、有限整盒备货、特殊盒与连单奖励。仓库根统一管理工程、工具、测试和项目规则。

## 运行

使用 Godot 4.5.1 打开 `Coding/godot/project.godot`，按 F5 进入首关。工程保留 Compatibility 渲染和 720×1280 竖屏设置。按住甜甜圈拖到空盒或同口味餐盒松手，成组搬运并按容量拆分。也保留先点来源盒、再点目标盒的操作。四颗同味匹配开放需求后自动打包回收，并由备货原位补盒；设置中可切换三关。

安装 Node.js 20 或更新版本后，可从仓库根执行：

```sh
node Tooling/preview/preview.mjs
node Testing/scripts/run_godot.mjs architecture home donut
```

可通过 `GODOT_BIN` 指定 Godot 可执行文件；工具不会自动下载安装引擎。macOS 也可双击 `Tooling/preview.command`。

## 目录

| 目录 | 内容 |
| --- | --- |
| `Coding/godot/` | Godot 工程、甜甜圈玩法、素材、Theme 与引擎基线 |
| `Tooling/` | 预览、微信／抖音测试包导出与引擎选择工具 |
| `Testing/` | 场景装配、三关完整解、规则和交互生命周期检查 |
| [`Designing/`](Designing/README.md) | 项目策划、玩法与关卡设计、UI 与美术说明、设计决策和验收记录 |
| `Archive/` | 设计参考图和构建产物 |
| `.agents/`、`AGENTS.md` | 项目技能与协作规则 |

双击 `Tooling/wechat.command` 或 `Tooling/douyin.command`，分别更新 `Archive/Builds/wechat/`、`Archive/Builds/douyin/` 固定目录。命令行入口和验收说明见 [微信测试说明](Coding/godot/platforms/wechat/README.md)、[抖音打包说明](Coding/godot/platforms/douyin/README.md)。缓存、日志、构建包、本机设置和凭据由根 `.gitignore` 排除。

工程说明见 [Godot README](Coding/godot/README.md)，仓库边界见 [GIT.md](Coding/godot/GIT.md)。
