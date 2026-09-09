class_name ProjectileMotion
extends RefCounted
## 弹道只采样只读飞行进度，绘制连续拖尾和已登记的逐帧弹体。

const T = preload("res://features/mechanics/contracts/combat_types.gd")

## 可见飞行段留出短促起手，六类弹体均在统一命中窗口内到达。
static func flight_duration(output: int) -> float:
	match output:
		T.Output.Physical: return 0.18
		T.Output.Witchcraft: return 0.22
		T.Output.Burn: return 0.23
		T.Output.Poison: return 0.24
		T.Output.Healing: return 0.23
		T.Output.Shield: return 0.20
	return 0.22

## 路径只受已确定的起终点和进度影响；中毒沿卡面侧向弯曲，没有屏幕固定重力。
static func point(output: int, start: Vector2, finish: Vector2, progress: float) -> Vector2:
	var p := clampf(progress, 0.0, 1.0)
	var delta := finish - start
	var side := delta.normalized().orthogonal()
	var arc := sin(p * PI)
	var reach := minf(delta.length() * 0.16, 42.0)
	match output:
		T.Output.Witchcraft: return start.lerp(finish, p) + side * arc * reach * 0.45
		T.Output.Burn: return start.lerp(finish, p) + Vector2(0, -reach * arc)
		T.Output.Poison: return start.lerp(finish, smoothstep(0.0, 1.0, p)) + side * arc * reach * 0.22
		T.Output.Healing: return start.lerp(finish, p) + side * arc * reach * 0.7
		T.Output.Shield: return start.lerp(finish, 1.0 - pow(1.0 - p, 1.5))
	return start.lerp(finish, p)

## 原画尖端由资源定义，拖尾沿历史路径收尖，保证替换弹体仍准确接触目标。
static func draw_flight(layer: Control, output: int, start: Vector2, finish: Vector2, progress: float, size: Vector2, color: Color, texture: Texture2D, tip_ratio: float = 0.67) -> void:
	if start.is_equal_approx(finish) or texture == null: return
	var p := clampf(progress, 0.0, 1.0)
	var center := point(output, start, finish, p)
	var tangent := (point(output, start, finish, minf(1.0, p + 0.015)) - point(output, start, finish, maxf(0.0, p - 0.015))).normalized()
	var core := color.lerp(Color("fff7df"), 0.78)
	var reach := minf(0.52, 110.0 / maxf(start.distance_to(finish), 1.0))
	var width := 3.5 if output == T.Output.Physical else 4.5 if output == T.Output.Poison else 11.0
	var tail := PackedVector2Array()
	for index in range(25):
		var t := lerpf(maxf(0.0, p - reach), p, float(index) / 24.0)
		tail.append(point(output, start, finish, t))
	_draw_ribbon(layer, tail, width * 1.65, Color(color, 0.10))
	_draw_ribbon(layer, tail, width * 0.62, Color(color, 0.55))
	_draw_ribbon(layer, tail, width * 0.16, Color(core, 0.78))
	layer.draw_set_transform(center, tangent.angle())
	layer.draw_texture_rect(texture, Rect2(Vector2(-size.x * tip_ratio, -size.y * 0.5), size), false)
	layer.draw_set_transform(Vector2.ZERO)

## 逐段四边形使用顶点透明度渐变，尾端收窄且没有硬切圆点。
static func _draw_ribbon(layer: Control, points: PackedVector2Array, width: float, color: Color) -> void:
	for index in range(1, points.size()):
		var from := points[index - 1]
		var to := points[index]
		if from.distance_squared_to(to) < 0.04: continue
		var normal := (to - from).normalized().orthogonal()
		var a := float(index - 1) / float(points.size() - 1)
		var b := float(index) / float(points.size() - 1)
		var before := normal * width * a * 0.5
		var after := normal * width * b * 0.5
		var c0 := Color(color, color.a * a * a)
		var c1 := Color(color, color.a * b * b)
		# 带状片始终是凸形，直接绘制基本图元，避免极细尖端的通用三角化误差。
		if index == 1:
			layer.draw_primitive(PackedVector2Array([from, to - after, to + after]), PackedColorArray([c0, c1, c1]), PackedVector2Array())
		else:
			layer.draw_primitive(PackedVector2Array([from - before, to - after, to + after, from + before]), PackedColorArray([c0, c1, c1, c0]), PackedVector2Array())
