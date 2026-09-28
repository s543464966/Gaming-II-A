# 抖音小游戏打包

日常双击 `Tooling/douyin.command`，或从工作区根执行：

```sh
node Tooling/export/douyin.mjs
```

需要 Node.js 20.11+（含 npm）、Godot 4.5.1、`curl`、`unzip`。无需运行抖音开发者工具；本入口不创建 IDE 项目、不打开模拟器、不上传。

## 固定目录与配置

唯一小游戏项目目录是 `Archive/Builds/douyin/`。其中 `game.js`、`game.json`、`project.config.json`、`godot.config.js`、`godot.launcher.js` 位于根目录，`godot/` 子包包含引擎与 Brotli 压缩的 `main.br` 资源包。每次更新同一目录、清理过期生成文件，保留 `project.private.config.json`；`build_report.json` 记录最新源码与资源指纹、依赖校验值、AppID、交付模式及包体大小。CDN 模式的独立资源文件存于相邻的 `Archive/Builds/douyin.cdn/`，不作为开发者工具项目导入。

当前源配置绑定抖音小游戏 AppID `tt0da47b1993dcc5c602`，本地项目名为“甜甜圈消消乐”。更换 AppID 或项目名时修改本目录的 `project.config.json`，再双击打包工具；不要直接修改生成目录中的配置。开发者工具应导入 `Archive/Builds/douyin/` 本身，不要在其中新建子项目。平台后台显示的应用名称由抖音账号管理，与本地项目名分别维护。

## 模板与构建

