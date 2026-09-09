# 共享机制架构

这里当前同时容纳可复用的数值与能力语义，以及冒险棋盘相关的装配、空间计算和模拟实现；目录名不表示全部代码都与玩法形式无关。不拥有内容素材、账号状态、页面、奖励流程或保存 I/O。按“契约 → 来源策略与装配 → 单场执行”组织，而不是为每个内容类别复制一套战斗系统。

棋盘只是冒险中的一种玩法，具体设定见工作区[Adventure](../../../../Designing/game_modes/pve_adventure.md#mode-rules)。现有BattleRequestValidator仍要求矩形尺寸和占位，CombatSimulator使用空间寻敌，尚不是任意玩法入口。其他模式独立定义交互和时序；不得为了复用而伪造坐标，也不预建尚无需求的适配层。本次文档归属调整不搬迁这些源码。

## 文件结构

```text
mechanics/
├── contracts/
│   ├── combat_types.gd              # 稳定枚举，不持有单位或公式
│   ├── ability_schema.gd            # 效果、条件、能力与修正的共同语义
│   ├── card_tag_query.gd            # 卡牌标签数量与集合匹配，不隐含元素效果
│   ├── card_capabilities.gd          # 原生输出与能力资格，内容校验和挂载共用
│   ├── battle_report.gd              # 递归封存战报，执行和回放共享只读快照
│   └── ability_source.gd            # 内容、来源实例、局部能力、宿主身份
├── foundation/
│   ├── deterministic_math.gd        # 单精度与中点取偶
│   └── deterministic_random.gd      # 单场固定种子随机序列
├── assembly/
│   ├── battle_assembly.gd           # 基础/构筑投影、主能力目录、快照与预览
│   ├── ability_projection.gd        # 按四种执行方式展开三类能力，不解释来源成长策略
│   └── build_restorer.gd            # 恢复构筑并通过同一装配校验
├── gameplay/
│   ├── build_state.gd               # 与模式无关的构筑事实
│   ├── growth/
│   │   ├── card_growth.gd           # 卡牌永久与临时成长投影
│   │   └── duplicate_growth.gd      # 累计份数与等级门槛
│   └── ability_sources/
│       ├── relics.gd               # 逐份遗物与队伍宿主贡献
│       ├── innate_abilities.gd    # 固有能力显式引用与资格
│       ├── talents.gd              # 前置与点数资格
│       └── synergies.gd            # 显式提供者、可选阵容条件与激活集合
└── combat/
    ├── simulation/
    │   ├── combat_simulator.gd      # 唯一时钟、步骤编排与语义战报
    │   ├── battle_request_validator.gd # 完整请求、部署与机制依赖校验
    │   ├── combat_unit.gd           # 独立单位状态与单位计时
    │   └── battle_rules.gd          # 模式规则形状与胜负计算
    ├── abilities/
    │   ├── main_abilities.gd                # 主能力授予来源与共享冷却
    │   ├── triggered_passives.gd    # 同步触发顺序、递归保护与预算
    │   ├── sustained_contributions.gd    # 常驻/条件贡献的激活与撤销
    │   └── conditions.gd            # 事件与状态条件、宿主存活判定
    ├── attributes/
    │   ├── attributes.gd            # 无状态数值公式
    │   └── modifiers.gd             # 运行修正来源账本
    ├── spatial/
    │   ├── battle_grid.gd           # 当前冒险棋盘的矩形占位
    │   └── combat_targeting.gd      # 当前棋盘上的寻敌与相邻关系
    ├── resolution/
    │   ├── action_executor.gd       # 有序效果与目标执行
    │   ├── health_resolution.gd     # 伤害、护盾、治疗、吸血与击败
    │   └── statuses.gd              # 状态刷新、到期和持续伤害节拍
    └── resources/
        └── pollution.gd            # 队伍/整场污染及跨战继承公式
```

不为只有设想而没有实现的能力、服务或玩法建立空目录。

## 内容、能力、运行状态不是同一种分类

| 概念 | 静态定义/素材 Owner | 这里负责什么 |
| --- | --- | --- |
| 英雄、随从、怪物、道具卡 | `game_content/cards/`，生成快照的 `cards` 表 | 装配为不同队伍的载体实例，不按类别复制内核 |
| 卡牌元素标签 | `card_tags` 字典及 cards.card_tag_ids | 校验标签数量、投影身份，供显式条件与目标集合查询 |
| 主能力 | `main_abilities` 表；已有素材在 `game_content/abilities/main_abilities/art/` | 展开引用；同单位同主能力多来源共用一个冷却 |
| 固有能力、天赋、羁绊 | 各自唯一内容表；素材有实际需求时归对应能力类别 | 筛选、激活或成长策略，然后交给同一能力投影 |
| 遗物 | `relics` 表与 `game_content/relics/` | 独立实例、全队宿主与消耗事实；不伪造成单位 |
| 效果、条件、修正 | 所属主能力或能力项的内联结构 | 契约校验与共享算法；不建立大量复制的全局“伤害效果表” |
| 灼烧、中毒、冻结等状态 | 能力项声明层数或控制时长 | 单场层数、每秒跳点与控制到期；与施加状态的那次动作分开 |
| 污染 | 模式显式提供初始资源与作用域 | 当前值、阈值、变化与继承计算，不属于能力来源 |
| 弹道、命中动画 | `game_content/projectiles/` 或实际内容的 `art/` | 只在战报声明表现键，不控制结算 |

策划仍在工作区五个 Owner 的 CSV 内维护，运行时只读取同批生成快照；主输出分类没有另建人工数据副本，内容 ID 保持；玩家存档迁移由 player_session 拥有。

内容能力统一为 `CombatTypes.AbilityCategory.Main / Passive / Bonus`：主能力是冷却驱动的主动；事件和条件均归被动，即便只改变数值；独立常驻个人或群体数值归增益。`ability_category()` 从执行方式派生分类，UI不另维护一套范围猜测，也不显示分类标题。

四种执行方式为 CooldownMain、TriggeredPassive、PersistentBonus、ConditionalPassive；它们不是四类内容能力。来源回答“从哪里来”，执行方式回答“什么时候生效”，CombatAction 回答“执行什么”，宿主和目标分别回答“由谁承载”和“影响谁”。被动 `internal_cooldown_seconds` 默认0，由触发账本按宿主、来源、局部能力单独维护，不接入主能力冷却槽。`trigger_keyword` 仅在创作时展开成事件与必要过滤，不在运行时建立第二个执行器；完整定义见[能力分类](../../../../Designing/battle_design/1-content_definitions.md#ability-categories)与[触发词条](../../../../Designing/battle_design/4-triggers_and_combinations.md#trigger-keywords)。

卡牌原生输出使用 CombatTypes.Output 的六种数值类型与特殊类；OUTPUT_STATS 明确对应属性。输出类型不替代载体、来源和执行方式；元素仅作为卡牌 Tag，不恢复旧阵营、职业、战术定位或元素伤害系统。遗物直接贡献全队能力，不依赖单卡类型或附着资格。羁绊只装配 cards.synergy_ids 明确引用的内容，并归属提供者；标签查询复用既有执行链，不能代替事件和目标范围。

## 单一数据流与状态所有权

下列描述当前卡牌构筑、预览与冒险棋盘入口，不是所有未来模式必须遵循的流程。

1. `GameCatalog` 校验、索引并冻结静态记录，只提供查询、资源和文本相关信息。
2. `BattleAssembly.base_definition` 生成基础战斗定义；`definition` 叠加显式选中的构筑机制；`assemble` 输出单位快照、非卡牌宿主和主能力定义。收藏、奖励与实际参战复用这些投影及同一成长公式。
3. `BattleRequestValidator` 在模拟前校验完整部署、队伍规则、引用、宿主兼容性及污染等机制依赖。它直接使用 `AbilitySchema`，不反向读取 CSV 解析器。
4. `CombatSimulator` 复制输入，持有唯一单位集合、随机源、污染与时钟；`begin/advance` 按软预算在完整固定步间让出，`simulate` 同步驱动同一实现。完成后输出递归只读的结果、事件及状态帧；取消不产生完成通知。
5. 模式决定奖励和保存；`BattlePlayback.start` 只接收已结算结果，动画与弹道不调用内核。卡面只需预览时使用 `BattleAssembly.preview_frame`，允许未部署或冲突占位，不产生随机数、事件或开战条件状态。

账号拥有、永久成长归 Collection/Backpack；模式持有本次 `MechanicBuild`。单位生命、护盾、状态、修正来源、主能力冷却、触发预算和污染是本场状态，不直接存成账号字段。`BuildRestorer` 不恢复市场、路线或奖励阶段，这些仍由模式恢复器处理。

## 关键执行边界

- `AbilitySchema` 拥有共同的能力语义；内容 `RuleCodec` 只扩展内容特有的成长数组、分类和羁绊结构。两者不各维护一套效果规则。
- `AbilitySource` 集中创建与校验 `source_kind/content_id/instance_id/part_id`，运行时补上 `host_id`。预算键按宿主、来源实例和局部能力隔离；效果目标不替代来源身份。
- 遗物逐份建立独立来源，常驻加值叠加；同名一次性来源在同一事件链只消耗一份。星能属于冒险奖励，不贡献战斗能力。
- 触发保持同步、深度优先，先记预算再执行效果；不能改成异步信号队列或广度优先而声称只是目录迁移。`SustainedContributions` 先观察同一状态，再统一更新贡献。
- `CombatActionExecutor` 借用单位、随机源、污染、主能力定义和生命结算组件；不接收整个模拟器。事件、刷新与结束检查使用调用期间的窄回调，不保存回调形成引用环。
- 直接伤害和持续伤害都调用 `HealthResolution`，状态模块不反向依赖效果执行器。每步先状态、再单位修正与主能力计时；没有主能力的单位也会撤销到期修正。
- 纯属性公式与纯占位函数允许内容校验和预览复用；可变单位、主能力、状态与触发账本只能由战斗执行持有。
- 共享内容组件与 `RuleText` 在 `ui/components/content/`；战斗特有的状态、完成原因和详情由 `features/combat/ui/combat_text.gd` 解释，不反向影响判定。

## 新增与维护

新增卡牌、固有能力、遗物、天赋或羁绊，优先在原内容表组合既有能力，再由来源策略接入装配；触发词条在契约内展开为事件与过滤。只有真正新增执行语义才扩展 contracts 和对应 combat Owner。冒险星能由模式奖励对象负责，不进入通用战斗机制。

从工作区运行 `node Testing/scripts/verify_godot_structure.mjs`，同时检查资源路径和全局类依赖；新增边界规则有 `node --test Testing/unit/scripts/test_godot_boundaries.mjs` 覆盖。机制改动运行 `mechanics combat`，装配同时覆盖 `content adventure session`，共享预览与回放覆盖 `localization home adventure-scene adventure-journey architecture`。测试入口、隔离规则和数据同步命令见工程 README。
