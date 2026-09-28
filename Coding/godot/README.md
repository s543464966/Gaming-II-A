# 甜甜圈小铺

Godot 4.5.1、Compatibility 渲染，720×1280 竖屏。现有素材已接入十关可完整通关的甜甜圈排序玩法。

当前 UI 按 1024 设计宽度组织，较长竖屏延展背景与棋盘行距；纸盒使用新包装素材，盒体、备货入场和甜甜圈都保持等比。页面已接入 `donut_game_assets_v7` 的店铺背景、浅色木台、四卡订单底板、纸盒、金币栏与设置按钮素材，以及用户提供的五张道具按钮素材；被替换的旧店铺背景和独立木质棋盘已移除。素材用途、分层与当前参考见 [美术与 UI 说明](../../Designing/mechanics_assets.md)。

使用 Godot 打开 `project.godot`，F5 直接进入首关；Home 和 DonutSortScreen 场景均可 F6 独立预览。按住来源盒最顶上的甜甜圈，拖到空盒或顶部同口味的目标盒松手；一次搬走顶部连续同口味的明牌组，数量不超过目标剩余容量，遇到不同口味或灰色层即停止。拖动时只有首颗跟手，后续同味食物留在原盒；拿取和放入均覆盖整叠食物与盒体，不显示落点文字、描边或明暗提示；也保留先点来源盒、再点目标盒的操作。松手后其余食物从原盒逐颗错峰起飞，后颗在前颗落下前跟上；整组只记一步且可一次撤回。常规容量 4；四颗同味且盒子可打包、匹配开放需求时，整盒从顶部回收。

棋盘固定 17 格，按 5／5／5／2 居中排列，每排最多 5 组餐盒与甜甜圈，底排左侧为普通空盒、右侧为初始锁定的加餐盒位；顶部一体式底板保留 4 个需求位置，默认仅左侧两位接单，右侧两位显示锁定，具体解锁方式尚未接入。底部仅保留居中的三个道具按钮，首批餐盒与后续备货按目标盒位所在半区从屏幕左右两侧水平移入；备货队列不在界面上预先展示。成功回收后仅将一个队首备货盒补入原盒位；搬空保留空盒，队列耗尽后回收留下不可接收食物的空盒位。完成全部需求、耗尽备货并清空甜甜圈才通关；关卡自带盒保留 2～3 个，第 1～6 关余 3 个，第 7～10 关余 2 个，道具额外盒在通关时等量归还。

第一关为 15 单，第二关为 18 单，均为 13 个满盒加 3 个普通空盒；两关开局装填率约 81%。两关均无需道具即可周转，全部需求由左侧两位的后续序列承接。普通餐盒默认全部明牌；当前每关仅一个初始盒启用隐藏下层，顶层显色、下层灰色，露顶后记住口味，再次叠放仍保持明牌。备货按自身配置入场，不继承原盒的隐藏效果。第三关为 27 个预设盒，覆盖数字盖、冰冻及混合需求连收；每次真实回收影响已在场机关，新补盒不继承之前的减数／解冻。金币栏、设置中的余额和奖励金额提示暂时隐藏；齿轮打开选关、重开与返回面板；点击关卡标题也可选关。新增第 4～10 关采用独立固定混排，订单量从 24 单增至 36 单，组合数字盖、冰冻与隐藏层；全部十关均有无需道具的完整验证解。选关面板以三列四排显示全部十关。通关后在底部显示约 1.2 秒完成反馈并自动进入下一关，第 10 关停留并提供再玩一遍；设置打开、隐藏、失焦或外部暂停期间不自动切关，恢复后重新显示完整反馈。关卡内没有暂停按钮。

底部撤回、加餐盒、置顶默认各 1 次，使用同款浅色方形底板、各自的图标与粉色次数角标。撤回恢复整次操作和全部自动结果；加餐盒启用固定格内的周转盒；置顶在底部操作区内选择可操作盒中的已知下层或灰色未知层，不打开遮罩弹窗；未知层置顶后揭示，已知口味持续保留，取消不扣次数。连单奖励按一次操作的回收数结算：2／3／4 盒及以上分别额外获得金币 5／10／20、钻石 0／1／2。金币栏和奖励金额展示暂时隐藏；后台仍按本关奖励结算，撤回同步恢复，重开或切关清零。

