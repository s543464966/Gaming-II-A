# 项目策划与设计资料

`Designing/` 统一保存项目的玩法策划、关卡设计、交互与 UI 说明、美术素材拆分、设计决策和验收记录。

文档使用有明确主题的 `snake_case` 文件名；内容较少时直接放在本目录，形成独立主题后再按需建立子目录。设计方案注明状态（草案、已确认或已替代），已替代的方案指向当前版本。

参考图继续保存在 `Archive/ReferenceImage/`，文档通过相对链接引用。游戏使用的素材与关卡配置保存在 `Coding/godot/`，设计文档记录意图与依据，不另存一套运行数据。

## 现有资料

| 资料 | 用途 |
| --- | --- |
| [R2 百关数值接入](r2_level_update.md) | 新版机制复用、装量、首归纳与中段腾位目标及实际验收 |
| [V1.3 数值与局内更新](v1_3_alignment.md) | 上一版100关、装量修正、四条件回放，以及保留的道具与补货行为 |
| [前100关实现与验收](level_100_implementation.md) | 当前百关范围、机制规则、400 条正式回放、固定网页预览与待试玩项目 |
| [前100关开发与素材评估](level_100_feasibility.md) | 对照最新产品文档、数值表、V9机制素材及源码，列出规则差距、缺图判断和百关验收步骤；开发前评估 |
| [局内盒位布局优化](board_layouts.md) | 当前交错／对齐／围合／散点构图、顶部与机关表现，8／12／25 盒位视觉样例及验证；底部出餐暂缓 |
| [局内界面 v8 更新](in_game_ui_refresh.md) | 三段背景、翻盖订单盒、圆纸托、奶白香草与配对贴纸、八组口味备用；iPhone 长屏留白修复与截图 |
| [小程序发布填写建议](release_information.md) | 名称、简称、介绍及 Logo 上传文件，待用户提交 |
| [基础玩法](basic_gameplay.md) | F-01～F-08、特殊盒、道具、确定性结算与已确认的连单奖励 |
| [项目术语](project_glossary.md) | 统一盒位、空盒、空盒位、需求、搬运、打包回收、备货与机关用语 |
| [玩法实现差距核对](gameplay_gap_analysis.md) | 本轮差距补齐状态、三关完整解、实机验证与当前范围 |
| [关卡容器预算](early_level_balance.md) | 十关普通空盒、初始密度、难度递进及可解性验收 |
| [旧 v7 盒子与布局参考](../Archive/ReferenceImage/donut_sort_layout_and_style_approved.png) | 旧方纸盒、甜甜圈堆叠和整体层次记录；当前以 v8 更新为准 |
| [上一版 UI 参考](../Archive/ReferenceImage/donut_sort_reference.png) | 历史布局参考 |
| [第二关实机 v3](../Archive/ReferenceImage/donut_sort_level_02_v3.png)、[连单 v3](../Archive/ReferenceImage/donut_sort_combo_v3.png) | 历史 v3 四需求、特殊盒与连单画面；美术已由新素材包替代 |
| [当前网页截图](../Archive/ReferenceImage/donut_sort_layout_browser.png)、[手机安全区模拟](../Archive/ReferenceImage/donut_sort_layout_phone.png)、[小屏截图](../Archive/ReferenceImage/donut_sort_layout_small.png) | 交错盒位、顶部贴纸与状态、柜体留白；基础内边距与安全区分开处理 |
| [UI 比例校准](ui_alignment.md) | 对照参考稿的尺寸差异、透视、透明层叠、排版和长屏适配 |
| [小游戏平台画面适配](platform_viewport.md) | 抖音画面挤压根因、两端安全区、等比缩放与模拟器验收 |
| [素材与界面](mechanics_assets.md) | 原素材来源与失败弹窗说明，链接当前 v8 替换方案 |
| [置顶选择](../Archive/ReferenceImage/donut_sort_top_choices_v2.png)、[补餐](../Archive/ReferenceImage/donut_sort_refill_v2.png)、[通关](../Archive/ReferenceImage/donut_sort_victory_v2.png) | 早期 v2 画面，仅保留历史对比；最新状态见差距补齐验收 |
| [工程说明](../Coding/godot/README.md) | 已实现玩法、运行方式与当前范围 |
| [关卡目录](../Coding/godot/game_content/donuts/levels/catalog.json) | 100 关配置入口，包含独立需求、特殊盒、逐盒备货和奖励 |

新增正式文档后，在此补充入口，方便按主题查阅。
