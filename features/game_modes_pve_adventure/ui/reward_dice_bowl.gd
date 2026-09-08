extends Node3D
## 不可见的宽浅承托面和封闭边界；轻微高差只限制散滚，不把骰子聚到固定点。

const FLOOR_Y: float = -5.0
const RISE: float = 0.4
const CEILING: float = FLOOR_Y + 3.8
const CENTER_RATIO: float = 0.15
var outer_half: Vector2

## 重建同一轮的承托面；旧碰撞先离树，避免重投首帧重叠。
func configure(half_size: Vector2) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	outer_half = half_size
	var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var inner := PackedVector3Array()
	var outer := PackedVector3Array()
	for corner: Vector2 in corners:
		var point: Vector2 = corner * outer_half
		inner.append(Vector3(point.x * CENTER_RATIO, FLOOR_Y, point.y * CENTER_RATIO))
		outer.append(Vector3(point.x, FLOOR_Y + RISE, point.y))
	var surface := PackedVector3Array()
	# 四块平整缓坡无台阶相接，避免细碎曲面让硬骰面跨缝持续摇晃。
	for index: int in range(4):
		var next: int = (index + 1) % 4
		surface.append_array(PackedVector3Array([inner[index], outer[index], outer[next], inner[index], outer[next], inner[next]]))
	# Godot 正面采用顺时针绕序，中央承托面的碰撞法线必须朝上。
	surface.append_array(PackedVector3Array([inner[0], inner[1], inner[2], inner[0], inner[2], inner[3]]))
	_add_surface(surface)
	var wall_y: float = (FLOOR_Y + CEILING) * 0.5
	var wall_height: float = CEILING - FLOOR_Y + 0.2
	_add_boundary("LeftWall", Vector3(-outer_half.x - 0.15, wall_y, 0), Vector3(0.3, wall_height, outer_half.y * 2 + 0.6))
	_add_boundary("RightWall", Vector3(outer_half.x + 0.15, wall_y, 0), Vector3(0.3, wall_height, outer_half.y * 2 + 0.6))
	_add_boundary("BackWall", Vector3(0, wall_y, -outer_half.y - 0.15), Vector3(outer_half.x * 2 + 0.6, wall_height, 0.3))
	_add_boundary("FrontWall", Vector3(0, wall_y, outer_half.y + 0.15), Vector3(outer_half.x * 2 + 0.6, wall_height, 0.3))
	# 上方挡面仅约束异常弹跳；正常投掷的能量不足以触及此面。
	_add_boundary("Ceiling", Vector3(0, CEILING + 0.15, 0), Vector3(outer_half.x * 2 + 0.6, 0.3, outer_half.y * 2 + 0.6))

## 中央最低为 -5，四块缓坡升至 -4.6；角落不叠加额外高度。
func height_at(point: Vector2) -> float:
	var ratio: Vector2 = (point.abs() / outer_half).clamp(Vector2.ZERO, Vector2.ONE)
	return FLOOR_Y + RISE * maxf(0.0, (maxf(ratio.x, ratio.y) - CENTER_RATIO) / (1.0 - CENTER_RATIO))

## 视口必须完整容纳碰撞体积，包括弹跳和侧面翻转。
func bounds() -> AABB:
	return AABB(Vector3(-outer_half.x - 0.1, FLOOR_Y - 0.1, -outer_half.y - 0.1), Vector3(outer_half.x * 2 + 0.2, CEILING - FLOOR_Y + 0.2, outer_half.y * 2 + 0.2))

## 整个承托面使用相同摩擦，只创建静态碰撞而不生成可见盘面。
func _add_surface(points: PackedVector3Array) -> void:
	var body := StaticBody3D.new()
	body.name = "Surface"
	body.collision_layer = 1
	body.collision_mask = 2
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 0.42
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(points)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

## 厚实封闭的挡面吸收碰撞能量，不通过改位置或反转速度限制越界。
func _add_boundary(node_name: String, center: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 2
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 0.12
	body.physics_material_override.absorbent = true
	body.physics_material_override.bounce = 0.15
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
