# 统一游戏字体

全部文字控件统一使用用户提供的 `chill_round_bold.ttf`（寒蝉全圆体 Bold），中文、英文、数字与提示符号共用这一份运行字体，不再合成加粗或混用旧字体。共享 Theme 和各功能场景均直接引用同一个字体文件。

- 文件与用户原件一致，未修改或子集化，大小为 7,004,128 字节。
- SHA-256：`f2c4f9295d9d04a1eb6392ae3c51ecf2a9ffab355a45c6686eeec5eede3381ec`。
- `LICENSE.txt` 复制自用户提供的字体包，含 ChillType 版权声明与 SIL Open Font License 1.1；导出时一并携带。
- 关闭设备系统字体回退；新增文字需确认字形覆盖。订单完成标记采用此字体提供的 `√`。
- 已删除旧字体文件、混合字体资源和旧子集制作工具；运行与导出无需字体制作依赖。

失败弹窗图片中的定稿立体字按用户要求保留；其余可编辑文案统一用本字体。原始美术中的字样属于图片内容，不是额外的字体文件。

替换后运行 `node Testing/scripts/run_godot.mjs architecture home donut`，检查中英文文字边界，并用 `node Tooling/export/web.mjs` 更新固定网页预览；小游戏导出包字体覆盖由 `Testing/integration/minigame/pack_test.gd` 检查。
