# MagicA

Godot 4 的 2D 卡牌游戏。第一方游戏与制作工具使用 GDScript；正式工程和 Git 根为 `Coding/godot/`。

## 打开与运行

使用标准版 Godot 打开本目录的 `project.godot`，F5 运行 `bootstrap/app.tscn`，初始化默认玩家后直接显示 Home。F6 可独立查看 Startup、Home、Adventure 的布局；没有注入玩家会话时只显示布局预览提示，不创建隐藏的全局应用或账号。

开发基线是 Godot **4.5.1 stable**，Compatibility 渲染、720×1280 逻辑视口、竖屏、单线程 Web 方向；当前本机安装的 4.7.2 也用于开发兼容检查。小游戏导出模板固定在 4.5.1，不能将编辑器的“能打开”视为任意引擎版本都可发布。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --editor --path /absolute/path/to/Coding/godot
```

本机另有已校验的 4.5.1 开发副本：工作区 `Tooling/.runtime/godot-platform/editor-4.5.1/Godot.app`。该副本不是产品源码或必须提交的依赖。

可交互的开发预览从工作区根运行 `node Tooling/preview/preview.mjs home|adventure`，通过 `GODOT_BIN` 指定引擎。它为本次进程创建独立临时目录，Home/Adventure 使用真实用例创建一次性本机默认玩家，正常退出清理；加 `--check` 可无窗口验证目标入口。失败诊断保留在输出的精确运行目录，不接触默认玩家目录。

## 结构与生命周期

| 位置 | 唯一职责 |
| --- | --- |
| `bootstrap/` | 持续存活的 App 主场景、服务装配与导航 |
| `features/mechanics/` | 可复用能力、构筑与装配，以及当前仍依赖棋盘的确定性执行代码 |
| `features/combat/` | 当前冒险棋盘、卡面与只读战报回放的表现实现 |
| `features/game_modes_pve_adventure/` | 冒险玩法规则及路线、部署、结算、奖励与章节存档 |
| `features/game_modes/ui/` | Home 模式与章节选择 |
| `features/activities/` | 活动总览与契约召唤、传说之路、每日任务、七日签到子页；当前仅展示占位 |
| `features/game_modes_pve_challenge/`、`features/game_modes_pvp_pk/`、`features/game_modes_pvp_chess/` | 挑战、对战、战棋的预留目录；仅有 `.gitkeep`，玩法未设定、未开放 |
| `features/backpack/` | 账号货币、可堆叠物品与背包页面 |
| `features/talents/` | 永久天赋、章节首通凭据与 Home 串行天赋页 |
| `features/<owner>/` | 各业务状态、用例；自己的页面与场景放在 `ui/` |
| `features/player_session/` | 本机默认玩家创建与恢复、保存编排和旧档导入 |
| `game_content/` | 分类素材、资源登记表、静态定义及按语言分离的展示文字 |
| `ui/design_system/` | Theme、设计令牌、字体与通用图标 |
| `ui/components/`、`ui/overlays/` | 可编辑原生组件、标准页签、安全区、全局模态与轻提示 |
| `services/save/` | 通用原子存储 I/O，不持有玩家业务状态 |
| `services/localization/` | 玩家加载前初始化原生翻译、可用语言与设备偏好，不修改玩家状态 |
| `platforms/` | 平台状态入口及 common、web、wechat、douyin 宿主适配 |
| `tooling/` | 与游戏版本绑定的 GDScript 数据制作、导入、导出和预览装配 |
| `addons/` | 第三方抖音 SDK 与引擎要求的插件薄入口 |

第一方工程路径统一 `snake_case`；节点、类名使用 PascalCase，资源键与策划 ID 不因目录迁移改变。第三方插件和 README、GIT、LICENSE 等约定名称不强制改写。

棋盘只是Adventure中的一种具体玩法，不是所有模式的默认形式。格位、相邻、空间寻敌及部署规则归[冒险设定](../../Designing/game_modes/pve_adventure.md#mode-rules)；现有模拟器仍有棋盘依赖，源码位于mechanics并不表示已经支持无棋盘玩法。其他模式按实际玩法选择可复用能力，不被要求接入同一棋盘或战斗流程。

App 持有 Services、SceneContainer、Overlay，始终保留同一服务实例。正常内容页按 Home ⇄ Adventure 切换；Startup 仅在启动错误或旧档选择有歧义时显示。Home 的 18 个功能页按需实例化、互斥显示并缓存，英雄详情改用全局内容浮层；活动总览与首页快捷入口复用同一子页，子页可返回活动总览，右上角关闭仍返回 Home；Adventure 内部切换路线、15 秒部署、自动战斗、结果及战后构筑。第一方 Autoload 为零，只有原始抖音 SDK 的 `tt` 保留其固定入口。

App、Home 子页与全局浮层只登记场景路径，首次使用时才加载，不在应用脚本解析阶段预载冒险、商城或图鉴。页面缓存仍由 Home 原有生命周期拥有；这优化加载时机，不改变完整包的资源范围。`startup-resources` 在独立进程检查实际资源缓存及首次导航，导出另检查空 VFS 中的延迟场景。

页面在入树前接收会话、操作 Callable 与表现依赖，通过信号请求导航，不反向查找应用根。稳定布局保存在 Feature 场景及通用组件 `.tscn`：Home、Adventure、启动恢复页骨架、目录页、卡面、页面边框、确认与轻提示可在编辑器打开。战后奖励骨架和卡片也有原生 .tscn；动态数据项、路线连线和具体奖励条目由脚本绑定；这不改变它们的业务 Owner。

载体类型、主输出类型与队伍身份分别使用 CardTypes.Kind、CombatTypes.Output 和 team_id。主输出分为六种数值类型与特殊类，已取消阵营、元素、职业和战术定位；技能、规则、附着、天赋、羁绊、卡牌成长与污染统一归 features/mechanics/，模式通过 BattleAssembly 选择能力，并提供 BattleRules 与初始资源。技能支持多项、来源合并和限时撤销；尚未开放的模式不因此变为完整玩法。

卡牌、固有能力、遗物、天赋、羁绊通过 `ability_parts` 组合主能力、被动能力、增益能力；三类内容使用四种执行方式，触发词条仅是事件／条件简写。共享机制分为 contracts、foundation、assembly、gameplay、combat；完整目录、分类与依赖边界见 [mechanics/README.md](features/mechanics/README.md)。GameCatalog 按明确表名查询静态记录，BattleAssembly 是基础与构筑投影的唯一入口；来源策略、主能力冷却、被动触发预算、持续贡献、动作与生命结算各有明确 Owner。内容与玩家存档独立版本化，旧别名只在迁移入口解析。

共享目录页、静态内容预览和 RuleText 归 `ui/components/content/`；所有卡牌详情通过 `ui/overlays/content_popup.tscn` 呈现限宽限高、内部滚动的小浮层。页面分别提供基础、账号永久或本场装配数据，购买和升星仍由所属 Feature 提交；确认取消恢复原详情，导航撤销全部模态。战斗专用 CombatText 只解释状态帧及完成原因。回放接收已经模拟完成的结果，不创建模拟器；卡面通过装配层获取零时刻预览，不直接持有战斗单位。

游戏内容定义与配套美术归 `game_content/`；UI 通用装饰归设计系统，业务界面装饰归 Feature 的 `ui/art/`。战斗规则不是无 Owner 的全局 system；存储、平台服务也不反向持有界面。尚无真实消费者的 shared、音频服务或其他平台目录不预建。

工作区 `Tooling/` 负责环境下载和进程编排，工程 `tooling/` 保留版本相关实现与依赖锁。导出预设排除工具与编辑器入口；运行时不依赖工作区工具。外层工具不在产品 Git 中，独立克隆可运行已有静态快照；制作与工作区预览需要按说明另行提供外层工具或数据。

## 屏幕与触控

界面以 720×1280 为设计基准，保持竖屏扩展适配。标准操作、关闭按钮和战斗开始入口采用 108 设计像素高度；在 320 宽视口约为 48 逻辑像素。正文字号默认为 30，长页签横向滚动，不靠持续缩小文字挤进一行。Home 按 941×1672 方案画布等比适配安全区，底部五个图文入口常驻，商城为独立牌面。方案中的紧凑入口在小屏采用约 32 逻辑像素以上的点击目标；它们不等同于通用页面的 48 像素标准按钮。

平台边界把宿主安全矩形与实际窗口求交，再交给共用 SafeArea。浏览器读取 CSS 安全边距、可见视口及 canvas 边界；微信／抖音优先读取窗口信息并避让可用的菜单胶囊；原生 Android／iOS 使用 DisplayServer 安全矩形。缺少宿主能力时回退零边距，具体设备仍需真机验证。背景不缩入安全区，Home 与模式页采用等比覆盖；模式页复用已确认章节背景，在 Home 满屏与带粗黑边的内缩章节框之间双向推拉，动画结束才切换页面显隐，未确认浏览通过叠层回到真实 Home 背景。首章使用 AtlasTexture 引用背景；血焰溶洞与冰刃荒原各自使用完整竖版主背景，Home 与模式选择复用同一章节图片。

窗口横向时，App 的全局遮罩显示竖屏状态并阻止输入，后台与横屏共用同一个环境暂停快照。恢复竖屏不自动关闭原有设置／卡牌详情暂停，尚未落地的拖拽会取消；不创建第二个应用或另一套持久化服务。

定向回归入口：`node Testing/scripts/run_godot.mjs mobile-layout architecture home adventure-scene platform`。`mobile-layout` 使用隔离玩家覆盖九组视口、安全区、常用点击目标、关闭按钮、完整棋盘及转屏暂停；桌面图形与本地 Web 验证不代表 iPhone、Android 或小游戏宿主的真机验收。

## 数据与素材维护

游戏定义与中文原文在工作区 `Archive/GameDesignData/` 五个 Owner 的业务 CSV 中维护，来源集合以 `content_schema.gd` 为准；Cards、Combat、Inventory、Progression 的四张 `translations.csv` 只存其他语言译文。主表名称、介绍和说明仍为完整中文，不搬空、不替换成 Key。游戏读取生成快照及同批语言资源，不读取外部 CSV。

编辑器顶部的 **CSV 数据** 标签可按实际文件和表头查看、编辑、保存 CSV，保存后自动执行现有数据同步。编辑器不解释游戏内容；增删分类、表或列后刷新即可，新结构是否可发布仍由数据管线判断。操作与保存失败处理见 [CSV 编辑器](tooling/game_data/csv_editor/README.md)。

内容 Schema 以 `game_content/runtime/snapshot_format.gd` 的 `VERSION` 为准（独立于玩家存档版本）。六类输出各自读取独立属性，所有伤害共用生命与护盾结算，巫术、灼伤和中毒按各自规则处理；同时支持伤害暴击、生命损失吸血、持续急速、一次性充能、英雄／随从多重施法及道具弹药扩充。治疗和护盾当前不判定暴击。具体定义与叠加边界见工作区[战斗设定索引](../../Designing/README.md#battle-design)，工程顺序见[单场战斗时序](../../Designing/shared_mechanics/battle_runtime.md)，内容字段见[GameDesignData](../../Archive/GameDesignData/README.md)。

从工程根执行下列命令，`Godot` 替换为本机引擎可执行文件：

```bash
Godot --headless --path . --script tooling/game_data/data_cli.gd -- preview
Godot --headless --path . --script tooling/game_data/data_cli.gd -- sync
Godot --headless --path . --script tooling/game_data/data_cli.gd -- validate
```

预览输出内容与语言候选摘要；同步在完整校验后发布快照、原生 PO 与完成清单，普通失败回退已替换文件；验证比对全部生成字节、来源哈希、定义、引用和资源。异常中断导致批次不匹配时拒绝启动或打包，重新同步恢复。独立克隆没有外层 CSV 时仍可直接运行已有快照；重新制作数据时必须提供完整来源目录作为末尾参数。

资源登记表 `game_content/asset_registry.json` 是唯一人工维护的“稳定键 → Godot 资源”映射，不是生成文件。原图、AtlasTexture 切片、SpriteFrames 动画与所属内容相邻保存。素材新增与弹道／普通特效的区别见 [game_content/README.md](game_content/README.md)。

## 多语言

中文业务原文只在上述主表维护；界面短文案与规则解释模板归 `game_content/localization/authoring/zh_hans/`。其他语言作者文件分别位于 `en/`、`ja/`、`zh_hant/`、`fr/`、`de/`，仅保存译文与原文指纹；生成文字统一在 `game_content/generated/localization/<语言>/`。不得手改生成 PO，或把中文复制成外语译文后标为完成。

应用 Services 持有唯一 LocalizationService，玩家加载前加载 Godot 原生 Translation，语言偏好写入独立 `language_preferences.json`。Startup 与 Home 设置使用同一个语言选择组件；仅一个可用语言时隐藏选项，但仍显示存储异常警告。首次明确选择当前语言也保存；写入失败保持原语言，损坏偏好保留原件并明确提示仅本次运行生效。动态文案使用命名参数，切换语言只重绑展示，不提交购买、重置部署或改写账号。首次无偏好时使用发行配置的默认语言（中文），不按系统语言自动切换；已保存选择仍优先恢复。

`tooling/export/language_profiles/` 使用 `locales`、`default_locale`、`disabled_locales`；数量由列表派生，与 Web／微信／抖音无关。未选择语言排除文本资源及专属字体，已打包但隐藏的语言不展示；缺失或过期译文不能作为完整发行语言。字体映射与许可证在语言登记表维护，App 切语言时更新同一个共享 Theme；不依赖系统字体补字。

本地资源 ZIP 使用工作区 `Tooling/export/pack.mjs`，先校验来源、当前代码 Schema、内容目录和实际字形，再检查真实包，最后才创建新的交付文件；不能以 Godot 的退出码为唯一依据。独立克隆可使用工程 `tooling/export/language_cli.gd` 进行只读前后置校验。用法和边界见 [tooling/export/README.md](tooling/export/README.md)。

已收录界面和业务展示字段具备五种外语 AI 初稿；每次新增或修改原文后仍须补译和同步，不自动更新旧译文指纹。尚待人工语言审校、剩余错误提示接入、地区字形及完整视觉验收；资源包验证不等于完整六语产品或小游戏发布已通过。

## 玩家数据

默认使用 Godot 的 `user://MagicA`；测试或独立开发可通过 `MAGICA_DATA_DIR` 显式隔离路径。本版本不提供注册、密码或验证码。首次打开自动创建一个随机稳定身份，后续打开复用同一存档并直达 Home；不同设备或独立目录不是同一个用户，也不具备云同步。

