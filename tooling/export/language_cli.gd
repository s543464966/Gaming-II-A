extends SceneTree
## 语言构建的只读前后置校验入口；失败返回非零且不写入交付路径。

const Profile = preload("res://tooling/export/language_profile.gd")
const Validator = preload("res://tooling/export/language_pack_validator.gd")
const Catalog = preload("res://game_content/runtime/game_catalog.gd")

## check 验证来源与字体；verify 额外检查真实 ZIP 或 PCK 内的资源边界。
func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() < 2 or not args[0] in ["check", "verify"] or args.size() != (3 if args[0] == "verify" else 2):
		printerr("Usage: language_cli.gd -- check <profile> | verify <profile> <package.zip|package.pck>")
		quit(2)
		return
	var profile = Profile.new()
	var valid = profile.prepare(args[1])
	var errors: Array[String] = profile.errors.duplicate()
	if valid:
		var catalog = Catalog.new()
		valid = catalog.load_content()
		errors.append_array(catalog.errors)
	if valid and args[0] == "verify":
		var validator = Validator.new()
		valid = validator.verify(profile, args[2])
		errors.append_array(validator.errors)
	if not valid:
		for error in errors: printerr("LANGUAGE ERROR: " + error)
		quit(1)
		return
	print("LANGUAGE %s PASS: %s" % [args[0], profile.fingerprint])
	quit()
