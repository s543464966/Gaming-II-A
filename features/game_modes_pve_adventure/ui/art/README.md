# 冒险路线美术

路线采用独立无边框底图和节点图案；文字、进度标记、连线与命中区域均由原生 UI 绘制。

- `route_background.png`：941 × 1672，章节通用的黑色纹理底；没有节点、文字或预绘制路线，仅 Route 阶段使用。
- `route_nodes.png`：1774 × 887，八个节点：起点、普通、精英、首领、遗迹、黑市、奇遇、未知。原始图是 RGB，不具有透明通道；只能由 `route_node.gd` 的牌面 UV 轮廓取样，不能直接放进 TextureRect。轮廓裁去外部棋盘格；更新图集时必须同步核对区域和轮廓、精英旗帜下沿及缩小后的边缘。
- 字体和颜色由 `ui/design_system/themes/adventure_route.tres` 管理；骨白切角面板是该主题旁的原生 SVG。按钮保持原生触摸取消与键盘输入，浮层不改变路线偏移。
- 牌面为 96 逻辑像素，原生命中区最大为 156 × 168，层距为 224；标题和当前位置仍由场景独立排版。完成盾章始终保留，可前往用金边，已知不可前往用压暗图案与减号，未知只露问号，查看用骨白角标；当前位置是可叠加标记。
- `route_node.gd` 的牌面轮廓同时用于 UV、连线交点和定位。已揭示节点的入线从侧面绕开标题／当前位置，未知节点直接接入下沿；全部路径仍来自真实 `next`，不会因选中或换语言改变拓扑。
- 连线与状态由原生绘制及当前节点图集表达，不再保留旧直线贴图、状态图或对应资源登记。

来源：内置 ImageGen，依据用户确认的完整 Home 风格路线稿生成。两张 PNG 原始字节保留；未把生成稿中的横向黑市连接、示例数值或文字带入运行逻辑。

生成提示词：

## route_bg

Use case: precise-object-edit. Extract a clean production BACKGROUND texture from this approved fantasy chapter route UI. Output one portrait 1024x1824 opaque image. Preserve the exact charcoal-black fine cracked lacquer/paper material and the very faint aged-gold contour engravings at the far side margins, same matte hand-painted game UI quality. Remove ALL interface elements: portrait, resource strip, numbers, text, arrows, settings, headings, node badges, compass, all route connections, shadows of removed objects, and all frames. Reconstruct seamless clean charcoal material where they were. Center 75% should remain quiet, low contrast, broadly even value for a scrolling node graph drawn separately. No landscape, archway, mountains, lava, stars, light source, parchment outline, panel border or centerpiece. No visible symbol or text anywhere. Preserve natural fine texture without large distracting cracks. Full bleed, no border. This neutral material must work across every chapter.

## route_nodes

Use case: stylized-concept. Produce ONE production sprite atlas for the approved chapter route screen shown in the reference. Actual transparent RGBA background, not a checkerboard, black canvas or white canvas. Exactly 4 columns by 2 rows of equal square cells, image 2048x1024. Each cell is512x512, each standalone sprite centered at its cell center, entire sprite including faint shadow fits within the central400x400, generous transparent gaps, no part crosses a cell. No gridlines, titles, captions, status checks, selection rings, route lines, numbers or text, except the ? in cell8. Same scale for all8sprites. Match the reference's thin worn antique-gold faceted octagonal frames, charcoal textured enamel core, bone-ivory painted symbols, restrained surface facets, shallow hand-painted relief. Match its complete finished node artwork exactly; not cartoon flat vectors and not shiny 3D jewelry. Each node includes a compact dark octagonal plaque and thin gold edge, identical nominal frame dimensions. Row1 left-to-right: (1) START — a small expedition gate with a single upright short sword; (2) NORMAL BATTLE — the reference crossed ivory blades and gold guards on black plaque; (3) ELITE BATTLE — the reference dark rust-red hanging pennant with crossed ivory blades, integrated inside its gold edged plaque; (4) BOSS — a dark frontal horned knight helmet with a small ivory crown motif, integrated gold and ivory planes, distinguishable from elite, no glowing eyes. Row2 left-to-right: (5) RELIC — the reference small classical temple with three ivory-gold pillars; (6) MARKET — the reference miniature warm ochre shop canopy and hanging sign; (7) ENCOUNTER — an open ivory storybook with a small gold four-point glint, no letters; (8) UNKNOWN — same dark plaque with only one large muted antique-gold question mark, no other hint to concealed content. The reference includes status dimming but this atlas is uniformly normal brightness so code can dim instances. Preserve genuine alpha outside each plaque and pennant. No whole-screen background. No reused player portrait or HUD. Final atlas exactly4by2 on transparency.


