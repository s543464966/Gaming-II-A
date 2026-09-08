extends Control
## 奖励骰子的独立三维表现与拖放；只发送使用请求，不抽奖或保存玩家状态。

signal die_requested(id: int)
const UI = preload("res://ui/components/ui.gd")
const DieMesh = preload("res://features/game_modes_pve_adventure/ui/reward_die_mesh.gd")
const DiceBowl = preload("res://features/game_modes_pve_adventure/ui/reward_dice_bowl.gd")
const Shadow = preload("res://features/game_modes_pve_adventure/ui/art/reward_dice_shadow.tres")
const LAUNCH_INTERVAL: float = 0.16
const REST_SECONDS: float = 0.5
const REST_LINEAR_SPEED: float = 0.08
const REST_ANGULAR_SPEED: float = 0.12
## 仅用上方七成容纳滚动范围，底部留给铭牌和领取区。
const VIEW_REGION := Rect2(0.04, 0.035, 0.92, 0.66)
var _entries: Array[Dictionary] = []
var _roll_revision: int = -1
var _elapsed: float = 0.0
var _dragged: int = -1
var _pointer: int = -2
var _hovering: bool = false
var _absorb: Tween
var _consuming: bool = false
var _random := RandomNumberGenerator.new()
var _mesh_factory := DieMesh.new()
var _warm_body: RigidBody3D
var _warm_kinds: Array = []
var _warm_atlas: Texture2D
@onready var _viewport: SubViewport = $View/SubViewport
@onready var _world: Node3D = $View/SubViewport/World
@onready var _camera: Camera3D = $View/SubViewport/World/Camera3D
@onready var _bowl: DiceBowl = $View/SubViewport/World/Bowl
@onready var _labels: Control = $Labels

## 初始化纯表现随机源与局部视口，不依赖会话。
func _ready() -> void:
	_random.randomize()
	resized.connect(_resize_view)
	visibility_changed.connect(_visibility_changed)
	_viewport.size_changed.connect(_resize_view)
	_labels.draw.connect(_draw_labels)
	_resize_view()
	_visibility_changed()
	set_process(false)

## 章节入口逐类离屏绘制真实骰面和金额，提前准备网格、字体与着色器。
func prepare_visuals(atlas: Texture2D) -> void:
	if not _entries.is_empty(): return
	_warm_kinds = ContentTypes.DiceKind.values()
	_warm_atlas = atlas
	set_process(true)

## 每帧只准备一类，离场随节点停止，不保留跨场景的异步等待。
func _process(_delta: float) -> void:
	_clear_warm_body()
	if _warm_kinds.is_empty():
		_stop_warmup()
		_visibility_changed()
		return
	_warm_body = _mesh_factory.create(_warm_kinds.pop_front(), _warm_atlas, 888)
	_warm_body.freeze = true
	_warm_body.collision_layer = 0
	_warm_body.collision_mask = 0
	_world.add_child(_warm_body)
	_warm_body.position = _camera.position - _camera.basis.z * 24.0
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

## 真实奖励绑定会取消剩余预热，资源模板仍由本骰盘继续复用。
func _stop_warmup() -> void:
	set_process(false)
	_warm_kinds.clear()
	_warm_atlas = null
	_clear_warm_body()

## 正式投掷或预热结束立即移除样例，不让预热骰进入玩家画面或碰撞。
func _clear_warm_body() -> void:
	if not is_instance_valid(_warm_body): return
	_world.remove_child(_warm_body)
	_warm_body.queue_free()
	_warm_body = null

