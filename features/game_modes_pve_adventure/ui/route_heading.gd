@tool
extends Control
## 章节悬题只绘制随文字宽度收放的金线与菱形，不铺底色或接收输入。

## 编辑器和运行时共用原生文字布局，字体适配后重算装饰位置。
func _ready() -> void:
	resized.connect(queue_redraw)
	for label: Label in [$Title, $Progress]:
		label.minimum_size_changed.connect(queue_redraw)
		label.resized.connect(queue_redraw)
		label.visibility_changed.connect(queue_redraw)
	for feedback: Signal in [$Back.mouse_entered, $Back.mouse_exited, $Back.button_down, $Back.button_up, $Back.focus_entered, $Back.focus_exited]:
		feedback.connect(queue_redraw)

## 切换主题和语言只更新装饰，不重建标题或影响路线位置。
func _notification(what: int) -> void:
	if what in [NOTIFICATION_THEME_CHANGED, NOTIFICATION_TRANSLATION_CHANGED]: queue_redraw()

## 短金线让出返回热区；长章节名优先保留文字，空间不足时收起金线。
func _draw() -> void:
	if not is_node_ready() or not $Title.visible: return
	var title: Rect2 = _text_rect($Title)
	var gold: Color = get_theme_color("ready", "RouteNode")
	var back: Button = $Back
	var arrow_color: Color = get_theme_color("font_color", "Label")
	if back.is_pressed(): arrow_color = arrow_color.darkened(0.17)
	elif back.is_hovered() or back.has_focus(): arrow_color = arrow_color.lightened(0.1)
	var arrow := Vector2(back.position.x + back.size.x * 0.5, title.get_center().y + 2.0)
	draw_polyline(PackedVector2Array([arrow + Vector2(5, -10), arrow + Vector2(-5, 0), arrow + Vector2(5, 10)]), arrow_color, 3.5, true)
	for side: float in [-1.0, 1.0]:
		var x: float = title.get_center().x + side * (title.size.x * 0.5 + 28.0)
		var room: float = x - 96.0 if side < 0 else size.x - 96.0 - x
		if room < 24.0: continue
		var center := Vector2(x, title.get_center().y + 2.0)
		_diamond(center, 4.5, gold, false)
		_diamond(center, 1.4, gold.darkened(0.15), true)
		var near: Vector2 = center + Vector2(side * 7.0, 0)
		var far: Vector2 = near + Vector2(side * minf(100.0, room - 7.0), 0)
		var transparent := Color(gold, 0.0)
		draw_polygon(PackedVector2Array([near - Vector2(0, 0.65), far - Vector2(0, 0.65), far + Vector2(0, 0.65), near + Vector2(0, 0.65)]), PackedColorArray([gold, transparent, transparent, gold]))
	var progress: Rect2 = _text_rect($Progress)
	if $Progress.text.is_empty(): return
	for side: float in [-1.0, 1.0]:
		_diamond(progress.get_center() + Vector2(side * (progress.size.x * 0.5 + 17.0), 1.0), 3.3, gold, true)

## 使用当前实际字号与译文测量，装饰不依赖固定的四个中文字。
func _text_rect(label: Label) -> Rect2:
	var font: Font = label.get_theme_font("font")
	var width: float = minf(label.size.x, font.get_string_size(label.tr(label.text), HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x)
	return Rect2(Vector2(label.position.x + (label.size.x - width) * 0.5, label.position.y), Vector2(width, label.size.y))

## 空心与实心菱形共用同一轮廓，保持小尺寸下的细金属线条。
func _diamond(center: Vector2, radius: float, color: Color, filled: bool) -> void:
	var points := PackedVector2Array([center + Vector2.UP * radius, center + Vector2.RIGHT * radius, center + Vector2.DOWN * radius, center + Vector2.LEFT * radius])
	if filled: draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		draw_polyline(points, color, 1.0, true)