无可移动位置且撤回、加餐盒、置顶均无实际可用操作时，显示独立失败弹窗：Level Failed 标题、Let’s try again! 副标题、散落甜甜圈插画及 Home／Try Again。Try Again 重开本关；Home 暂只预留 `home_requested` 导航信号，未接主页时保留弹窗和重试入口。

App 持续拥有 `Services`、`SceneContainer` 和 `Overlay`，并向 Home 显式注入独立 DonutSession。服务和全局浮层容器当前为空，不挂载 Autoload。正常游戏仅使用底部置顶选择和通关反馈；仅失败自动弹窗，玩家主动打开的设置与选关面板照常展示。基础 Theme 使用随包 Noto Sans SC 子集，来源和许可证见 [字体说明](design_system/fonts/README.md)。

运行结构为 `bootstrap/app.tscn` → `features/home/ui/home_screen.tscn` → `features/donut_sort/ui/donut_sort_screen.tscn`。Home 是现有启动及单页预览入口，直接实例化玩法场景，不复制玩法实现。

- `features/donut_sort/donut_session.gd`：唯一关卡状态与事务协调；[玩法结构](features/donut_sort/README.md)说明各功能目录。
- `features/donut_sort/donut_level.gd`：加载目录并校验配置与各口味供需。
- `game_content/donuts/levels/catalog.json` 与 `level_01.json`～`level_10.json`：唯一人工关卡定义；食物数组从顶部到下部，口味 0/1/2/3/4/5/6 为草莓/巧克力/抹茶/蓝莓/柠檬/香草/紫色彩糖；每关至少 7 种，当前十关开局均可拿取全部 7 种。
- `game_content/donuts/art/`：11 款食物原图与实际使用的 AtlasTexture；当前四个口味 ID 保持不变。
- `features/donut_sort/ui/art/`：保留的 v1 页面素材与 v7 店铺、木台背景；`asset_manifest.json` 记录页面素材路径与哈希。
- `features/donut_sort/orders/ui/art/`：v7 一体式四卡订单底板。
- `features/donut_sort/board/ui/art/`：v7 纸盒后层、前沿与封口包装；独立清单记录新素材路径与哈希。
- `features/donut_sort/tools/`：三个道具模块分别拥有专用图标与按钮场景，`tools/ui/art/` 保存共用底板、次数角标和新素材清单。
- `design_system/themes/game_theme.tres`：字体、面板与基础按钮样式。

旧业务分类及其 `.gitkeep` 已移除。`game_content/`、`platforms/`、`design_system/` 和 `addons/` 中剩余的通用框架位置不代表已实现功能；新业务及内容分类按实际需求建立，不恢复旧业务空目录。

从工作区根运行：

```sh
node Tooling/preview/preview.mjs
node Tooling/preview/preview.mjs home
node Testing/scripts/run_godot.mjs architecture home donut
```

双击 `Tooling/preview.command` 也可启动。预览运行期间保存脚本、场景或素材会重新导入并启动本地游戏；关闭游戏窗口或按 Ctrl+C 停止。`GODOT_BIN` 可以指定引擎；默认优先使用工作区已有的 4.5.1，其次使用本机 Godot。检查使用独立项目副本，诊断位于 `Testing/.runtime/`。

微信小游戏使用 `node Tooling/export/wechat.mjs`，抖音使用 `node Tooling/export/douyin.mjs`，分别更新各平台固定打包目录；也可双击 `Tooling/` 下同名 `.command`。配置、分包、启动适配和验收见 [微信测试说明](platforms/wechat/README.md)、[抖音打包说明](platforms/douyin/README.md)。当前抖音仅完成打包工具，其他平台与上传入口尚未接入。Git 边界见 [GIT.md](GIT.md)。
