# MagicA Git 仓库

正式产品与唯一仓库根是工作区的 `Coding/godot/`；远端为 `git@github.com:s543464966/MagicA.git`，主分支为 `main`。GitHub 仓库根直接展示 Godot 工程，不再包一层 `Coding/godot`。

## 提交边界

| 内容 | 是否提交 | 原因 |
| --- | --- | --- |
| `project.godot`、`export_presets.cfg`、README、GIT、`.gitignore` | 提交 | 工程入口、可复现配置和使用说明；导出 AppID 在构建时注入 |
| `bootstrap/`、`features/`、`services/`、`platforms/`、`ui/` | 提交 | 正式游戏逻辑、场景、主题、组件与平台适配 |
| `game_content/` 的静态内容、素材、登记表、作者文案 | 提交 | 正式内容及资源事实源 |
| `game_content/generated/` 的快照、PO、清单和完成记录 | 提交 | 同批运行数据；独立克隆没有外部 CSV 也能运行，不能当普通缓存忽略 |
| 原始美术、字体、许可证、来源说明、`.uid`、源素材旁的 `*.import` | 提交 | 资源原件、稳定标识和导入设置；保留的设计原件不等于必须打入发行包 |
| 工程内 `tooling/`、`addons/` | 提交 | 版本绑定的制作实现、依赖锁、插件薄入口与第三方 SDK；SDK 自带动态库不是本地产物 |
| `.godot/`、`.runtime/`、`exports/`、build/dist/temp/tmp、日志、IDE 与系统文件 | 不提交 | 可重建缓存、运行诊断或本机状态，由 `.gitignore` 排除 |
| 导出凭据、签名私钥、`.env` 实值、小游戏工具私人配置、真实玩家数据 | 不提交 | 私密或本机数据；只有不含秘密的环境示例可以入库 |
| 工作区外层 Archive、Designing、Testing、Tooling、AGENTS、`.agents/`、`.codex/` | 不提交 | 位于产品仓库外，必须单独备份；不会因为提交产品而获得 Git 保护 |

不全局忽略 `*.import`、`*.uid`、`*.json`、`*.po` 或动态库扩展名，这些包含真实产品输入。外层 CSV 的唯一人工来源仍是 `Archive/GameDesignData/`，不要为提交而复制到工程中；修改内容后通过原有数据管线生成运行快照。

## 提交流程

1. 从工程根确认分支、远端、已有暂存和工作区差异；未跟踪文件也要审阅。只在用户授权后提交或推送，不强制推送或重写历史。
2. 区分产品内容与本地产物，先更新忽略规则。忽略规则不会自动移除已跟踪文件；对误跟踪的本地文件仅取消跟踪，保留磁盘原件。
3. 检查密钥、私人路径、大文件和资源依赖；按已确认的目录分组暂存。迁移提交同时记录旧 Unity 文件删除与新 Godot 文件添加，不另建仓库，也不恢复已淘汰的 Unity 目录。
4. 审查最终暂存树，而不只看工作区。检查缓存和外层资料没有入库；验证从该树导出的无缓存副本能导入并启动，存档必须使用隔离测试目录。
5. 提交前再次确认暂存内容未被并行编辑改变；获取远端状态后正常推送。远端领先或发生分叉时停止覆盖，先明确整合方案；推送后比对本地与远端提交号。

```bash
git status --short
git diff --cached --stat
git diff --cached --check
git ls-files
```

## 获取与启动

```bash
git clone git@github.com:s543464966/MagicA.git
cd MagicA
```

使用 Godot 4.5.1 标准版打开 `project.godot`，首次由引擎重建 `.godot/`。运行静态快照不要求外部 CSV；数据制作、工作区自动预览、测试与完整导出编排需要另行提供外层数据或工具，详见 [README](README.md)。Git 提交与本地启动检查不代表小游戏平台上传、真机或发布验收。
