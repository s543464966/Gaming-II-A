@tool
extends Label
## 固定插画布局的短文案只在既定区域内换行或缩字，不反向撑大组件。

@export_range(12, 32) var minimum_font_size: int = 16
@export_range(1, 4) var maximum_lines: int = 2
@export_range(0, 2, 0.1) var emphasis: float = 0
var _maximum_font_size: int
var _fit_queued: bool = false
var _emphasis_font: FontVariation

## 保留场景设定的参考字号，语言变化后仍能恢复到该上限。
func _ready() -> void:
	_maximum_font_size = get_theme_font_size("font_size")
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resized.connect(fit_content)
	minimum_size_changed.connect(fit_content)
	fit_content()

## 合并字体、翻译和尺寸通知，避免修改字号导致递归布局。
func _notification(what: int) -> void:
	if what in [NOTIFICATION_TRANSLATION_CHANGED, NOTIFICATION_THEME_CHANGED] and is_node_ready(): fit_content()

## 合并适配请求；动态文字变化时也可显式请求重新测量。
func fit_content() -> void:
	if _fit_queued or not is_inside_tree(): return
	_fit_queued = true
	_fit.call_deferred()

## 使用同一原生字体与换行规则测量实际译文，中文保持原始字号。
func _fit() -> void:
	_fit_queued = false
	if not is_inside_tree() or size.x <= 0 or size.y <= 0: return
	var parent_size = get_parent_control().size
	var bounds = parent_size * Vector2(anchor_right - anchor_left, anchor_bottom - anchor_top)
	bounds += Vector2(offset_right - offset_left, offset_bottom - offset_top)
	if get_parent() is Container: bounds = size
	bounds -= Vector2(get_theme_constant("outline_size") * 2 + 2, 2)
	if bounds.x <= 0 or bounds.y <= 0: return
	if emphasis > 0 and (_emphasis_font == null or _emphasis_font.base_font != get_theme_default_font()):
		_emphasis_font = FontVariation.new()
		_emphasis_font.base_font = get_theme_default_font()
		_emphasis_font.variation_embolden = emphasis
		add_theme_font_override("font", _emphasis_font)
	var font = get_theme_font("font")
	var translated = text if auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else tr(text)
	var flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var chosen = mini(minimum_font_size, _maximum_font_size)
	for candidate in range(_maximum_font_size, chosen - 1, -1):
		var measured = font.get_multiline_string_size(translated, horizontal_alignment, bounds.x, candidate, -1, flags)
		var lines = maxi(1, ceili(measured.y / font.get_height(candidate)))
		var height = measured.y + (lines - 1) * get_theme_constant("line_spacing") + get_theme_constant("outline_size") * 2
		if height <= bounds.y and measured.x <= bounds.x + 1 and lines <= maximum_lines:
			chosen = candidate
			break
	if chosen != get_theme_font_size("font_size"): add_theme_font_size_override("font_size", chosen)