图集复核修正提示词：移除图集中误画的棋盘格，保留八个节点的画风、尺寸和布局，输出真实透明 PNG。生成结果仍为 RGB，因此运行时采用上述轮廓取样，不宣称该图集已经透明。

## 奖励三选一

`reward_choice_sheet.png` 为用户确认的无字 UI 定稿的深色底版本（941×1672）。保留细金边、羊皮纸、黑色标题底和刷新箭头，移除了浅底混入轮廓的白边。原图以无损方式导入，启用 mipmaps；顶部装饰和技能饰线继续取自这张图集；完整纸面、标题牌、刷新、次数圆框与倒计时圆环各用独立无字原图，不复制卡牌内容。

| 切片资源 | 原图矩形（x, y, width, height） | 用途 |
| --- | --- | --- |
| `reward_paper.tres` | 独立 `reward_paper_background.png`，原图 66, 62, 608, 2016 | 连续完整的无字纸面及外框 |
| `reward_nameplate.tres` | 独立 `reward_nameplate.png`，原图 128, 194, 1788, 348 | 空标题牌，单独叠在纸面上 |
| `reward_divider.tres` | 51, 1198, 232, 24 | 随真实技能／队伍效果分区放置的饰线 |
| `reward_title_rule.tres` | 180, 191, 139, 35 | 主标题两侧饰线，右侧镜像 |
| `reward_subtitle_mark.tres` | 372, 254, 32, 30 | 副标题菱形 |
| `reward_timer_ring.tres` | 独立 `reward_timer_background.png` 的有效图案区域 | 无字双环与四向刻度 |
| `reward_refresh_button.tres` | 独立 `reward_refresh_icon.png` 的有效图案区域 | 补齐完整外环的刷新箭头，不含次数徽章 |
| `reward_badge.tres` | 独立 `reward_refresh_badge.png` 的有效图案区域 | 无字次数圆框 |

`reward_icon.gdshader` 在渲染时去除图集底色，保留纸面和圆环轮廓内部的深色填充，并移除边缘混入的底色。对应 `*_cutout.tres` 保存导入后纹理坐标中的不透明内区；饰线单独从纸色中提取。这是原生 AtlasTexture 加透明材质，源 PNG 本身仍是 RGB，不冒充已有 alpha 的独立 PNG。

布局仍在 `reward_page.tscn`、`reward_card.tscn`：标题按整页中轴居中，计时环独立靠右；三栏留 16 逻辑像素的页面边距，顶部及刷新按钮参考原图比例。背景和装饰忽略鼠标，整张候选点击即领取；刷新次数、标题、实际卡面与规则效果由原生控件实时绘制，长正文保留触摸滚动。普通／悬停／按下／禁用以轻微明度差表达。

较早使用的局部参考图已原字节保留在工作区 `Archive/ReferenceImage/reward_refresh_reference.png` 和 `reward_header_reference.png`，运行时不再引用。

本次深色底由内置 ImageGen 编辑生成，主要提示词：保持 941×1672 布局、尺寸和所有 UI 位置不变，仅把 UI 外的浅灰底换成 #10120f 深炭色；清除轮廓外的白色底边并对深色底抗锯齿，保留金边、象牙白纸面和原有细节，不新增文字、卡牌或按钮。

刷新入口分为三个独立层：Button 的图标、`Remaining/Frame` 的次数圆框、`Remaining` 的原生数字。圆框与数字可整体移动／隐藏；调整它们不裁掉主图，主刷新环已补齐原遮挡处。两张独立 1254×1254 源图保持原字节，导入分别限制到 256×256 并保留 mipmaps，Atlas 坐标按 256/1254 缩放，避免小按钮占用高分辨率纹理内存。

独立素材使用内置 ImageGen 从深色定稿图提取：主图仅保留完整刷新环与两段箭头，移除右下小徽章并补全遮挡；次数图仅保留黑底细金边空圆框。均要求深炭色底、无文字、无白边，不增加厚金属造型。

