extends RefCounted
## 创建带类别纹章、独立金额文字与金属棱框的凸多面体；不参与奖励抽取。

const Surface = preload("res://features/game_modes_pve_adventure/ui/reward_die_surface.gdshader")
const AmountLabel = preload("res://features/game_modes_pve_adventure/ui/reward_die_amount.tscn")
const C = preload("res://game_content/runtime/content_types.gd")
## 骰盘生命周期内最多保留四类模板；网格和碰撞共享，金额与刚体各自独立。
var _templates: Dictionary = {}
var _atlas: Texture2D

## 四类骰子共享无字图集；金额是实例文字，碰撞仍取原始几何顶点。
func create(kind: int, atlas: Texture2D, amount: int = 0) -> RigidBody3D:
	if _atlas != atlas:
		_templates.clear()
		_atlas = atlas
	if _templates.has(kind):
		var instance: RigidBody3D = _templates[kind].instantiate()
		set_amount(instance, amount)
		return instance
	var faces: Array = _faces(kind)
	var body := RigidBody3D.new()
	body.set_meta("face_count", faces.size())
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var points := PackedVector3Array()
	var edges: Array = []
	var tile := Vector2(kind % 2, kind / 2) * 0.5
	var amounts: Node3D
	if kind == C.DiceKind.StarStone:
		amounts = Node3D.new()
		amounts.name = "Amounts"
		body.add_child(amounts)
	for face in faces:
		var center := Vector3.ZERO
		for point in face:
			center += point
			if not point in points: points.append(point)
		center /= face.size()
		var normal: Vector3 = (face[1] - face[0]).cross(face[2] - face[0]).normalized()
		if normal.dot(center) < 0: normal = -normal
		var up: Vector3 = Vector3.FORWARD if absf(normal.y) > 0.9 else Vector3.UP
		# 三角面以一个真实顶点为顶角，保证图案和数字始终完整落在面内。
		if face.size() == 3: up = (face[0] - center).normalized()
		up = (up - normal * up.dot(normal)).normalized()
		var right: Vector3 = up.cross(normal).normalized()
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for point in face:
			var local := Vector2(point.dot(right), point.dot(up))
			low = low.min(local)
			high = high.max(local)
		if kind == C.DiceKind.StarStone:
			_add_amount(amounts, center, Basis(right, up, normal), high - low)
		for index in range(1, face.size() - 1):
			for point in [face[0], face[index], face[index + 1]]:
				vertices.append(point)
				normals.append(normal)
				var local := (Vector2(point.dot(right), point.dot(up)) - low) / (high - low)
				uvs.append(Vector2(local.x, 1.0 - local.y))
		for index in range(face.size()):
			var pair: Array = [face[index], face[(index + 1) % face.size()]]
			if not edges.any(func(edge): return edge == pair or edge == [pair[1], pair[0]]): edges.append(pair)
	var material := ShaderMaterial.new()
	material.shader = Surface
	material.set_shader_parameter("surface_atlas", atlas)
	material.set_shader_parameter("tile_origin", tile)
	material.set_shader_parameter("surface_metallic", 0.12 if kind == C.DiceKind.Card else 0.3)
	_add_mesh(body, vertices, normals, uvs, material)
	_add_rim(body, edges)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collision.shape = shape
	body.add_child(collision)
	body.mass = 1.0
	body.collision_layer = 2
	body.collision_mask = 3
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 12
	body.gravity_scale = 1.8
	body.linear_damp = 0.12
	body.angular_damp = 0.35
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.bounce = 0.16
	body.physics_material_override.friction = 0.62
	for child: Node in body.find_children("*", "", true, false): child.owner = body
	var template := PackedScene.new()
	if template.pack(body) == OK: _templates[kind] = template
	set_amount(body, amount)
	return body

