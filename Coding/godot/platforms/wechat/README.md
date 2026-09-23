# 微信小游戏测试

当前使用新项目 AppID `wxcc827d83f6ca0202`，Godot 保持 4.5.1、Compatibility 和竖屏。微信端直接运行当前 Godot 关卡；资源随包分发，无 CDN、账号、广告或支付接入。

## 导出与打开

需要 Node.js 20.11+、Godot 4.5.1、`curl`、`unzip` 和微信开发者工具。当前流程在 macOS 验证；其他系统可通过 `GODOT_BIN`、`WECHAT_CLI` 指定工具路径。

日常操作：双击 `Tooling/wechat.command`，等待“打包完成”，再到微信开发者工具点击“编译”。也可从工作区根执行：

```sh
node Tooling/export/wechat.mjs
```

首运行下载固定的 [GodotHub 4.5.1 微信模板](https://github.com/godothub/godot-minigame/releases/tag/4.5.1)，按 `Tooling/export/wechat_template.json` 的 SHA-256 校验后缓存到 `Tooling/.runtime/wechat/`。无需安装普通 Web 导出模板或编辑器插件。`--prepare` 只准备模板与检查引擎；下载失败可手动将同名归档放入上述缓存，仍须通过校验。

`Archive/Builds/wechat/` 是唯一微信项目目录，`game.js`、`project.config.json`、`engine/`、`content/` 直接位于其中。每次打包更新此目录并清除过期生成文件，不创建按时间或随机名称区分的新包；目录自身与开发者工具生成的 `project.private.config.json` 保留。`build_report.json` 随包更新，记录版本、源码指纹、资源校验值、AppID 和分包字节数。

构建与资源检查在 `Testing/.runtime/wechat-export-*/` 的工程副本中完成，不改写 Godot 源工程缓存；全部通过后才替换固定项目内容，替换失败则恢复上一版。成功后清理临时目录和替换备份；失败时输出诊断路径，检查后删除该次临时目录。打包入口禁止同时运行，异常强制终止后可按错误提示检查并清除残留锁文件。

首次在微信开发者工具选择“小游戏 → 导入”，选择 **`Archive/Builds/wechat/`** 并检查 AppID。以后一直打开该项目，打包完成后点击“编译”即可，不需要重新创建或导入项目。开发者工具已开启“设置 → 安全设置 → 服务端口”时，还可使用：

```sh
node Tooling/export/wechat.mjs --open
```

`--open` 只打开上述固定目录；自动打开失败不影响已经完成的打包。双击入口默认仅打包，不依赖开发者工具的服务端口，也不修改安全设置；终端保留成功或失败结果，按回车关闭。

## 配置与验证边界

- `project.config.json` 是 AppID、项目名称和共享开发者工具设置的唯一源；修改这里后重新导出，不长期手改制品。个人调试设置由固定项目中的 `project.private.config.json` 保存，打包不会覆盖。
- `game.json` 声明竖屏、iOS 高性能模式及 `engine` / `content` 分包。模板脚本和 WASM 属于引擎分包，Godot PCK 改名为 `content/game_pack.bin`，避免微信忽略未知扩展名。
- `runtime/` 负责启动、分包失败提示和前后台焦点转发；页面沿用已有失焦取消机制。上游加载器的失败回调在导出时针对固定模板补入，不维护一份复制的第三方源码。
- `export_presets.cfg` 使用完整资源导出并显式包含关卡 JSON，排除平台配置和制作工具。所有原始美术保留。项目预算为主包 4 MiB、单个分包 20 MiB、总包 30 MiB；超出立即失败。微信最终包体限制与权限以当前开发者工具实际预览结果为准。
- 导出成功前自动运行真实 PCK 冒烟检查，验证主场景、关卡与中文字体。可独立执行 `node Testing/scripts/check_wechat.mjs Archive/Builds/wechat`；固定目录更新、失败回滚、启动失败与生命周期转发测试为 `node --test Testing/integration/minigame/export_test.mjs Testing/integration/wechat/export_test.mjs`。与抖音共用构建核心和 PCK 检查，各端配置与模板独立。

PCK 检查使用本机 Godot，只证明资源完整，不能替代 WXWebAssembly、模拟器和真机验收。开发者工具应能出现关卡，控制台出现 `[wechat] game started`，无脚本或资源错误；检查点按移动、撤回、暂停恢复及重新开始。

## 手机测试

微信开发者工具登录账号须为该 AppID 的开发者。点击“预览”生成二维码，用有权限的微信扫码；分别在 Android 和 iOS 检查冷启动、中文、竖屏布局和点击命中，再检查切后台/锁屏后回到游戏、暂停恢复与重新开始。当前尚未完成真机验收。

二维码预览需要开发者工具将测试包发送给微信；本地导出不会上传或发布。正式上传、提审和上线未接入本入口。