现行玩家 Schema 为 24；23→24 退役旧星能被动，将历史份数与未领候选转为章节奖励次数和锁定八项，不补发账号资产。22→23 移除六个退役章节天赋及章节点数，根据已完成章节或已解锁后继补齐永久首通凭据；不把旧点数兑换为永久点数。21→22 只将章节生命转换到整数点数边界，不改份数、奖励、路线或永久培养。20→21 将特殊随从／道具改为被动后失去资格的冷却装备按完整份数退回章节手牌。Schema 19→20 删除阵营状态，按原生输出重新校验装备，并将不再适配的装备按累计份数退回章节手牌。此前的 Schema 18→19 将营地转为星辉遗迹、旧遗迹改为星能选择，保留路线拓扑、阵型和完成进度，已完成节点不补奖；Schema 17→18 迁移星级、生命比例、开章永久成长记录及同目标装备累计份数，未使用旧 rank/grade 仅保留迁移凭据；Schema 16→17 清理已消费治疗骰历史与收藏身份，不改变现有生命、其他骰子或随机序列；Schema 15→16 清理旧技能／属性骰子强化并稳定转换未领取候选，不重置选择时限；Schema 14→15 将旧市场转换为分类骰子、通用附着和强化手牌，并将旧章节剩余金币一次性并入账号金币；Schema 12 在会话恢复时迁移内容 ID，Schema 13 迁移章节市场报价 ID 和轮次字段，旧 Schema 1–11 由专用映射层导入。导入只接受完整账号表及关联存档，拒绝部分导入、覆盖非空目标或把损坏存档当作新号。旧凭据仅作迁移格式检查，不再执行认证；原设备选择或唯一旧玩家会被采用，多旧档有歧义时进行一次性选择。

