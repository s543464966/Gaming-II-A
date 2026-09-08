extends SceneTree
## 核验官方抖音导出目录、固定引擎字节与实际 PCK 的内容边界；不执行上传或启动宿主。

const Profile = preload("res://tooling/export/language_profile.gd")
const Validator = preload("res://tooling/export/language_pack_validator.gd")
const Catalog = preload("res://game_content/runtime/game_catalog.gd")
var errors: Array[String] = []

## 仅在来源、游戏定义、压缩前资源包和宿主配置均匹配时输出完成标记。
func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("Usage: douyin_verify.gd -- <language-profile> <export-directory>")
		quit(2)
		return
	var profile = Profile.new()
	if not profile.prepare(args[0]): errors.append_array(profile.errors)
	var catalog = Catalog.new()
	if not catalog.load_content(): errors.append_array(catalog.errors)
	if errors.is_empty():
		var validator = Validator.new()
		if not validator.verify(profile, args[1].path_join("godot/main.pck")): errors.append_array(validator.errors)
	_verify_host(args[1])
	if not errors.is_empty():
		for message in errors: printerr("DOUYIN ERROR: " + message)
		quit(1)
		return
	print("DOUYIN VERIFY PASS: " + profile.fingerprint)
	quit()

## 固定 SDK 的入口、分包、AppID 和模板必须同时一致，空产物不得通过。
func _verify_host(root: String) -> void:
	var expected = ["game.js", "game.json", "project.config.json", "godot.config.js", "godot.launcher.js", "godot/godot.js", "godot/godot.wasm.br", "godot/main.br", "godot/main.pck"]
	for path in expected:
		if not FileAccess.file_exists(root.path_join(path)) or FileAccess.get_file_as_bytes(root.path_join(path)).is_empty(): errors.append("缺少或空导出文件: " + path)
	if not errors.is_empty(): return
	var project = _json(root.path_join("project.config.json"))
	if OS.get_environment("MAGICA_DOUYIN_APP_ID").is_empty() or project.get("appid") != OS.get_environment("MAGICA_DOUYIN_APP_ID"): errors.append("导出 AppID 与本次配置不同。")
	if project.get("projectname") != ProjectSettings.get_setting("application/config/name"): errors.append("导出项目名称不同。")
	if not project.get("engineInfos", []).has({"name": "godot", "version": "4.5.1"}): errors.append("导出引擎标识不同。")
	var game = _json(root.path_join("game.json"))
	if game.get("deviceOrientation") != "portrait": errors.append("抖音必须使用竖屏配置。")
	if game.get("enableWebGL2") != true or not game.get("subpackages", []).has({"name": "godot", "root": "godot"}): errors.append("缺少 WebGL2 或 Godot 分包。")
	if not FileAccess.file_exists(root.path_join("godot/game.js")): errors.append("缺少分包入口。")
	var settings = _json("res://tooling/export/douyin_settings.json")
	if game.get("plugins", {}).get("GodotPlugin", {}).get("version") != settings.get("plugin_version"): errors.append("宿主插件版本不同。")
	var config = FileAccess.get_file_as_string(root.path_join("godot.config.js"))
	for declaration in ["canvasResizePolicy: 0", "mainPack: 'godot/main.br'", "mainWasm: 'godot/godot.wasm.br'", "godotModule: 'godot/godot.js'", "godotVersion: '4.5.1'", "subpackages: ['godot']"]:
		if not config.contains(declaration): errors.append("加载配置不匹配: " + declaration)
	if FileAccess.get_file_as_bytes(root.path_join("game.js")) != FileAccess.get_file_as_bytes("res://platforms/douyin/game.js"): errors.append("抖音画布适配入口与正式源码不同。")
	if FileAccess.get_file_as_bytes(root.path_join("godot.launcher.js")) != FileAccess.get_file_as_bytes("res://tooling/.runtime/export-dependencies/douyin-launcher.js"): errors.append("本地加载器与固定依赖不同。")
	var template = ZIPReader.new()
	if template.open("res://tooling/.runtime/export-dependencies/douyin-web-release.zip") != OK:
		errors.append("固定模板无法读取。")
		return
	for path in ["godot.js", "godot.wasm.br"]:
		if not template.file_exists(path) or template.read_file(path) != FileAccess.get_file_as_bytes(root.path_join("godot").path_join(path)): errors.append("引擎文件与固定模板不同: " + path)
	template.close()

## 配置损坏时记录原因，不将空字典视为默认有效配置。
func _json(path: String) -> Dictionary:
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		errors.append("无效 JSON: " + path)
		return {}
	return parser.data
