extends "res://ui/components/touch_button.gd"
## 节点图案按轮廓取样；文字、揭示、焦点与进度标记独立绘制。

const ATLAS = preload("res://features/game_modes_pve_adventure/ui/art/route_nodes.png")
const TYPES: Dictionary = {0: 0, 1: 1, 2: 2, 3: 3, 5: 4, 6: 5, 7: 6, -1: 7}
## 原图保留不改字节；UV 轮廓位于牌面内，外部棋盘格不进入采样。
const REGIONS: Array[Rect2] = [Rect2(107, 106, 269, 278), Rect2(525, 106, 284, 278), Rect2(956, 103, 305, 311), Rect2(1377, 105, 291, 280), Rect2(97, 501, 286, 275), Rect2(526, 501, 281, 275), Rect2(955, 501, 289, 275), Rect2(1395, 502, 265, 273)]
var _type: int = -1
var _title: String = ""
var _completed: bool = false
var _available: bool = false
var _current: bool = false
var _inspected: bool = false
var _pointer_top: float = -INF

## 宿主提供渐隐区的可点上界；独立节点预览保持完整热区。
func set_pointer_top(value: float) -> void:
	_pointer_top = value

## 半透明边缘仍可起手滚动，但接近消失的节点像素不能触发查看。
func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point) and (get_global_transform() * point).y >= _pointer_top

## 配置只接收已揭示的显示身份，不持有玩家状态或真实隐藏类型。
func configure(type: int, title: String, completed: bool, available: bool, current: bool) -> void:
	_type = type
	_title = title
	_completed = completed
	_available = available
	_current = current
	if is_node_ready(): _refresh_text()

## 原生 Button 继续处理触摸取消、键盘与滚动容器中的拖动。
func _ready() -> void:
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	resized.connect(_refresh_text)
	_refresh_text()

## 语言与主题变化只刷新显示，保留控件、焦点和滚动位置。
func _notification(what: int) -> void:
	if what in [NOTIFICATION_TRANSLATION_CHANGED, NOTIFICATION_THEME_CHANGED] and is_node_ready(): _refresh_text()
	if what in [NOTIFICATION_MOUSE_ENTER, NOTIFICATION_MOUSE_EXIT, NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT]: queue_redraw()

## 未知节点仅显示问号；已完成状态使用独立徽记，不与标题拼接。
func _refresh_text() -> void:
	$Title.text = _title
	$Title.visible = _type >= 0
	$Current.visible = _current
	$Completed.visible = _completed
	$Title.add_theme_color_override("font_color", get_theme_color("caption_muted" if _type >= 0 and not _available and not _completed else "caption", "RouteNode"))
	$Completed.position = art_rect().end - Vector2(9, 7)
	$Completed/Seal.color = get_theme_color("seal", "RouteNode")
	$Completed/Check.default_color = get_theme_color("seal_ink", "RouteNode")
	tooltip_text = tr(_title)
	queue_redraw()

## 查看与可前往分开，查看未知节点不会把它变成可进入状态。
func set_inspected(value: bool) -> void:
	_inspected = value
	queue_redraw()

## 绘制、连线和定位共用牌面尺寸，缩小图案不缩小原生触摸区域。
func art_rect() -> Rect2:
	var extent: float = minf(get_theme_constant("art_extent", "RouteNode"), size.x - 24)
	return Rect2(Vector2((size.x - extent) * .5, get_theme_constant("art_top", "RouteNode")), Vector2.ONE * extent)

## 返回真实牌面多边形，未知身份始终使用同一八边轮廓。
func art_contour() -> PackedVector2Array:
	var rect: Rect2 = art_rect()
	var points := PackedVector2Array()
	for point: Vector2 in _outline(): points.append(rect.position + point * rect.size)
	return points

## 连线从牌面中心沿指定方向求最近边界交点，精英折角也使用实际轮廓。
func connection_port(direction: Vector2) -> Vector2:
	var center: Vector2 = art_rect().get_center()
	var far: Vector2 = center + direction.normalized() * art_rect().size.length() * 2
	var contour: PackedVector2Array = art_contour()
	var result: Vector2 = far
	for index in range(contour.size()):
		var hit: Variant = Geometry2D.segment_intersects_segment(center, far, contour[index], contour[(index + 1) % contour.size()])
		if hit is Vector2 and center.distance_squared_to(hit) < center.distance_squared_to(result): result = hit
	return result

## 路径绕开当前可见文字；未知节点不保留隐藏标题的占位。
func caption_rect() -> Rect2:
	var bounds := Rect2()
	if $Title.visible: bounds = $Title.get_rect()
	if $Current.visible: bounds = bounds.merge($Current.get_rect()) if bounds.has_area() else $Current.get_rect()
	return bounds

## 八边牌面避开源图外底，精英额外保留旗帜底部的折角。
func _outline() -> PackedVector2Array:
	if _type == 2:
		return PackedVector2Array([Vector2(.23, 0), Vector2(.77, 0), Vector2(1, .23), Vector2(1, .65), Vector2(.83, .81), Vector2(.83, .92), Vector2(.65, .85), Vector2(.5, 1), Vector2(.35, .85), Vector2(.17, .92), Vector2(.17, .81), Vector2(0, .65), Vector2(0, .23)])
	return PackedVector2Array([Vector2(.24, 0), Vector2(.76, 0), Vector2(1, .25), Vector2(1, .75), Vector2(.76, 1), Vector2(.24, 1), Vector2(0, .75), Vector2(0, .25)])

## 材质明度服从状态，边框反馈和完成标记在同一原生绘制中完成。
func _draw() -> void:
	var region: Rect2 = REGIONS[TYPES[_type]]
	var polygon: PackedVector2Array = art_contour()
	var uv := PackedVector2Array()
	for point: Vector2 in _outline():
		uv.append((region.position + point * region.size) / ATLAS.get_size())
	var tint: Color = get_theme_color("active" if _available or _current else "completed" if _completed else "unknown" if _type < 0 else "unavailable", "RouteNode")
	if is_pressed(): tint = tint.darkened(.17)
	elif is_hovered() or has_focus(): tint = tint.lightened(.10)
	draw_polygon(polygon, PackedColorArray([tint]), uv, ATLAS)
	var border: Color = get_theme_color("ready", "RouteNode")
	if _available or _current:
		var edge: PackedVector2Array = polygon.duplicate()
		edge.append(edge[0])
		draw_polyline(edge, border, 1.1, true)
	if _type >= 0 and not _available and not _completed and not _current:
		var at: Vector2 = art_rect().end - Vector2(9, 7)
		draw_circle(at, 9, get_theme_color("badge", "RouteNode"))
		draw_arc(at, 9, 0, TAU, 24, get_theme_color("caption_muted", "RouteNode"), 1, true)
		draw_line(at - Vector2(4, 0), at + Vector2(4, 0), get_theme_color("caption_muted", "RouteNode"), 1.5, true)
	if _inspected or has_focus(): _draw_focus()

## 骨白角标只表示查看或键盘焦点，不复用可前往的金边。
func _draw_focus() -> void:
	var rect: Rect2 = art_rect().grow(6)
	var color: Color = get_theme_color("focus", "RouteNode")
	for corner: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
		var at: Vector2 = rect.position + rect.size * corner
		var inward := Vector2(1 - 2 * corner.x, 1 - 2 * corner.y)
		draw_polyline(PackedVector2Array([at + Vector2(0, 10 * inward.y), at, at + Vector2(10 * inward.x, 0)]), color, 1.5, true)
