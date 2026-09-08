class_name LocalizationService
extends Node
## 应用级语言生命周期；玩家加载前可用，只保存设备偏好，不修改账号与进度。

const ROOT = "res://game_content/generated"
const MANIFEST = ROOT + "/localization/manifest.json"
const PREFERENCE = "language_preferences.json"
const Manifest = preload("res://game_content/runtime/language_manifest.gd")
signal locale_changed(locale: String)
var error: String = ""
## 损坏偏好不覆盖；警告使用展示键并持续到有效保存或下次初始化。
var preference_warning: String = ""
var current_locale: String = ""
var default_locale: String = ""
var available: Array[Dictionary] = []
var current_font: Font
var _repository: RefCounted
var _translations: Array[Translation] = []
var _fonts: Dictionary = {}
var _saved_locale: String = ""
var _preference_can_save: bool = true

## 先验证完整资源列表，再一次性注册翻译；不加载被隐藏的语言。
func initialize(repository: RefCounted, manifest_path: String = MANIFEST) -> bool:
	_release()
	error = ""
	var contract = Manifest.new()
	if not contract.read(manifest_path):
		error = "\n".join(contract.errors)
		return false
	var manifest: Dictionary = contract.data
	default_locale = manifest.default_locale
	var root = manifest_path.get_base_dir().get_base_dir()
	for row in manifest.locales:
		if row.id in manifest.disabled_locales or row.get("missing_count", 1) != 0: continue
		for path in row.files:
			var full_path = root.path_join(path)
			var resource = load(full_path)
			if not resource is Translation or resource.locale != row.id:
				error = "语言资源与清单身份不符: " + path
				break
			_translations.append(resource)
		if not error.is_empty(): break
		if not _fonts.has(row.font.path):
			var font = FontFile.new()
			if font.load_dynamic_font(row.font.path) != OK:
				error = "语言字体无法读取: " + row.font.path
				break
			font.allow_system_fallback = false
			_fonts[row.font.path] = font
		available.append(row.duplicate(true))
	if not default_locale in available.map(func(row): return row.id): error = "默认语言未打包、被隐藏或翻译尚未完整。"
	if not error.is_empty():
		_release()
		return false
	for translation in _translations: TranslationServer.add_translation(translation)
	_repository = repository
	var preference: Dictionary = {}
	if _repository != null and _repository.exists(PREFERENCE):
		preference = _repository.read(PREFERENCE, _valid_preference)
		if not _repository.error.is_empty():
			_preference_can_save = false
			preference_warning = "ui.language.preference_unreadable"
		elif _repository.recovered_from_backup:
			preference_warning = "ui.language.preference_recovered"
		else: _saved_locale = preference.get("locale", "")
	# 首次使用发行配置的默认语言；只有玩家已保存的选择才能覆盖它。
	var requested: String = preference.get("locale", default_locale)
	_apply_locale(_match_locale(requested))
	return true

## 先保存再切换；损坏偏好只允许会话内切换，不产生账号或导航副作用。
func select_locale(locale: String) -> bool:
	error = ""
	if not locale in available.map(func(row): return row.id):
		error = "ui.language.unavailable"
		return false
	if _repository != null and _preference_can_save and locale != _saved_locale:
		if not _repository.write(PREFERENCE, {"version": 1, "locale": locale}):
			error = "ui.language.save_failed"
			return false
		_saved_locale = locale
		preference_warning = ""
	if locale == current_locale: return true
	_apply_locale(locale)
	locale_changed.emit(locale)
	return true

## 当前字体优先，其他已开放语言只作字符回退；不读取系统或包外字体。
func _apply_locale(locale: String) -> void:
	current_locale = locale
	var selected = FontVariation.new()
	var paths: Array[String] = []
	for row in available:
		if row.id == locale:
			selected.base_font = _fonts[row.font.path]
			paths.append(row.font.path)
	for row in available:
		if not row.font.path in paths:
			selected.fallbacks.append(_fonts[row.font.path])
			paths.append(row.font.path)
	current_font = selected
	TranslationServer.set_locale(locale)

## 简繁不相互猜测；区域变种按原生语言匹配评分回退到已打包默认值。
func _match_locale(requested: String) -> String:
	var normalized = TranslationServer.standardize_locale(requested)
	var best = default_locale
	var score = 0
	for row in available:
		if normalized.begins_with("zh_") and row.id.begins_with("zh_") and normalized.get_slice("_", 1) != row.id.get_slice("_", 1): continue
		var candidate = TranslationServer.compare_locales(normalized, row.id)
		if candidate > score:
			score = candidate
			best = row.id
	return best

## 偏好仅记录语言身份；损坏文件不冒充可覆盖的新配置。
static func _valid_preference(value: Dictionary) -> bool:
	return value.size() == 2 and value.get("version") == 1 and value.get("locale") is String and not value.locale.strip_edges().is_empty()

## 仅卸载本服务注册的资源，不清空 SDK 或编辑器拥有的翻译。
func _release() -> void:
	for translation in _translations: TranslationServer.remove_translation(translation)
	_translations.clear()
	_fonts.clear()
	current_font = null
	available.clear()
	current_locale = ""
	default_locale = ""
	_repository = null
	_saved_locale = ""
	_preference_can_save = true
	preference_warning = ""

## 应用退出时释放自己的翻译引用。
func _exit_tree() -> void:
	_release()
