# 随包 UI 字体

`donut_sans_sc.otf` 是 Noto Sans SC Regular 的子集，遵循随附 SIL OFL 1.1。覆盖 GB2312 常用字符以及生成时工程中的文本，确保微信环境无需设备系统字体即可显示中文。文件已提交，普通预览、导出不需要 Python。

源文件：[notofonts/noto-cjk / NotoSansSC-Regular.otf](https://github.com/notofonts/noto-cjk/blob/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf)。本次源文件 SHA-256：`faa6c9df652116dde789d351359f3d7e5d2285a2b2a1f04a2d7244df706d5ea9`。重新获取同版本源文件后，使用 Python 与 `fonttools==4.60.0` 执行：

```sh
python3 Tooling/data/subset_ui_font.py /path/to/NotoSansSC-Regular.otf
```

脚本校验源文件哈希，在工作区生成同一字体路径。更新字符或上游字体后重新生成，重新导入并运行 `architecture home` 与微信导出包检查；新增生僻字应在目标设备确认字形。字体许可随微信包一并复制。

## 参考稿排版字体

主界面的英文标题、订单数字与道具文字使用 Lilita One；盒沿 Donut 和出餐纸盒文案使用 Lobster Two Italic。两者均随包携带完整字体，模态菜单与中文反馈继续使用 Noto Sans SC。许可证已完整追加到 `LICENSE.txt`，现有导出入口会随制品复制该文件。

- `lilita_one.ttf`：[Google Fonts 官方来源](https://github.com/google/fonts/tree/main/ofl/lilitaone)，SHA-256 `f5b641c45c69d772ee4eda687bc9fda411d5cad6b0b45371491da4580cbc8d59`。
- `lobster_two_italic.ttf`：[Google Fonts 官方来源](https://github.com/google/fonts/tree/main/ofl/lobstertwo)，SHA-256 `c727ae1d9e1e166a7c0679fcf79c2ff0c21bc5483ee253fdfee2f5792c0bebd9`。
