# 战斗表现原画

## 当前画风样例

2026-09-09 使用内置 imagegen 重新生成物理、中毒的弹体、命中及独立中毒附着；没有使用 CLI/API 回退，没有复用被否定的旧命中原画，也没有提取竞品素材。对照实际首页、图鉴与 H001/H004 卡牌的深石面、旧金边、明确色块的手绘人物，采用哑光笔触、有限明暗层、局部接触亮色，收掉玻璃体积、荧光液体和密集碎屑。

| 成品原图 | 排列与消费者 |
| --- | --- |
| [物理／中毒弹体](../../projectiles/art/flight_brush.png) | 4×2；上行物理、下行中毒，各四帧循环 |
| [物理斩痕](impact_physical/impact_physical_painted.png) | 4×4；16 帧接触、笔锋断裂与消散 |
| [中毒腐蚀](impact_poison/impact_poison_painted.png) | 4×4；16 帧正面扩散、中心破开与碎散 |
| [中毒附着](impact_poison/poison_status.png) | 2×2；四帧短墨痕，分布在卡面两侧，中央留空 |

PNG 原件保持生成字节，保留真正 Alpha。弹体源图 1774×887，其余三张 1254×1254；Godot 导入限制长边 1024，分别得到 1024×512 和 1024×1024，不拉伸原画。导入延续 Lossy / 0.85，AtlasTexture 根据导入尺寸切片；不合格的棋盘格版本未接入工程。

弹体尖端在单帧宽度的 0.91 处，由 SpriteFrames 的 tip_ratio 元数据定义；显式弹道覆盖使用被选资源的支点，不由伤害分类猜测。物理直行；中毒只在起终点组成的屏幕平面内轻微侧弯，曲线随方向旋转，没有固定重力。细拖尾补足移动连续性，主轮廓由四帧原画提供。

命中使用正常透明混合，在静止卡位中心播放，受击回弹不拖走落点；物理和中毒不使用地面支点。基础速度 32 FPS，前四帧各 0.4 帧权重，其余各 1；暴击增强同一个命中而不叠第二张。中毒常驻播放独立 status 动画，6 FPS、四帧循环，不循环水洼尾帧。冷却向下扫描和权威结算时钟保持原样。

## 生成提示词

弹体提示词要点：transparent PNG; strict four-column two-row atlas; top row four frames ivory brush blade with muted vermilion underside and tiny antique gold edge; bottom row four frames matte jade-teal thorn/spore dart; both point right, stable leading tip, tail silhouette flutters; hand-painted fantasy card illustration, broad three-tone planes; no glossy drop, fire, bloom, ground, text or grid. 生成后按实际尖端位置配置支点，而非假定模型遵循指定像素位置。

以下为最终接入的三张效果图使用的完整提示词。

### 物理命中

```text
Transparent background. Production game sprite atlas. Create a NEW 16 frame animation of a SHORT PHYSICAL SLASH for a front-facing 2D hand-painted fantasy card game. EXACTLY 4 columns x4 rows, equal square cells, reading left-right then down. All 16 fixed central pivots. Blank space transparent alpha, NOT a gray checker pattern; PNG with real alpha. Style: matte ivory paint stroke, muted vermilion narrow underside, thin ochre shadow plane. Only three broad colored planes, painterly torn edges, restrained fantasy illustration, no realistic metal or volumetric shards, no glow, no fire. Animation frames1-2 a small fast ivory diagonal notch (bottomleft to topright);3-4 compact sharp crossing contact flash in ivory, one longer diagonal brush slash over it;5-8 slash lengthens and breaks into3-4 broad paint streaks;9-12 streaks separate into sparse small irregular vermilion and ivory angular flecks;13-16 very few fading tiny flecks. One coherent chronological motion with major silhouette changes, not16 identical icons. Peak spans75%cell, plenty transparent margin, nevertouchcellboundaries. Surface parallel toscreen; noground,floor,perspective,shadows,smoke,3Dshape,photorealtexture,text,borders,grid,runes. Minimal noise and strong silhouette, matches illustrated fantasy cards without looking like a shiny particle explosion. 1024x1024 preferred.
```

### 中毒命中

