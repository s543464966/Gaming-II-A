# 甜甜圈素材与界面

2026-10-08 接入用户提供的 `01_纯色甜甜圈与贴纸`：15 款柔光糖霜甜甜圈与 15 款正俯视贴纸全部入库，立体图用于棋盘、拖拽、补货、收餐、置顶选择和机制说明，俯视图用于订单。百关范围见 [百关实现](level_100_implementation.md)，页面布局见 [UI 校准](ui_alignment.md)。

## 2026-10-09 彩色纸托与机制素材

接入用户 `08_玩法机制/彩色纸托` 的 15 张原图，其中奶白与现有文件相同，其余 14 张从本次来源包入库；15 组纸托及同源前沿的裁切、来源与摘要记录在[机关清单](../Coding/godot/features/donut_sort/board/ui/art/mechanics/asset_manifest.json)。13 个对应口味改为直接显示彩色原图，前沿沿用各自原图的缩放与坐标；不再经过统一染色。口味编号保持现行十五色映射：包内深灰、摩卡仅入库备用，不重新绑定已改为宝蓝、黄色的 11／14；这两种备用口味仍用奶白纸托与原有色板着色。

炸弹、循环、单格纸托和问号四张 PNG 均与工程现有原图逐字节一致，复用原文件及裁切并更新来源记录。单格容量标记、徽章与动态倒计时保持既有呈现；问号图保留备用，隐藏食物继续使用新版灰圈。删除已无消费者的旧 `bomb_icon`、`icon_cycle`、`timer_plate`、`tray_single`、`color_ring` 及配套裁切／导入文件，共 11 个文件，清理页面素材清单。

验证：`node Testing/scripts/run_godot.mjs donut` 通过，退出码 0，无脚本／资源错误；初次沙箱导入因编辑器设置写入限制停止，允许本机引擎访问后同一标准入口通过。Compatibility 渲染十五组口味、单格／循环／炸弹／备用问号，以及 393×852、320×568 下第 24／41／61／81 关；保留[组件总览](../Archive/ReferenceImage/donut_mechanics_palette.png)、[手机固定纸托](../Archive/ReferenceImage/donut_mechanics_393_041.png)、[短屏炸弹](../Archive/ReferenceImage/donut_mechanics_320_081.png)。100 关与目录共 101 份文件摘要未变，本轮未改玩法或关卡，未重跑 `hundred`。`node Tooling/export/web.mjs` 仍因固定目录缺少 Godot 4.5.1 Web 模板而停止，网页包未更新，未做小游戏真机验收。

## 2026-10-08 纸托与整叠冰壳

按用户确认接入 `02_纸托与新冰冻`：新增 `board/ui/art/mechanics/ice_stack_shell.png` 及 AtlasTexture；该 PNG 与用户原件字节一致。普通／数字冰冻共用一只整叠冰壳，分别适配三层和四层；顶部与底沿保持同一缩放倍率，中段按高度伸缩，不把整个轮廓压扁。九宫格源图上沿 270、下沿 235 像素，左右不切片；显示不透明度 0.8，让内部口味和下层仍可辨认。食物四周预留水平 14、垂直 8 设计单位，开局居中同步计算冰壳上沿，解冻与撤回只刷新呈现，不修改规则。

纸托、封盖、时钟 PNG 与工程现有文件完全相同，复用唯一原图；纸托与封盖按用户新 `.tres` 收紧透明留白，时钟连裁切也相同，保持原样。普通纸托新增用户提供的 `paper_holder_round_front.tres`；固定色和单颗纸托分别从自身原图定义前沿裁片，保留口味颜色和单颗“1”标记。前沿共用底图缩放、颜色和原图坐标偏移，覆盖最底层的小段饼底；空盒、锁位、封盖和食物全部飞离时隐藏前沿。

本包灰圈宽高比约 1.41，与已接入彩色甜甜圈约 1.20 不匹配，按确认方案保留当前 `soft_glaze_hidden_gray`，没有复制另一套灰圈。旧逐颗冰霜、停用冰罩及其裁切／导入描述共 6 个文件已删除，运行代码和清单引用同步移除。机制说明复用正式冻结盒，而不是显示空冰罩图片。

实际 Compatibility 截图：[组件与三／四层](../Archive/ReferenceImage/donut_ice_shell_components.png)、[手机五排](../Archive/ReferenceImage/donut_ice_shell_393_004.png)、[短屏五排](../Archive/ReferenceImage/donut_ice_shell_320_004.png)、[冰冻说明](../Archive/ReferenceImage/donut_ice_shell_lesson_393.png)。当前测试入口为 `Testing/visual/ice_shell_capture.gd` 和 `donut` 回归，执行结果见 [测试记录](../Testing/README.md)。

