extends RefCounted
## 平台无关的语言打包策略；完整性、可见性与默认值来自显式配置。

const ROOT = "res://game_content/generated/"
const MANIFEST = ROOT + "localization/manifest.json"
const DEFAULT = "res://tooling/export/language_profiles/chinese.json"
const Manifest = preload("res://game_content/runtime/language_manifest.gd")
var errors: Array[String] = []
var manifest: Dictionary = {}
var files: Dictionary = {}
var assets: Dictionary = {}
var fingerprint: String = ""

## 主题加载时从脚本和令牌恢复样式，不把派生字体与图片副本写进制品。
static func export_theme(theme: Theme) -> Theme:
	var result: Theme = theme.duplicate()
	result.clear()
	result.default_font = null
	return result

## 编辑器选项与命令行环境覆盖使用同一份配置，不按平台猜测语言。
static func selected_path(preset: EditorExportPreset = null) -> String:
	var override = OS.get_environment("MAGICA_LANGUAGE_PROFILE")
	if not override.is_empty(): return override
	return str(preset.get("localization/profile")) if preset != null and preset.get("localization/profile") != null else DEFAULT

## 未登记、重复、缺失、过期或默认值不可用时拒绝创建发行清单。
func prepare(profile_path: String, source_manifest: String = MANIFEST) -> bool:
	errors.clear()
	manifest.clear()
	files.clear()
	assets.clear()
	fingerprint = ""
	var profile = _read(profile_path)
	var contract = Manifest.new()
	if not contract.read(source_manifest): errors.append_array(contract.errors)
	if not errors.is_empty(): return false
	var source: Dictionary = contract.data
	_validate_freshness(source, source_manifest)
	if not errors.is_empty(): return false
	if profile.keys().size() != 3 or not profile.get("locales") is Array or not profile.get("disabled_locales") is Array or not profile.get("default_locale") is String:
		errors.append("语言配置只能包含 locales、default_locale、disabled_locales。")
		return false
	if not source.get("locales") is Array: errors.append("生成语言清单缺少 locales。"); return false
	var ids: Array = profile.locales
	if ids.is_empty() or not ids.all(func(id): return id is String) or _duplicates(ids): errors.append("导出语言不能为空、重复或含非字符串。")
	if not profile.default_locale in ids or profile.default_locale in profile.disabled_locales: errors.append("默认语言必须已打包且开放。")
	if _duplicates(profile.disabled_locales) or not profile.disabled_locales.all(func(id): return id in ids): errors.append("隐藏语言必须是导出列表的无重复子集。")
	if not errors.is_empty(): return false
	var index: Dictionary = {}
	for row in source.locales: index[row.id] = row
	manifest = {"version": Manifest.VERSION, "content_hash": source.content_hash, "default_locale": profile.default_locale, "disabled_locales": profile.disabled_locales, "locales": []}
	var root = source_manifest.get_base_dir().get_base_dir()
	for id in ids:
		if not index.has(id): errors.append("语言未登记: " + id); continue
		var row: Dictionary = index[id]
		if row.get("missing_count", 1) != 0: errors.append("语言译文未完整或已过期: " + id); continue
		_validate_font(row, root)
		for path in row.files:
			files[path] = row.files[path]
		assets[row.font.path] = row.font.sha256
		assets[row.font.license_path] = row.font.license_sha256
		manifest.locales.append(row.duplicate(true))
	if not errors.is_empty():
		manifest.clear()
		files.clear()
		assets.clear()
		return false
	fingerprint = (JSON.stringify(manifest, "", true) + JSON.stringify(assets, "", true) + FileAccess.get_sha256(source_manifest)).sha256_text()
	return true

## 过滤以清单的完整路径匹配，不以文件名或平台约定猜测。
func includes(path: String) -> bool:
	return files.has(path.trim_prefix(ROOT)) or assets.has(path)

## 发行字体必须独立覆盖该语言实际文案，系统回退不能掩盖包内缺字。
func _validate_font(row: Dictionary, root: String) -> void:
	var font = FontFile.new()
	if font.load_dynamic_font(row.font.path) != OK:
		errors.append("语言字体无法加载: " + row.id)
		return
	font.allow_system_fallback = false
	var missing: Dictionary = {}
	var characters: Dictionary = {}
	var values: Array[String] = [row.native_name]
	for path in row.files:
		var translation = load(root.path_join(path))
		if not translation is Translation or translation.locale != row.id:
			errors.append("语言文案原生资源身份错误: " + path)
			return
		for key in translation.get_message_list(): values.append(String(translation.get_message(key)))
	for value in values:
		for character in value:
			var point = character.unicode_at(0)
			if point in [9, 10, 13] or characters.has(point): continue
			characters[point] = true
			if not font.has_char(point): missing[character] = true
	if not missing.is_empty(): errors.append("语言字体缺字 %s: %s" % [row.id, "".join(missing.keys())])

## 构建验证输入新鲜度；独立克隆允许完全没有外部主表，但不允许缺半套来源。
func _validate_freshness(source: Dictionary, path: String) -> void:
	var snapshot = _read(path.get_base_dir().get_base_dir().path_join("game_data_snapshot.json"))
	if not snapshot.get("metadata") is Dictionary or snapshot.metadata.get("schema_version") != SnapshotFormat.VERSION:
		errors.append("定义快照与当前代码 Schema 不一致，请重新同步。")
		return
	if source.get("content_hash", "").is_empty() or source.get("content_hash") != snapshot.metadata.get("content_hash"):
		errors.append("静态内容与语言包不属于同一次生成。")
	if not source.get("inputs") is Dictionary:
		errors.append("语言清单缺少作者来源指纹。")
		return
	var external = ProjectSettings.globalize_path("res://../../Archive/GameDesignData")
	for input in source.inputs:
		if not input is String or input.contains("..") or input.contains("\\") or input.begins_with("/") or (input.contains(":") and not input.begins_with("res://")) or not Manifest.digest_valid(source.inputs[input]):
			errors.append("作者来源路径或指纹无效。")
			continue
		var location: String = input if input.begins_with("res://") else external.path_join(input)
		if not input.begins_with("res://") and not DirAccess.dir_exists_absolute(external): continue
		if not FileAccess.file_exists(location) or FileAccess.get_sha256(location) != source.inputs[input]: errors.append("语言作者来源已变化，请重新同步: " + input)
	if DirAccess.dir_exists_absolute(external):
		if not snapshot.metadata.get("sources") is Array:
			errors.append("定义快照缺少有效来源列表。")
			return
		for origin in snapshot.get("metadata", {}).get("sources", []):
			if not origin is Dictionary or not origin.get("file") is String or origin.file.contains("..") or origin.file.contains("\\") or origin.file.contains(":") or origin.file.begins_with("/") or not Manifest.digest_valid(origin.get("sha256")):
				errors.append("业务主表来源记录损坏。")
				continue
			if not FileAccess.file_exists(external.path_join(origin.file)) or FileAccess.get_sha256(external.path_join(origin.file)) != origin.sha256: errors.append("业务主表已变化，请重新同步: " + origin.file)

## 配置文件只读解析，缺失文件给出可见错误。
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): errors.append("缺少语言配置: " + path); return {}
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		errors.append("语言配置 JSON 损坏: " + path)
		return {}
	return parser.data

## 配置重复不是无害的显示问题，会影响默认值与资源边界。
static func _duplicates(values: Array) -> bool:
	var seen: Array = []
	for value in values:
		if value in seen: return true
		seen.append(value)
	return false