```text
Create a production game SPRITE SHEET, genuine transparent-background PNG with alpha, NOT an illustration of a checkerboard. EXACTLY 4 columns and 4 rows = 16 animation frames read left-to-right top-to-bottom, equal square cells with no borders/no captions. 1024x1024 preferred. Theme: POISON CONTACT on the front plane of a 2D fantasy card. Matte hand-painted jade teal ink-corrosion burst. Colors dark blue-green #174b49, jade #299e91, pale muted mint #b2d1bc, only 3 broad tonal planes. Simplified painterly strokes and torn inky edges, enough brush character to fit matte fantasy character card paintings, but no micro noise or realism. The effect is viewed absolutely straight on, parallel to screen, fixed center pivot in every cell. Frame1 tiny compressed mint contact notch at center;2 small asymmetrical teal star snap;3 sharp short broad torn brush splash;4 maximum graphic teal blossom spanning60%cell, pale small central split;5-8 the center quickly becomes hollow while 4-6 jagged ink petals expand sideways/radially around center;9-12 jagged patches fragment into sparse irregular stains/spores;13-15 very sparse fading dots;16 almost invisible tiny flecks. Strong distinct chronological silhouette change, not 16 identical icons. No continuous circle/ring, no white glow, no glossy liquid, no 3D volume. CRITICAL: NO falling drop, downward stream, liquid drips, puddle, ground plane, floor, perspective ellipse, bowl, smoke rising from base, gravity direction, cast shadow, leaf/emblem, rune, skull. Everything expands IN THE SCREEN PLANE from center like a brush stain blooming on paper. Transparent empty space in and around all frames must be alpha=0, do not paint a checkerboard. Shapes stay at least10%cell from boundaries.
```

### 中毒附着

```text
Transparent background, true alpha channel PNG. Production game sprite atlas, FOUR-frame LOOP arranged exactly2columns x2rows, equal square cells, no grid, no borders, no text. This is a subtle POISON INFESTATION animation attached to the front surface of a 2D portrait CARD, no card itself shown. Each cell contains TWO small loose matte jade-teal wisps/stains, one near LEFT perimeter x=12%, one nearRIGHTperimeter x=88%, around centerheight. Preserve the central70%width entirely empty transparent; no background, no rectangle, no ring, no floor, no puddle, no drips, no droplet, no realistic liquid, no lower basin, no growing fromground, no smoke column. Painterly torn broad brush edges, jade #299e91, darkteal #174b49 and mutedmint #a8c8b2 highlights only. Simple3tone graphic painting, no glossy light, no densefinegrain. These sidewisps are short interrupted ink stains, not a tall ornamental frame; occupy roughly40%cellheight around center and15%width peredge. Small irregular spore flecks near them. Fourframes show a subtle morphing flutter of SAME positioned wisps, not drifting or growing, loop4backto1. Fixedcenterpivot. Strong negative space and understatedcolor fit matte handpainted fantasy character portraits. No skull, runes, leaves, ornaments, stars or lettering. Actual transparent alpha empty space, do not draw checkerboard. 1024x1024 preferred.
```

## 其他四类与验证

巫术、燃烧、治疗、护盾仍使用 2026-09-08 的 16 帧图集，尚未按本轮画风重绘；其弹体仍为四帧 SVG。巫术为符文碎片聚散，燃烧为火舌与余烬，治疗为薄荷金色旋流，护盾为青色晶片。燃烧常驻仍使用原卡角余韵。这些旧版本的存在不表示六类已经完成风格统一。

`impact-resources` 检查真实 Alpha、图集裁切、帧时序、独立中毒附着、显式弹道覆盖与曲线旋转一致性；`combat` 覆盖结算与回放；`texture-imports` 检查导入质量。隔离视觉样片位于工作区 Testing 的 battle_vfx_visual.gd，在正式 5×6 棋盘、原卡插画和实际表现代码上播发测试事件；它不是权威战斗模拟，也不写玩家数据。需看连续录屏中的单次、反向、暴击、密集触发和常驻状态，不能用静态图替代动画验收。

此前节奏观察：[月圆之夜实战](https://www.bilibili.com/video/BV1nH4y1z7oU/)、[The Bazaar 战斗片段](https://www.bilibili.com/video/BV1oKbT6pEpE/)。仅参考起手、飞行、落点和消散的关系，不复制其美术风格。
