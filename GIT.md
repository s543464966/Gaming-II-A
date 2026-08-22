# MagicA Git 仓库说明

## 仓库信息

- 仓库地址：`git@github.com:s543464966/MagicA.git`
- 默认分支：`main`
- 仓库根目录：Unity 工程根目录，也就是当前工作区中的 `Coding/unity/`
- 当前仓库只管理 Unity 工程；工作区外层的 `Archive/`、`Testing/`、`Tooling/` 等目录不属于本仓库。

## 版本管理范围

应提交 Unity 工程的源码和可复现配置，包括：

- `Assets/`：脚本、美术资源、场景、Prefab 及其 `.meta` 文件
- `Packages/`：Unity Package Manager 的依赖清单与项目内包
- `ProjectSettings/`：Unity 项目设置
- 工程根目录中的项目配置、产品文档和构建配置

不提交本地生成内容，包括 `Library/`、`Temp/`、`Obj/`、`Logs/`、`UserSettings/`、构建产物、IDE 配置、崩溃转储和本地 Agent 运行状态。具体规则以根目录 `.gitignore` 为准。

Unity 的 `.meta` 文件必须与对应资源一同提交、移动或删除，避免资源 GUID 和场景、Prefab 引用失效。

## 日常提交

在 Unity 工程根目录执行：

```bash
git status
git add <本次变更的文件或目录>
git diff --cached
git commit -m "说明本次变更"
git push origin main
```

提交前确认 `git status` 中没有 `Library/`、临时文件、构建产物、密钥或与本次任务无关的内容。

## 首次获取项目

```bash
git clone git@github.com:s543464966/MagicA.git
cd MagicA
```

使用 Unity Hub 打开克隆目录。首次打开时由 Unity 根据 `Packages/` 和 `ProjectSettings/` 重建本地缓存。

## 历史边界

本仓库于 2026-08-22 从当前 Unity 工程重新初始化，只保留 `MagicA` 的新 `main` 分支历史。原 `2D_Card` 远端及其 `dev`、`master`、备份分支和提交记录不属于本仓库。
