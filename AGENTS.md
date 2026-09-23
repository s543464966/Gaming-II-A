# AGENTS

本工作区已在新项目骨架上实现甜甜圈排序三关与基础玩法。唯一 Git 根是工作区 `GamingII-A/`，Godot 产品工程位于 `Coding/godot/`。产品开发默认在工程内进行；修改前读取直接相关源码并从工作区根检查 Git 状态，不覆盖已有改动。旧玩法、素材、账号、数据管线和平台集成已移除；空目录不代表功能已实现，不从 Git 历史、恢复包或旧规则推断新需求。

项目远端为 `git@github.com:s543464966/Gaming-II-A.git`，主分支为 `main`。远端操作前通过 `git remote -v` 核对实际目标。

## 目录与事实源

- 工程入口为 `Coding/godot/project.godot`，使用 GDScript、Godot 4.5.1 与 Compatibility；现有竖屏设置保留。运行与结构说明见 `Coding/godot/README.md`，Git 边界见 `Coding/godot/GIT.md`。
- 第一方文件和目录使用 `snake_case`，节点与类名使用 PascalCase；README、GIT、LICENSE 和第三方文件遵循各自约定。修改目录大小写时检查实际磁盘名称。
- 玩法状态、规则与页面归 `features/<owner>/`；页面及专属装饰归该 Owner 的 `ui/`。当前 `features/home/` 是启动与独立预览入口，实例化 `features/donut_sort/` 的关卡页面；新增业务目录按实际实现或已确认需求建立。失效业务目录、`.gitkeep` 和文档引用同步移除，不保留旧业务空占位。
- 游戏静态定义、素材与文本归 `game_content/`，同类内容相邻并保持唯一人工事实源。通用 UI 资源归 `ui/design_system/`，通用组件归 `ui/components/`，全局模态归 `ui/overlays/`。当前没有 Schema 或生成管线，建立后再明确来源、校验与生成物边界。
- 后续通用存储等 I/O 归 `services/`，当前没有服务实现，按实际需要创建目录；宿主适配归 `platforms/`，微信与抖音配置和启动适配分别位于 `platforms/wechat/`、`platforms/douyin/`。不预建笼统的 systems 或全局状态副本。
- `Designing/` 统一保存项目策划与设计文档，入口为 `Designing/README.md`；`Archive/ReferenceImage/` 只保存参考图，`Archive/Builds/<平台>/` 是各平台唯一打包目录。每次打包更新该目录内容并保留本地 IDE 配置，不另建随机或时间目录，不重复创建模拟器项目；双击 `Tooling/<平台>.command` 委托对应导出入口，后续平台接入时沿用。设计文档引用工程内的运行素材与配置，不复制维护第二套运行数据；不得把备份或生成缓存当作开发事实源。
- 工作区 `Tooling/` 按 preview、export、data、environment 分用途；桌面 `.command` 仅委托唯一入口。工程 `tooling/` 当前只保留引擎基线 `engine.json`，版本绑定的制作实现按实际需要添加；`addons/` 仅放实际需要的第三方插件和引擎薄入口。运行时不得依赖工作区工具或测试代码。
- `Coding/`、`Designing/`、`Archive/` 中的人工资料、`Testing/`、`Tooling/`、`AGENTS.md` 和 `.agents/` 技能统一纳入工作区 Git；缓存、构建产物、本机 `.codex/` 配置与凭据按根 `.gitignore` 排除。Git 根与 Godot 工程根相互独立，不在工程内保留嵌套仓库。

## 生命周期与界面

- `bootstrap/app.tscn` 是唯一持续存活的 App，拥有 Services、SceneContainer、Overlay；页面替换只影响 SceneContainer 的子场景，服务不随页面重建。第一方不使用 Autoload。当前 App 向 Home 显式注入 DonutSession；F6 独立页面创建预览会话，无账号或存档读写。
- 页面通过显式依赖接收状态，通过信号请求操作或导航，不查找全局根、不创建第二套 App。稳定布局用 `.tscn`，样式由设计系统的 Theme 驱动。
- F6 用于单页预览；完整启动使用 F5 或 `Tooling/preview/preview.mjs`。新增存储时隔离新项目数据，不自动读取或迁移旧项目真实账号。
- 玩家界面保留必要状态、错误反馈和操作确认，避免教学步骤、重复玩法说明与开发布局备注。新增滚动、点击、拖拽或关闭交互时先读 `Coding/godot/ui/README.md`，验证取消、暂停、隐藏、离树与恢复。

## 修改与验证

- 第一方 GDScript 遵循 `.agents/skills/maintaining-gdscript-comments/SKILL.md`；第三方与生成文件不套用该注释规则。
- 资源移动或重命名时同步修复 `res://`、场景、资源与 `.uid` 引用，不手写或提交 `.godot/` 缓存；非明确素材删除任务不得丢失原始美术。
- 测试与隔离运行内容归 `Testing/`，入口为 `node Testing/scripts/run_godot.mjs <suite...>`，当前支持 `architecture`、`home`、`donut`。甜甜圈规则或关卡配置变更运行 `donut`，保留完整解与数量守恒验证。临时数据归唯一 `Testing/.runtime/<run-id>/`，读取结果后清理，不使用真实账号做测试。
- 修改应用装配、生命周期或共享 Theme 后运行 `architecture home`，新增玩法按风险补最小充分的验证。Godot 退出码为 0 仍须检查脚本、资源错误和完成标记。
- 微信、抖音打包分别使用 `node Tooling/export/wechat.mjs`、`node Tooling/export/douyin.mjs`，按对应 `Coding/godot/platforms/<平台>/README.md` 维护配置、固定依赖与验证；两端共用构建核心和真实资源包检查。抖音当前仅准备工具，AppID 可留空并在报告中标记未绑定，不创建 IDE 项目；其他平台和上传入口尚未接入。绑定时使用当前项目实际 AppID，不复用旧项目或其他平台目标；本地启动、导出、模拟器和真机分别验收。
- 缓存、导出制品、运行诊断、IDE 配置与凭据遵循工作区根 `.gitignore`，不作为源码提交。

## 交付

说明完成内容、修改位置、实际验证和残余限制。Git 操作从工作区根执行，确认仓库根、分支、远端及实际跟踪范围；未获授权不提交或推送。