```bash
Godot --headless --path . --script tooling/player_data/import_cli.gd -- preview /absolute/source-save-dir
Godot --headless --path . --script tooling/player_data/import_cli.gd -- import /absolute/source-save-dir /absolute/empty-target-dir
```

来源是包含 `accounts.json` 的玩家存档目录，不是项目备份。导入不会修改来源。主文件写入采用临时文件发布与上一份成功写入备份。默认身份写在 `local_player.json`，先落盘玩家再绑定身份，中断后复用已创建存档。身份损坏、已绑定玩家缺档或旧删除事务未完成时停止并保留原件，不自动覆盖；本版本没有账号删除入口。

恢复玩家字段先完整验证类型和范围，不把损坏值强转成默认值；成功使用备份时，在 Home 显示一次恢复提示并说明最近进度可能未保留。商城购买和冒险变化都经 `PlayerSessionState.transact` 提交；保存失败恢复整个聚合，不另维护商城自己的保存锁与局部回滚副本。

## 开发回归

测试位于产品仓库外的工作区 `Testing/`，不混入游戏包。入口要求显式选择 suite，自动隔离数据并检查进程退出码、脚本错误、泄漏和完成标记。

```bash
node Testing/scripts/run_godot.mjs mechanics combat content adventure
node Testing/scripts/run_godot.mjs session repository legacy-save player-io
node Testing/scripts/run_godot.mjs home adventure-scene platform
node Testing/scripts/run_godot.mjs adventure-journey adventure-balance
node Testing/scripts/run_godot.mjs architecture
node Testing/scripts/verify_godot_structure.mjs
```

