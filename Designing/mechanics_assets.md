# 甜甜圈素材与界面

状态：已接入 `donut_game_assets_v1`、v7 的背景、订单与纸盒素材，以及用户提供的五张道具按钮图。当前盒形、堆叠和按钮布局依据为 [已确认参考图](../Archive/ReferenceImage/donut_sort_layout_and_style_approved.png)；[上一版参考图](../Archive/ReferenceImage/donut_sort_reference.png)与旧 v1～v3 截图只作历史对照。

## 收录与归属

v1 的 11 张甜甜圈归 `Coding/godot/game_content/donuts/art/`，保留的页面素材归 `Coding/godot/features/donut_sort/ui/art/`；独立木质棋盘和被替换的旧店铺背景已删除。v7 的店铺背景与浅色木台归页面 `ui/art/scene/`，一体式四卡底板归 `orders/ui/art/`，3 张纸盒 PNG 归 `board/ui/art/`，金币栏归 `currency/ui/art/`，设置图标归 `settings/ui/art/`。用户提供的 3 张道具图标分别归撤回、加餐盒、置顶模块；设置与道具按钮共用的一份浅色底板归 `design_system/art/`，次数角标归 `tools/ui/art/`。新原图均未修改。完整路径、尺寸及 SHA-256 见[页面素材清单](../Coding/godot/features/donut_sort/ui/art/asset_manifest.json)、[v7 纸盒清单](../Coding/godot/features/donut_sort/board/ui/art/asset_manifest.json)、[金币清单](../Coding/godot/features/donut_sort/currency/ui/art/asset_manifest.json)、[设置清单](../Coding/godot/features/donut_sort/settings/ui/art/asset_manifest.json)、[共用按钮底板清单](../Coding/godot/design_system/art/asset_manifest.json)与[道具清单](../Coding/godot/features/donut_sort/tools/ui/art/asset_manifest.json)。包内预览、HTML 和制作过程文件不作为运行素材复制。

v1 的部分素材仍作备用，旧透明餐盒现已被 v7 纸盒替代。纸盒 PNG 使用 Godot 纹理导入，源 PNG 的 SHA-256 不变。另以旧问号甜甜圈为形状参考，通过内置 imagegen 生成 1254×1254 透明灰色甜甜圈 [`donut_concealed_gray.png`](../Coding/godot/game_content/donuts/art/donut_concealed_gray.png)；旧图仍保留供素材追溯，但运行时隐藏层改用灰色图。

实际使用的 `.tres` 只定义 PNG 的透明留白区域，不重绘或缩小原始美术。餐盒前后层共用同一裁切区域和显示矩形，出餐纸盒前后层也共用区域，避免独立裁边造成错位。PNG 保留可供后续制作的原始画布。

| 已接入部分 | 素材 |
| --- | --- |
| 七种正式口味 | 粉色彩糖、巧克力坚果、抹茶淋面、蓝莓、柠檬淋面、香草彩糖、紫色彩糖；口味 ID 依次为 0、1、2、3、4、5、6，每关开局均出现七种 |
| 场景与边缘装饰 | 店铺背景、出餐纸盒前后层、黑板、粉盒、盆栽、前景叶片、卡片、咖啡与糖针 |
| 订单和道具 | 标题、订单计数与夹板、订单面板及开放／锁定卡片、备货面板；同款浅色方形按钮、粉色撤回图标、纸盒加号、紫色置顶图标及粉色次数角标 |
| 餐盒与已有机关 | v7 敞口纸盒后层与前沿、粉色缎带封口包装、锁图标、白霜、灰色隐藏层甜甜圈、等待需求标记 |
| 操作反馈与奖励 | 选中框、上升箭头、闪光、常驻金币栏与本关奖励 |

暂未启用但已收录：另外 4 款甜甜圈、完整空盒和完整出餐纸盒、炸弹及计时板、只进不出／固定颜色／底部置顶标记、冰裂与碎冰、爆炸组件、警示框、无效操作叉号和投影。素材收录不代表对应玩法已实现，正式规则仍以关卡配置和会话为准。

## 布局与动态状态

基础画布为 1024×1536：左上金币栏、居中粉色标题、右侧齿轮按钮、订单底板右侧的进度、四张需求卡、无独立底板、每排最多 5 组的 17 个纸盒位，以及同排的出餐纸盒与三个浅色方形道具按钮。盒沿不显示容量与空盒文字。按钮名称在按钮内部，次数角标位于右上。现有界面文案保留中文。

餐盒按 5／5／5／2 的四排坐标排列，每排居中，所有纹理保留原始宽高比；每个盒组只做整体等比缩放，不用不同的宽高倍率制造透视。较长竖屏把额外高度分配给背景与棋盘行距，纸盒维持 200×157 设计尺寸。金币栏始终可见，从 0 开始显示本关奖励；连单与撤回实时更新，重开或切关清零。关卡标题可点选关，齿轮打开设置面板，界面不显示暂停按钮。页面拼接由 `donut_sort_screen.tscn` 定义，盒位排列由棋盘模块维护，适配归页面脚本。详细核对见 [UI 比例校准](ui_alignment.md)。

棋盘按纸盒后层、下层至顶层甜甜圈、纸盒前沿、机关与标记绘制；最上层是实际可搬运的口味。备货盒入场时复用棋盘餐盒的分层矩形与原图比例，从出餐纸盒位置飞入目标盒位；备货内容入场前不展示。棋盘甜甜圈向纸盒上方堆起，前沿盖住最下层的一小部分。普通盒全部显色，仅指定隐藏层盒中尚未揭示的甜甜圈显示灰色纹理；首次露顶后显示真实口味并保持，重新叠放也不变灰。数字盖使用封口包装遮住食物；白霜保留透明中心；等待需求使用时钟标记。移动、出餐和补位共享同一口味资源映射。

参考图的 16 单、两张锁定需求卡、口味分布和三个道具数量是示意。实际画面展示关卡真实订单和次数；按后续确认，十关均仅左侧两订单位可用，右侧两位显示锁定，暂不提供解锁入口。

## 旧资源处理

已删除被本包替代的旧背景、餐盒和 UI 图集、机关图集、旧食物图集及相应 AtlasTexture／导入记录；工程不再维护 `_v2.png` 等重复运行版本。历史截图仍位于 Archive，仅作前后效果对照。

## 验证与运行截图

`node Testing/scripts/run_godot.mjs architecture home donut` 曾通过：三关完整解、数量守恒、鼠标／触摸拖拽、无效落点、撤回与外部中断恢复。素材比例回归检查覆盖强制拉伸、非等比变换与棋盘／备货组合差异；连续缩放检查覆盖 1024×1536、720×1280、720×1600：餐盒点击区域互不重叠、按钮完整可达，缩放中断拖拽不会提交旧手势。

Godot 4.5.1 Compatibility 真实渲染曾检查三关及上述尺寸，并通过视口指针实际完成出餐、撤回和暂停按钮操作；以下截图拍摄于移除暂停入口之前，保留为历史布局记录：[参考比例截图](../Archive/ReferenceImage/donut_sort_current.png)、[720×1280 截图](../Archive/ReferenceImage/donut_sort_current_mobile.png)、[特殊盒截图](../Archive/ReferenceImage/donut_sort_current_mechanics.png)。

此前素材接入时已通过 `node Tooling/export/wechat.mjs` 的本地导出和资源加载检查。接入 v7 纸盒后，微信包仍需重新导出并进行真机验收。
