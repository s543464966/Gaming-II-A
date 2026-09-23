# 工程与玩法验证

从工作区根运行：

```sh
node Testing/scripts/run_godot.mjs architecture home donut
```

默认运行上述三组，也可单独指定。Architecture 检查真实主场景装配及页面替换后 App、服务和浮层容器的存活；Home 检查独立关卡加载、16 格布局和 Theme 资源。

Donut 运行真实规则与页面，逐步执行三关无需道具的完整解（8／17／29 步，8／10／24 单），分别检查 32／40／96 颗甜甜圈数量守恒与容量。第三关同时要求实际产生至少三连单及金币、钻石奖励。

前两关额外检查：至少 4／3 个普通空盒、开局容量占用不超过 55%／65%、每个可搬来源至少有两个普通落点；借用每个初始空盒的 7 条分支均能不用道具通关。真实 App 场景通过视口鼠标事件完成两关拖拽（含空盒周转为 9／18 次）；持续用例在步间中断动效，完整动效与实际画面另见 [数值调整验收](../Designing/early_level_balance.md)。

边界覆盖：成组搬运和一格／多格拆分、隐藏露顶不续搬、空盒与空盒位、等待不锁取放、独立需求连收与锁定过滤、原位逐盒补位、数字盖和冰冻逐次效果、新入场盒不承接历史效果、同味匹配顺序、单颗暂存与周转、完整撤回、置顶可见性、二／三／四及以上奖励、不跨操作连单、严格通关和重开。UI 检查四需求、选关、取消、隐藏／失焦／暂停／动效中断与离树后的状态和输入恢复；通过实际视口鼠标／触摸事件验证拖拽、轻点抖动、容量拆分、无效落点、多指及模拟鼠标去重、系统取消与输入恢复。

每次将当前工程复制到 `Testing/.runtime/<run-id>/project/`，排除 Git 与缓存，先由 Godot 重新导入，再运行场景检查。成功必须同时满足退出码、无脚本或资源错误，以及每组完成标记。通过后自动清理；失败诊断保留于输出的精确目录，读取后清理。检查不读取旧账号或进度。

小游戏打包增加以下检查：

```sh
node --test Testing/integration/minigame/export_test.mjs Testing/integration/wechat/export_test.mjs Testing/integration/douyin/export_test.mjs
node Testing/scripts/check_minigame.mjs Archive/Builds/wechat/content/game_pack.bin
node Testing/scripts/check_minigame.mjs Archive/Builds/douyin/godot/main.bin
```

共享用例覆盖固定目录重复更新、过期文件清理、IDE 私有配置保留及替换失败回滚；平台用例覆盖 AppID、分包预算、启动失败反馈和宿主焦点转发。抖音另检查未绑定 AppID 的工具模式、启动器路径及无 IDE/上传入口。真实资源检查用本机 Godot 加载实际 PCK，验证主场景、关卡数据和中文字体，两端导出都会自动执行。原 `check_wechat.mjs <项目目录>` 保留为共享检查的委托入口。

这些检查不代表平台模拟器或真机通过。布局、素材遮挡和触感需用可见预览检查；平台验收见 [微信测试说明](../Coding/godot/platforms/wechat/README.md)及 [抖音打包说明](../Coding/godot/platforms/douyin/README.md)。
