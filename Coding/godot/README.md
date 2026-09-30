# 甜甜圈小铺

Godot 4.5.1、Compatibility 渲染，720×1280 竖屏。已实现 100 关首轮可玩内容，机制、验证及待试玩事项见 [百关验收](../../Designing/level_100_implementation.md)。

当前 UI 按 1024 设计宽度组织，使用 v8 三段店铺背景、纯色甜甜圈、四个独立翻盖订单盒和圆纸托。标题定位在安全区顶部，标题和需求池保持 20 设计单位间隔；墙面优先保留窗下绿植，台面与地板之间完整展示柜门。三行以内的盒位收紧行距并保留上下留白，底部出餐区暂缓。最新构图与截图见 [盒位布局](../../Designing/board_layouts.md)。

使用 Godot 打开 `project.godot`，F5 启动并恢复有效的本地进度；Home 和 DonutSortScreen 场景均可 F6 独立预览。按住来源盒最顶上的甜甜圈，拖到空盒或顶部同口味的目标盒松手；一次搬走顶部连续同口味的明牌组，数量不超过目标剩余容量，遇到不同口味或灰色层即停止。拖动时只有首颗跟手，后续同味食物留在原盒；拿取和放入均覆盖整叠食物与盒体，不显示落点文字、描边或明暗提示；也保留先点来源盒、再点目标盒的操作。松手后其余食物从原盒逐颗错峰起飞，后颗在前颗落下前跟上；整组只记一步且可一次撤回。常规容量 4；四颗同味且盒子可打包、匹配开放需求时，整盒从顶部回收。

百关按 R2 数值表配置实际盒数，每关包含两个锁定周转位；前十关 6～9 个，百关最多 20 个。预设使用连续居中的行列或紧凑错位，没有中央挖空。盒位编号与处理顺序稳定，搬运、回收、补货和解锁不重排。顶部四位需求维持左二开放、右二锁定。底部三个道具及侧边入场沿用现有实现，周转奖励在本地明确模拟，尚未接入正式广告。最新机制节奏和数值验收见 [R2 接入](../../Designing/r2_level_update.md)。

前两关各 3 单、12 颗甜甜圈、2 种口味；前五关无隐藏层，第六关引入隐藏，第九关开始原位补货。后续逐步加入数字盖、冰冻、单格盒、数字冰冻、固定口味、只进不出、循环及炸弹。数量与字段见 [内容说明](game_content/README.md)。100 关各四种周转条件的完整解已验证，不等于目标首试通关率或时长已验证。设置共十页，可选全部百关；通关后自动进入下一关，第 100 关提供重玩。

底部撤回、加餐盒、置顶默认各 1 次，使用同款浅色方形底板、各自的图标与粉色次数角标。撤回恢复整次操作和全部自动结果；加餐盒启用固定格内的周转盒；置顶在底部操作区内选择可操作盒中的已知下层或灰色未知层，不打开遮罩弹窗；未知层置顶后揭示，已知口味持续保留，取消不扣次数。连单奖励按一次操作的回收数结算：2／3／4 盒及以上分别额外获得金币 5／10／20、钻石 0／1／2。金币栏和奖励金额展示暂时隐藏；后台仍按本关奖励结算，撤回同步恢复，重开或切关清零。

无普通搬运路线时保留补救入口，不直接判失败。炸弹超时显示独立失败弹窗：Level Failed 标题、Let’s try again! 副标题、散落甜甜圈插画及 Home／Try Again。Try Again 重开本关；Home 暂只预留 `home_requested` 导航信号，未接主页时保留弹窗和重试入口。

App 持续拥有 `Services`、`SceneContainer` 和 `Overlay`，并向 Home 显式注入独立 DonutSession 和 DonutProgress。进度服务归 Services，使用独立 `user://sweet_sort_100_v1.json`，不读旧账号；没有 Autoload。页面增加首次机制提示、玩法回看及切关／重开／周转奖励确认。F6 和自动化脚本不读写真实存档。基础 Theme 使用随包 Noto Sans SC 子集，来源和许可证见 [字体说明](design_system/fonts/README.md)。

运行结构为 `bootstrap/app.tscn` → `features/home/ui/home_screen.tscn` → `features/donut_sort/ui/donut_sort_screen.tscn`。Home 是现有启动及单页预览入口，直接实例化玩法场景，不复制玩法实现。

- `features/donut_sort/donut_session.gd`：唯一关卡状态与事务协调；[玩法结构](features/donut_sort/README.md)说明各功能目录。
- `features/donut_sort/donut_level.gd`：加载目录并校验配置与各口味供需。
- `game_content/donuts/levels/catalog.json` 与 `level_01.json`～`level_100.json`：唯一运行关卡定义；食物数组从顶部到下部，原口味 0/1/2/3/4/5/6 仍为草莓粉/巧克力棕/抹茶绿/蓝莓蓝/香橙/香草奶白/葡萄紫，扩展至 15 种映射。
- `game_content/donuts/art/`：旧版食物原图、十五款 v8 原图、灰色隐藏圈与 AtlasTexture；十五组食物与贴纸已接入，前十关仍使用 2～4 种。
- `features/donut_sort/ui/art/`：v8 三段背景及保留的旧页面美术；`asset_manifest.json` 记录页面素材路径与哈希。
- `features/donut_sort/orders/ui/art/`：v8 六色翻盖订单盒、十五款配对贴纸与保留的旧四卡底板。
- `features/donut_sort/board/ui/art/`：v8 圆纸托与保留的 v7 包装；独立清单记录素材路径与哈希。
- `features/donut_sort/tools/`：三个道具模块分别拥有专用图标与按钮场景，`tools/ui/art/` 保存共用底板、次数角标和新素材清单。
- `design_system/themes/game_theme.tres`：字体、面板与基础按钮样式。

旧业务分类及其 `.gitkeep` 已移除。`game_content/`、`platforms/`、`design_system/` 和 `addons/` 中剩余的通用框架位置不代表已实现功能；新业务及内容分类按实际需求建立，不恢复旧业务空目录。

从工作区根运行：

```sh
node Tooling/preview/preview.mjs
node Tooling/preview/preview.mjs home
node Testing/scripts/run_godot.mjs architecture home donut hundred
node Tooling/export/web.mjs
```

macOS 双击 `Tooling/preview.command`、Windows 双击 `Tooling/preview.cmd` 也可启动，两者调用相同的预览入口。预览运行期间保存脚本、场景或素材会重新导入并启动本地游戏；关闭游戏窗口或按 Ctrl+C 停止。`GODOT_BIN` 可以指定引擎；macOS 默认优先使用工作区已有的 4.5.1，其次使用本机 Godot，Windows 默认使用 `PATH` 中的 `godot`。Windows 配置示例见 [工具说明](../../Tooling/README.md)。检查使用独立项目副本，诊断位于 `Testing/.runtime/`。

微信小游戏使用 `node Tooling/export/wechat.mjs`，抖音使用 `node Tooling/export/douyin.mjs`，分别更新各平台固定打包目录；也可双击 `Tooling/` 下同名 `.command`。配置、分包、启动适配和验收见 [微信测试说明](platforms/wechat/README.md)、[抖音打包说明](platforms/douyin/README.md)。当前抖音仅完成打包工具，其他平台与上传入口尚未接入。Git 边界见 [GIT.md](GIT.md)。
