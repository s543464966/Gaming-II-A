@tool
extends EditorExportPlatformExtension
## 使用 godothub 的固定版本运行模板；第一方导出逻辑不依赖 C++ 编辑器工具箱。

const TEMPLATE_SHA256 = "032d0c91130c9b0710a7c4f91471b384b1e5b6a15ac4ac54512df52a759161de"
const TEMPLATE_PATH = "res://tooling/.runtime/export-dependencies/minigame4.5.1.3.tpz"
const FILES = ["engine/game.js", "engine/godot-sdk.js", "engine/godot.js", "engine/godot.wasm.br", "game.js", "game.json", "godot-loader.js", "weapp-adapter.js", "images/background.jpg", "images/logo.png", "project.config.json"]

## 与项目导出预设中的平台名保持一致。
func _get_name() -> String:
	return "MagicA WeChat"

## 将小游戏宿主与桌面或标准 Web 导出区分。
func _get_os_name() -> String:
	return "WeChatMiniGame"

## 编辑器列表复用项目已有图标，不引入额外资源依赖。
func _get_logo() -> Texture2D:
	return load("res://game_content/dice/art/faces/relic_surface.tres")

## 导出路径指向小游戏配置文件，其他文件写入同级目录。
func _get_binary_extensions(_preset: EditorExportPreset) -> PackedStringArray:
	return PackedStringArray(["config.json"])

## 运行时使用 Web 能力与微信宿主特性。
func _get_platform_features() -> PackedStringArray:
	return PackedStringArray(["web", "Web", "wechat"])

## 固定单线程 wasm32 和移动端纹理格式，不打包原生扩展。
func _get_preset_features(_preset: EditorExportPreset) -> PackedStringArray:
	return PackedStringArray(["web", "wechat", "wasm32", "nothreads", "web_noextensions", "etc2"])

## AppID 默认留空，后续平台阶段由环境注入。
func _get_export_options() -> Array[Dictionary]:
	return [{"name": "wechat/app_id", "type": TYPE_STRING, "default_value": ""}]

## 缺少标识或模板指纹不符时阻止创建无效包。
func _has_valid_export_configuration(preset: EditorExportPreset, _debug: bool) -> bool:
	var languages = preload("res://tooling/export/language_profile.gd").new()
	if not languages.prepare(languages.selected_path(preset)):
		set_config_error("\n".join(languages.errors))
		return false
	if String(preset.get_or_env("wechat/app_id", "MAGICA_WECHAT_APP_ID")).is_empty():
		set_config_error("缺少 MAGICA_WECHAT_APP_ID；禁止使用模板自带的演示 AppID。")
		return false
	if FileAccess.get_sha256(TEMPLATE_PATH) != TEMPLATE_SHA256:
		set_config_error("微信模板未安装或校验失败，请使用工作区 Tooling/environment/prepare_dependencies.mjs wechat 准备依赖。")
		return false
	return true

## 社区模板固定依赖对应的引擎版本和 Compatibility 渲染。
func _has_valid_project_configuration(_preset: EditorExportPreset) -> bool:
	var version = Engine.get_version_info()
	return version.major == 4 and version.minor == 5 and version.patch == 1 and ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility"

## 白名单提取运行文件，不携带演示资源、私人配置或编辑器缓存。
func _export_project(preset: EditorExportPreset, debug: bool, path: String, _flags: int) -> Error:
	if not _has_valid_project_configuration(preset) or not _has_valid_export_configuration(preset, debug): return ERR_INVALID_PARAMETER
	var target = ProjectSettings.globalize_path(path).get_base_dir().simplify_path()
	if target == ProjectSettings.globalize_path("res://").trim_suffix("/"): return ERR_INVALID_PARAMETER
	var zip = ZIPReader.new()
	var error = zip.open(TEMPLATE_PATH)
	if error != OK: return error
	for name in FILES:
		if not zip.file_exists(name):
			zip.close()
			return ERR_FILE_CORRUPT
	for name in FILES:
		var output = target.path_join(name)
		error = DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		if error != OK: break
		var file = FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			error = FileAccess.get_open_error()
			break
		file.store_buffer(zip.read_file(name))
		file.flush()
		error = file.get_error()
		file.close()
		if error != OK: break
	zip.close()
	if error != OK: return error
	var app_id = String(preset.get_or_env("wechat/app_id", "MAGICA_WECHAT_APP_ID"))
	error = _write_json(target.path_join("project.config.json"), {"appid": app_id, "projectname": "MagicA", "compileType": "game", "miniprogramRoot": ".", "setting": {"urlCheck": true, "es6": true, "minified": true}})
	if error != OK: return error
	# 保留固定模板要求的高性能模式，只声明实际生成的 engine 子包。
	error = _write_json(target.path_join("game.json"), {"deviceOrientation": "portrait", "iOSHighPerformance": true, "iOSHighPerformance+": true, "subpackages": [{"name": "engine", "root": "engine/"}], "plugins": {}})
	if error != OK: return error
	var saved = save_pack(preset, debug, target.path_join("engine/demo-pck.bin"))
	if saved.result != OK: return saved.result
	return DirAccess.copy_absolute("res://tooling/export/licenses/godot_minigame_license.txt", target.path_join("godot-minigame-LICENSE.txt"))

## 独立资源包仍委托 Godot 的标准打包接口。
func _export_pack(preset: EditorExportPreset, debug: bool, path: String, _flags: int) -> Error:
	var languages = preload("res://tooling/export/language_profile.gd").new()
	if not languages.prepare(languages.selected_path(preset)): return ERR_INVALID_PARAMETER
	return save_pack(preset, debug, path).result

## 写入可读配置并检查落盘错误，不把部分写入当作成功。
func _write_json(path: String, value: Dictionary) -> Error:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "  ") + "\n")
	file.flush()
	var result = file.get_error()
	file.close()
	return result
