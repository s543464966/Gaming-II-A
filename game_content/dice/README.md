# 奖励骰美术

`art/faces/reward_faces.png` 是当前四类骰子使用的无字图集，通过唯一资源键 `dice.reward_surface` 使用。原始 1254×1254 PNG 保留，Godot 导入为 1024×1024 并生成 mipmaps；图集不烘焙金额、名称或界面文字。

| 区域 | 骰子 | 轮廓与材质 |
| --- | --- | --- |
| 左上 | 遗物 | D6，深青石材、青铜六角遗物徽记 |
| 右上 | 卡牌 | D6，暖纸面、铜金包边、叠牌星纹 |
| 左下 | 星石 | D4，绿色石材、三角嵌框、小星石纹章，中央偏下留给动态金额 |
| 右下 | 宝物 | D8，金色三角底材与晶体星纹封印；不提前承诺碎片或金额 |

`dice.relic_surface` 为遗物定义的稳定资源键，通过 `art/faces/relic_surface.tres` 取图集左上块；微信导出器标识也复用这个切片，不维护另一张遗物贴图或旧骰面副本。

`features/game_modes_pve_adventure/ui/reward_die_mesh.gd` 构造实际凸多面体、共享面材质与合并金属棱框。三角面按真实顶角建立完整 UV，不再扩放、裁掉图案；碰撞体的原始顶点不变。骰面和面数不参与抽奖。

金额事实来自已保存的 `die.reward.amount`，经 RewardPage → DiceTray → DieMesh 绑定。当前星石池为 100／200／300，但 UI 不写死档位；`set_amount()` 支持未来金额，长数字自动缩放。同一轮更新金额只改文字，不重建、重投或旋转骰子，不污染其他实例。四面体各面显示本次同一个实得金额，不把四面解释成四档概率。

字体样式在 `features/game_modes_pve_adventure/ui/reward_die_amount.tscn` 的原生 `Label3D` 中编辑：`font`、`font_size`、`pixel_size`、`modulate`、`outline_modulate` 和 `outline_size` 分别控制字体、字号、物理尺度、字色与描边。文字随真实骰面旋转，受深度遮挡，不朝相机悬浮，也不生成每个金额的图片。金额为零或尚未确定时隐藏文字。

星石继续按内容规则即时入账；奖励页只读展示本场最近一颗星石骰与金额，不重复消费。宝物骰的碎片或 500～600 星石在展开候选时才确定，骰面仅显示类别纹章，候选卡仍由原生文字显示真实金额。规则的人工参数仍只在 Progression 的 `dice_reward_pools.csv` 维护，修改参数后走既有 preview → sync → validate；本次未改奖励数值、概率、CSV 或存档。

三维投掷使用 Adventure UI 内的隐藏宽浅承托面：活动范围铺满可用宽度，中心高度 -5、四周外沿 -4.6，均匀缓升只温和限制散滚，不聚拢到固定中心。封闭挡面防止飞出；骰盘没有可见网格，画面只保留骰子、跟随真实离地高度变化的柔和阴影及就近铭牌。从边缘横向投出后，由物理模拟决定碰撞、落点和朝向，不按时长拉回、冻结或摆正。自然静止后才允许拖拽，取消返回实际落地姿态。相机完整框住物理空间，缩放视口不移动刚体。

定向验证从工作区运行 `node Testing/scripts/run_godot.mjs reward-dice-faces reward-dice-motion reward-dice-tray adventure-scene content`。原生骰面截图可用固定引擎运行 `test_reward_dice_faces.gd`，显式设置 `MAGICA_DICE_FACE_VISUAL=1` 与本轮 `Testing/.runtime/` 隔离目录；普通无头回归不输出图片。

生成提示摘要：以旧图集和现有绿色星石图标作风格参考，重绘等分 2×2 正交骰面图集；左上深青青铜六角遗物、右上羊皮纸叠牌、左下绿色三角小星石与空白金额区、右下金色三角晶体星纹封印。所有图块保持完整底材，不含文字、数字、透视、外部投影或水印。使用内置 ImageGen，未使用 CLI；完整提示保留在任务记录。
