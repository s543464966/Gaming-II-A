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

项目按[抖音代码包限制](https://developer.open-douyin.com/docs/resource/zh-CN/mini-game/develop/guide/basic-function/subpackages/introduction)的默认总包 20 MiB 打包，主包限制 4 MiB；不依赖开通虚拟支付后的 30 MiB 额度。`main.br` 由固定启动器解压，内容与原始 PCK 逐字节往返校验。常规双击 `douyin.command` 默认使用 `auto`：配置了正式 HTTPS CDN 目录时生成对应 CDN 包，否则启动或复用本机 CDN 服务。

## 本机 CDN 预览

没有正式 CDN 地址时，直接双击 `Tooling/douyin.command` 即可。工具只监听电脑的 `127.0.0.1`，先从本机地址回下载并核对全部资源块，再替换固定的 `Archive/Builds/douyin/`；**仍在原有抖音开发者工具项目点击“编译”**。本机资源不通过公网隧道提供。测试期间保持服务窗口运行；关掉后重新双击同一工具会启动新服务并重新绑定包内地址。

服务运行期间再次双击会通过独立的本机控制接口复用同模式的原服务并重新打包；进程已退出的残留锁会自动清理。切换本机与 Cloudflare 模式前先关闭原服务窗口，工具不会把本机地址误当成手机测试地址。资源更新失败时保留旧小游戏包。工具只在全部资源校验通过后更新固定项目，保留本地 IDE 配置；服务保留当前与上一批资源，避免正在运行的旧预览在更新时缺文件。

CDN 模式从真实完整 PCK 的导入映射自动识别非启动贴图，包括以后新增的界面素材，按约 4 MiB 一块组织为内容摘要命名的 PCK。单个大贴图可独占一块，上限 32 MiB；超过时明确指出需要优化的素材。启动场景的递归依赖、脚本、字体、场景与玩法数据保留在小游戏包；不是只迁移固定的两张背景，也不改变原始贴图字节。小游戏包仍受 20 MiB 检查，不能保证引擎、代码或单张素材无限增长。

App 按清单逐块下载到 `user://cdn`，核对长度与 SHA-256，全部就绪后挂载并进入关卡。损坏块会重新下载，重试保留已校验的块；加载页显示当前块数，失败可重试。`build_report.json` 的 `delivery.packs` 记录每块文件名、摘要、体积与资源路径。本机包允许电脑开发者工具跳过域名检查，并标记为模拟器专用；手机会给出明确提示，不会尝试把手机自身的 `127.0.0.1` 当成这台电脑。

### Cloudflare 手机测试

无正式 CDN 时可双击 `Tooling/douyin_cdn_test.command`，它委托同一导出入口的 `--delivery cloudflare-cdn`。若要日常双击 `douyin.command` 也使用手机测试，在被 Git 忽略的 `Tooling/export/douyin.local.json` 设置 `delivery_mode: cloudflare-cdn`。配置为 `local-cdn` 则只提供本机模拟器测试；无本机配置时仍默认 `auto`。

工具校验固定版本 `cloudflared`，通过 Cloudflare Quick Tunnel 将本机资源服务映射为临时 `https://*.trycloudflare.com/`。只有随机路径下已登记的资源块和健康响应可读；控制接口使用另一个仅本机端口。Cloudflare 会转发游戏资源字节，持有完整资源 URL 的人可在服务运行期间下载。公网健康响应及每块资源的大小、SHA-256 校验通过后才更新固定项目。

看到 `CDN TEST READY` 后，在原有项目编译并扫码测试。测试包设置 `setting.urlCheck=false`；[抖音官方说明](https://developer.open-douyin.com/docs/resource/zh-CN/mini-game/develop/guide/basic-function/network)明确该设置适用于开发者工具与手机调试模式，普通预览和上传版本的实际域名行为仍需手机验收。上传测试通道不代表正式上线，不提交审核。

保持电脑联网、不休眠及服务窗口运行。再次双击会复用原 HTTPS 地址重新打包；关闭服务后重启会换地址并重新导出，手机需加载新测试包。临时隧道仅用于开发测试，Cloudflare 不承诺其可用性；不能用它代替正式发行的稳定资源服务。公网检查失败时旧包保留，工具不会绕过 HTTPS 校验。

### 正式 CDN 与离线模式

有正式 CDN 目录后，可复制 `Tooling/export/douyin.local.example.json` 为被 Git 忽略的 `douyin.local.json`，填写以 `/` 结尾的 `cdn_base_url`，设置 `delivery_mode: auto`，然后照常双击 `douyin.command`。也可执行 `node Tooling/export/douyin.mjs --delivery cdn --cdn-base-url https://example.com/game/`。工具生成 `Archive/Builds/douyin.cdn/<摘要>.pck`，但不负责上传；必须按报告中的 `delivery.packs` 清单原名上传资源，并在预览前确认 URL 返回相同字节，同时配置抖音后台 request 合法域名。

完整离线包只通过 `node Tooling/export/douyin.mjs --delivery embedded` 显式生成；全部资源必须满足 20 MiB 预算。当前美术规模已超过离线预算，日常使用默认 CDN 模式。`--prepare` 仅准备固定依赖，不启动服务或打包。

## 验证边界

```sh
node --test Testing/integration/minigame/export_test.mjs Testing/integration/douyin/export_test.mjs Testing/integration/douyin/cdn_test.mjs
node Testing/scripts/check_minigame.mjs Archive/Builds/douyin/godot/main.br # 仅离线包
```

CDN 导出时自动检查完整包、启动依赖、多块挂载、新界面贴图、坏缓存修复与缓存复用；单独运行上述 `check_minigame.mjs` 只适用于离线包。资源检查由本机 Godot 执行，不能代替抖音运行环境验收。手机可使用 Cloudflare 临时 HTTPS 或正式 CDN，另验冷启动下载、中文字体、竖屏布局、触摸操作与前后台恢复。扫码预览使用抖音 35.0.0 及以上版本。

2026-09-23 已用 iPhone 扫码确认游戏进入关卡；加入侧边栏入口后的 `0.0.2` 版已上传到 AppID `tt0da47b1993dcc5c602` 的默认测试通道。上传成功但审核预检仍提示未接入内购、广告等推荐能力；这些不是测试版上传阻断项，正式提审前应按游戏实际商业化方案决定是否接入。

2026-09-28 的 `0.0.3` 已由开发者工具回执确认上传到同一 AppID 的默认测试通道。该包使用 Cloudflare 临时 HTTPS，小游戏包 8,785,393 字节，5 块远程贴图合计 17,296,940 字节；全部资源已完成公网回下载与摘要校验。开发者工具显示关卡正常，当前版本的 iPhone 下载与进入关卡仍待用户验收。预检继续提示内购、添加到桌面、订阅消息和广告等能力，上传已成功，未提交正式审核。

2026-09-29 在 Windows 上接入 v8 素材及长屏上下留白修复，已生成同一固定目录下的本机 CDN 包：小游戏包 8,789,031 字节，7 块贴图合计 24,510,156 字节。完整资源包、分块挂载、坏缓存恢复及全部分块回下载与 SHA-256 检查通过。离线版本为 31,879,848 字节，超出项目 20 MiB 预算，未交付为有效离线包。本次仅监听电脑本机地址，适用于开发者工具；手机需配置可访问的 HTTPS CDN 后重新导出，未更新远端测试通道或执行本轮 IDE／真机验收。界面尺寸模拟与截图见[局内更新](../../../../Designing/in_game_ui_refresh.md)。

同日增补后已再次更新上述固定目录：奶白香草替换旧图、七款专用订单贴纸启用，其余八组口味入库备用。最新小游戏包 8,792,352 字节，8 块贴图合计 30,558,716 字节；真实完整包、分块挂载及下载摘要检查通过，清单确认备用图未打入当前资源包。仍为本机 CDN 模拟器测试包，未上传或执行真机验收。

同日内边距再平衡后再次更新同一目录，最新小游戏包为 8,792,679 字节，贴图块不变。新增安全区内基础留白，选关／失败弹窗独立适配。完整包、CDN 挂载、缓存恢复及 8 块下载摘要检查通过；与 Web 导出并行时首次导入遇到 Godot 字体内存错误，串行重试成功。仍未上传或做真机验收。