## 2026-10-08 订单盒与打包素材

按用户要求接入 `03_订单盒与打包` 的 8 张 PNG 与 9 份 AtlasTexture，统一放在 `features/donut_sort/orders/ui/art/`。六色空盒 PNG 与工程原图字节一致，保留唯一原件并采用用户新裁切；新增 `order_box_filled_four`、`order_box_closed` 两张原图及裁切。`order_box_shadow.tres` 复用工程中与来源包字节一致的通用阴影，不复制另一张 PNG。路径、裁切及 SHA-256 见[订单素材清单](../Coding/godot/features/donut_sort/orders/ui/art/asset_manifest.json)。

六色盒用于当前订单卡；贴纸、锁和完成标记按原图标牌中心 `(621, 412)`、各色裁切与实际等比留白定位，刷新口味或改变尺寸时同步对齐。锁定去色和逐颗落盒流程保持现有实现。满盒、闭盒与独立投影已入库备用，当前收餐动画不切换这两张静态图，避免把其他口味显示成图内固定的四颗草莓粉食物。

删除停用的 `ui/art/trays/package_closed` 与 `board/ui/art/paper_package_closed`，连同裁切和导入描述共 6 个文件；清理两处素材清单。棋盘场景的默认盖纹理改为其运行时一直使用的 `cover_opaque_round`，不再加载旧包装盒。

实际验证：8 张 PNG 字节与 9 份裁切均和来源一致，资源路径、清单摘要与引擎加载检查通过。`node Testing/scripts/run_godot.mjs donut` 首次检测到新裁切下的标牌偏移，修复后完整回归通过；Compatibility 渲染检查长短屏收餐共 160 帧。截图：[九份资源](../Archive/ReferenceImage/donut_order_boxes_assets.png)、[手机收餐](../Archive/ReferenceImage/donut_order_boxes_phone.png)、[短屏收餐](../Archive/ReferenceImage/donut_order_boxes_short.png)。网页导出在模板检查阶段停止：本机缺少 `Tooling/.runtime/godot-platform/web-4.5.1/web_nothreads_debug.zip`（对应目录不存在），本轮未生成网页包；未做平台真机验收。

## 2026-10-08 按钮与通用 UI

接入用户 `05_按钮与通用UI` 的 11 张 PNG 与 10 份资源配置。11 张 PNG 与当前对应原图字节一致，复用唯一原件；按钮底板、撤回／加餐盒／置顶图标、关卡标题底板和锁图标采用用户新裁切。次数角标、闪光裁切以及显示字体／Theme 在适配工程路径后均与现有配置一致，保持原样。

设置与三个道具按钮统一引用 `design_system/art/button_base.tres`，移除道具目录中的旧底板裁切和设置场景的重复内嵌裁切。清理 `ui/art/icons/` 下停用的三种旧道具图标及重复金币，连同 `.tres` 和 `.import` 共 12 个文件；保留 `tools/ui/art/` 的新图标与 `currency/ui/art/` 的唯一金币。四处素材清单同步更新来源、裁切和引用。金币栏继续隐藏，不因素材接入恢复显示。

`node Testing/scripts/run_godot.mjs architecture home donut` 通过，资源定义与用户文件逐项一致（仅适配路径），无旧路径残留。Compatibility 输出并检查按钮未领取／已领取／耗尽状态和 393×852／320×568 下第 1、4 关；截图：[组件与状态](../Archive/ReferenceImage/donut_common_ui_components.png)、[手机页面](../Archive/ReferenceImage/donut_common_ui_phone.png)、[短屏五排](../Archive/ReferenceImage/donut_common_ui_short.png)。未改规则、关卡或字体文件；本轮未导出网页／小游戏包，缺失的本机 Web 模板仍未安装，未做真机验收。

## 当前资源与编号

两张 PNG 与用户源文件逐字节一致，不重绘、不缩小。30 份 AtlasTexture 保留用户给定裁切区域，只修复 `res://` 路径。正文图集为 `game_content/donuts/art/soft_glaze_palette.png`；贴纸图集为 `features/donut_sort/orders/ui/art/soft_glaze_stickers.png`，两处 `.tres` 分别使用 `soft_glaze_<颜色>` 与 `soft_glaze_sticker_<颜色>`。

