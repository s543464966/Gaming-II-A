# 设计稿与早期原型

这里保留迁入前的设计资料，便于继续讨论和编辑。HTML 与 PNG 记录其当时方案，旧 4×4、25 盒和错落示例不限制当前关卡；当前游戏使用的新版素材仍由 Godot 工程维护。

| 内容 | 可编辑稿 | 参考图 |
| --- | --- | --- |
| 错落布局、8／12／25 盒与六种视觉组合 | [staggered_layout.html](staggered_layout.html) | [布局](../../Archive/ReferenceImage/planning/staggered_layout.png)、[六方案](../../Archive/ReferenceImage/planning/staggered_layout_variants.png)、[盒数对比](../../Archive/ReferenceImage/planning/staggered_layout_counts.png) |
| 保留的旧 4×4 方案 | [grid_layout_legacy.html](grid_layout_legacy.html) | [布局](../../Archive/ReferenceImage/planning/grid_layout_legacy.png)、[六方案](../../Archive/ReferenceImage/planning/grid_layout_variants_legacy.png) |
| 方盒／圆盒与甜甜圈 | [box_shape_comparison.html](box_shape_comparison.html)、[art_overview.html](art_overview.html) | 原图位置见迁入清单 |
| 四款出餐盒比较 | [dispatch_box_comparison.html](dispatch_box_comparison.html) | 原图位置见迁入清单 |
| 原素材包组装稿 | [assembly_preview.html](assembly_preview.html) | [原始交付 ZIP](../art_reference/in_game_art_source.zip) |
| 早期交互原型 | [原型源码与说明](../prototypes/legacy_donut_sort/README.md) | 原型是旧演示关，不能作为当前百关验收 |

静态 HTML 可作为设计文件打开，其中图片和 JSON 素材引用均已改为仓库内相对路径。PNG 没有重新压缩或修改；28 个相同内容的重复引用合并到同一文件。素材清单和说明分别见 [CSV](../art_reference/asset_manifest.csv)、[说明](../art_reference/asset_notes.txt)，原交付 ZIP 保持原件。

正式游戏预览仍只使用 [固定网页入口](http://127.0.0.1:4173/)，由 `Tooling/preview/web.mjs` 提供当前 `Archive/Builds/web/`，不运行旧原型服务器。全部来源及迁入后位置见 [文件清单](../planning_import_manifest.json)。
