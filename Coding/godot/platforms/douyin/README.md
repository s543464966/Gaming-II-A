# 抖音小游戏打包

日常双击 `Tooling/douyin.command`，或从工作区根执行：

```sh
node Tooling/export/douyin.mjs
```

需要 Node.js 20.11+、Godot 4.5.1、`curl`、`unzip`。无需运行抖音开发者工具；本入口不创建 IDE 项目、不打开模拟器、不上传。

## 固定目录与配置

唯一输出目录是 `Archive/Builds/douyin/`。其中 `game.js`、`game.json`、`project.config.json`、`godot.config.js`、`godot.launcher.js` 位于根目录，`godot/` 子包包含引擎与 `main.bin` 资源包。每次更新同一目录、清理过期生成文件，保留 `project.private.config.json`；`build_report.json` 记录最新源码与资源指纹、依赖校验值、AppID 状态及包体大小。

当前 `project.config.json` 的 `appid` 有意留空，表示只准备打包工具。以后在本目录的源配置中填入当前项目的抖音 AppID，再双击打包即可。未配置时仍生成完整本地包，但报告的 `appidConfigured` 为 `false`，不表示已完成平台项目绑定；不会复用微信或旧项目的 AppID。

## 模板与构建

依照[抖音官方 Godot SDK 1.0.4](https://developer.open-douyin.com/docs/resource/zh-CN/mini-game/develop/guide/game-engine/godot/sdk-usage-guide)的导出文件约定，使用其分发的 `web_release 4.5.1-rc-1.0.0.12` 模板和内嵌启动器 `1.1.27`。下载来源、版本、SHA-256 固定在 `Tooling/export/douyin_template.json`，构建不跟随远端配置自动升级；首次下载后缓存到 `Tooling/.runtime/douyin/`。`--prepare` 只准备依赖并检查引擎。官方运行模板为 4.5 系列专用构建，产品编辑器仍为 4.5.1。

`Tooling/export/minigame.mjs` 共用微信与抖音的资源导出、包体检查、构建报告和固定目录替换。抖音配置、模板、`tt` 启动适配归本平台所有，不安装编辑器插件或引入 Autoload。启动使用随包官方启动器；画布按设备像素尺寸创建，宿主前后台事件传入画布焦点，启动失败显示错误提示。

构建在 `Testing/.runtime/douyin-export-*/` 的工程副本中进行，使用 `Douyin Resources` 预设，保留全部玩法资源并排除平台配置与制作工具。导出后检查 PCK 标识、官方 WASM、主场景、关卡数据、中文字体及包体预算；通过后才更新固定目录。替换发生错误时恢复上一版；成功清理临时文件，失败输出诊断位置。重复启动会被锁文件阻止，异常强制终止后按错误提示确认没有打包进程，再清除残留锁。

项目采用[抖音分包预算](https://developer.open-douyin.com/docs/resource/zh-CN/mini-game/develop/guide/dev-guide/bytedance-mini-game)：主包 4 MiB、单分包 20 MiB、总包 20 MiB。资源包使用 `.bin` 后缀，避免 `.pck` 被平台忽略。当前全部内容随包提供，无 CDN。

## 验证边界

```sh
node --test Testing/integration/minigame/export_test.mjs Testing/integration/douyin/export_test.mjs
node Testing/scripts/check_minigame.mjs Archive/Builds/douyin/godot/main.bin
```

资源检查由本机 Godot 执行，不能代替抖音运行环境验收。本次仅准备工具与本地包；尚未创建开发者工具项目、验证模拟器或真机。后续绑定 AppID 后再检查冷启动、中文字体、竖屏布局、触摸操作与前后台恢复。
