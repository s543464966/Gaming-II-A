# 背景音乐

本目录保存 MagicA 的循环配乐。资源键只在上级 `asset_registry.json` 登记；章节通过策划表的 `route_music_key`、`battle_music_key` 选择音乐，页面不从文件名推断地区。

游戏的声音方向是中世纪黑暗奇幻管弦乐，与石砌遗迹、远山、熔岩洞穴、冰原和卡牌棋盘的绘画风格保持一致。Home 使用带启程感的完整主题；路线曲保留探索空间和持续推进；战斗曲以弦乐、铜管与打击乐提高紧迫度，不使用合成器主旋律、电子鼓或 EDM 脉冲。路线与战斗分别使用独立且可循环的立体声 OGG，播放、交叉淡化、音量偏好和暂停恢复归应用级 `services/audio/`。

| 稳定资源键 | 页面／阶段 | 曲目 |
| --- | --- | --- |
| `music.home` | Home | Adventure Begins |
| `music.route.rock` | 岩断巨峰路线 | Epic Departure v2 |
| `music.battle.rock` | 岩断巨峰部署、战斗与结算 | Clash |
| `music.route.blood` | 血焰溶洞路线 | In Darkness v2 |
| `music.battle.blood` | 血焰溶洞部署、战斗与结算 | Obscurium |
| `music.route.ice` | 冰刃荒原路线 | Zwischenwelt |
| `music.battle.ice` | 冰刃荒原部署、战斗与结算 | Ship In A Storm |

Home 的缓存子页面沿用首页主题，不因刷新或打开子页面重新起播。冒险路线、事件和极光节点奖励沿用章节路线曲；部署、战斗、结果和普通战后奖励沿用章节战斗曲。设置与详情弹窗不另开音乐；返回 Home 切回首页主题，Startup 错误页停止音乐。

本目录 OGG 是保留的原始音频，不在此存放压缩副本。抖音／微信导出插件自动制作 64 kbps、32 kHz 立体声版本，保留完整时长及循环设置；普通 Web／桌面仍用原件。后续加入本目录的 OGG 沿用同一规则，短音效不参与此转码。具体依赖、失败保护与验证见[小游戏配乐派生](../../tooling/export/README.md#小游戏配乐派生)。

七首曲目均来自 Of Far Different Nature 的 **Essentials Pack for Fantasy Games — Loop Box #3**，依据 CC BY 4.0 使用。作者、曲目、来源和许可证链接保存在 `music_license.txt`，现有导出预设显式包含该文件。发行页面或游戏署名处也应保留：`Music by Of Far Different Nature (https://fardifferent.carrd.co/), licensed under CC BY 4.0.` 来源页、下载地址与成品哈希见 `music_sources.json`。短音效另有独立来源与许可，不沿用本段授权。
