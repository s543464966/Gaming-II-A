@tool
extends Control
## 卡牌顶部圆角矩形数值条；左区随字宽适配，右区固定，总宽不超过卡身的 85%。

const HEALTH_WIDTH_PER_CELL: float = 0.44
const MAXIMUM_WIDTH_PER_CELL: float = 0.85
const INNER_EDGE: float = 1.5
## 左侧数值文字在原留白基础上，左右各追加的逻辑像素；生命区不追加。
const OUTPUT_EXTRA_PADDING: float = 2.0
const NUMBER_HEIGHT_SHARE: float = 0.60
const MINIMUM_FONT_SIZE: int = 6
const HEIGHT_PER_CELL: float = 0.18
var _number_font: FontVariation = FontVariation.new()
## 仅为尺寸变化重新排版保留输入数值，不推进或回写状态帧。
var _numbers: Array[float] = [0.0, 0.0]
## 由宿主单格尺寸提供的固定生命内宽，不随输出、当前生命或生命上限变化。
var _health_width: float = 44.0

## 原生节点负责数值，独立材质负责精确轮廓与手绘表面。
func _ready() -> void:
	resized.connect(_layout_values)
	_layout_values()

## 主题和语言只刷新字体与颜色，不重新计算游戏数值。
func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready(): _layout_values.call_deferred()

## 上限只用于绿色填充比例，文字只显示当前生命，不回写真实帧。
func set_values(output: int, strength: float, health: float, maximum: float) -> void:
	_numbers = [strength, health]
	$Output.visible = output != CombatTypes.Output.Special
	var surface: ShaderMaterial = $Surface.material
	surface.set_shader_parameter("output_color", DesignTokens.output_color(output))
	surface.set_shader_parameter("health_ratio", clampf(health / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0)
	_layout_values()

## 正常输出提纯提亮，不可用仍用柔暗基础色；生命、文字和几何不随左区调色变化。
func set_unavailable(unavailable: bool) -> void:
	$Surface.self_modulate = get_theme_color("unavailable_surface_tint", "CardStatsBadge") if unavailable else Color.WHITE
	$Surface.material.set_shader_parameter("unavailable", unavailable)

## 先预留固定血条，再测量输出所需宽度；超过卡宽上限时只压缩左区文字。
func fit_to_card(cell_width: float, card_width: float) -> void:
	_prepare_number_font()
	var height: float = clampf(cell_width * HEIGHT_PER_CELL, 12, 22)
	var font_size: int = _number_size(height)
	var padding: float = height * 0.24 + 1.0 + OUTPUT_EXTRA_PADDING * 2
	var limit: float = minf(card_width, cell_width) * MAXIMUM_WIDTH_PER_CELL
	_health_width = minf(cell_width * HEALTH_WIDTH_PER_CELL, maxf(1, limit - INNER_EDGE * 2))
	var output_width: float = 0
	if $Output.visible:
		var measured: float = _number_font.get_string_size(_point_text(_numbers[0], false), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		output_width = minf(ceilf(measured + padding), maxf(0, limit - _health_width - INNER_EDGE * 2))
	size = Vector2(INNER_EDGE * 2 + output_width + _health_width, height)
	_layout_values()

## 测量与绘制使用同一字体和字重，避免宽度适配采用另一套字符尺寸。
func _prepare_number_font() -> void:
	_number_font.base_font = theme.get_font("font", "CardStatValue")
	_number_font.variation_embolden = get_theme_constant("embolden_percent", "CardStatValue") / 100.0

## 字号随更矮的底板收敛，仍为极小卡片保留可辨认的最低尺寸。
func _number_size(height: float) -> int:
	return mini(get_theme_font_size("font_size", "CardStatValue"), maxi(MINIMUM_FONT_SIZE, floori(height * NUMBER_HEIGHT_SHARE)))

## 以同一内部矩形计算材质分界和文字中心，不让字体最小尺寸撑开徽章。
func _layout_values() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or size.x <= INNER_EDGE * 2: return
	var surface: ShaderMaterial = $Surface.material
	var inner_width: float = size.x - INNER_EDGE * 2
	var output_width: float = maxf(0, inner_width - _health_width) if $Output.visible else 0.0
	surface.set_shader_parameter("badge_size", size)
	surface.set_shader_parameter("output_share", output_width / inner_width)
	surface.set_shader_parameter("inner_edge", INNER_EDGE)
	surface.set_shader_parameter("corner_radius", get_theme_constant("corner_radius", "CardStatsBadge"))
	surface.set_shader_parameter("health_color", get_theme_color("health_surface", "CardStatsBadge"))
	surface.set_shader_parameter("rim_color", get_theme_color("rim_color", "CardStatsBadge"))
	$Output.position = Vector2(INNER_EDGE, 0)
	$Output.size = Vector2(output_width, size.y)
	$Health.position = Vector2(INNER_EDGE + output_width, 0)
	$Health.size = Vector2(inner_width - output_width, size.y)
	_prepare_number_font()
	for label: Label in [$Output, $Health/Current]:
		label.add_theme_font_override("font", _number_font)
	var upper: int = _number_size(size.y)
	var edge_space: float = size.y * 0.24 + 1.0
	var output_size: int = _fit_region($Output, _numbers[0], upper, maxf(1, $Output.size.x - edge_space - OUTPUT_EXTRA_PADDING * 2))
	var health_size: int = _fit_region($Health/Current, _numbers[1], upper, maxf(1, $Health.size.x - edge_space))
	$Output.add_theme_font_size_override("font_size", output_size)
	$Health/Current.add_theme_font_size_override("font_size", health_size)

## 两区独立测量与紧凑显示，生命长数不改变左侧字号或徽章外形。
func _fit_region(label: Label, value: float, upper: int, available: float) -> int:
	for mode in range(3):
		label.text = _point_text(value, mode > 0) if label.visible else ""
		var lower: int = maxi(MINIMUM_FONT_SIZE, ceili(upper * (0.75 if mode == 0 else 0.70))) if mode < 2 else MINIMUM_FONT_SIZE
		for candidate in range(upper, lower - 1, -1):
			var width: float = _number_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, candidate).x
			if width <= available: return candidate
	return MINIMUM_FONT_SIZE

## 输出与当前生命只由整数生成文字，紧凑单位也不带小数；不修改状态帧。
func _point_text(value: float, compact: bool) -> String:
	var points: int = roundi(value)
	if compact and absi(points) >= 999950: return str(roundi(points / 1000000.0)) + "M"
	if compact and absi(points) >= 1000: return str(roundi(points / 1000.0)) + "k"
	return str(points)