倒计时由 `ChoiceHeader/Timer` 容器内两个同级控件构成：`Frame` 只绘制无字圆环，`Value` 只绘制实际剩余秒数。显隐文字不影响圆环、布局或完成入口；到期事务和绝对截止时间仍由原奖励流程维护。`reward_timer_background.png` 保留 1254×1254 源图，导入缩至 256×256，`reward_timer_ring.tres` 按同一比例取源图矩形 (133, 125, 990, 994)。

倒计时素材由内置 ImageGen 提取：仅保留右上空计时环、细双金线、四个短刻度和黑色内底，四周深炭色；无数字、文字、指针或额外装饰，清理浅色底边，不增加厚金属高光。

三选一纸面已移除原来的上下两段拼接：`Paper/Background` 使用完整纸面，`Title/Frame` 使用独立黑金标题牌。两者均为 NinePatchRect，显示比例固定为 0.75，切片边距 24，只有中间区域随容器尺寸伸缩；标题牌的内凹四角使用独立轮廓参数，文字、卡面和滚动效果不被烘焙到素材中。

纸面原图为 736×2138，导入限制长边 1069，正好缩至 368×1069，Atlas 使用原图坐标的二分之一；标题牌原图 2048×768，导入 512×192，Atlas 使用四分之一坐标。三栏复用同一组纹理。旧 `reward_paper_footer.tres` 与纸面专用旧轮廓材质已移除。

纸面和标题牌使用内置 ImageGen 从深色定稿提取。纸面只保留完整外框和羊皮纸，移除标题牌、固定饰线与文字；标题牌单独保留黑底、细金轮廓及内凹四角。纸面复核后再次清理：沿四边的内侧细线改为连续、粗细均匀的暖金描边，移除斑驳反光、断线和污渍状深浅斑块，保留纸面纹理及外部深炭色底；不增加厚金属边或白色光晕。

胜利骰盘的 `victory_drop_active.png` 保留完整原始素材，运行时仅由 `reward_dice_tray.tscn` 中四个 AtlasTexture 取出折角，分别锚定触发区四角。Atlas 坐标按导入宽度 1024 / 原图宽度 1810 缩放，并使用 `victory_cutout.tres` 移除黑底；不绘制原图中央纹理、骰子图案和边缘中段。拖入只提亮折角与原生文字，不叠加矩形底光。默认轻提示单独使用 `victory_drop_hint.png`，拿起骰子时隐藏。

## 遗迹、黑市与奇遇

三种关卡复用原生资源栏、共享字体、黑金标题和纸面按钮，并分别使用独立无文字背景：

- `ruins_background.png`：940 × 1672 的星殿、紫色晶体和祭坛。`reward_page.tscn` 的星能区域显示章节触发进度与本次轮次；`aurora_choice.tscn` 复用现有奖励纸面与标题牌，三张整牌直接选择。纸牌与目标列表使用正文滚动，完成入口固定在底部。
- `black_market_background.png`：941 × 1672 的篷布、灯笼、天平和空摊位。`event_page.tscn` 保留碎片三栏、货币兑换两栏与体力两栏；`market_offer.tscn` 只承载当前保存的商品，价格使用原生数值与货币图标。两种支付共用一次购买资格，已购项目原位禁用。
- `encounter_background.png`：939 × 1676 的遗迹拱门、旅途手记和石台。收获与代价共用一张纸面契约；底部保留接受、一次刷新和放弃，满队替换时收起插画留白，保留契约并在正文滚动区域显示候选。

这三张图片由内置 ImageGen 从用户确认的页面方案提取，源 PNG 原字节保留；移除全部界面文案、价格、图标、按钮和商品，仅保留场景插画，并延伸低对比的深色底面。背景使用 mipmaps，文字、按钮及命中区域都由 Godot 原生控件绘制。奖励与商品插画读取正式内容原图，资源余额使用设计系统图标，大尺寸奖励使用已有物品插画；不把方案中的示例奖励写入真实章节。

提取提示词要点：遗迹保留上方约 39% 的晶体与祭坛，中央下方保持安静的深炭色石面；黑市保留上方约 16% 的篷布与灯笼，下方去除商品和货架；奇遇保留上方约 42% 的拱门与打开的手记，下方延伸无 UI 的深色石台。三者沿用项目的手绘暗色奇幻画风、暖金点缀和克制的边缘细节。

`event_die.svg` 是奇遇契约的原生矢量骰子标记，沿用骨白与旧金配色，以骰面点数表达额外骰子，不复用带有伤害符号的战斗骰面。
