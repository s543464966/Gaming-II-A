# 工作区工具

策划与开发共用仓库内 [1—100 关数值总表](../Designing/levels/level_plan_001_100.xlsx)。导入命令为 `python Tooling/data/import_level_plan.py Designing/levels/level_plan_001_100.xlsx Testing/.runtime/<run-id>/level_plan.json`；不再依赖旧策划工作区的 `outputs/`。文件编辑与正式关卡安装边界见 [数值表维护说明](../Designing/levels/README.md)。

当前 R2 百关制作使用 `data/import_level_plan.py` 只读提取数值表、`data/build_r2_levels.py` 生成层序与四条件路线，并检查首归纳及中段腾位。`--tune` 在装量不变的条件下局部交换口味；仅显式识别为旧 V1.3 的来源才应用 `data/level_adjustments.json`。先在 `Testing/.runtime/<run-id>/` 制作，经 `Testing/scripts/check_v13_levels.py` 检查，再由 `data/rebalance_hundred_levels.py <目录> --install` 更新唯一运行配置。完整命令与验证限制见 [R2 接入](../Designing/r2_level_update.md)。

网页预览唯一地址为 [http://127.0.0.1:4173/](http://127.0.0.1:4173/)。先执行 `node Tooling/export/web.mjs` 验证并覆盖最新百关包，再执行 `node Tooling/preview/web.mjs` 启动或复用固定服务；它只读取 `Archive/Builds/web/`。导出使用本机已准备的 `Tooling/.runtime/godot-platform/web-4.5.1/` 无线程模板，不自动下载。外壳使用 `preview/web.html`，更新后刷新原有页面，不新增版本链接、端口或标签页。服务禁用资源缓存，旧的 `?v=...` 地址会跳转到固定入口。下文 `preview.mjs` 是 Godot 原生窗口预览。

使用 Node.js 20 或更新版本、Godot 4.5.1。`environment/engine.mjs` 读取工程 `tooling/engine.json`，优先使用 `GODOT_BIN`，再查找已准备的本地引擎，最后使用系统 Godot；不会自动下载依赖。

```sh
node Tooling/preview/preview.mjs
node Tooling/preview/preview.mjs home
node Tooling/preview/preview.mjs --check
```

默认运行完整 App，`home` 独立运行首页，`--check` 委托 `Testing/scripts/run_godot.mjs`。macOS 双击 `preview.command`，Windows 双击 `preview.cmd`，均委托同一入口。本地预览运行时监听 Godot 工程；保存脚本、场景或素材后自动重新导入并启动游戏，当前关卡状态会重置。关闭游戏窗口或按 Ctrl+C 结束预览；日志位于唯一 `Testing/.runtime/preview-*/`，成功退出清理，失败时保留并打印精确路径。

Windows 需要 Node.js 20 或更新版本在 `PATH` 中，并能通过 `godot` 命令启动 Godot 4.5.1，或已配置 `GODOT_BIN`。Godot 官方压缩包中的文件名包含版本号，可在 Windows 用户环境变量中将 `GODOT_BIN` 设为实际 `.exe` 的完整路径（变量值不加引号），然后从新打开的终端启动；工具不会安装引擎或修改系统环境变量。也可在 PowerShell 中只为当前终端指定：

```powershell
$env:GODOT_BIN = 'C:\Tools\Godot\Godot_v4.5.1-stable_win64.exe'
.\Tooling\preview.cmd
.\Tooling\preview.cmd home
.\Tooling\preview.cmd --check
.\Tooling\preview.cmd home --check
```

请将示例引擎路径替换为本机安装位置。`preview.cmd` 支持项目路径中的中文和空格，可从任意当前目录启动；参数原样交给 `preview.mjs`，正常关闭后退出，失败时保留终端诊断并等待按键。这是本地预览入口，不生成平台安装包。

微信小游戏双击 `wechat.command` 打包，或执行唯一入口 `node Tooling/export/wechat.mjs`。每次更新固定项目 `Archive/Builds/wechat/`，保留本地调试设置；开发者工具只导入一次，以后打包后点击“编译”。可选 `--open` 委托开发者工具打开同一路径，双击打包本身不依赖服务端口。首次下载并校验固定版本微信模板，之后使用 `Tooling/.runtime/wechat/` 缓存；本机 Godot 不自动下载。完整操作与真机验收见 [微信测试说明](../Coding/godot/platforms/wechat/README.md)，无上传入口。

抖音小游戏双击 `douyin.command`，或运行 `node Tooling/export/douyin.mjs`，更新唯一的 `Archive/Builds/douyin/`。非启动贴图自动分块放到 `Archive/Builds/douyin.cdn/`，避免持续挤占 20 MiB 小游戏包。`auto` 在没有正式 CDN 时使用仅本机模拟器服务；手机测试可在被 Git 忽略的 `export/douyin.local.json` 中设置 `delivery_mode: cloudflare-cdn`，让同一个打包入口启动或复用 Cloudflare 临时 HTTPS，资源会经 Cloudflare 对外提供。也可双击 `douyin_cdn_test.command` 显式选择该模式。保持电脑和服务窗口运行，在原有抖音开发者工具项目编译、扫码测试；重复双击复用同一模式服务并重新打包。当前 AppID 为 `tt0da47b1993dcc5c602`，域名测试设置、正式 CDN 和显式离线模式见 [抖音打包说明](../Coding/godot/platforms/douyin/README.md)。

每个平台有一个 `Tooling/<平台>.command` 薄入口，委托 `Tooling/export/<平台>.mjs`。微信和抖音通过 `export/minigame.mjs` 共用资源导出、验证与固定目录替换；各自的模板和宿主配置保持独立。TapTap 接入时沿用固定目录约定，当前尚未实现。

游戏使用用户提供的完整统一字体，不再运行旧字体子集工具；原件摘要与授权见 [字体说明](../Coding/godot/design_system/fonts/README.md)。