| 口味 ID | 新颜色 | 使用范围 |
| --- | --- | --- |
| 0 | `pink` | 当前关卡使用 |
| 1 | `cocoa` | 当前关卡使用 |
| 2 | `forest_green` | 当前关卡使用 |
| 3 | `sky_blue` | 当前关卡使用 |
| 4 | `orange` | 当前关卡使用 |
| 5 | `ivory` | 当前关卡使用 |
| 6 | `purple` | 当前关卡使用 |
| 7 | `raspberry` | 当前关卡使用 |
| 8 | `red` | 当前关卡使用 |
| 9 | `caramel` | 当前关卡使用 |
| 10 | `teal` | 备用，当前百关未使用 |
| 11 | `royal_blue` | 备用，当前百关未使用 |
| 12 | `lime` | 当前关卡使用 |
| 13 | `lavender` | 备用，当前百关未使用 |
| 14 | `yellow` | 备用，当前百关未使用 |

当前百关合计使用 11 个口味 ID，按每关配置展示，不能理解为每关都出现 15 色。编号 11、14 原本属于未使用的深灰、摩卡，现分别收录宝蓝和明黄；其余映射保持对应色系。未修改任何关卡定义、层序、需求、固定口味规则或完整解文件。

灰色隐藏圈采用内置 imagegen 按新版形状生成，灰色糖霜与灰色饼底、透明背景与洞口；首次露顶后仍按原规则永久揭示，再堆叠不变灰。资源为 [`soft_glaze_hidden_gray.png`](../Coding/godot/game_content/donuts/art/soft_glaze_hidden_gray.png)。提示词、哈希与裁切框记录在[食物清单](../Coding/godot/game_content/donuts/art/asset_manifest.json)；订单配对记录在[订单清单](../Coding/godot/features/donut_sort/orders/ui/art/asset_manifest.json)。

固定口味纸托按盒子的指定口味绑定本次彩色原图，清空或食物变化不改底色。仅素材包缺少的宝蓝、黄色备用口味保留 `fixed_holder_tint.gdshader` 着色；各盒材料实例独立，普通纸托与已有对应原图的纸托关闭染色。普通纸托、数字盖及整叠冰壳保持现有资源，循环和炸弹徽章复用与本次来源一致的原图，见[机关清单](../Coding/godot/features/donut_sort/board/ui/art/mechanics/asset_manifest.json)。

## 尺寸与动态呈现

新版立体图裁切宽高比约 1.20，食物容器由 160×114 调整为 160×136；TextureRect 始终等比适配。底端仍落在纸托局部 y=108，层距改为 40，满四层选中上沿预留为 169。这样保持可见宽度和纸托落点，并继续满足五排小屏的预留空间。冰壳覆盖整叠，顶部和底沿保留比例，中段适配实际层数。

拖拽只让首颗跟手，其余同味颗粒逐颗错峰起飞；收餐改为统一倍率缩放、对齐盒口中心并向下裁切，避免按盒口宽高分别缩放而压扁甜甜圈。补货共用正式盒子。操作命中仍包含整叠上缘，不增加落点文案、描边或合法性明暗提示。

## 替换范围

2026-10-08 柔光糖霜接入时曾按用户确认删除被替代的旧食物、旧贴纸、旧灰圈和 14 份独立颜色纸托，以及对应 AtlasTexture／导入描述；当时共移除 57 张 PNG、167 个文件，约 50.5 MiB 原始资源。2026-10-09 已按本次提供的彩色纸托包重新接入 14 张原图，当前映射与旧机制清理范围见上方记录。清理教学场景和页面清单中残留的旧食物引用。

背景、道具图标、机关封盖、普通纸托及失败弹窗插画属于其他界面资源，继续保留；六色翻盖订单盒及旧包装盒的后续处理见上方订单盒接入记录。失败弹窗已接入 2026-10-09 用户定稿：中文保留原图立体字，英文使用去字底图与本地化文字层，按钮为独立图标；当前图片来源见[失败素材清单](../Coding/godot/features/donut_sort/failure/ui/art/asset_manifest.json)。Archive 中旧截图只用于历史对照，不作为运行资源。

## 核对入口

`Testing/visual/soft_glaze_capture.gd` 直接渲染 15 组食物与订单贴纸、固定色纸托、灰圈与冰冻堆叠，并捕获 393×852 和 320×568 下的第 1／4／6／86／89 关。检查 Atlas 边界、口味配对、原色纸托与备用着色及材料实例独立；界面与动作回归仍由 `donut` 套件负责。实际执行结果见 [测试记录](../Testing/README.md)。
