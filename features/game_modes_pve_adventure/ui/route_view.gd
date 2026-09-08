class_name AdventureRouteView
extends Control
## 路线只投射真实拓扑和临时焦点，不提交进度或推断合法入口。

signal focused(index: int)
const UI = preload("res://ui/components/ui.gd")
const C = preload("res://game_content/runtime/content_types.gd")
const NODE = preload("res://features/game_modes_pve_adventure/ui/route_node.tscn")
const EDGE_FADE = preload("res://features/game_modes_pve_adventure/ui/route_edge_fade.gdshader")
const TITLES = {C.NodeType.Start: "ui.route.start", C.NodeType.NormalBattle: "ui.route.battle", C.NodeType.EliteBattle: "ui.route.elite", C.NodeType.BossBattle: "ui.route.boss", C.NodeType.Relic: "ui.route.relic", C.NodeType.BlackMarket: "ui.route.market", C.NodeType.Adventure: "ui.route.encounter"}
const LAYER_HEIGHT: float = 224.0
const PROGRESS_ANCHOR_RATIO: float = 0.65
var nodes: Array = []
var candidates: Array = []
var selected: int = -1
var current: int = -1
var _buttons: Dictionary = {}
var _scroll: ScrollContainer
var _edge_queued: bool = false

## 每张路线独立持有渐隐材质，节点子项继承它，不生成整张长地图的离屏贴图。
func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = EDGE_FADE
	set_notify_transform(true)

## 宿主注入真实滚动视口，所有节点与连接线共用同一透明边界。
func bind_viewport(scroll: ScrollContainer) -> void:
	_scroll = scroll
	_scroll.resized.connect(_queue_edge)
	_queue_edge()

## 滚动和安全区重排后按屏幕位置同步渐隐与命中，不依赖每帧轮询。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED: _queue_edge()

## 合并原生容器的连续布局通知，等最终视口位置确定后再更新边界。
func _queue_edge() -> void:
	if _scroll == null or _edge_queued or not is_inside_tree(): return
	_edge_queued = true
	_refresh_edge.call_deferred()

## 顶部四十八设计像素渐隐；最浅的十六像素不接受节点点击。
func _refresh_edge() -> void:
	_edge_queued = false
	if not is_inside_tree() or not is_instance_valid(_scroll): return
	var top: float = _scroll.get_global_rect().position.y
	var height: float = maxf(1.0, get_viewport_rect().size.y)
	material.set_shader_parameter("top_edge", Vector2(top, top + 48.0) / height)
	for button: Control in _buttons.values(): button.set_pointer_top(top + 16.0)

## 保留空槽和稳定索引，全部有效节点都能查看，未知节点只绑定问号。
func configure(route: RefCounted, _catalog: RefCounted) -> void:
	UI.clear(self)
	selected = -1
	current = route.current
	_buttons.clear()
	nodes = route.nodes.duplicate(true)
	candidates = route.candidates()
	custom_minimum_size.y = 0 if nodes.is_empty() else (nodes.back().layer + 1) * LAYER_HEIGHT + 32
	for node: Variant in nodes:
		if node == null: continue
		var button: Button = NODE.instantiate()
		var known: bool = node.unlocked or node.completed or node.index in candidates
		button.configure(node.type if known else -1, TITLES[node.type] if known else "ui.route.unknown", node.completed, node.index in candidates, node.index == current)
		button.pressed.connect(select_node.bind(node.index))
		_buttons[node.index] = button
		add_child(button)
	if not resized.is_connected(_layout): resized.connect(_layout)
	_layout()
	_queue_edge()

## 临时选择只改变反馈并打开锚定浮层，不定位路线。
func select_node(index: int) -> void:
	if index >= 0 and not _buttons.has(index): return
	selected = index
	for id: int in _buttons: _buttons[id].set_inspected(id == selected)
	focused.emit(index)

## 提供真实控件作为浮层和定位锚点，宿主不复制坐标公式。
func node_control(index: int) -> Control:
	return _buttons.get(index)

## 首节点前定位起点，其余阶段定位当前推进锚点，并为上方候选保留主要空间。
func position_progress_anchor() -> void:
	if not is_instance_valid(_scroll): return
	var anchor: Control = node_control(maxi(0, current))
	if not is_instance_valid(anchor): return
	var bar: VScrollBar = _scroll.get_v_scroll_bar()
	var limit: float = maxf(0.0, bar.max_value - bar.page)
	var center_y: float = anchor.position.y + anchor.art_rect().get_center().y
	_scroll.scroll_vertical = roundi(clampf(center_y - _scroll.size.y * PROGRESS_ANCHOR_RATIO, 0.0, limit))

## 按下时清理临时预览，事件继续传给滚动容器以建立原生拖动。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		select_node(-1)

