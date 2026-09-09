extends SceneTree
## 旧本地存档导入的命令行入口；默认只预览，显式 import 才写空目标目录。

const Catalog = preload("res://game_content/runtime/game_catalog.gd")
const Importer = preload("res://tooling/player_data/legacy_import.gd")
const Repository = preload("res://services/save/json_repository.gd")

## 校验参数与完整源目录，只有显式 import 才发布到空目标。
func _init() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() < 2 or not args[0] in ["preview", "import"] or (args[0] == "import" and args.size() != 3):
		printerr("用法：-- preview <源存档目录>，或 -- import <源存档目录> <空目标目录>")
		quit(2)
		return
	var content = Catalog.new()
	if not content.load_content():
		printerr("静态目录校验失败：", "；".join(content.errors))
		quit(1)
		return
	var importer = Importer.new(content)
	if not importer.preview(args[1]):
		printerr(importer.error)
		quit(1)
		return
	for warning in importer.warnings: print("提示：", warning)
	if args[0] == "import" and not importer.publish(Repository.new(args[2])):
		printerr(importer.error)
		quit(1)
		return
	print("PLAYER IMPORT ", "PASS" if args[0] == "import" else "PREVIEW PASS", ": ", importer.account_count, " accounts; source unchanged")
	quit()
