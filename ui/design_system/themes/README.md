# 通用详情材质

卡面居中的内容浮层使用与 Home、模式选择一致的黑金标题牌、羊皮纸和金色分隔线。原始素材保留于 `features/game_modes/ui/art/mode_atlas.png`，生成来源见该目录 README。

- `detail_title.png`：原图区域 `(190,115,560,179)`，沿标题牌实际轮廓保留透明边缘。
- `detail_paper.png`：原图区域 `(153,1292,625,144)`，沿八角纸面外沿抠图。
- `detail_surface.png`：纸面裁片按固定角部、连续直边和单个边缘纹章拼成 500×820 的长面板，中心取原图 `(280,1330,350,63)` 纸纹并镜像接续，避免纵向重复边饰及硬拼缝。
- `detail_rule.png`：原图区域 `(319,350,299,25)`，按亮度去除暗底，保留金色横线与菱形。

这些无文字裁片由共享 Theme 持有，通用弹窗不引用 Feature。裁片以 50% 等比缩小至逻辑像素尺寸，九宫格固定 20 像素角部比例，正文使用长纸面，避免把短按钮纵向反复平铺；标题、正文及操作文本均由原生控件按语言绑定，实际卡面仍使用 CardFaceView。

## 独立升星与操作底板

`detail_supplement.png` 由 Codex 内置 imagegen 参考本目录的 `detail_title.png` 和 `detail_paper.png` 生成。无字黑金底板用于卡牌正文下方的可选升星与操作模块；碎片数量、进度和按钮仍由原生控件呈现。原始 PNG 保留 1983×793 的生成尺寸与字节，Godot 通过 `process/size_limit=512` 等比导入，Theme 使用固定 20 像素九宫格角部，适应仅成长、仅操作和二者并存的不同高度。生成文件实际为 RGB，透明请求未被模型落实；`detail_supplement.gdshader` 按导入图固定 14 像素切角裁掉外侧黑底，仅作用于底板，不裁切子控件或改变交互。

生成时使用的完整提示词：

```text
Use case: style-transfer. Create ONE production-ready blank fantasy UI background panel for a compact star-upgrade module. Reference 1 is the actual approved dark title plaque from our game; preserve its charcoal embossed material, aged muted warm gold double rim, shallow bevel and restrained hand-painted detail. Reference 2 is the existing parchment button; the new DARK panel must sit behind these light buttons, so its rim should be finer and quieter than theirs.
Deliver a wide horizontal rectangular panel, target aspect ratio 2.5:1, intended to display at about 500 by 200 logical pixels. Straight horizontal and vertical edges with small precise 45-degree chamfered corners, mirrored left/right and top/bottom. A thin double gold rim occupies only the outer 3 percent. The large inside area is continuous near-black graphite with very subtle embossed texture; flat even illumination suitable for gold text and a progress bar near the top, two light buttons below. No internal dividers or compartments. Do not draw the text, numbers, stars, icons, progress bar or buttons. No center ornament. No curls or filigree. No parchment inside. No broad glowing edges, heavy shadows, flare, uneven perspective or bulging sides. Front-facing orthographic UI asset.
The panel must fill the image almost edge to edge with only a tiny transparent margin. Genuine PNG alpha transparency outside the chamfered silhouette; no white background, no baked checkerboard, no white fringe. Crisp reusable game UI asset, not a mockup or screen.
```
