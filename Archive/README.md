# 参考图与构建归档

项目策划与设计文档统一放在 [Designing](../Designing/README.md)。本目录保存：

- `ReferenceImage/`：设计参考图与用于视觉比对的实机截图。
- `Builds/`：按平台维护唯一打包目录，打包工具原地更新内容，不按次创建新文件夹。微信为 `Builds/wechat/`、抖音为 `Builds/douyin/`，各自附最新 `build_report.json`；TapTap 接入时使用 `Builds/taptap/`。资源检查、模拟器和真机结果分别记录，不将已导出等同于真机通过。

参考图与必要目录占位纳入工作区 Git，完整导出包按根 `.gitignore` 排除。此目录不作为运行时源码或缓存目录。