## 保持三槽顺序，少量确定性偏移只改变构图，不改层级和连接。
func _center(node: Dictionary) -> Vector2:
	var offsets := PackedFloat32Array([-7, 5, -3, 8, -4, 2])
	var x: float = size.x * (node.lane + 0.5) / 3.0
	var shift: float = offsets[(node.layer + node.lane * 2) % offsets.size()]
	return Vector2(x + shift, 76 + (nodes.back().layer - node.layer) * LAYER_HEIGHT + shift * 0.5)

## 点击范围大于图案，窗口变化只重排横向布局。
func _layout() -> void:
	for index: int in _buttons:
		var button: Button = _buttons[index]
		button.size = Vector2(minf(156, size.x / 3.0 - 20), button.custom_minimum_size.y)
		button.position = _center(nodes[index]) - button.art_rect().get_center()
	queue_redraw()

## 真实边从牌面轮廓出发；已揭示节点从侧面接入，避开下方标题和位置标记。
func _edge_points(source: Dictionary, target: Dictionary) -> PackedVector2Array:
	var from: Button = _buttons[source.index]
	var to: Button = _buttons[target.index]
	var from_center: Vector2 = from.position + from.art_rect().get_center()
	var to_center: Vector2 = to.position + to.art_rect().get_center()
	var caption: Rect2 = to.caption_rect()
	var points := PackedVector2Array()
	if caption.has_area():
		var side: float = (-1.0 if target.lane == 2 else 1.0) if source.lane == target.lane else signf(from_center.x - to_center.x)
		var end: Vector2 = to.position + to.connection_port(Vector2(side, .12))
		var corridor_x: float = to.position.x + (caption.end.x + 14 if side > 0 else caption.position.x - 14)
		var guide := Vector2(corridor_x, to.position.y + caption.end.y + 12)
		var direction := Vector2(clampf((guide.x - from_center.x) * .3, -32, 32), -96)
		var start: Vector2 = from.position + from.connection_port(direction)
		var rise: float = maxf(12, (start.y - guide.y) * .45)
		_append_curve(points, start, start - Vector2(0, rise), guide + Vector2(0, rise), guide)
		_append_curve(points, guide, Vector2(corridor_x, end.y + 24), end + Vector2(side * 30, 0), end)
	else:
		var direction: Vector2 = to_center - from_center
		var start: Vector2 = from.position + from.connection_port(direction)
		var end: Vector2 = to.position + to.connection_port(-direction)
		var rise: float = (start.y - end.y) * .42
		_append_curve(points, start, start - Vector2(0, rise), end + Vector2(0, rise), end)
	return points

## 相邻曲线共享唯一端点，拼接处切线同向，虚线弧长连续。
func _append_curve(points: PackedVector2Array, start: Vector2, first: Vector2, second: Vector2, end: Vector2) -> void:
	for step in range(0 if points.is_empty() else 1, 25):
		points.append(start.bezier_interpolate(first, second, end, step / 24.0))

## 在曲线上按弧长切分虚线，避免等参数间隔变成忽密忽疏的链条。
func _draw_dashed(points: PackedVector2Array, color: Color, width: float, dash: float, gap: float) -> void:
	var distance: float = 0.0
	for index in range(1, points.size()):
		var start: Vector2 = points[index - 1]
		var length: float = start.distance_to(points[index])
		var walked: float = 0.0
		while walked < length:
			var phase: float = fmod(distance + walked, dash + gap)
			var amount: float = minf(length - walked, (dash if phase < dash else dash + gap) - phase)
			if amount < 0.001: amount = minf(0.001, length - walked)
			if phase < dash:
				draw_line(start.lerp(points[index], walked / length), start.lerp(points[index], (walked + amount) / length), color, width, true)
			walked += amount
		distance += length

## 实线、可选金线和未到达虚线来自进度，不按视觉距离猜测。
func _draw() -> void:
	for node: Variant in nodes:
		if node == null: continue
		for index: int in node.next:
			var destination: Dictionary = nodes[index]
			var points: PackedVector2Array = _edge_points(node, destination)
			var chosen: bool = node.index == current and index in candidates
			var walked: bool = node.completed and destination.completed
			var color: Color = get_theme_color("path_ready" if chosen else "path_walked" if walked else "path_idle", "RouteView")
			if chosen or walked:
				draw_polyline(points, get_theme_color("path_shadow", "RouteView"), 3.2, true)
				draw_polyline(points, color, 1.7 if chosen else 1.2, true)
				draw_circle(points[0], 1.8 if chosen else 1.2, color)
				draw_circle(points[-1], 1.8 if chosen else 1.2, color)
			else:
				_draw_dashed(points, color, 1.15, 3.5, 8)
