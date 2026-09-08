# 静态内容与素材

中文与游戏定义维护在工作区 `Archive/GameDesignData/` 的 21 张业务 CSV；四张 Owner `translations.csv` 仅维护外语。运行时定义读 `generated/game_data_snapshot.json`，展示文字读同批生成的 `generated/localization/<语言>/`。主表中文不移走、不换成 Key。通用 UI 与规则模板作者文件归 `localization/authoring/`，不进入游戏数值定义。图片和可播放资源使用本目录 `asset_registry.json` 的稳定键登记，这是唯一人工维护映射，不从文件名猜测类别。

## 新增素材

1. 原图放到实际内容 Owner 的 `art/`；同一原图不因多个消费者重复复制。游戏定义与配套美术按本目录分类；通用 UI 字体与图标归 `ui/design_system/`，Feature 专用界面装饰归自己的 `ui/art/`，不复制游戏定义。
2. 切片用 AtlasTexture `.tres`，动画用 SpriteFrames `.tres`；在 Godot 编辑器中维护帧、帧率和循环设置，保留素材旁的 `.import` 导入配置。
3. 登记唯一资源键与 `kind`、`path`，在对应 CSV 引用，再执行工程 README 的 preview、sync、validate。

| kind | 资源 | 使用边界 |
| --- | --- | --- |
| `Texture` | Texture2D 或 AtlasTexture | 卡牌、道具、背景、图标等静态图 |
| `Effect` | SpriteFrames | 技能发动、命中、状态等普通特效；不因有动画就成为弹道 |
| `Projectile` | SpriteFrames | 从来源卡牌飞到目标的攻击表现，必须使用 `projectile.` 键与 projectiles 目录 |

`Effect` 通常登记为 `ability.<ID>.effect`，动画资源命名 `*_effect_frames.tres`；`Projectile` 资源命名 `projectile_<名称>.tres`，额外登记逻辑像素 `width`、`height`。静态弹道也使用仅一帧的 SpriteFrames；初始方向朝右，棋盘按来源到目标旋转。逐帧时长与循环由 SpriteFrames 决定；飞行总时长统一为 BattlePlayback 的 0.24 秒，不参与权威结算。

六类数值卡分别绑定 `projectile.physical / witchcraft / burn / poison / healing / shield`；特殊卡默认键为空。每种弹体具有独立 SVG 轮廓，`projectile_motion.gd` 消费回放进度绘制轨迹与命中，不参与模拟。六类效果显式键优先，其次为修正来源替换，最后为卡牌默认；持续伤害每跳不发射，自作用只播局部效果。原 `projectile.default` 与四帧原图保留为可显式使用的覆盖资源。

## 原始资源保全与已知缺图

迁移原图只在当前内容、真实消费者或明确的制作／备用用途需要时保留；已确认退役且零引用的 UI 素材连同 `.import` 清理，不为历史数量常驻运行工程。正式登记项以 `asset_registry.json` 为准；资源校验检查存在性与实际 Godot 类型，防止纹理伪装为可播放弹道。

S0013 原命中动画所引用的 21 张帧图在用户备份中也不存在。对应 `s0013_effect_frames.tres` 使用该能力已有静态图保留原动画时长；四帧默认攻击弹道不受影响。后续取得正确帧图后只替换该 Effect 资源，不修改战斗规则或把缺图混入默认弹道。

原字体许可证随 `ui/design_system/typography/` 保存；本文件不替原始游戏美术声明新的许可。

## 能力定义

卡牌与构筑增强的 `ability_parts` 只声明来源所提供的能力，执行方式与内容类别独立。CooldownMain 引用 `main_abilities.csv`；技能是无独立名称和介绍的运行定义，具体效果参数保留在所属定义。TriggeredPassive 同样保留自身效果参数；PersistentBonus／ConditionalPassive 使用修正对象，强度加成字段为 `action_modifiers`。数值效果的 `Damage` 等类别是结算词汇；上文素材登记的 `Effect` 表示表现资源，二者不得混用。

已有技能原图与普通技能特效归 `abilities/main_abilities/art/`，卡牌素材仍归 `cards/`，遗物归 `relics/`，攻击弹道始终单独归 `projectiles/`。词条、天赋、羁绊已有各自能力表，星能奖励归 Progression；没有实际素材时不为了目录对称建立空素材目录，不把生成快照拆成第二套人工定义。

`runtime/game_catalog.gd` 只负责验证后的只读目录与资源查询。战斗定义和预览帧由 `features/mechanics/assembly/battle_assembly.gd` 创建；共享展示在 `ui/components/content/`，不放回内容加载层。`RuleCodec` 解释内容专属格式，效果和能力语义复用 `AbilitySchema`；发布校验同时检查通用内容约束与当前模式要求。
