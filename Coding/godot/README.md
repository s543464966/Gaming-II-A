# 甜甜圈小铺

Godot 4.5.1、Compatibility 渲染，720×1280 竖屏。现有素材已接入三关可完整通关的甜甜圈排序玩法。

当前 UI 按新的 1024×1536 参考图组织，较长竖屏将完整场景等比居中并延展背景；棋盘保持固定行距，餐盒、备货及动态食物均按原始宽高比等比显示。已收录 `donut_game_assets_v1` 的全部 66 张原始 PNG，替换并移除旧运行图集；未启用素材也保留在对应目录。素材用途、分层与当前参考见 [美术与 UI 说明](../../Designing/mechanics_assets.md)。

使用 Godot 打开 `project.godot`，F5 直接进入首关；Home 和 DonutSortScreen 场景均可 F6 独立预览。按住甜甜圈拖到空盒或顶部同口味的目标盒松手，连续已显示的同味组按剩余容量移入。拖动时显示跟手食物、数量与合法目标高亮；也保留先点来源盒、再点目标盒的操作。常规容量 4；四颗同味且盒子可打包、匹配开放需求时，整盒从顶部回收。

棋盘固定 16 格、两个周转盒位初始锁定；顶部 4 个独立需求位置。底部出餐区显示真实备货预览，成功回收后仅将一个队首备货盒补入原盒位；搬空保留空盒，队列耗尽后回收留下不可接收食物的空盒位。完成全部需求、耗尽备货并清空甜甜圈才通关，空盒可保留。

第一关为 8 单，保留 4 个普通空盒；第二关为 10 单，保留 3 个普通空盒和 1 个单颗暂存盒，加入少量隐藏层。两关均无需道具即可周转，四需求全部开放。第三关为 25 个预设盒，覆盖数字盖、冰冻、需求解锁及混合需求连收；每次真实回收影响已在场机关，新补盒不继承之前的减数／解冻。设置可暂停、重开和选择关卡，通关后可进下一关。

底部保留撤回、加餐盒、置顶。撤回恢复整次操作和全部自动结果；加餐盒启用固定格内的周转盒；置顶只允许选择已揭示且可操作的食物，取消不扣次数。连单奖励按一次操作的回收数结算：2／3／4 盒及以上分别额外获得金币 5／10／20、钻石 0／1／2。当前为本关奖励，撤回同步恢复，重开或切关清零。

App 持续拥有 `Services`、`SceneContainer` 和 `Overlay`，并向 Home 显式注入独立 DonutSession。服务和全局浮层容器当前为空，不挂载 Autoload。暂停和置顶属于当前关卡页面的局部面板。基础 Theme 使用随包 Noto Sans SC 子集，来源和许可证见 [字体说明](ui/design_system/fonts/README.md)。

运行结构为 `bootstrap/app.tscn` → `features/home/ui/home_screen.tscn` → `features/donut_sort/ui/donut_sort_screen.tscn`。Home 是现有启动及单页预览入口，直接实例化玩法场景，不复制玩法实现。

- `features/donut_sort/donut_session.gd`：唯一关卡状态与规则。
- `features/donut_sort/donut_level.gd`：加载目录并校验配置与各口味供需。
- `game_content/donuts/levels/catalog.json` 与 `level_01.json`～`level_03.json`：唯一人工关卡定义；食物数组从顶部到下部，口味 0/1/2/3 为草莓/巧克力/抹茶/蓝莓。
- `game_content/donuts/art/`：11 款食物原图与实际使用的 AtlasTexture；当前四个口味 ID 保持不变。
- `features/donut_sort/ui/art/`：场景、餐盒、界面、机关、特效及装饰原图；`asset_manifest.json` 记录全包路径与哈希。
- `ui/design_system/themes/game_theme.tres`：字体、面板与基础按钮样式。

旧业务分类及其 `.gitkeep` 已移除。`game_content/`、`platforms/`、`ui/` 和 `addons/` 中剩余的通用框架位置不代表已实现功能；新业务及内容分类按实际需求建立，不恢复旧业务空目录。

从工作区根运行：

```sh
node Tooling/preview/preview.mjs
node Tooling/preview/preview.mjs home
node Testing/scripts/run_godot.mjs architecture home donut
```

双击 `Tooling/preview.command` 也可启动。`GODOT_BIN` 可以指定引擎；默认优先使用工作区已有的 4.5.1，其次使用本机 Godot。检查使用独立项目副本，诊断位于 `Testing/.runtime/`。

微信小游戏使用 `node Tooling/export/wechat.mjs`，抖音使用 `node Tooling/export/douyin.mjs`，分别更新各平台固定打包目录；也可双击 `Tooling/` 下同名 `.command`。配置、分包、启动适配和验收见 [微信测试说明](platforms/wechat/README.md)、[抖音打包说明](platforms/douyin/README.md)。当前抖音仅完成打包工具，其他平台与上传入口尚未接入。Git 边界见 [GIT.md](GIT.md)。