## 真实投掷代次改变才重建；领取只移除已用骰，保留剩余骰的位置与朝向。
func configure(dice: Array, roll_revision: int, atlas: Texture2D) -> void:
	_stop_warmup()
	var replay: bool = _roll_revision != roll_revision
	_roll_revision = roll_revision
	_cancel_drag()
	for index: int in range(_entries.size() - 1, -1, -1):
		var entry: Dictionary = _entries[index]
		var matching: Array = dice.filter(func(die): return die.id == entry.id and die.kind == entry.kind)
		if not replay and not matching.is_empty():
			entry.title = matching[0].title
			entry.paid = matching[0].get("paid", false)
			entry.amount = matching[0].get("amount", 0)
			DieMesh.set_amount(entry.body, entry.amount)
			continue
		_world.remove_child(entry.body)
		entry.body.queue_free()
		_entries.remove_at(index)
	if replay: _elapsed = 0.0
	for index in range(dice.size()):
		var die: Dictionary = dice[index]
		if _entries.any(func(entry): return entry.id == die.id): continue
		var body: RigidBody3D = _mesh_factory.create(die.kind, atlas, die.get("amount", 0))
		body.freeze = true
		body.visible = false
		body.collision_layer = 0
		body.collision_mask = 0
		_world.add_child(body)
		body.rotation = Vector3(_random.randf() * TAU, _random.randf() * TAU, _random.randf() * TAU)
		var points: PackedVector3Array = body.get_node("CollisionShape3D").shape.points
		var radius: float = 0.0
		for point: Vector3 in points: radius = maxf(radius, point.length() + 0.04)
		_entries.append({"id": die.id, "kind": die.kind, "body": body, "home": Transform3D.IDENTITY, "title": die.title,
			"settled": false, "launched": false, "quiet": 0.0, "points": points, "radius": radius,
			"paid": die.get("paid", false), "amount": die.get("amount", 0)})
	_resize_view()
	_visibility_changed()
	_redraw()

## 只施加入场速度并观察静止；滚动全程由重力、缓坡和碰撞推进。
func _physics_process(delta: float) -> void:
	if not is_visible_in_tree() or _bowl.outer_half == Vector2.ZERO or _dragged >= 0: return
	_elapsed += delta
	for index in range(_entries.size()):
		var entry: Dictionary = _entries[index]
		var body: RigidBody3D = entry.body
		if not entry.launched:
			if _elapsed >= index * LAUNCH_INTERVAL: _launch(entry, index)
			continue
		var quiet: bool = body.sleeping or (body.get_contact_count() > 0
			and body.linear_velocity.length() < REST_LINEAR_SPEED and body.angular_velocity.length() < REST_ANGULAR_SPEED)
		entry.quiet = entry.quiet + delta if quiet else 0.0
		entry.settled = entry.quiet >= REST_SECONDS
		if entry.settled: entry.home = body.transform
	_redraw()

## 从边缘横向投出而不瞄准中心；检查出生间距，避免重叠造成爆炸式弹开。
func _launch(entry: Dictionary, index: int) -> void:
	var body: RigidBody3D = entry.body
	var side: float = -1.0 if index % 2 == 0 else 1.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body.get_node("CollisionShape3D").shape
	query.collision_mask = 2
	query.margin = 0.08
	for attempt: int in range(8):
		var spawn_half: Vector2 = _bowl.outer_half - Vector2.ONE * (entry.radius + 0.1)
		var position := Vector3(side * spawn_half.x, DiceBowl.FLOOR_Y, _random.randf_range(-spawn_half.y, spawn_half.y))
		var direction := Vector3(-side, 0, _random.randf_range(-0.18, 0.18)).normalized()
		# 两侧被累积骰占据时，使用前后方的真实空隙，不让待投骰永久等待。
		if attempt >= 4:
			var end: float = -1.0 if attempt % 2 == 0 else 1.0
			position = Vector3(_random.randf_range(-spawn_half.x, spawn_half.x), DiceBowl.FLOOR_Y, end * spawn_half.y)
			direction = Vector3(_random.randf_range(-0.18, 0.18), 0, -end).normalized()
		for vertex: Vector3 in entry.points:
			var point: Vector3 = body.basis * vertex
			position.y = maxf(position.y, _bowl.height_at(Vector2(position.x + point.x, position.z + point.z)) - point.y)
		position.y += 0.22
		query.transform = Transform3D(body.basis, position)
		if not body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): continue
		body.position = position
		body.visible = true
		body.collision_layer = 2
		body.collision_mask = 3
		body.freeze = false
		body.sleeping = false
		body.linear_velocity = direction * _random.randf_range(6.2, 8.0) + Vector3.DOWN * 0.8
		body.angular_velocity = Vector3.UP.cross(direction) * _random.randf_range(8, 11) + Vector3(_random.randf_range(-3, 3), _random.randf_range(-5, 5), _random.randf_range(-3, 3))
		entry.launched = true
		return

## 屏幕投影同时用于显示与命中，避免视口缩放后的输入偏移。
func die_position(id: int) -> Vector2:
	for entry in _entries:
		if entry.id == id and entry.launched: return _project(entry.body.position)
	return Vector2(-1000, -1000)

