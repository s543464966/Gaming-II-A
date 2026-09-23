# Git 仓库

唯一 Git 根是工作区 `GamingII-A/`，Godot 工程仍位于 `Coding/godot/`。保留现有提交历史和 `main` 分支，远端为 `git@github.com:s543464966/Gaming-II-A.git`。

工程配置、源码、场景、资源原件、许可证、`.uid`、源资源旁的 `.import` 和必要目录占位文件属于版本管理。`Designing/` 的策划与设计文档、`Archive/` 的参考图、`Testing/`、`Tooling/`、`AGENTS.md` 和 `.agents/` 技能也随工作区提交。

Git 不跟踪空目录；只有实际需要保留的框架位置才使用 `.gitkeep`。废弃业务目录连同占位文件一起删除，并同步文档和 Git 删除记录，不通过忽略规则掩盖仍被跟踪的旧内容。暂存删除后，已提交版本与远端仍需通过后续提交和推送更新。

工作区根 `.gitignore` 是唯一忽略规则入口；`.godot/`、`.runtime/`、可重建依赖、导出制品、凭据和本机 IDE、`.codex/` 配置不提交。`Archive/Builds/` 仅保留说明和目录占位，不上传导出包。`Coding/godot/` 不再包含独立 `.git`。

Git 操作从工作区根执行，先确认仓库根、分支、远端以及暂存、未暂存和未跟踪内容。不覆盖已有改动；只有得到用户授权才提交或推送，不重写历史。

克隆后用 Godot 打开 `Coding/godot/project.godot`。预览与测试命令从仓库根运行，入口见根 `README.md`。工具和测试随仓库分发，但不是游戏运行依赖。
