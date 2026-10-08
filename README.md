# Gaming-II-A

甜甜圈小铺的 Godot 工程，已实现 100 关首轮可玩内容、独立需求、有限整盒备货、特殊盒与连单奖励。百关机制、验证和待试玩项目见 [实现与验收](Designing/level_100_implementation.md)。仓库根统一管理工程、工具、测试和项目规则。

## 策划与开发

策划与开发统一在本仓库进行。原“文档 / Codex / Projects / 消除小游戏”中的策划资料已迁入；以后从 [策划入口](Designing/README.md) 查阅与更新，旧目录仅保留迁入前原件，不再作为日常维护位置。

| 工作 | 入口 |
| --- | --- |
| 产品方向、玩法与系统策划 | [产品策划方案](Designing/product_plan.md) |
| 当前局内需求基线 | [V1.3 需求文档](Designing/requirements/in_game_v1_3.md)，结合 [R2 实施与用户后续调整](Designing/r2_level_update.md) |
| 逐关数值编辑 | [1—100 关数值总表](Designing/levels/level_plan_001_100.xlsx) |
| 设计稿与历史版本 | [设计资料索引](Designing/README.md) |
| 游戏开发 | [Godot 工程说明](Coding/godot/README.md) |

策划方案持续更新同一份正文，正式需求版本保留历史；修改 Excel 不会自动修改已运行关卡，须经过导入、层序生成与验证。实际开发完成情况以实施及测试记录为准。

## 运行

网页预览统一使用 [http://127.0.0.1:4173/](http://127.0.0.1:4173/)，始终读取 `Archive/Builds/web/` 中的最新导出。更新后刷新同一页面即可；服务入口为 `node Tooling/preview/web.mjs`，不再生成带版本参数的预览链接。

使用 Godot 4.5.1 打开 `Coding/godot/project.godot`，按 F5 启动并恢复有效的本地进度。工程保留 Compatibility 渲染和 720×1280 竖屏设置。按住甜甜圈拖到空盒或同口味餐盒松手，成组搬运并按容量拆分。也保留先点来源盒、再点目标盒的操作。四颗同味匹配开放需求后自动打包回收，并由备货原位补盒；设置中可按页切换全部 100 关。

安装 Node.js 20 或更新版本后，可从仓库根执行：

```sh
node Tooling/preview/preview.mjs
node Testing/scripts/run_godot.mjs architecture home donut hundred
node Tooling/export/web.mjs
```

可通过 `GODOT_BIN` 指定 Godot 可执行文件；工具不会自动下载安装引擎。macOS 可双击 `Tooling/preview.command`，Windows 可双击 `Tooling/preview.cmd`。Windows 引擎路径配置与命令行参数见 [工具说明](Tooling/README.md)。

## 目录

| 目录 | 内容 |
| --- | --- |
| `Coding/godot/` | Godot 工程、甜甜圈玩法、素材、Theme 与引擎基线 |
| `Tooling/` | 预览、微信／抖音测试包导出与引擎选择工具 |
| `Testing/` | 场景装配、百关四种周转条件完整解、规则和交互生命周期检查 |
| [`Designing/`](Designing/README.md) | 项目策划、玩法与关卡设计、UI 与美术说明、设计决策和验收记录 |
| `Archive/` | 设计参考图和构建产物 |
| `.agents/`、`AGENTS.md` | 项目技能与协作规则 |

双击 `Tooling/wechat.command` 或 `Tooling/douyin.command`，分别更新 `Archive/Builds/wechat/`、`Archive/Builds/douyin/` 固定目录。命令行入口和验收说明见 [微信测试说明](Coding/godot/platforms/wechat/README.md)、[抖音打包说明](Coding/godot/platforms/douyin/README.md)。缓存、日志、构建包、本机设置和凭据由根 `.gitignore` 排除。

工程说明见 [Godot README](Coding/godot/README.md)，仓库边界见 [GIT.md](Coding/godot/GIT.md)。
