extends RefCounted
## 外语匹配、原文过期检查与原生 gettext 生成；不回写中文主表或旧译文。

const Schema = preload("res://game_content/runtime/content_schema.gd")
const Csv = preload("res://tooling/game_data/strict_csv.gd")
const Manifest = preload("res://game_content/runtime/language_manifest.gd")
const REGISTRY = "res://game_content/localization/locale_registry.json"
const SOURCE_ROOT = "res://game_content/localization/authoring"
const DOMAINS = Manifest.DOMAINS
var errors: Array[String] = []
var warnings: Array[String] = []
var entries: Dictionary = {}
var locales: Dictionary = {}
var messages: Dictionary = {}
var inputs: Dictionary = {}
var missing: Dictionary = {}

## 全量候选先在内存构建；只有原文指纹一致的非空译文可发布。
func build(source: String, content_entries: Dictionary, content_hash: String = "") -> Dictionary:
	errors.clear()
	warnings.clear()
	entries = content_entries.duplicate(true)
	locales.clear()
	messages.clear()
	inputs.clear()
	missing.clear()
	var registry = _json(REGISTRY)
	if registry.get("source_locale") != "zh_Hans" or not registry.get("locales") is Array:
		errors.append("语言登记表必须声明中文原文和语言列表。")
		return {}
	for locale in registry.locales:
		if not _locale(locale): continue
		locales[locale.id] = locale
		messages[locale.id] = {"content": {}, "ui": {}, "rules": {}}
		missing[locale.id] = []
	if not locales.has("zh_Hans") or not locales.has(registry.get("default_locale")):
		errors.append("原文语言和默认语言必须已登记。")
	if not errors.is_empty(): return {}
	for domain in ["ui", "rules"]: _source_messages(domain)
	for key in entries:
		var domain = key.get_slice(".", 0)
		if not entries[key].source.is_empty(): messages.zh_Hans[domain][key] = entries[key].source
	for file in Schema.TRANSLATION_FILES: _content_translations(source.path_join(file), file)
	for locale in locales:
		if locale == "zh_Hans": continue
		for domain in ["ui", "rules"]: _interface_translations(locale, domain)
		for key in entries:
			if entries[key].source.is_empty(): continue
			if not messages[locale][key.get_slice(".", 0)].has(key): missing[locale].append(key)
		if not missing[locale].is_empty(): warnings.append("%s 有 %d 条缺失或待更新译文，不可作为完整发行语言。" % [locale, missing[locale].size()])
	if not errors.is_empty(): return {}
	var files: Dictionary = {}
	var manifest = {"version": Manifest.VERSION, "content_hash": content_hash, "default_locale": registry.default_locale, "disabled_locales": [], "locales": [], "inputs": inputs}
	for locale in locales:
		var item: Dictionary = locales[locale].duplicate(true)
		item.font = {"path": item.font_path, "sha256": inputs[item.font_path], "license_path": item.font_license, "license_sha256": inputs[item.font_license]}
		item.erase("font_path")
		item.erase("font_license")
		item.files = {}
		item.missing_count = missing[locale].size()
		for domain in DOMAINS:
			var path = "localization/%s/%s.po" % [item.directory, domain]
			var bytes = _gettext(item, messages[locale][domain]).to_utf8_buffer()
			files[path] = bytes
			item.files[path] = _hash(bytes)
		manifest.locales.append(item)
	files["localization/manifest.json"] = (JSON.stringify(manifest, "  ", true) + "\n").to_utf8_buffer()
	return files

## 登记使用标准语言标识，目录名独立且只能是安全的 snake_case。
func _locale(value: Variant) -> bool:
	if not value is Dictionary or not value.get("id") is String or not value.get("directory") is String or not value.get("native_name") is String or not value.get("plural_forms") is String:
		errors.append("语言登记字段损坏。")
		return false
	var pattern = RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]*$")
	if value.id != TranslationServer.standardize_locale(value.id, false) or locales.has(value.id) or pattern.search(value.directory) == null or locales.values().any(func(row): return row.directory == value.directory):
		errors.append("语言标识或目录重复／无效: " + value.id)
		return false
	if not Manifest.font_path_valid(value.get("font_path")) or not Manifest.font_path_valid(value.get("font_license"), true):
		errors.append("语言必须指定设计系统中的字体和许可证: " + value.id)
		return false
	for path in [value.font_path, value.font_license]:
		if not FileAccess.file_exists(path):
			errors.append("语言字体或许可证缺失: " + path)
			return false
		inputs[path] = FileAccess.get_sha256(path)
	return true

