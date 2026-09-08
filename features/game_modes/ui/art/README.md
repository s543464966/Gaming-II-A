# 模式选择素材与接入记录

本页按已确认的「画框巡游」纯 UI 方案接入 Godot 原生控件。正文、章节名称和状态来自运行时内容；不把带文字的整页抠图当成运行时界面。

- `mode_atlas.png`：原始无文字图集，继续由 AtlasTexture 引用提示框、金边、纸面、箭头和图标；本轮没有重绘位图，避免细碎肌理累积。
- 页面底色使用场景内的柔和深灰渐变，去掉全屏压纹。活动页仍保留原来的共用背景资源。
- `ui/design_system/icons/common/immersive_back.png`：从图集返回区域 `(799,40,111,111)` 无缩放裁出，作为沉浸式页面共用的菱形返回图标。
- `mode_selected_plaque.png`：按用户补充参考生成的空白切角黑金徽牌，内侧金线已加粗提亮并改成连续闭合切角。源文件是 1451 × 1084 RGB，原生材质按实际源图切角内缩裁切，并移除采样中的中性浅底残留；金色高光保留。仅徽牌启用 mipmaps 和线性多级采样，避免缩小或滑动时细线出现断续像素。
- 页面布局与材质：[`game_modes_page.tscn`](../game_modes_page.tscn)。
- 浏览、确认与过渡：[`game_modes_page.gd`](../game_modes_page.gd)。
- 三个巡游位置共用 [`chapter_card.tscn`](../chapter_card.tscn) 与 [`chapter_card.gd`](../chapter_card.gd)：原画、底部章名、奶白色「当前使用」牌及文字渐暗遮罩归同一张卡片。
- `cut_corner.gdshader`：清除图集切角外的矩形底色；画框同时清除原图内部黑底，不产生宽黑边。
- `chapter_art.gdshader`：原画等比覆盖并裁去画框切角；进入或返回 Home 时逐渐恢复与 Home 一致的居中取景。

设计画布为 941 × 1672。主框为 `(107,196,725,1044)`，邻章以同一水平中心线排列并缩小至 88%；横移时整张卡片连续缩放，章名与状态随卡片淡入淡出。章名放在框内下方，去掉框外大标题牌和重复的已选择文案。三个定位菱形用短细线连接，更多章节时总宽度最多 290。

确认按钮可见纸面为 `(210,1316,521,105)`，透明点击区保持 144 高，窄屏也不牺牲触控面积。底栏只保留一块连续奶白底板和一块移动徽牌；奶白底板高 154，黑色徽牌高 187，四格图标与文字保留原排版、随选中状态变色。顶部返回区域沿用原实现。

每次进入重新读取账号已确认章节，未提交浏览位置不跨页面保留。未解锁章节仍显示禁用的「未解锁」，只有选择用例保存成功后才返回 Home，并展开同一背景资源。

素材使用内置 imagegen 工具生成，没有切换到 CLI/API；工具未提供可验证的模型型号。下面保存图集整理约束以及后两张素材的完整生成提示词。

## 图集整理约束

Input is the approved 941 × 1672 picture-frame carousel UI design. Preserve positions, silhouettes, thin double warm-gold borders, subtly embossed dark material, diamond arrows, parchment action panel and footer icons. Remove all baked Chinese text, digits and chapter scenery; replace chapter image interiors with clean black areas, and leave all label areas blank for native Godot controls. No extra UI, no layout redesign, no heavy stone borders.

## 连续背景的生成提示词

Use case: precise-object-edit. Asset type: native game UI full-screen background texture. Edit target: supplied UI atlas. Remove EVERY foreground object: every frame, gold border, diamond, arrow, cream panel, icon, black chapter window. Fill the entire 941 x 1672 portrait canvas with ONLY the same charcoal-black subtly embossed floral leather/textile material visible in the gaps of the reference. This is a clean background extraction with no UI components remaining. Preserve the original very dark neutral charcoal color (#191918 approximately), fine low contrast ornamental pattern and painterly material. Even illumination across the whole surface, no rectangular patches, no grid, no horizontal bands, no vignetting, no borders, no text, no symbols, no marble cracks, no stone blocks. Full bleed texture, perfectly continuous from top to bottom.

## 黑色选中徽牌的生成提示词

Use case: background-extraction. Input: screenshot of approved fantasy game mode tab bar. Edit target: ONLY the black selected Adventure plaque at the left. Deliver a single isolated reusable blank black plaque asset on a genuinely transparent background. Remove the mountain icon and Chinese text completely, restoring the subtly embossed black material behind them. Preserve exactly this plaque's silhouette: a WIDE OCTAGONAL RECTANGLE with straight diagonal chamfered corners, horizontal top and bottom, vertical middle sides; thin double warm gold metal rims, shallow bevel, restrained highlights. Keep the geometry, black texture and metal treatment of the supplied leftmost selected tab, not an ornate concave-corner title plaque. Plaque aspect ratio approx 1.37 width:1 height. It must be completely blank inside. Crop tightly around the plaque with only a tiny transparent margin. Exclude the entire cream bar and all other icons, letters and background. High resolution crisp hand-painted fantasy UI material, actual PNG alpha transparency, no checkerboard baked in. The output is one blank reusable plaque, not a screen mockup.

## 内侧金线优化提示词

Use case: precise-object-edit. Asset type: reusable blank selected-tab plaque for a fantasy mobile game. Input image is the EDIT TARGET. Fix ONLY the inner thin gold outline on the black face: it currently becomes broken dotted pixels when the asset is displayed at 242 by 187 UI units or 100 by 77 actual pixels. Repaint that INNER outline as one perfectly continuous, clean, even-weight warm antique-gold closed octagonal contour, approximately 12 source pixels wide at this 1470 by 1070 source size. Strong enough contrast against charcoal to survive reduction, softly metallic but never dark gaps or glitter. Simplify the tiny stepped corner joints into clean straight connected chamfers; no interrupted segments, no distressed edges. Keep exactly the same outer silhouette, outer metallic bevel frame, black leather texture, proportions, position and canvas dimensions as input. Outer object coordinates approximately x74 to1396, y100 to978. Do not change the pale checkerboard outside the object or expand the object. No symbols, no lettering, no new ornaments. The only change is a substantially clearer continuous inset gold contour, suitable for a small game UI button.

## 本轮验证范围

- Home 与 Mobile Layout：三章实际按钮选择、保存失败、未解锁状态、快速正反向浏览、滑动中切模式、强制关闭，以及首次切模式的位移和颜色中间帧。
- 新增画框缩放中仍保持中心线、章名与状态归属、侧章文字淡入及窄屏框内文案边界检查。
- 「当前使用」六语言人工文案经过 preview、sync、validate，Localization 组验证通过。
- Compatibility 原生 720 × 1280 和 320 × 568 截图覆盖三章、章节横移、模式切换与德语窄屏。未进行小游戏真机验收。
