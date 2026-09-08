class_name ProjectileMotion
extends RefCounted
## 六类弹道与命中形态只消费回放进度，颜色和轨迹不参与战斗判定。

const T = preload("res://features/mechanics/contracts/combat_types.gd")

## 各类轨迹保持独立轮廓；相同进度始终得到相同位置。
static func point(output: int, start: Vector2, finish: Vector2, progress: float) -> Vector2:
	var p = clampf(progress, 0, 1)
	var delta = finish - start
	var side = delta.normalized().orthogonal()
	var arc = sin(p * PI)
	var reach = minf(delta.length() * 0.2, 50.0)
	match output:
		T.Output.Witchcraft: return start.lerp(finish, p) + side * sin(p * TAU) * arc * 13
		T.Output.Burn: return start.lerp(finish, p) + Vector2(0, -reach * arc)
		T.Output.Poison: return start.lerp(finish, p * p) + Vector2(0, reach * arc)
		T.Output.Healing: return start.lerp(finish, p) + side * arc * reach * 0.65
		T.Output.Shield: return start.lerp(finish, 1.0 - pow(1.0 - p, 2))
	return start.lerp(finish, p)

## 弹体、拖尾和旋转按输出类型分配，不用换色复用一种飞行效果。
static func draw_flight(layer: Control, texture: Texture2D, output: int, start: Vector2, finish: Vector2, progress: float, size: Vector2, color: Color) -> void:
	var center = point(output, start, finish, progress)
	var angle = (finish - start).angle()
	match output:
		T.Output.Physical:
			layer.draw_line(point(output, start, finish, maxf(0, progress - 0.18)), center, Color(color, 0.65), 3, true)
		T.Output.Witchcraft: angle += progress * TAU
		T.Output.Burn:
			for index in range(3):
				layer.draw_circle(point(output, start, finish, maxf(0, progress - index * 0.055)), 4.0 - index, Color(color, 0.5))
		T.Output.Poison:
			for index in range(1, 4):
				layer.draw_circle(point(output, start, finish, maxf(0, progress - index * 0.08)) + Vector2(0, index * 2), 3.5 - index * 0.5, Color(color, 0.7))
		T.Output.Healing:
			var ribbon = PackedVector2Array()
			for index in range(9): ribbon.append(point(output, start, finish, maxf(0, progress - 0.32 + index * 0.04)))
			layer.draw_polyline(ribbon, Color(color, 0.45), 7, true)
			layer.draw_polyline(ribbon, Color("b8f7cc"), 2, true)
		T.Output.Shield:
			angle = 0
			for sign_value in [-1, 1]:
				var offset = Vector2(0, sign_value * 20 * (1.0 - progress))
				layer.draw_texture_rect(texture, Rect2(center + offset - size * 0.3, size * 0.6), false, Color(1, 1, 1, 0.6))
	layer.draw_set_transform(center, angle)
	layer.draw_texture_rect(texture, Rect2(-size / 2, size), false)
	layer.draw_set_transform(Vector2.ZERO)

## 每跳伤害不再发射弹道；首次施加和自疗自盾也有可辨认的局部反馈。
static func draw_impact(layer: Control, output: int, center: Vector2, progress: float, color: Color) -> void:
	color.a = 1.0 - progress
	var radius = 10 + progress * 22
	match output:
		T.Output.Physical:
			layer.draw_line(center + Vector2(-radius, radius * 0.6), center + Vector2(radius, -radius * 0.6), color, 4, true)
		T.Output.Witchcraft:
			layer.draw_polyline(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0), center + Vector2(0, -radius)]), color, 2, true)
		T.Output.Burn:
			for index in range(3): layer.draw_line(center + Vector2(index * 8 - 8, 8), center + Vector2(index * 8 - 8, -radius), color, 3, true)
		T.Output.Poison:
			for index in range(4): layer.draw_circle(center + Vector2.from_angle(index * PI * 0.5) * radius * 0.55, 4 * (1.0 - progress), color)
		T.Output.Healing:
			center.y -= progress * 15
			layer.draw_line(center + Vector2(-8, 0), center + Vector2(8, 0), color, 4, true)
			layer.draw_line(center + Vector2(0, -8), center + Vector2(0, 8), color, 4, true)
		T.Output.Shield:
			layer.draw_arc(center, radius, PI * 0.1, PI * 0.9, 16, color, 3, true)