## UI 与规则中文不属于策划业务表，按稳定展示键独立维护。
func _source_messages(domain: String) -> void:
	var path = SOURCE_ROOT.path_join("zh_hans").path_join(domain + ".json")
	var rows = _json(path)
	for key in rows:
		if not key.begins_with(domain + ".") or entries.has(key) or not rows[key] is String or str(rows[key]).is_empty():
			errors.append("中文展示键或文案无效: " + key)
			continue
		entries[key] = {"source": rows[key], "source_hash": rows[key].sha256_text(), "file": path}

## 辅助表只含外语、定位键和指纹，不接受中文原文列或其他字段。
func _content_translations(path: String, relative: String) -> void:
	if not FileAccess.file_exists(path):
		errors.append("缺少外语匹配表: " + relative)
		return
	inputs[relative] = FileAccess.get_sha256(path)
	var csv = Csv.new()
	var rows = csv.parse(FileAccess.get_file_as_string(path), relative)
	errors.append_array(csv.errors)
	if rows.is_empty() or rows.pop_front() != ["text_key", "locale", "text", "source_hash"]:
		errors.append(relative + " 字段必须为 text_key,locale,text,source_hash；不得复制中文列。")
		return
	var seen: Dictionary = {}
	for row in rows:
		if row.size() != 4:
			errors.append(relative + " 外语匹配列数错误。")
			continue
		var key: String = row[0]
		var locale: String = row[1]
		var identity = key + ":" + locale
		if seen.has(identity) or not entries.has(key) or not str(entries.get(key, {}).get("file", "")).begins_with(relative.get_base_dir() + "/"):
			errors.append(relative + " 重复或跨 Owner／未知文本键: " + identity)
			continue
		seen[identity] = true
		_accept(key, locale, row[2], row[3])

## 每语言项目文案只保存译文与其已核对的原文指纹。
func _interface_translations(locale: String, domain: String) -> void:
	var path = SOURCE_ROOT.path_join(locales[locale].directory).path_join(domain + ".json")
	var rows = _json(path)
	for key in rows:
		var row: Variant = rows[key]
		if not key.begins_with(domain + ".") or not entries.has(key) or not row is Dictionary or row.keys().size() != 2 or not row.get("text") is String or not row.get("source_hash") is String:
			errors.append("项目译文记录损坏或文本键无效: " + key)
			continue
		_accept(key, locale, row.text, row.source_hash)

## 原文修改只使对应语言的旧译文失效，不覆盖译文或自动确认指纹。
func _accept(key: String, locale: String, text: String, source_hash: String) -> void:
	if locale == "zh_Hans" or not locales.has(locale):
		errors.append("匹配表只能填写已登记的其他语言: " + locale)
		return
	if text.is_empty() or entries[key].source.is_empty(): return
	if source_hash != entries[key].source_hash:
		warnings.append("待更新译文: %s/%s" % [locale, key])
		return
	if _parameters(text) != _parameters(entries[key].source):
		errors.append("译文占位参数不匹配: %s/%s" % [locale, key])
		return
	messages[locale][key.get_slice(".", 0)][key] = text

## 命名参数集合必须完全一致，允许翻译调整顺序。
static func _parameters(text: String) -> Array:
	var pattern = RegEx.new()
	pattern.compile("\\{[a-zA-Z_][a-zA-Z0-9_]*\\}")
	var result: Array = []
	for match_value in pattern.search_all(text):
		if not match_value.get_string() in result: result.append(match_value.get_string())
	result.sort()
	return result

## JSON 作者文件拒绝重复键；来源指纹覆盖全部影响生成物的输入。
func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("缺少语言来源: " + path)
		return {}
	var text = FileAccess.get_file_as_string(path)
	var value: Variant = JSON.parse_string(text)
	if not value is Dictionary or not Csv.unique_json_keys(text):
		errors.append("语言 JSON 格式错误或重复键: " + path)
		return {}
	inputs[path] = FileAccess.get_sha256(path)
	return value

## 输出标准 PO 给 Godot 原生解析；不嵌入中文原文或编辑备注。
static func _gettext(locale: Dictionary, values: Dictionary) -> String:
	var header = "Language: %s\nContent-Type: text/plain; charset=UTF-8\nPlural-Forms: %s\n" % [locale.id, locale.plural_forms]
	var lines: PackedStringArray = ["# Generated. Edit authoring sources, not this file.", "msgid \"\"", "msgstr " + JSON.stringify(header), ""]
	var keys = values.keys()
	keys.sort()
	for key in keys:
		lines.append("msgid " + JSON.stringify(key))
		lines.append("msgstr " + JSON.stringify(values[key]))
		lines.append("")
	return "\n".join(lines) + "\n"

## 对最终字节计算指纹，避免文件编码差异漏检。
static func _hash(bytes: PackedByteArray) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