## 没有骰子时也不存在待完成动画，全部领取后仍可继续冒险。
func is_settled() -> bool:
	return _entries.all(func(entry): return entry.settled)

## 拖拽状态供页脚阻止另一根手指同时重投或离开。
func is_dragging() -> bool:
	return _dragged >= 0

## 接收区中心直接取稳定场景布局，四角框和实际命中共享同一矩形。
func drop_position() -> Vector2:
	return $DropZone.get_rect().get_center()

## 四角框内部全部可用；指针仅经过时只高亮，松手才消费。
func _in_drop(point: Vector2) -> bool:
	return $DropZone.get_rect().has_point(point)

## 单指持有一次拖拽；系统取消与正常松手分开，第二根手指不能抢占。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.canceled:
			if _pointer == event.index: _cancel_drag()
		elif event.pressed: _begin_drag(event.position, event.index)
		elif _pointer == event.index: _end_drag(event.position)
	elif event is InputEventScreenDrag and _pointer == event.index:
		_move_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.canceled:
			if _pointer == -1: _cancel_drag()
		elif event.pressed: _begin_drag(event.position, -1)
		elif _pointer == -1: _end_drag(event.position)
	elif event is InputEventMouseMotion and _pointer == -1:
		_move_drag(event.position)
	accept_event()

## 停稳后按实际投影轮廓拿取，视觉重叠时先命中前方骰子。
func _begin_drag(point: Vector2, pointer: int) -> void:
	if _dragged >= 0 or _consuming or not is_settled(): return
	var picked: int = _pick_die(point)
	if picked < 0: return
	_dragged = picked
	var entry: Dictionary = _entries[_dragged]
	entry.home = entry.body.transform
	# 拿取期间暂停已停稳的整组骰子，避免支撑关系变化后取消拖拽造成相互穿插。
	for other: Dictionary in _entries: other.body.freeze = true
	entry.body.collision_layer = 0
	entry.body.collision_mask = 0
	_pointer = pointer
	_move_drag(point)

## 命中覆盖可用骰子的凸骰面及十二像素容差，不把中心小圆当作整个骰面。
func _pick_die(point: Vector2) -> int:
	var picked: int = -1
	var nearest: float = INF
	var nearest_depth: float = INF
	for index: int in range(_entries.size()):
		var entry: Dictionary = _entries[index]
		if entry.paid: continue
		var projected := PackedVector2Array()
		for vertex: Vector3 in entry.points: projected.append(_project(entry.body.transform * vertex))
		var outline: PackedVector2Array = Geometry2D.convex_hull(projected)
		var distance: float = 0.0 if Geometry2D.is_point_in_polygon(point, outline) else INF
		for edge: int in range(outline.size() - 1):
			distance = minf(distance, point.distance_to(Geometry2D.get_closest_point_to_segment(point, outline[edge], outline[edge + 1])))
		var depth: float = -_camera.to_local(entry.body.global_position).z
		if distance > 12.0 or distance > nearest: continue
		if is_equal_approx(distance, nearest) and depth >= nearest_depth: continue
		picked = index
		nearest = distance
		nearest_depth = depth
	return picked

## 拖拽锁定姿态并抬离桌面，射线与固定高度平面求交。
func _move_drag(point: Vector2) -> void:
	if _dragged < 0: return
	var screen: Vector2 = point * Vector2(_viewport.size) / size
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var direction: Vector3 = _camera.project_ray_normal(screen)
	_entries[_dragged].body.position = origin + direction * ((DiceBowl.FLOOR_Y + 1.4 - origin.y) / direction.y)
	_hovering = _in_drop(point)
	_redraw()

## 松手先恢复局部状态，再把一次请求交由页面事务处理。
func _end_drag(point: Vector2) -> void:
	if _dragged < 0: return
	var id: int = _entries[_dragged].id
	var use: bool = _in_drop(point)
	if not use:
		_cancel_drag()
		return
	_consuming = true
	_pointer = -2
	var body: RigidBody3D = _entries[_dragged].body
	_absorb = create_tween()
	_absorb.tween_property(body, "scale", Vector3.ONE * 0.03, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_absorb.tween_callback(func():
		_absorb = null
		_cancel_drag()
		die_requested.emit(id))

## 离开、失焦或取消恢复原位，不触发奖励。
func _cancel_drag() -> void:
	if _absorb != null:
		_absorb.kill()
		_absorb = null
	_consuming = false
	if _dragged >= 0 and _dragged < _entries.size():
		var entry: Dictionary = _entries[_dragged]
		entry.body.transform = entry.home
		entry.body.collision_layer = 2
		entry.body.collision_mask = 3
		for other: Dictionary in _entries:
			other.body.freeze = false
			other.body.sleeping = true
	_dragged = -1
	_pointer = -2
	_hovering = false
	_redraw()

## 暂停或失焦立即归还骰子，恢复后不等待已丢失的松手事件。
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED]: _cancel_drag()
	elif what == NOTIFICATION_TRANSLATION_CHANGED: _redraw()

