# 静态内容与素材

中文与游戏定义维护在工作区 `Archive/GameDesignData/` 的 24 张业务 CSV；四张 Owner `translations.csv` 仅维护外语。运行时定义读 `generated/game_data_snapshot.json`，展示文字读同批生成的 `generated/localization/<语言>/`。主表中文不移走、不换成 Key。通用 UI 与规则模板作者文件归 `localization/authoring/`，不进入游戏数值定义。图片和可播放资源使用本目录 `asset_registry.json` 的稳定键登记，这是唯一人工维护映射，不从文件名猜测类别。

## 新增素材

1. 原图与音乐放到实际内容 Owner；同一资源不因多个消费者重复复制。游戏定义与配套素材按本目录分类；通用 UI 字体、图标和音效归 `ui/design_system/`，Feature 专用界面装饰与音效归自己的 `ui/art/`、`ui/audio/`，不复制游戏定义。
2. 切片用 AtlasTexture `.tres`，动画用 SpriteFrames `.tres`；在 Godot 编辑器中维护帧、帧率和循环设置，保留素材旁的 `.import` 导入配置。
3. 登记唯一资源键与 `kind`、`path`，在对应 CSV 引用，再执行工程 README 的 preview、sync、validate。

| kind | 资源 | 使用边界 |
| --- | --- | --- |
| `Texture` | Texture2D 或 AtlasTexture | 卡牌、道具、背景、图标等静态图 |
| `Audio` | AudioStream | 章节音乐、界面反馈及只读战斗表现音效 |
| `Effect` | SpriteFrames | 技能发动、命中、状态等普通特效；不因有动画就成为弹道 |
| `Projectile` | SpriteFrames | 从来源卡牌飞到目标的攻击表现，必须使用 `projectile.` 键与 projectiles 目录 |

当前 `Effect` 使用 `effect.combat.` 前缀，登记为六类共用命中的 SpriteFrames；不保留没有消费者的逐技能动画登记。`Projectile` 资源命名 `projectile_<名称>.tres`，额外登记逻辑像素 `width`、`height`。静态弹道也使用仅一帧的 SpriteFrames；初始方向朝右，棋盘按来源到目标旋转。逐帧时长与循环由 SpriteFrames 决定；命中窗口统一为 BattlePlayback 的 0.24 秒，各输出类型可在窗口内使用不同的可见飞行段，不参与权威结算。

六类数值卡分别绑定 `projectile.physical / witchcraft / burn / poison / healing / shield`；特殊卡默认键为空。物理与中毒使用新绘制的四帧手绘 PNG 弹体，其余四类仍为 SVG 图集，均由循环 SpriteFrames 播放；弹体可用 `tip_ratio` 元数据声明实际尖端位置。`projectile_motion.gd` 只消费回放进度绘制路径、连续拖尾与弹体。六类效果显式键优先，其次为修正来源替换，最后为卡牌默认；持续伤害每跳不发射，自作用只播局部效果。原 `projectile.default` 与四帧原图保留为可显式使用的覆盖资源。

六类命中独立归 `effects/combat/impact_*/`，每类为 16 帧透明 PNG 图集、非循环 SpriteFrames；前四帧短促展开，接触峰值后播放碎片和消散。棋盘以正常透明混合绘制，不用整层加色；同一时刻的普通与暴击反馈合并为一个落点。物理和中毒已重绘为卡面中心的手绘斩痕与正面腐蚀；中毒常驻使用独立四帧附着图集，不再复用命中尾帧。燃烧仍循环原卡角余韵，其余四类尚未统一新画风。素材来源与提示词见 [命中素材说明](effects/combat/README.md)。

授权循环配乐归 `audio/music/`，章节在 `Progression/chapters.csv` 分别声明路线与战斗音乐键；首页使用独立主题。音乐使用立体声 OGG，来源与署名见 `audio/README.md` 和 `audio/music_license.txt`。通用按钮反馈归 `ui/design_system/audio/`，战斗和冒险交互音效归各自 Feature 的 `ui/audio/`；短音效以 32 kHz 单声道 WAV 保存，Godot 导入压缩用于运行包。

27 类音效以 Kenney 的 Casino、Interface、Impact、RPG 四套 CC0 素材为来源，经短切、滤波、轻量叠层和响度整理，使用纸张、布料、轻接触与少量玻璃亮点构成轻巧、清透的材质方向。每类通过 `AudioStreamRandomizer` 轮换 3–4 个不连续重复的变体，共 85 个短采样；不使用旧版振荡器提示音或合成敲击。来源链接、原始文件与成品 SHA-256 见 `audio/sound_sources.json`，授权说明见 `audio/kenney_license.txt`；该授权不延伸到音乐和其他美术。

`sfx.adventure.dice_roll` 是单次碰撞而非整段滚动，骰盘只读实际物理冲量触发，扣除静态支撑并按强弱调整音量，停稳、隐藏和退出后保持安静。战斗同帧保留一个优先反馈，并用真实时间控制跨类别密度，不随回放加速缩短听觉间隔。普通点击短而轻，施法与状态退居背景，关键命中和结算保留层次；停止局部音效不改变音乐、用户音量偏好或战斗结算。

## 原始资源保全

冒险章节背景中的重复原图集中为 `progression/pve_adventure/art/chapter_backgrounds/shared_locked.png` 与 `shared_unlocked.png`；各章节保留自己的稳定资源键并共享引用。前三章独有主图与首章 AtlasTexture 切片继续留在对应章节目录，不因去重替换画面。

迁移原图只在当前内容、真实消费者或明确的制作／备用用途需要时保留；已确认退役且零引用的 UI 素材连同 `.import` 清理，不为历史数量常驻运行工程。正式登记项以 `asset_registry.json` 为准；资源校验检查存在性与实际 Godot 类型，防止纹理伪装为可播放弹道。

正式技能静态图、六类命中序列及默认备用弹道的共用源图分别保留；删除闲置动画时不能连带删除这些仍被引用的依赖。

原字体许可证随 `ui/design_system/typography/` 保存；本文件不替原始游戏美术声明新的许可。

## 能力定义

当前保留 66 份实际使用的主能力配方；8 份退役配方已退出 CSV 和运行快照。旧存档兼容只在 `tooling/player_data/legacy_save_codec.gd` 保存必要身份，不为历史导入常驻整份技能定义。

卡牌与构筑增强的 `ability_parts` 只声明来源所提供的能力，执行方式与内容类别独立。CooldownMain 引用 `main_abilities.csv`；技能是无独立名称和介绍的运行定义，具体效果参数保留在所属定义。TriggeredPassive 同样保留自身效果参数；PersistentBonus／ConditionalPassive 使用修正对象，强度加成字段为 `action_modifiers`。数值效果的 `Damage` 等类别是结算词汇；上文素材登记的 `Effect` 表示表现资源，二者不得混用。

已有技能静态图归 `abilities/main_abilities/art/`，当前命中序列归 `effects/combat/`；卡牌素材归 `cards/`，遗物归 `relics/`，攻击弹道始终单独归 `projectiles/`。词条、天赋、羁绊已有各自能力表，星能奖励归 Progression；没有实际素材时不为了目录对称建立空素材目录，不把生成快照拆成第二套人工定义。

`runtime/game_catalog.gd` 只负责验证后的只读目录与资源查询。战斗定义和预览帧由 `features/mechanics/assembly/battle_assembly.gd` 创建；共享展示在 `ui/components/content/`，不放回内容加载层。`RuleCodec` 解释内容专属格式，效果和能力语义复用 `AbilitySchema`；发布校验同时检查通用内容约束与当前模式要求。
