@tool
extends EditorExportPlugin
## 对所有平台应用同一语言白名单，不把作者文件或未选语言带入包。

const Profile = preload("res://tooling/export/language_profile.gd")
const THEME = "res://ui/design_system/themes/game_theme.tres"
var _profile: RefCounted

## 固定插件身份便于编辑器和测试定位。
func _get_name() -> String:
	return "MagicALanguages"

## 语言数量与宿主无关，Web 与小游戏使用相同导出规则。
func _supports_platform(_platform: EditorExportPlatform) -> bool:
	return true

## 导出器界面选择配置文件，默认只输出已完整的中文。
func _get_export_options(_platform: EditorExportPlatform) -> Array[Dictionary]:
	return [{"option": {"name": "localization/profile", "type": TYPE_STRING, "hint": PROPERTY_HINT_FILE, "hint_string": "*.json"}, "default_value": Profile.DEFAULT}]

## 编辑器可提前显示错误，正式导出仍重新验证以防来源变化。
func _get_export_option_warning(_platform: EditorExportPlatform, option: String) -> String:
	if option != "localization/profile": return ""
	var profile = Profile.new()
	profile.prepare(str(get_option(option)))
	return "\n".join(profile.errors)

## 仅为本次制品注入清单，不改写开发清单或用户预设。
func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	_profile = Profile.new()
	if not _profile.prepare(Profile.selected_path(get_export_preset())):
		get_export_platform().add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR, "Localization", "\n".join(_profile.errors))
		printerr("LOCALIZATION EXPORT ERROR: " + "\n".join(_profile.errors))
		return
	add_file(Profile.MANIFEST, (JSON.stringify(_profile.manifest, "  ", true) + "\n").to_utf8_buffer(), false)
	for path in _profile.files: add_file(Profile.ROOT + path, FileAccess.get_file_as_bytes(Profile.ROOT + path), false)
	for path in _profile.assets: add_file(path, FileAccess.get_file_as_bytes(path), false)

## 原生成清单被本次注入替代；作者目录和未选语言一律不导出。
func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path.begins_with("res://game_content/localization/") or path.begins_with(Profile.ROOT + "localization/") or path == Profile.ROOT + "bundle.json": skip()
	if path.begins_with(LanguageManifest.FONT_ROOT): skip()
	if _profile == null or not _profile.errors.is_empty(): skip()

## 开发 Theme 的中文预览字体不能成为所有发行包的强制依赖。
func _begin_customize_resources(_platform: EditorExportPlatform, _features: PackedStringArray) -> bool:
	return true

## 只导出脚本与令牌，加载时重建派生条目；不内嵌样式生成的字体副本。
func _customize_resource(resource: Resource, path: String) -> Resource:
	if path != THEME or not resource is Theme: return null
	return Profile.export_theme(resource)

## 切换配置或重新生成语言资源后使引擎导出缓存失效。
func _get_customization_configuration_hash() -> int:
	return (FileAccess.get_sha256(Profile.selected_path(get_export_preset())) + FileAccess.get_sha256(Profile.MANIFEST)
		+ FileAccess.get_sha256(THEME) + FileAccess.get_sha256("res://ui/design_system/themes/game_theme.gd")
		+ FileAccess.get_sha256("res://tooling/export/language_profile.gd")).hash()

## 释放单次导出状态，下一次语言选择不会沿用旧清单。
func _export_end() -> void:
	_profile = null