## 隐藏后停止三维渲染和物理，避免奖励选择期间继续占用。
func _visibility_changed() -> void:
	if not is_node_ready(): return
	_cancel_drag()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	_world.process_mode = Node.PROCESS_MODE_INHERIT if is_visible_in_tree() else Node.PROCESS_MODE_DISABLED

## 按整个封闭空间取景；窗口缩放只改变相机，不移动正在滚动的骰子。
func _resize_view() -> void:
	if not is_node_ready() or _entries.is_empty() or size.x <= 0 or size.y <= 0: return
	var inverse: Basis = _camera.basis.inverse()
	var aspect: float = size.x / size.y
	if _entries.all(func(entry): return not entry.launched):
		# 先让承托范围铺满宽度，再由实际宽高比求纵深，避免相机为深盘缩小全场。
		var half_width: float = maxf(6.0, sqrt(_entries.size() * 6.0))
		var view_width: float = (half_width * 2 + 0.2) / VIEW_REGION.size.x
		var vertical: float = view_width / aspect * VIEW_REGION.size.y
		var air_projection: float = absf((inverse * Vector3.UP).y) * (DiceBowl.CEILING - DiceBowl.FLOOR_Y + 0.2)
		var depth_projection: float = absf((inverse * Vector3.BACK).y)
		var half_depth: float = maxf(1.5, (vertical - air_projection) / (2 * depth_projection) - 0.1)
		_bowl.configure(Vector2(half_width, half_depth))
	var bounds: AABB = _bowl.bounds()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for index: int in range(8):
		var point: Vector3 = inverse * bounds.get_endpoint(index)
		low = low.min(Vector2(point.x, point.y))
		high = high.max(Vector2(point.x, point.y))
	_camera.size = maxf((high.x - low.x) / VIEW_REGION.size.x, (high.y - low.y) * aspect / VIEW_REGION.size.y)
	var center: Vector2 = (low + high) * 0.5
	center.y += (VIEW_REGION.get_center().y - 0.5) * _camera.size / aspect
	_camera.position = _camera.basis * Vector3(center.x, center.y, 24)
	_redraw()

## 投影使用当前局部视口，同一坐标供命中与标签排布使用。
func _project(point: Vector3) -> Vector2:
	return _camera.unproject_position(point) * size / Vector2(_viewport.size)

## 阴影位于骰子后方，铭牌位于前方，两层同步重绘。
func _redraw() -> void:
	queue_redraw()
	if is_instance_valid(_labels): _labels.queue_redraw()
	if not is_node_ready(): return
	$DropZone.visible = _entries.any(func(entry): return not entry.paid)
	$DropZone/Hint.visible = not is_dragging()
	$DropZone/Active.visible = is_dragging()
	$DropZone/Active.modulate = Color(1.25, 1.18, 1.05) if _hovering else Color(1, 1, 1, 0.8)
	$DropZone/Caption.modulate = Color(1.15, 1.12, 1.04) if _hovering else Color(1, 1, 1, 0.86)

## 骰盘只绘制骰子阴影；拖入反馈由四个独立折角提亮，不覆盖矩形底色。
func _draw() -> void:
	if not is_node_ready(): return
	_draw_shadows()