## 只更新本骰已确定的金额；长数字自动适配，不修改网格、刚体或共享贴图。
static func set_amount(body: RigidBody3D, amount: int) -> void:
	var amounts: Node3D = body.get_node_or_null("Amounts")
	if amounts == null: return
	for label: Label3D in amounts.get_children():
		var base: Font = GameUI.THEME.get_font("font", "Label")
		if not label.font is FontVariation or label.font.base_font != base:
			var emphasized := FontVariation.new()
			emphasized.base_font = base
			emphasized.variation_embolden = 0.65
			label.font = emphasized
		label.text = str(amount) if amount > 0 else ""
		label.visible = amount > 0
		var width: float = label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x + label.outline_size * 2
		label.pixel_size = minf(label.get_meta("base_pixel_size"), label.get_meta("face_width") / maxf(width, 1.0))

## 金额文字与真实骰面共面；场景提供配色和字号，字库绑定当前共享字体。
static func _add_amount(parent: Node3D, center: Vector3, axes: Basis, extent: Vector2) -> void:
	var label: Label3D = AmountLabel.instantiate()
	label.name = "Face%d" % parent.get_child_count()
	label.transform = Transform3D(axes, center + axes.y * (extent.y * 0.035) + axes.z * 0.022)
	label.set_meta("base_pixel_size", label.pixel_size)
	label.set_meta("face_width", extent.x * 0.52)
	parent.add_child(label)

## 返回多面体各面；顶点围成真正的四面体、八面体或六面体。
static func _faces(kind: int) -> Array:
	if kind == C.DiceKind.StarStone:
		var a := Vector3(0, 1.225, 0)
		var b := Vector3(0, -0.408, 1.155)
		var c := Vector3(1, -0.408, -0.577)
		var d := Vector3(-1, -0.408, -0.577)
		return [[a, b, c], [a, c, d], [a, d, b], [b, d, c]]
	if kind == C.DiceKind.Treasure:
		var result: Array = []
		var ring: Array[Vector3] = [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]
		for index in range(4):
			result.append([Vector3.UP * 1.05, ring[index] * 1.05, ring[(index + 1) % 4] * 1.05])
			result.append([Vector3.DOWN * 1.05, ring[(index + 1) % 4] * 1.05, ring[index] * 1.05])
		return result
	var faces: Array = []
	for normal in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var up: Vector3 = Vector3.FORWARD if absf(normal.y) > 0.9 else Vector3.UP
		var right: Vector3 = up.cross(normal)
		faces.append([(normal - right + up) * 0.72, (normal + right + up) * 0.72,
			(normal + right - up) * 0.72, (normal - right - up) * 0.72])
	return faces

## 所有金属棱合并为一个网格，避免每条边产生独立绘制节点。
static func _add_rim(body: Node3D, edges: Array) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for edge in edges:
		var direction: Vector3 = (edge[1] - edge[0]).normalized()
		var right: Vector3 = direction.cross(Vector3.UP if absf(direction.y) < 0.9 else Vector3.RIGHT).normalized()
		var up: Vector3 = direction.cross(right)
		for index in range(8):
			var n1: Vector3 = right * cos(index * TAU / 8) + up * sin(index * TAU / 8)
			var n2: Vector3 = right * cos((index + 1) * TAU / 8) + up * sin((index + 1) * TAU / 8)
			var a: Vector3 = edge[0] + n1 * 0.032
			var b: Vector3 = edge[1] + n1 * 0.032
			var c: Vector3 = edge[1] + n2 * 0.032
			var d: Vector3 = edge[0] + n2 * 0.032
			vertices.append_array(PackedVector3Array([a, b, c, a, c, d]))
			normals.append_array(PackedVector3Array([n1, n1, n2, n1, n2, n2]))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("bd9450")
	material.metallic = 0.65
	material.roughness = 0.38
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(body, vertices, normals, PackedVector2Array(), material)

## 单次提交三角形与法线，图集纹理保持共享。
static func _add_mesh(body: Node3D, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, material: Material) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	if not uvs.is_empty(): arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	body.add_child(view)
