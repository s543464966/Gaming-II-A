# 盒位与店铺画面

2026-09-30 R2 最新分排：按总盒数选择行数，每排最多五盒并均摊余数，优先每排四至五盒；16–20 盒使用四排，少盒关不强凑四排、不额外加盒。所有 100 关沿用下述对称留白规则。短屏收紧头尾占高，操作区、盒体大小与排间距随可用屏幕变化，关内不重新居中。数值及最新验收见 [R2 更新](r2_level_update.md)。下方前十关数量与旧布局只保留历史记录。

2026-09-30 最新修正：100 关统一保持开局上下留白对称，且每侧大于最大可见排间隙。保留配置的盒数、行数、横坐标和顺序；先按满四层抬起与机关下沿收紧多余层距，再以开局整排边界适配。每侧留白至少为最大排间隙的 1.05 倍加 4 个随盒缩放的单位，高度富余时按 1.20 倍限制行距伸展；不再把剩余高度优先填入排间。上下留白由棋盘统一计算，页面不再额外叠加 20 单位内缩，局内不重排。订单贴纸在上一版 74×74 基础上再缩至 64×64，中心不变。最新截图：[第 96 关](../Archive/ReferenceImage/donut_hundred_level_096.png)、[第 98 关](../Archive/ReferenceImage/donut_hundred_level_098.png)、[第 98 关小屏](../Archive/ReferenceImage/donut_hundred_small_098.png)、[第 7 关小屏](../Archive/ReferenceImage/donut_hundred_small_007.png)。当前实现见 [百关实现与验收](level_100_implementation.md)；下方保留早期记录，其留白参数不再代表当前版本。

2026-09-29，按用户确认实施。依据最新两份产品文档及数值总表第 1–10 关，取消统一 17 盒。第 11–100 关和底部出餐区不在本次范围。

## 本次结果

- 每关实际盒位数为 10／11／11／11／11／11／12／12／11／12，均包含两个锁定周转位。逐关非空盒、空盒、口味、订单与备货一并对齐，见 [运行内容](../Coding/godot/game_content/README.md)。
- 根据用户最新要求，前十关不再采用中间挖洞的预设构图，使用连续行列或紧凑错位。第 3 关改为连续的 4／4／3；第 4 关为三列常规盒位加两个周转位；第 7 关为连续的 3／3／4 加两个周转位。第 6 关逐行错位、第 9 关阶梯、第 10 关居中紧凑分组。各关独立固定坐标，盒位数与业务序号不变。
- 根据画面反馈，第 10 关取消中排两端孤立的 4／2／4 构图，十个常规盒位改为 4／3／3，后两排水平居中；底部两个锁定位保持原位。只调整预设坐标与对应视觉层次，不修改盒位 ID、处理序号、食物或备货。
- 标题与设置移回安全区顶部，标题与需求保持 20 单位间距；不再随长屏墙面比例向下移动。背景取景保留窗下绿植，完整显示台面前沿与柜门下边框。
- 三行构图纵向层距为 330 设计单位，四行层距为 310；所有行数统一预留 200 设计单位的纵向空间。按唯一关卡定义中的初始食物和纸托边界进行视觉居中，上下可见留白对称且各不少于半个纸托宽度，满四层和选中抬起仍不越界。少盒位关不拉开行距填满桌面，局内不会重新居中。
- 纸托仍为 200×126，食物 160×114、层距 48；最底层底端位于 108，露出两侧与前沿褶边，单颗暂存也使用同一落点。布局等比缩放上限 1.08，四层与选中抬起均不重叠、不越界。底部三按钮与地板入口沿用原实现。
- 同一关的盒位不因食物减少、回收或解锁而移动，不随屏幕变化自动改行。

## 配置边界

`Coding/godot/game_content/donuts/levels/` 保存实际玩法；`layouts/board_layouts.json` 的 `levels` 指定十关模板，各条目持有稳定 `id`、数组索引一致的 `order`、视觉 `layer` 与纸托上沿中心 `x/y`。`level_01`～`level_10` 是正式布局，原 8／12／17／25 盒位模板仅保留为独立几何与机制测试样例，不决定真实关卡数。旧文档与旧截图中的围合、中央留白等建议已被“不预设中间空洞”的最新要求替代；测试样例不用于正式选关。

页面按每关数量创建／移除盒位节点，动态盒位的按压信号和命中数组同步维护。配置校验允许可变数量，上限 25，必须含两个锁定周转位，不再要求每关七种口味或通关余下两至三盒。

## 验收与限制

真实 Godot 会话重放十关无道具完整解；逐步验证食物守恒、容量、订单、周转盒归还及撤回重做。图形预览覆盖长短屏、手机安全区、平板以及代表性构图。测试入口为 `node Testing/scripts/run_godot.mjs architecture home donut`；截图入口为 `Testing/visual/donut_layout_capture.gd`。

前次 `architecture`、`home`、`donut` 均通过。本轮将上下留白检查扩展到全部十关，以实际开局内容至桌面上下沿的距离为准，差值须小于 1 逻辑像素，同时复查清空盒位后重新适配不移动位置。320～440 宽手机、DPR 1／3 与平板均在覆盖范围。短屏四行布局为保留留白会等比缩小图案，纸托可见宽度下限为 36 逻辑像素，带既有边缘容错的实际点击范围仍须至少 44×44；不再把图案本身宽度当成点击范围。网页与手机安全区分别取景，真机仍需单独验收。

- [第二关截图尺寸复查](../Archive/ReferenceImage/donut_sort_spacing_fixed_review_level_02.png)、[首关](../Archive/ReferenceImage/donut_sort_spacing_fixed_browser.png)、[小屏](../Archive/ReferenceImage/donut_sort_spacing_fixed_small.png)、[手机安全区](../Archive/ReferenceImage/donut_sort_spacing_fixed_phone.png)
- [盘沿修正：单颗、双层与四层](../Archive/ReferenceImage/donut_sort_plate_rim_mixed.png)、[盘沿修正：小屏](../Archive/ReferenceImage/donut_sort_plate_rim_small.png)
- [第 3 关连续矩阵](../Archive/ReferenceImage/donut_sort_contiguous_level_03.png)、[第 4 关三列分组](../Archive/ReferenceImage/donut_sort_contiguous_level_04.png)、[第 7 关连续错位](../Archive/ReferenceImage/donut_sort_contiguous_level_07.png)、[第 10 关紧凑分组](../Archive/ReferenceImage/donut_sort_contiguous_level_10.png)
- 当前上下留白：[第 1 关](../Archive/ReferenceImage/donut_sort_balanced_padding_level_01.png)、[第 7 关](../Archive/ReferenceImage/donut_sort_balanced_padding_level_07.png)、[第 7 关短屏](../Archive/ReferenceImage/donut_sort_balanced_padding_small_07.png)。

数值表是首轮策划，隐藏层比例按整数颗数落地；仅验证了可行解，未验证目标难度、通关率或时长，也未做手机真机验收。两只周转位的正式广告资格和播放流程仍未接入；现有道具次数及底部区域暂不扩展。本次只更新本地网页预览，未发布平台包或提交、推送代码。
