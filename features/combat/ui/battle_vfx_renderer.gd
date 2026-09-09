class_name BattleVfxRenderer
extends RefCounted
## 绘制战斗状态、被动连接与飘字，普通命中原画由棋盘采样独立图集。

const T = preload("res://features/mechanics/contracts/combat_types.gd")


## 战场常驻微光保持暗色石面有呼吸感，密度固定避免同屏单位增加开销。
static func draw_ambient(layer: Control, rect: Rect2, time: float) -> void:
	if not rect.has_area(): return
	for index in range(7):
		var phase := fmod(time * (0.10 + index * 0.007) + index * 0.173, 1.0)
		var x := rect.position.x + rect.size.x * fmod(index * 0.379 + sin(time * 0.17 + index) * 0.035 + 1.0, 1.0)
		var y := rect.end.y - rect.size.y * phase
		var pulse := 0.45 + sin(time * 2.1 + index * 1.7) * 0.25
		var color := Color("d9a457") if index % 2 == 0 else Color("7569b8")
		color.a = 0.045 * pulse
		layer.draw_circle(Vector2(x, y), 2.0 + index % 3, color)


## 被动与联动使用短暂能量脉络，亮点沿曲线移动而不遮挡卡面主体。
static func draw_link(layer: Control, start: Vector2, finish: Vector2, progress: float, output: int) -> void:
	var p := clampf(progress, 0.0, 1.0)
	var fade := sin(p * PI)
	var delta := finish - start
	var control := start.lerp(finish, 0.5) + delta.normalized().orthogonal() * minf(delta.length() * 0.13, 28.0)
	var points := PackedVector2Array()
	for index in range(17):
		var t := float(index) / 16.0
		points.append(start * pow(1.0 - t, 2.0) + control * 2.0 * (1.0 - t) * t + finish * t * t)
	var accent := _accent(output)
	layer.draw_polyline(points, Color(accent, 0.18 * fade), 7.0, true)
	layer.draw_polyline(points, Color(_core(accent), 0.78 * fade), 1.5, true)
	var spark_index := mini(16, floori(ease(p, -1.6) * 16.0))
	layer.draw_circle(points[spark_index], 5.0 * fade, Color(_core(accent), 0.86 * fade))


## 状态循环只读取当前状态帧和回放时钟，暂停时保持原位置。
static func draw_statuses(layer: Control, rect: Rect2, statuses: Array, time: float, sequences: Dictionary) -> void:
	if statuses.is_empty() or not rect.has_area(): return
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.48
	for raw_status in statuses:
		match int(raw_status):
			T.Status.Burn:
				_draw_status_sequence(layer, sequences.get(T.Output.Burn), rect, time, false)
			T.Status.Poison:
				_draw_status_sequence(layer, sequences.get(T.Output.Poison), rect, time, true)
			T.Status.Freeze:
				var ice := Color("aeeaff", 0.58)
				for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
					var inward: Vector2 = (center - corner).normalized()
					var normal := inward.orthogonal()
					layer.draw_colored_polygon(PackedVector2Array([corner, corner + inward * radius * 0.52 + normal * 4.0, corner + inward * radius * 0.24 - normal * 6.0]), Color("75cce7", 0.22))
					layer.draw_line(corner, corner + inward * radius * 0.52, ice, 1.5, true)
					layer.draw_line(corner + inward * radius * 0.16 - normal * 7.0, corner + inward * radius * 0.26 + normal * 6.0, ice, 1.0, true)
			T.Status.Slow:
				layer.draw_arc(center, radius * (0.78 + sin(time * 2.0) * 0.04), time * 0.35, time * 0.35 + PI * 1.45, 28, Color("7ad5dd", 0.35), 2.0, true)
			T.Status.Stun:
				for index in range(3):
					var direction := Vector2.from_angle(time * 2.6 + index * TAU / 3.0)
					var point := center + Vector2(direction.x * radius * 0.64, -radius * 0.74 + direction.y * 5.0)
					layer.draw_colored_polygon(PackedVector2Array([point + Vector2(0, -5), point + Vector2(2, -1), point + Vector2(5, 0), point + Vector2(1, 2), point + Vector2(0, 5), point + Vector2(-2, 1), point + Vector2(-5, 0), point + Vector2(-1, -2)]), Color("ffe57a", 0.82))

## 中毒播放独立的正面附着循环；燃烧仍沿用原有卡角余韵，不重放命中爆发。
static func _draw_status_sequence(layer: Control, frames: SpriteFrames, rect: Rect2, time: float, poison: bool) -> void:
	if frames == null: return
	var animation: StringName = &"status" if poison else &"impact"
	if not frames.has_animation(animation): return
	var frame_index := int(time * frames.get_animation_speed(animation)) % frames.get_frame_count(animation) if poison else 8 + int(time * 10.0) % 4
	var texture := frames.get_frame_texture(animation, frame_index)
	var extent := minf(rect.size.x, rect.size.y) * (0.96 if poison else 0.56)
	var anchor := rect.get_center() if poison else Vector2(rect.position.x + extent * 0.40, rect.end.y - extent * 0.48)
	layer.draw_texture_rect(texture, Rect2(anchor - Vector2.ONE * extent * 0.5, Vector2.ONE * extent), false, Color(1, 1, 1, 0.72))


## 伤害数字使用阴影、亮芯与上浮缩放，避免直接贴在复杂插画上失去层级。
static func draw_feedback(layer: Control, font: Font, center: Vector2, text: String, color: Color, progress: float, critical: bool) -> void:
	var p := clampf(progress, 0.0, 1.0)
	var alpha := 1.0 - smoothstep(0.62, 1.0, p)
	var font_size := 34 if critical else 25
	var rise := ease(p, -1.6) * (58.0 if critical else 44.0)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var point := center + Vector2(-width * 0.5, 5.0 - rise)
	var shadow := Color(0.04, 0.025, 0.02, 0.92 * alpha)
	for offset in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		layer.draw_string(font, point + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow)
	layer.draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color.lerp(Color("fff4d8"), 0.65), alpha))
	if critical:
		layer.draw_line(point + Vector2(0, 7), point + Vector2(width, 7), Color("fff1b0", 0.62 * alpha), 2.0, true)


## 语义配色增加饱和度和亮度，保持与卡面输出徽章同源但不显灰。
static func _accent(output: int) -> Color:
	var color := DesignTokens.output_color(output)
	if color.a <= 0.0: color = Color("d9b86c")
	return Color.from_hsv(color.h, minf(1.0, color.s * 1.2 + 0.12), minf(1.0, color.v * 1.18 + 0.08), 1.0)


## 光芯向暖白收敛，确保不同颜色在暗背景上都有共同打击峰值。
static func _core(color: Color) -> Color:
	return color.lerp(Color("fff6d2"), 0.72)
