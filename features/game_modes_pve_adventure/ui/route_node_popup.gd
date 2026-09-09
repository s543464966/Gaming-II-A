extends Control
## 节点锚定浮层：负责定位、入场与输入隔离，不决定节点是否可进入。

signal dismissed

@onready var content: VBoxContainer = $Panel/Scroll/Content
@onready var panel: PanelContainer = $Panel
var _route_scroll: ScrollContainer
var _anchor: Control
var _locked_scroll: int = 0
var _layout_queued: bool = false
var _target_position: Vector2
var _reveal_progress: float = 1.0
var _tween: Tween
## -2 表示没有外部按下，-1 为鼠标，其余值为触点编号。
var _tap_pointer: int = -2
var _tap_start: Vector2
var _tap_dragged: bool = false

## 内容换行和视口变化只重排浮层，不调整路线位置。
func _ready() -> void:
	content.minimum_size_changed.connect(_queue_layout)
	content.child_entered_tree.connect(_center_text)
	resized.connect(_queue_layout)

## 节点标题、说明和状态统一居中，长文仍按浮层宽度自然换行。
func _center_text(node: Node) -> void:
	if node is Label:
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		node.theme_type_variation = &"RoutePopupTitle" if node.get_index() == 0 else &"RoutePopupBody"
		node.remove_theme_font_size_override("font_size")
	elif node is Button:
		node.theme_type_variation = &"DetailDarkActionButton"
		node.compact = true

## 注入唯一底层滚动容器，位置守卫也阻止惯性和键盘带来的残余滚动。
func bind_route(scroll: ScrollContainer) -> void:
	_route_scroll = scroll
	_route_scroll.get_v_scroll_bar().value_changed.connect(_hold_route_position)
	_route_scroll.resized.connect(_queue_layout)

## 固定当前路线位置，从所点节点上方轻微浮出；不移动或居中节点。
func present(anchor: Control) -> void:
	_anchor = anchor
	_locked_scroll = _route_scroll.scroll_vertical
	_tap_pointer = -2
	_reveal_progress = 0.0
	panel.modulate.a = 0.0
	show()
	_queue_layout()
	if _tween != null: _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_reveal, 0.0, 1.0, 0.16)
	_focus_action.call_deferred()

## 先撤去输入屏障，再通知宿主清理临时焦点；不保存玩家状态。
func close() -> void:
	if not visible: return
	if _tween != null: _tween.kill()
	hide()
	_tap_pointer = -2
	if is_instance_valid(_anchor) and _anchor.is_visible_in_tree(): _anchor.grab_focus()
	_anchor = null
	dismissed.emit()

## 浮层存续时固定路线偏移，浮层内部的独立长文滚动不受影响。
func _hold_route_position(value: float) -> void:
	if visible and int(value) != _locked_scroll: _route_scroll.scroll_vertical = _locked_scroll

## 合并尺寸通知，等待原生容器完成文字换行。
func _queue_layout() -> void:
	if not visible or _layout_queued: return
	_layout_queued = true
	_layout_popup.call_deferred()

## 优先上方放置，顶部不足时避让至下方，长内容限制高度并在浮层内滚动。
func _layout_popup() -> void:
	_layout_queued = false
	if not is_inside_tree() or not visible or not is_instance_valid(_anchor): return
	var inverse = get_global_transform().affine_inverse()
	var bounds: Rect2 = (inverse * _route_scroll.get_global_rect()).grow(-12)
	var anchor_rect: Rect2 = inverse * _anchor.get_global_rect()
	var width = minf(get_theme_constant("maximum_width", "RoutePopup"), bounds.size.x)
	# 紧凑按钮在手机缩放后仍保留至少 44 像素的触摸区域。
	var touch_height: float = ceilf(44.0 / maxf(0.01, get_viewport().get_final_transform().get_scale().y))
	for child: Node in content.get_children():
		if child is Button: child.custom_minimum_size.y = maxf(child.tokens.detail_action_height, touch_height)
	var style = panel.get_theme_stylebox("panel")
	var height = minf(content.get_combined_minimum_size().y + style.get_minimum_size().y, minf(get_theme_constant("maximum_height", "RoutePopup"), bounds.size.y))
	panel.size = Vector2(width, height)
	var x = clampf(anchor_rect.get_center().x - panel.size.x / 2, bounds.position.x, bounds.end.x - panel.size.x)
	var y = anchor_rect.position.y - panel.size.y - 16
	var above = y >= bounds.position.y
	if not above: y = anchor_rect.end.y + 16
	y = clampf(y, bounds.position.y, bounds.end.y - panel.size.y)
	_target_position = Vector2(x, y)
	_reveal(_reveal_progress)

## 内容重排时继续同一次浮出动画，不因翻译或换行重新播放。
func _reveal(progress: float) -> void:
	_reveal_progress = progress
	panel.position = _target_position + Vector2(0, (1.0 - progress) * 12)
	panel.modulate.a = progress

## 键盘焦点留在浮层主操作，不能穿透到路线节点触发另一关。
func _focus_action() -> void:
	if not visible: return
	var actions = content.find_children("*", "Button", true, false).filter(func(button): return not button.disabled)
	var target: Control = panel if actions.is_empty() else actions[0]
	for property in ["focus_next", "focus_previous", "focus_neighbor_top", "focus_neighbor_bottom", "focus_neighbor_left", "focus_neighbor_right"]:
		target.set(property, target.get_path())
	target.grab_focus()

## 只有浮层外的完整轻点关闭；滚轮、触控板和拖动均被屏障消费。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_outside_pointer(-1, event.pressed, event.position)
	elif event is InputEventScreenTouch:
		_outside_pointer(event.index, event.pressed, event.position)
	elif event is InputEventMouseMotion and _tap_pointer == -1:
		_tap_dragged = _tap_dragged or event.position.distance_to(_tap_start) > 12
	elif event is InputEventScreenDrag and event.index == _tap_pointer:
		_tap_dragged = _tap_dragged or event.position.distance_to(_tap_start) > 12
	accept_event()

## 区分轻点与滑动，关闭事件不再传给底层节点或设置按钮。
func _outside_pointer(pointer: int, pressed: bool, point: Vector2) -> void:
	if pressed:
		if _tap_pointer != -2: return
		_tap_pointer = pointer
		_tap_start = point
		_tap_dragged = false
	elif _tap_pointer == pointer:
		_tap_pointer = -2
		if not _tap_dragged and point.distance_to(_tap_start) <= 12 and not panel.get_rect().has_point(point): close()

## 场景离开时终止局部动画，不能让排队回调复活浮层。
func _exit_tree() -> void:
	if _tween != null: _tween.kill()
