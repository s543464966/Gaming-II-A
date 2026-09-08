class_name LanguageManifest
extends RefCounted
## 运行与导出共用的语言资源契约；完整验证后才公开清单和资源路径。

const VERSION = 2
const DOMAINS = ["content", "ui", "rules"]
const FONT_ROOT = "res://ui/design_system/typography/"
var data: Dictionary = {}
var errors: Array[String] = []

## 清单与静态定义必须同批，语言资源、字体和许可证均按原始字节校验。
func read(path: String) -> bool:
	data.clear()
	errors.clear()
	var candidate = _json(path)
	if not errors.is_empty(): return false
	var problem = validate(candidate)
	if not problem.is_empty(): errors.append(problem); return false
	var root = path.get_base_dir().get_base_dir()
	var snapshot = _json(root.path_join("game_data_snapshot.json"))
	if not snapshot.get("metadata") is Dictionary or snapshot.metadata.get("content_hash") != candidate.content_hash:
		errors.append("静态内容与语言包不属于同一次生成。")
	var verified: Dictionary = {}
	for row in candidate.locales:
		var paths = resources(root, row)
		for resource_path in paths:
			var digest: String = paths[resource_path]
			if verified.has(resource_path):
				if verified[resource_path] != digest: errors.append("同一语言资源存在冲突指纹: " + resource_path)
				continue
			verified[resource_path] = digest
			if not FileAccess.file_exists(resource_path) or FileAccess.get_sha256(resource_path) != digest:
				errors.append("语言资源缺失或指纹不符: " + resource_path)
	if not errors.is_empty(): return false
	data = candidate
	return true

## 身份、目录、完整域和字体字段显式校验，未知版本不得按旧格式继续加载。
static func validate(value: Dictionary) -> String:
	if value.get("version") != VERSION or not digest_valid(value.get("content_hash")):
		return "语言清单版本或内容指纹无效。"
	if not value.get("locales") is Array or value.locales.is_empty() or not value.get("disabled_locales") is Array or not value.get("default_locale") is String:
		return "语言清单缺少有效语言列表与默认值。"
	var ids: Array[String] = []
	var directories: Array[String] = []
	for row in value.locales:
		if not row is Dictionary or not row.get("id") is String or not row.get("directory") is String or not row.get("native_name") is String or row.native_name.strip_edges().is_empty():
			return "语言清单登记项损坏。"
		if row.id.is_empty() or row.id != TranslationServer.standardize_locale(row.id, false) or row.id in ids or not directory_valid(row.directory) or row.directory in directories:
			return "语言标识或目录重复／无效。"
		ids.append(row.id)
		directories.append(row.directory)
		if not row.get("missing_count") is float and not row.get("missing_count") is int: return "语言完整性计数损坏。"
		if row.missing_count < 0 or not is_finite(float(row.missing_count)) or row.missing_count != int(row.missing_count): return "语言完整性计数无效。"
		if not row.get("files") is Dictionary or row.files.size() != DOMAINS.size(): return "语言文案域不完整。"
		for domain in DOMAINS:
			if not digest_valid(row.files.get("localization/%s/%s.po" % [row.directory, domain])): return "语言资源域路径或指纹无效。"
		if not row.get("font") is Dictionary or row.font.size() != 4: return "语言字体登记不完整。"
		if not font_path_valid(row.font.get("path")) or not font_path_valid(row.font.get("license_path"), true) or not digest_valid(row.font.get("sha256")) or not digest_valid(row.font.get("license_sha256")):
			return "语言字体或许可证路径／指纹无效。"
	var disabled: Array = []
	for id in value.disabled_locales:
		if not id is String or not id in ids or id in disabled: return "隐藏语言不是已登记语言的无重复子集。"
		disabled.append(id)
	if not value.default_locale in ids or value.default_locale in disabled: return "默认语言未登记或被隐藏。"
	return ""

## 清单中字体为项目绝对资源路径，文本域相对同批生成根目录。
static func resources(root: String, row: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for path in row.files: result[root.path_join(path)] = row.files[path]
	result[row.font.path] = row.font.sha256
	result[row.font.license_path] = row.font.license_sha256
	return result

## 字体只能来自设计系统的安全路径，不允许跨目录或路径穿越。
static func font_path_valid(value: Variant, license_file: bool = false) -> bool:
	if not value is String or not value.begins_with(FONT_ROOT) or value.contains("..") or value.contains("\\") or value.trim_prefix("res://").contains("//"): return false
	return value.ends_with(".txt") if license_file else value.get_extension() in ["otf", "ttf", "woff", "woff2"]

## 目录与 Locale ID 分离，保持可读的第一方 snake_case 路径。
static func directory_valid(value: String) -> bool:
	var pattern = RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]*$")
	return pattern.search(value) != null

## 指纹格式先校验，避免空值与非字符串被当成合法资源身份。
static func digest_valid(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character in value:
		if not character in "0123456789abcdef": return false
	return true

## 损坏 JSON 只产生可追踪诊断，不发布半份清单。
func _json(path: String) -> Dictionary:
	var parser = JSON.new()
	if not FileAccess.file_exists(path) or parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		errors.append("语言清单或关联定义无法读取: " + path)
		return {}
	return parser.data