依照[抖音官方 Godot SDK 1.0.4](https://developer.open-douyin.com/docs/resource/zh-CN/mini-game/develop/guide/game-engine/godot/sdk-usage-guide)的导出文件约定，使用其分发的 `web_release 4.5.1-rc-1.0.0.12` 模板和内嵌启动器 `1.1.27`。下载来源、版本、SHA-256 固定在 `Tooling/export/douyin_template.json`，构建不跟随远端配置自动升级；首次下载后缓存到 `Tooling/.runtime/douyin/`。`--prepare` 只准备依赖并检查引擎。官方运行模板为 4.5 系列专用构建，产品编辑器仍为 4.5.1。

`Tooling/export/minigame.mjs` 共用微信与抖音的资源导出、包体检查、构建报告和固定目录替换。抖音配置、模板、`tt` 启动适配归本平台所有，不安装编辑器插件或引入 Autoload。启动使用随包官方启动器；画布按设备像素尺寸创建，宿主前后台事件传入画布焦点，启动失败显示错误提示。抖音远端预览编译器不接受官方启动器和引擎脚本中的可选链等新语法，打包时使用 `Tooling/export/douyin_js/` 锁定的 esbuild 将这两份脚本转换为 ES2017；首次运行自动执行 `npm ci`，以后复用本地依赖。

点击关卡标题打开的选关面板会在支持侧边栏场景的抖音宿主上显示“抖音侧边栏”。入口由 `runtime/game.js` 同步监听前后台事件、调用 `tt.checkScene` 判断可用性，玩家点击时调用 `tt.navigateToScene`；其他平台不显示该按钮。[抖音上传预检](https://developer.open-douyin.com/docs/resource/zh-CN/mini-game/develop/dev-tools/mini-app-developer-instrument)将侧边栏复访列为必接项。

固定启动器 1.1.27 存在 `screenWidth: e.screenHeight` 错误，导致长屏按正方形渲染后被压窄。导出入口在校验原始 SHA-256 后按唯一锚点修正宽高，锚点不匹配即停止构建；不手改缓存或生成文件。启动与窗口变化统一使用逻辑窗口尺寸，DPR 只换算画布像素，Godot 页面保持等比缩放。共用 `platforms/minigame/host_viewport.gd` 通过宿主接口读取安全区与胶囊位置，避开刘海、系统手势区和宿主按钮；使用 `JavaScriptBridge.get_interface`，不依赖平台禁用的 `eval`。

构建在 `Testing/.runtime/douyin-export-*/` 的工程副本中进行，使用 `Douyin Resources` 预设。打包前从当前工程的场景、脚本及其静态资源引用选择运行内容，排除不再使用的美术、平台配置、宿主 JS 与制作工具；共用 GDScript 适配器包含在 PCK 中，`host_viewport.js` 由主包加载。导出后检查 PCK 标识、官方 WASM、主场景、关卡数据、中文字体及包体预算；通过后才更新固定目录。替换发生错误时恢复上一版；成功清理临时文件，失败输出诊断位置。重复启动会被锁文件阻止，异常强制终止后按错误提示确认没有打包进程，再清除残留锁。

项目按[抖音代码包限制](https://developer.open-douyin.com/docs/resource/zh-CN/mini-game/develop/guide/basic-function/subpackages/introduction)的默认总包 20 MiB 打包，主包限制 4 MiB；不依赖开通虚拟支付后的 30 MiB 额度。`main.br` 由固定启动器解压，内容与原始 PCK 逐字节往返校验。常规双击 `douyin.command` 使用 `embedded` 模式，所有关卡资源随包，可离线启动。

## 本机 CDN 预览

没有正式 CDN 地址时，双击 `Tooling/douyin_cdn_test.command`，或执行 `node Tooling/export/douyin_cdn_test.mjs`。工具启动本机资源服务和临时 HTTPS 隧道，先从公网地址回下载并核对本次资源 SHA-256，再替换固定的 `Archive/Builds/douyin/`；**仍在原有抖音开发者工具项目点击“编译”**。这只用于本地模拟器预览，不创建第二个 IDE 项目，也不上传代码包。测试期间保持工具窗口运行；关掉后临时地址失效，可双击 `douyin.command` 恢复离线包。

CDN 模式只把两张关卡背景贴图的导入载荷放进按内容摘要命名的远程 PCK，其余脚本、场景、字体和玩法数据留在小游戏包。App 先下载资源到 `user://cdn`，核对长度与 SHA-256 后挂载，失败时显示重试按钮；已校验的缓存供下次启动使用。`build_report.json` 的 `delivery` 字段记录 URL、文件名、摘要和体积。本机测试项目会关闭开发者工具的域名检查，仅用于这次模拟器预览；真实设备或正式环境需要可长期使用的 HTTPS 目录及抖音后台 request 合法域名配置。

有正式 CDN 目录后，可复制 `Tooling/export/douyin.local.example.json` 为被 Git 忽略的 `douyin.local.json`，设置 `delivery_mode` 为 `cdn` 和以 `/` 结尾的 `cdn_base_url`，然后照常双击 `douyin.command`。也可执行 `node Tooling/export/douyin.mjs --delivery cdn --cdn-base-url https://example.com/game/`。工具生成 `Archive/Builds/douyin.cdn/<摘要>.pck`，但不负责上传；必须按报告中的文件名上传资源，并在预览前确认 URL 返回相同字节。配置缺省为 `embedded`。

## 验证边界

```sh
node --test Testing/integration/minigame/export_test.mjs Testing/integration/minigame/viewport_test.mjs Testing/integration/douyin/export_test.mjs
node Testing/scripts/check_minigame.mjs Archive/Builds/douyin/godot/main.br # 仅离线包
```

CDN 导出时自动检查完整包、拆分后的文件集合与资源字节，以及已校验缓存挂载后的关卡加载；单独运行上述 `check_minigame.mjs` 只适用于离线包。资源检查由本机 Godot 执行，不能代替抖音运行环境验收。开发者工具 4.5.6 已将固定目录作为小游戏项目打开；此前离线包在 iPhone 15 Pro 模拟器进入过关卡。CDN 模式的 `tt.request` 下载仍须在抖音模拟器验证；真机还需检查冷启动、中文字体、竖屏布局、触摸操作与前后台恢复。扫码预览使用抖音 35.0.0 及以上版本。

2026-09-23 已用 iPhone 扫码确认游戏进入关卡；加入侧边栏入口后的 `0.0.2` 版已上传到 AppID `tt0da47b1993dcc5c602` 的默认测试通道。上传成功但审核预检仍提示未接入内购、广告等推荐能力；这些不是测试版上传阻断项，正式提审前应按游戏实际商业化方案决定是否接入。
