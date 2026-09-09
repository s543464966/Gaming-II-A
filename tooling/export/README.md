# 平台适配与本地导出

当前支持用户明确启动的**抖音本地导出**，不自动进行上传、发布、小游戏开发者工具联调或真机验收。预设中的 AppID 保持空白，仅在单次构建注入，不使用模板演示账号；本地检查通过不代表可上线版本。

## 已保留的接入层

- Web 使用 Godot 4.5.1 官方单线程模板、Compatibility 和 GDScript。
- 抖音采用官方 `ttsdk` 1.0.4，GDScript 包装器固定官方模板与加载器版本，并从 `MAGICA_DOUYIN_APP_ID` 读取标识。参见[官方引擎接入指南](https://developer.open-douyin.com/docs/resource/zh-CN/mini-game/develop/guide/game-engine/godot/godot-engine-integration-guide)与[SDK 说明](https://developer.open-douyin.com/docs/resource/zh-CN/mini-game/develop/guide/game-engine/godot/sdk-usage-guide)。
- 微信使用 [godothub/godot-minigame](https://github.com/godothub/godot-minigame) 的 4.5.1.3 模板和第一方 GDScript 导出器；这是社区适配，不是将其宣称为腾讯官方引擎插件。AppID 来自 `MAGICA_WECHAT_APP_ID`。
- 平台运行层统一前后台暂停、存档检查点和安全区；标准 Web 页面使用可见性事件。真实平台回调、输入法、存储持久性和设备安全区仍待联调。

预设在工程 `export_presets.cfg`；正式 SDK 编辑器代码只负责压缩等导出职责，排除于游戏包。项目未接通平台认证、支付、广告、云存储或后端。

## 抖音完整本地制品

工作区唯一入口为 `node Tooling/export/export.mjs`；macOS 可双击 `Tooling/export.command`。输出固定为工作区 `Archive/Builds/douyin/`，`game.js` 等直接放在这一层，不嵌套版本或 `project/` 目录。开发者工具直接导入 `douyin/`，以后重复使用同一路径；构建记录在同级 `douyin.build.json`。AppID 由工作区本机配置或 `MAGICA_DOUYIN_APP_ID` 提供，默认使用中文语言配置，完整操作见工作区 `Tooling/README.md`。

包装器输出导出完成标记，但交付还必须经过 `douyin_verify.gd` 的目录、AppID、模板、语言与 PCK 验证。外层工具验证 SDK 的 Brotli 与原 PCK 相同，再调用 `pck_deduplicate.gd` 对相同载荷做无损去重、使用 Brotli 11 重新压缩并核对解压字节；生成包实际使用 `godot/main.br`，重复 PCK 仅作临时验证。去重保留全部资源路径与逐项原始字节，不删除或重写源素材；统计进入构建记录的 `optimization`。

`pck_reader.gd` 仅接受固定引擎的独立、未加密 PCK，按 [Godot 4.5.1 包格式实现](https://github.com/godotengine/godot/blob/4.5.1-stable/core/io/file_access_pack.cpp)检查目录、边界与 MD5。去重另验证前后路径和字节完全一致。`pck_report.gd` 将导入／场景缓存映射回源资源路径，按唯一载荷统计分类体积与最大 20 项，保存到构建记录的 `optimization.inventory`；共用载荷只计一次。这里是解压后的载荷字节，不能视作整包 Brotli 压缩贡献。外层工具另记录相对上次成功包的总字节变化。

`pack_load_verify.gd` 在无产品源码的实际包虚拟文件系统中解析 App、三类延迟页面及内容／下载浮层，检查默认语言字体和重建主题，防止源码或提前加载掩盖漏包；不创建玩家会话。

本项目固定输出采用保守的 **30,000,000 字节**上限，达到或超过预算即拒绝替换旧包；分包、字体、引擎和脚本合计计入。该门禁不是抖音上传计量，平台账号额度与真机仍需单独核验。Brotli 11 会增加数十秒的本地导出耗时。

大背景、已评估的大界面贴图，以及卡牌、遗物、主能力的静态插画在各自 `.png.import` 中使用 Lossy / 0.85；没有全局自动降画质策略，新素材需单独评估。已覆盖三张冒险事件背景、胜利横幅与两张掉落提示贴图、六套战斗命中序列；不将该设置推广到未评估的新增素材。原 PNG 和既有尺寸、透明度设置保留，编辑器和所有发行平台共用导入配置；小图、像素风素材不统一套用有损压缩。`texture-imports` 回归检查加载与配置尺寸，对未缩放资源检查透明度逐字节一致及可见颜色 PSNR ≥ 32 dB，数值检查不替代实际界面的视觉验收。当前统一中文常规字库但不裁字；只保留语言登记所需的原始字体及许可证。

工具保留最近成功构建的文件摘要；先验证临时新包，再切换固定目录，普通失败回退，成功不保留旧版本。独占锁阻止并发，构建中源码或目标变化拒绝覆盖；本地私有配置和指定 IDE 设置保留，缓存不复制。导出前停止预览与自动编译，完成后重新编译。语言作者数据未同步时应先明确完成数据制作流程；导出不会自动同步正式主表或修改生成资源。独立克隆仍需自行提供工作区编排，工程内验证实现与依赖锁保持完整。

## 小游戏配乐派生

`minigame_audio_export_plugin.gd` 通过 Godot 原生资源定制，在抖音和微信导出时将 `game_content/audio/music/` 中实际导出的 OGG 派生为 **64 kbps、32 kHz、立体声 Vorbis**；同一曲目只制作一次。保留完整时长、循环开关、循环偏移和节拍设置，不裁切或删除曲目，不改资源键与播放服务。普通 Web、桌面和其他原生平台继续使用原始 OGG。该音频策略与共用的图片导入策略不同。

编码器是 `dependencies.json` 锁定的 imageio-ffmpeg 0.6.0 macOS ARM64 归档内 FFmpeg 7.1。依赖准备同时校验归档与二进制 SHA-256，不依赖系统安装；当前仅支持这类构建主机，其他主机明确报错。它只参与本机构建，编码器、缓存、制作脚本不进入游戏包；来源见 [imageio-ffmpeg](https://github.com/imageio/imageio-ffmpeg)。

导出临时副本归 `tooling/.runtime/`，结束即清理，不建立第二份长期音频事实源。配置／实现／依赖锁变化使引擎定制缓存失效；转码失败或时长差超过 10 ms 时阻止交付。`minigame-audio` 使用真实编码器校验全部曲目、循环元数据、原件哈希、重复编码字节和失败分支，`export-live` 另在无源码的真实包中检查派生配乐与署名。压缩属于有损处理，音乐细节和设备播放效果仍需试听，不宣称音质无损。

## 语言资源与本地 ZIP 验证

`language_profiles/` 提供中文单语、英文单语和六语配置。`locales` 决定真正随包的语言，`disabled_locales` 是其中暂不显示的子集，默认语言必须随包且开放；数量由列表派生，不与平台绑定。文本域、字体和许可证的路径与 SHA-256 由生成清单记录，发行包不携带作者 JSON／CSV、未选 PO 或字体缓存副本。

语言服务使用当前语言对应字体，标题、正文和骰子数字不再各带独立字库。英法德使用拉丁字体，中日繁当前共用既有中文思源黑体。Theme 样式由脚本与令牌派生，`language_profile.gd` 仅在导出副本清空派生条目和中文预览默认字体；App 启动后绑定当前语言字体。实际包验证拒绝达到 128 KiB 的派生 `game_theme.res`，防止完整字体再次内嵌；主题配置变化也使导出缓存失效。

发行字体唯一来自语言清单，删除额外场景字库名单及其导入资源补包路径。中文包只携带一份 Regular 原始字库与许可证；英文包无需附带中文标题或骰子字体。验证器拒绝所有额外 `.fontdata` 副本。打包前禁用系统回退并逐字检查当前 PO；地区字形与美术效果另行验收。原件与许可证见[字体说明](../../ui/design_system/typography/README.md)。

在工作区根执行以下命令，通过 `GODOT_BIN` 指定 4.5.1 引擎。目标父目录须已存在，目标 ZIP 必须尚不存在，并与工作区运行目录位于同一文件系统：

```bash
node Tooling/export/pack.mjs Web res://tooling/export/language_profiles/english.json /absolute/output/english.zip
node Testing/scripts/run_godot.mjs language-pack
```

这个入口创建的是本地**资源 ZIP**，不是可发布的 Web 页面、App 安装包或小游戏目录；不会下载模板、读取 AppID 或上传。它依次导入、检查来源／Schema／真实内容目录／字体、构建临时 ZIP、核验包内字节，并确认前后语言指纹未改变。最后以不覆盖同名文件的原子操作交付；跨文件系统拒绝，不降级为可能留下半包的复制。失败日志和隔离数据留在明确输出的运行目录；成功会清理临时目录，并打印引擎版本、命令步骤、语言指纹、大小和包摘要。

必须注意：Godot 导出插件报错后仍可能以 0 退出并产生残缺文件。上述入口同时检查错误日志、完成标记和真实 ZIP；抖音完整导出使用同一语言策略核验真实 PCK。编辑器导出按钮本身不提供相同的交付门禁，两种本地检查都不能代替平台验收。

独立产品克隆可以直接调用同一只读校验实现；它不构建、不覆盖文件：

```bash
Godot --headless --path . --script tooling/export/language_cli.gd -- check res://tooling/export/language_profiles/english.json
Godot --headless --path . --script tooling/export/language_cli.gd -- verify res://tooling/export/language_profiles/english.json /absolute/output/english.zip
```

实际 ZIP 回归覆盖英文单语、中文单语、六语但隐藏日文，逐包检查资源排除并在空工作目录中启动正式 App。故障检查覆盖缺失文案、额外语言、损坏字体／快照／清单，以及退出码假成功、构建中来源变化与输出竞态。

## 按需资源交付（本地阶段）

默认完整包仍可离线启动；没有 `game_content/generated/delivery_manifest.json` 时，新服务不改变原加载流程。抖音完整导出的唯一入口 `Tooling/export/export.mjs` 已接入显式 CDN 模式，仍调用本目录 `content_partition.gd`，不会另建导出器。`Tooling/export/delivery.mjs` 继续提供两端独立的**资源集合构建**，尚未提供微信完整工程的一键交付。没有真实 HTTPS 域名时，保留 `embedded` 默认模式，仅用隔离测试验证远程路径，不给产品填占位地址。

已实现的边界：

- 从同次真实 Douyin／WeChat 完整资源 PCK 中拆出登记的 `game_content/` 静态 PNG 导入载荷。源码、场景和资源文件通过字面路径直接引用的图片，以及同批快照中英雄的肖像留在核心；动画、脚本、字体、配乐、UI 装饰及其他资源不自动拆分。CSV、内容 ID、资源键、原图和 `.import` 映射不移动。
- `delivery_manifest.json` 只在构建副本注入，固定格式 1、Godot 4.5.1、平台、登记表摘要、HTTPS 目录、包与文件 SHA-256 和大小。不下载可变清单，不接收远端代码。按原图目录分组，不把不相干类别混包；每组目标为 1 MiB 导入载荷，单图超过该值拒绝构建。运行清单要求压缩和展开大小分别不超过 2 MiB，每条只能是 `.godot/imported/` 下的 `.ctex`。
- `game_content/runtime/delivery_manifest.gd` 只负责契约；`services/content_delivery/` 由唯一 App 持有，负责串行下载、完整校验、缓存和挂载。`platforms/common/asset_download.gd` 提供 tt／wx ArrayBuffer 请求与桌面 HTTP 分支，30 秒等待上限、取消与迟到回调隔离。
- 制作校验仍全量检查；运行校验只跳过清单中路径相符的延迟纹理。首页仍核对当前英雄与背景，当前新玩家所需资源均在核心，可冷缓存离线进入首页；旧玩家切到未缓存的远程章节背景时仍可能下载。Home 根据页面展示集合请求资源，未开放页面不下载；冒险准备可随机取得的公共卡牌／奖励资源与当前章，不创建模式页或下载其他章节背景。公共卡牌仍整组准备，尚非每个敌人／每个可见条目的精细加载。
- `GameCatalog.resource_keys()` 只从调用方指定的静态记录递归提取注册表身份。页面与冒险 Owner 决定需求，下载服务不承载业务分类。`pending/prepare/prepare_content` 的无参数／`null` 表示明确全量预取，显式 `[]` 表示零需求，不能把没有资源的页面变成全量下载。
- 覆盖层显示完成字节百分比、失败、重试和取消；未准备好不进入目标页面或开启冒险。完整缓存不用联网。下载先写 `.part`，校验整体 SHA 与 ZIP 条目白名单后改名挂载；损坏缓存重新下载。本版一批实际需求成功后只清理新清单不再引用的旧摘要缓存，不要求玩家先浏览全部内容；失败或取消仍保留旧缓存，过程不触碰玩家存档。清单版本在进程内不可切换，已挂载包不尝试热卸载。

独立资源集合输出为配套的 `core.pck`、`core.br`、`manifest.json`、`remote/` 与构建记录。完整抖音 CDN 导出把核心放入真正加载的 `godot/main.br`，摘要 ZIP 放在旁边的 `Archive/Builds/douyin.cdn/`；小游戏目录不夹带远程包，固定构建记录同时拥有两套制品，切换失败成套回退。启用配置与上传先后顺序见[工作区工具](../../../../Tooling/README.md#cdn-小初始包模式)。

核心与外部包的实际路径／字节并集须保持原包完整；语言检查、空工作目录启动依赖检查、构建期间源码变化保护继续生效，压缩结束后再次检查工作区作者来源。ZIP 时间戳固定，相同资源输入重复构建保持缓存摘要不变。`content-delivery` 覆盖拒绝、空需求、损坏、取消、重试、缓存修复和重复构建；`delivery-live` 在隔离源副本中导出两个真实预设，再使用本机 HTTP 验证首页零请求、分页面下载、失败取消恢复和跨进程断网缓存启动。`export-tool` 覆盖成套回退与冲突，`export-live` 对比同源完整包与 CDN 完整工程体积并启动包内 Home。这些检查不是 tt／wx 开发者工具或真机运行。

资源故障会在下载浮层正文和启动错误页显示 `CDN-D1` 脱敏诊断：`stage` 区分下载、缓存写入、校验与挂载，`pack` 为资源包 SHA-256 前十二位。下载浮层不再另设可隐藏的诊断节点；失败详情为空时，正文仍显示 `stage=unknown reason=missing_details`，不猜测网络原因。下载详情保留 `transport`、固定原因分类、HTTP 状态、宿主数值 `errNo` 和 `bytes=实际/预期`；`-1` 表示尚未收到或未知，不等于收到零字节。控制台使用服务生成的诊断，不记录 URL、响应正文、原始宿主错误或存档路径。超时与主动取消分别标识，成功重试清除旧诊断。百分比仍按完成校验和挂载的字节计算，`0%` 本身不能证明没有收到响应。源码回归入口为 `download-diagnostics content-delivery architecture home platform`；`download-diagnostics-pack` 在空目录运行当前已验证的抖音实际包，不导出或上传，也不以本机结果代替真机验证。

当前剩余工作：

1. 中文已统一 Regular，App／Home 子页／全局浮层改为按需加载。后续自动文案子集、语言资源按需下载和更细的 UI 资源拆分仍未实现；当前保留完整正文字符覆盖。**资源拆包成功不代表总包小于 30 MB**，预算仍须包含引擎与平台文件。
2. 微信完整平台加载器与交付仍待接通。独立 `core.br` 只是资源压缩制品；现有微信模板读取原始 PCK，尚未使用它，不能作为微信初始包体积。抖音已可显式导出完整 CDN 工程，但本机未配置真实域名，固定交付默认仍为完整离线包。
3. 有域名后配置 HTTPS 存储、平台合法域名及匹配版本上传顺序，再分别验证真实 tt／wx 请求、平台缓存落盘／容量、断网、后台恢复和设备内存。当前只验证了本地文件缓存，没有宣称实现平台配额驱逐或真机持久性。

多平台继续共用内容 ID 和逻辑清单，按实际引擎与纹理格式各自构建，不强行共用二进制包。iOS／Android 以后按实际需求接入平台资源交付，Steam／桌面可继续完整离线安装；本轮未预建这些平台服务。小游戏分包不自动免除总代码包预算。25 MB 是建议的完整交付日常目标，抖音硬门禁仍为 30,000,000 字节。

## 可复现依赖

`dependencies.json` 固定 URL、SHA-256 和引擎版本，随产品维护。下载编排位于工作区 `Tooling/environment/`。下载缓存归工程 `tooling/.runtime/export-dependencies/`，不提交 Git，不把用户目录残留当作依赖来源。抖音一键入口自动调用已有依赖准备；也可在工作区根单独运行：

```bash
node Tooling/environment/prepare_dependencies.mjs web
node Tooling/environment/prepare_dependencies.mjs wechat
node Tooling/environment/prepare_dependencies.mjs douyin
```

工具可用末尾参数指定其他 Godot 工程目录。外层脚本不在产品 Git 内，独立克隆需另行提供；版本锁与导出器仍随产品维护。工具先核验已有文件，只在缺失或校验不符时下载，校验成功后才发布；Web 官方完整模板归档约 1.26 GB，只提取两个声明的单线程模板。此入口不登录、不上传、不创建发布记录。

导出器固定要求 4.5.1，小游戏缺少 AppID 或模板指纹不符即拒绝执行。本地已有分包、包体预算和启动依赖检查，但不能把编辑器导入成功或 Godot 包能启动当作平台通过；仍需在开发者工具及真机验证实际计量、加载画面、输入、存储和平台要求。

## 依赖来源与局部修正

### 抖音画布适配

`platforms/douyin/game.js` 是小游戏上屏画布的唯一尺寸入口，每次导出覆盖 SDK 默认入口，并逐字节验证交付文件。尺寸取自宿主当前窗口逻辑像素，乘设备像素比得到 canvas 像素；输入矩形使用同一逻辑尺寸，安全区留给既有 Godot UI 处理。窗口事件和返回前台按需更新，尺寸不变不重置渲染缓冲；失败／引擎退出解除监听，不随业务页面重建。

抖音预设固定 `canvasResizePolicy: 0`（None），让 Godot 读取而不改写宿主管理的画布；工程 `canvas_items + expand` 的等比布局保持不变。这是 [Godot 自定义画布支持的策略](https://docs.godotengine.org/en/4.5/tutorials/platform/web/html5_shell_classref.html)，不是关闭 UI 等比适配。当前固定官方加载器 `1.1.27` 将 `screenWidth` 错取为 `screenHeight`，导致虚拟 `window.innerWidth` 错误；不能再用 Adaptive (2) 让它把真实竖屏改成正方形。保留供应商原始字节和依赖校验，用同一入口保护内置加载器与平台插件两条路径；基础库版本按数值比较，避免 `3.100` 被误判为旧版。

回归入口为 `node Testing/scripts/run_godot.mjs douyin-viewport export-live`：前者用固定模板的真实 resize／输入函数验证尺寸、触摸映射、窗口变化与退出，以及旧策略可复现变形；后者在隔离工程实际导出，并拒绝缺失适配入口或错误 resize policy 的包。仍须在抖音开发者工具和真机完成视觉与点击验收，测试桩不是平台插件实机运行。

### 供应商来源

抖音 SDK 原包 `douyin_godot_sdk_1.0.4_6573599.zip` 的 SHA-256 为 `8047ac4b07e7e957d237287d1595507eb8c22e6451f156ae2fdacf4bd98ad3e8`，来自官方 SDK 页面附件。原包没有独立许可证文件；保留供应商归属，未来再分发前核对 SDK 使用条款，不擅自标为 MIT。

供应商代码仅做必要的适用性修正：`ttsdk/base/utils.gd` 在普通 Web 创建标准 JavaScript Object；`ttsdk/api/tt.gd` 仅在真实抖音宿主注册平台事件；`ttsdk.editor/export_report.gd` 的纯数据报告改用 `RefCounted`，修复未入树 Node 在导出进程退出时泄漏。其余供应商接口保持原样。

微信社区模板的 MIT 许可证保存在 `licenses/godot_minigame_license.txt`。没有引入其原生编辑器工具箱，模板提取使用白名单，排除演示数据包、私人配置和演示 AppID。模板自带启动图片尚未做产品化替换，平台阶段仍需处理。

Godot 引擎版本与导出模板来源为 [4.5.1 官方发布](https://github.com/godotengine/godot-builds/releases/tag/4.5.1-stable)。本地导出不包含发布签名、上传、审核或上线步骤。
