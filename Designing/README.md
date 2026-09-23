# 项目策划与设计资料

`Designing/` 统一保存项目的玩法策划、关卡设计、交互与 UI 说明、美术素材拆分、设计决策和验收记录。

文档使用有明确主题的 `snake_case` 文件名；内容较少时直接放在本目录，形成独立主题后再按需建立子目录。设计方案注明状态（草案、已确认或已替代），已替代的方案指向当前版本。

参考图继续保存在 `Archive/ReferenceImage/`，文档通过相对链接引用。游戏使用的素材与关卡配置保存在 `Coding/godot/`，设计文档记录意图与依据，不另存一套运行数据。

## 现有资料

| 资料 | 用途 |
| --- | --- |
| [基础玩法](basic_gameplay.md) | F-01～F-08、特殊盒、道具、确定性结算与已确认的连单奖励 |
| [项目术语](project_glossary.md) | 统一盒位、空盒、空盒位、需求、搬运、打包回收、备货与机关用语 |
| [玩法实现差距核对](gameplay_gap_analysis.md) | 本轮差距补齐状态、三关完整解、实机验证与当前范围 |
| [前两关数值调整](early_level_balance.md) | 普通空盒、初始密度、难度递进、多种开局路线及拖拽验收 |
| [当前 UI 参考](../Archive/ReferenceImage/donut_sort_reference.png) | 新素材包与界面重排依据；订单、口味和数量由正式关卡决定 |
| [第二关实机 v3](../Archive/ReferenceImage/donut_sort_level_02_v3.png)、[连单 v3](../Archive/ReferenceImage/donut_sort_combo_v3.png) | 历史 v3 四需求、特殊盒与连单画面；美术已由新素材包替代 |
| [新版运行截图](../Archive/ReferenceImage/donut_sort_current_mobile.png)、[特殊盒截图](../Archive/ReferenceImage/donut_sort_current_mechanics.png) | 新素材包接入后的真实引擎渲染 |
| [UI 比例校准](ui_alignment.md) | 对照参考稿的尺寸差异、透视、透明层叠、排版和长屏适配 |
| [素材与界面](mechanics_assets.md) | 全部 66 张素材的收录、启用／预留范围、分层与布局适配 |
| [置顶选择](../Archive/ReferenceImage/donut_sort_top_choices_v2.png)、[补餐](../Archive/ReferenceImage/donut_sort_refill_v2.png)、[通关](../Archive/ReferenceImage/donut_sort_victory_v2.png) | 早期 v2 画面，仅保留历史对比；最新状态见差距补齐验收 |
| [工程说明](../Coding/godot/README.md) | 已实现玩法、运行方式与当前范围 |
| [关卡目录](../Coding/godot/game_content/donuts/levels/catalog.json) | 三关配置入口，包含独立需求、特殊盒、逐盒备货和奖励 |

新增正式文档后，在此补充入口，方便按主题查阅。
