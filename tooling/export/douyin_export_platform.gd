@tool
extends "res://addons/ttsdk.editor/export_platform.gd"
## 使用官方 SDK 的打包逻辑和固定官方模板；AppID 只由构建环境注入。

const PINNED_TEMPLATE = "res://tooling/.runtime/export-dependencies/douyin-web-release.zip"
const PINNED_LAUNCHER = "res://tooling/.runtime/export-dependencies/douyin-launcher.js"
const SETTINGS = "res://tooling/export/douyin_settings.json"
const GAME_ENTRY = "res://platforms/douyin/game.js"

## 与项目导出预设中的平台名保持一致。
func _get_name() -> String:
	return "MagicA Douyin"

## 缺少真实标识或固定模板时拒绝导出，不使用供应商演示值。
func _has_valid_export_configuration(preset: EditorExportPreset, debug: bool) -> bool:
	var languages = preload("res://tooling/export/language_profile.gd").new()
	if not languages.prepare(languages.selected_path(preset)):
		set_config_error("\n".join(languages.errors))
		return false
	if debug:
		set_config_error("此固定依赖只提供 release 模板；调试逻辑请先使用 Web/桌面验证。")
		return false
	if preset.get(OPTIONS_CANVAS_RESIZE_POLICY) != 0:
		set_config_error("抖音画布由宿主适配管理，Canvas Resize Policy 必须为 None (0)。")
		return false
	if not FileAccess.file_exists(GAME_ENTRY):
		set_config_error("缺少抖音画布适配入口: " + GAME_ENTRY)
		return false
	if String(preset.get_or_env(OPTIONS_APP_ID, "MAGICA_DOUYIN_APP_ID")).is_empty():
		set_config_error("缺少 MAGICA_DOUYIN_APP_ID。")
		return false
	if FileAccess.get_sha256(PINNED_TEMPLATE) != "5c11f7379d2f79f99d58c6f4913cac139143e9c81bbd4b8bdca9492f09bea2a5" or FileAccess.get_sha256(PINNED_LAUNCHER) != "e3783a2d863f9b29a2c6994460eac02e383525dcb74791fbfbe01c71ab863c3b":
		set_config_error("抖音依赖未安装或校验失败。")
		return false
	return true

## 固定模板只接受对应引擎与 Compatibility 渲染配置。
func _has_valid_project_configuration(preset: EditorExportPreset) -> bool:
	var version = Engine.get_version_info()
	return version.major == 4 and version.minor == 5 and version.patch == 1 and ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility" and super._has_valid_project_configuration(preset)

## 不改写正式预设文件；只在本次导出对象中注入 AppID。
func _export_project(preset: EditorExportPreset, debug: bool, path: String, flags: int) -> Error:
	if not _has_valid_project_configuration(preset) or not _has_valid_export_configuration(preset, debug): return ERR_INVALID_PARAMETER
	var previous_id = preset.get(OPTIONS_APP_ID)
	preset.set(OPTIONS_APP_ID, preset.get_or_env(OPTIONS_APP_ID, "MAGICA_DOUYIN_APP_ID"))
	var had_setting = OS.has_environment("BUILD_SETTINGS_LOCAL_FILE")
	var previous_setting = OS.get_environment("BUILD_SETTINGS_LOCAL_FILE")
	OS.set_environment("BUILD_SETTINGS_LOCAL_FILE", ProjectSettings.globalize_path(SETTINGS))
	var error = super._export_project(preset, debug, path, flags)
	if had_setting: OS.set_environment("BUILD_SETTINGS_LOCAL_FILE", previous_setting)
	else: OS.unset_environment("BUILD_SETTINGS_LOCAL_FILE")
	preset.set(OPTIONS_APP_ID, previous_id)
	if error != OK: return error
	# 官方加载器只用于旧基础库的本地回退，不在构建时下载可变远端代码。
	error = DirAccess.copy_absolute(PINNED_LAUNCHER, _get_export_dir_safe(path).path_join("godot.launcher.js"))
	if error != OK: return error
	# 每次从正式平台 Owner 导出，不保留导出目录里的临时改法。
	error = DirAccess.copy_absolute(GAME_ENTRY, _get_export_dir_safe(path).path_join("game.js"))
	if error == OK: print("DOUYIN EXPORT PASS: " + _get_export_dir_safe(path))
	return error

## 使用已校验的固定本地模板，避免 SDK 自动选择远端可变版本。
func _get_template_file_path(_preset: EditorExportPreset, _debug: bool, _template_name: String) -> String:
	return ProjectSettings.globalize_path(PINNED_TEMPLATE)

## 资源制作保留标准 PCK 文件名，完整小游戏入口仍使用 SDK 的 Brotli 交付格式。
func _export_pack(preset: EditorExportPreset, debug: bool, path: String, _flags: int) -> Error:
	var languages = preload("res://tooling/export/language_profile.gd").new()
	if not languages.prepare(languages.selected_path(preset)): return ERR_INVALID_PARAMETER
	return save_pack(preset, debug, path).result
