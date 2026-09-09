# 旧玩家数据导入

本目录拥有旧 Schema 1–11 的导入入口、只读预览、纯 JSON 转换及空目标发布。游戏运行时不依赖本目录，现有导出预设排除 `tooling/*`。

从工程根使用 `import_cli.gd -- preview <源目录>`，成功核对后才使用 `import_cli.gd -- import <源目录> <空目标目录>`；完整 Godot 命令见[工程说明](../../README.md#玩家数据)。预览不写盘，导入不修改来源；已有目标、缺失账号存档或损坏内容都会拒绝，不能部分发布。

`legacy_save_codec.gd` 将有效旧技能卡按每份 10 金币折算，合法份数仍为 1–9；旧技能市场槽位继续按原协议转换。当前配方与别名由 GameCatalog 查询，已退役的 SK022、SK032、SK069–SK074 只保留在转换器的身份名单中，不保存效果、冷却或美术副本，不重新进入策划表。未知 ID 仍拒绝转换；停止支持 Schema 1–11 时，名单与导入器一起退出。

当前玩家恢复、现行 Schema 升级和启动时旧身份选择仍由 `features/player_session/` 拥有，导入工具复用其恢复校验，不复制另一套存档规则。回归入口为工作区 `Testing/scripts/run_godot.mjs legacy-save player-io`。