以上从工作区根运行；通过 `GODOT_BIN` 指定引擎绝对路径。日常只运行受修改影响的组，迁移收尾才覆盖上述整条游戏链。

`adventure-journey` 从正式 App 用真实鼠标点击与拖拽验证 Home 进入、路线、部署、开始、奖励领取、设置退出及文件恢复后继续参战；`adventure-balance` 验证预设培养程度下的章节难度与组队收益。批量数值测量不能替代界面旅程，培养耗时和人类操作体验仍需实玩反馈。数值口径见工作区[PVE Adventure 模式](../../Designing/game_modes/pve_adventure.md#battle-input)。

## 当前边界

- 已实现本机默认玩家、内容目录、收藏与英雄选择、账号商城、资产查看、本机排行和 PVE 冒险循环；引擎迁移之外，经确认的战斗参数改造已在当前 CSV 和共享内核生效，新增效果的数值仍是可调整的平衡基线。
- 活动、成就、联网社交、通知、PVP／战棋／挑战，原先未实现的业务仍明确显示未开放，不将页壳写成完整玩法；城镇入口已退役，不再保留占位页。
- 迁移原图已按当前消费者和明确备用用途收敛，字体及许可证继续保留。S0013 的原命中动画引用了备份中也不存在的 21 张帧图，当前用同一能力静态图保留该段时长；没有编造缺失帧。
- 微信、抖音方向保留；抖音已提供工作区 `Tooling/export.command` 一键本地导出，制品统一归 `Archive/Builds/douyin/`。产品预设不保存 AppID，不使用演示账号。本地导出和 Web 开发检查均不等于小游戏真机、上传或发布验收。
- 第三方来源、模板约束及未验证项见 [tooling/export/README.md](tooling/export/README.md)。迁移阶段的全素材 Web 开发包约 76 MiB；本轮结构调整没有开展小游戏发布，包体优化仍未完成，不能直接宣称可上线。

Git 根、原始改动与跟踪范围见 [GIT.md](GIT.md)。工作区规则与设计文档分别位于外层 `AGENTS.md` 和 `Designing/`。