## 阴影始终投在隐藏承托面上，弹起时扩散变淡，贴地时收紧。
func _draw_shadows() -> void:
	for entry: Dictionary in _entries:
		if not entry.launched: continue
		var body: RigidBody3D = entry.body
		var ground := Vector3(body.position.x, _bowl.height_at(Vector2(body.position.x, body.position.z)), body.position.z)
		var clearance: float = INF
		var footprint: float = 0.0
		for vertex: Vector3 in entry.points:
			var offset: Vector3 = body.basis * vertex
			var point: Vector3 = body.position + offset
			clearance = minf(clearance, point.y - _bowl.height_at(Vector2(point.x, point.z)))
			footprint = maxf(footprint, Vector2(offset.x, offset.z).length())
		clearance = clampf(clearance, 0, 3)
		var radius: float = footprint * (1.0 + clearance * 0.2)
		ground += Vector3(0.18, 0, 0.12) * clearance
		var center: Vector2 = _project(ground)
		var axis_x: Vector2 = (_project(ground + Vector3.RIGHT) - center) * radius
		var axis_y: Vector2 = (_project(ground + Vector3.BACK) - center) * radius
		draw_set_transform_matrix(Transform2D(axis_x, axis_y, center))
		draw_texture_rect(Shadow, Rect2(-1, -1, 2, 2), false, Color(1, 1, 1, 1.0 / (1.0 + clearance * 0.8)))
		draw_set_transform_matrix(Transform2D.IDENTITY)

## 根据自然落点就近安排铭牌；优先避开骰子、已有文字和领取区。
func _draw_labels() -> void:
	if not is_settled(): return
	var font: Font = get_theme_font("font", "Label")
	var occupied: Array[Rect2] = [$DropZone.get_rect().grow(8)]
	var silhouettes: Array[Rect2] = []
	for entry: Dictionary in _entries:
		var rect := Rect2(die_position(entry.id), Vector2.ZERO)
		for vertex: Vector3 in entry.points: rect = rect.expand(_project(entry.body.transform * vertex))
		silhouettes.append(rect.grow(5))
	occupied.append_array(silhouettes)
	var gold: Color = UI.tokens.detail_gold_color
	var plate := StyleBoxFlat.new()
	plate.bg_color = gold.darkened(0.12)
	plate.border_color = UI.tokens.detail_caption_color
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(3)
	for index: int in range(_entries.size()):
		var entry: Dictionary = _entries[index]
		if index == _dragged: continue
		var title: String = entry.title.call()
		var amount_text: String = "+%d ✓" % entry.amount if entry.paid else ""
		var amount_size: int = 16
		var title_width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var amount_width: float = font.get_string_size(amount_text, HORIZONTAL_ALIGNMENT_LEFT, -1, amount_size).x
		var text_width: float = minf(ceilf(maxf(title_width, amount_width)), size.x * 0.4)
		# 铭牌同时容纳名称和实得金额；极长金额只缩小字号，不截去末位。
		while amount_width > text_width and amount_size > 1:
			amount_size -= 1
			amount_width = font.get_string_size(amount_text, HORIZONTAL_ALIGNMENT_LEFT, -1, amount_size).x
		var label_size := Vector2(text_width + 16, 47 if entry.paid else 26)
		var rect: Rect2 = _label_rect(silhouettes[index], label_size, occupied)
		occupied.append(rect.grow(3))
		var point: Vector2 = die_position(entry.id)
		var connection: Vector2 = point.clamp(rect.position, rect.end)
		var start: Vector2 = connection.clamp(silhouettes[index].position, silhouettes[index].end)
		_labels.draw_line(start, connection, Color(gold, 0.38), 1, true)
		_labels.draw_style_box(plate, rect)
		_labels.draw_string(font, rect.position + Vector2(8, 19), title, HORIZONTAL_ALIGNMENT_LEFT, text_width, 18, Color("111719"))
		if entry.paid:
			_labels.draw_string(font, rect.position + Vector2(8, 39), amount_text, HORIZONTAL_ALIGNMENT_LEFT, text_width, amount_size, Color("111719"))

## 候选位置从贴近骰子向外扩散，保持随机落点下的铭牌可辨认。
func _label_rect(die: Rect2, dimensions: Vector2, occupied: Array[Rect2]) -> Rect2:
	var best := Rect2(die.get_center() + Vector2(-dimensions.x * 0.5, die.size.y * 0.5 + 5), dimensions)
	var best_score: float = INF
	for distance: int in range(6):
		for direction: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
			var center: Vector2 = die.get_center() + direction * (die.size + dimensions) * 0.5 + direction * (5 + distance * 18)
			var rect := Rect2((center - dimensions * 0.5).clamp(Vector2(4, 4), size - dimensions - Vector2(4, 4)), dimensions)
			var score: float = rect.get_center().distance_to(die.get_center())
			for other: Rect2 in occupied:
				if rect.intersects(other): score += 10000 + rect.intersection(other).get_area()
			if score < best_score:
				best = rect
				best_score = score
	return best
