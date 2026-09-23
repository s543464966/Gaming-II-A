class_name DonutBoardInput
extends Node
## 识别棋盘上的轻点与单指拖拽，只发送操作意图，不改动玩法状态。

signal tapped(index: int)
signal drag_began(source: int)
signal drag_moved(viewport_position: Vector2)
signal drag_ended(target: int, canceled: bool)

const DRAG_DISTANCE: float = 12.0 # 视口像素；小幅抖动仍视为轻点。
const NO_POINTER: int = -2
const MOUSE_POINTER: int = -1

var _boxes: Array[DonutBox] = []
var _enabled: Callable
var _pointer: int = NO_POINTER
var _source: int = -1
var _origin: Vector2
var _dragging: bool = false


## 由页面显式提供命中区域与交互状态，不查找全局页面或会话。
func initialize(boxes: Array[DonutBox], enabled: Callable) -> void:
	cancel()
	_boxes = boxes
	_enabled = enabled


## 捕获从棋盘开始的主指针，触摸产生的模拟鼠标不再次执行搬运。
func _input(event: InputEvent) -> void:
	if not _enabled.is_valid() or not _enabled.call():
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		if is_active():
			get_viewport().set_input_as_handled()
		return
	if is_active() and (event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag):
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and is_active():
			_release(_pointer, event.position, true)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press(MOUSE_POINTER, event.position)
			else:
				_release(MOUSE_POINTER, event.position, event.canceled)
	elif event is InputEventMouseMotion:
		_motion(MOUSE_POINTER, event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index, event.position, event.canceled)
	elif event is InputEventScreenDrag:
		_motion(event.index, event.position)


## 仅记录首个从可见餐盒区域开始的按下，其他手指不能接管手势。
func _press(pointer: int, point: Vector2) -> void:
	if is_active():
		return
	var index: int = box_at(point)
	if index < 0:
		return
	_pointer = pointer
	_source = index
	_origin = point
	_dragging = false
	get_viewport().set_input_as_handled()


## 超过移动阈值后才开始拖拽，后续位置仍使用同一个指针。
func _motion(pointer: int, point: Vector2) -> void:
	if not is_active() or pointer != _pointer:
		return
	if not _dragging and point.distance_to(_origin) >= DRAG_DISTANCE:
		_dragging = true
		drag_began.emit(_source)
	if _dragging:
		drag_moved.emit(point)


## 抬起时确定目标；先释放指针再通知页面，避免回收动效重入手势。
func _release(pointer: int, point: Vector2, canceled: bool) -> void:
	if not is_active() or pointer != _pointer:
		return
	if not canceled:
		_motion(pointer, point)
	var was_dragging: bool = _dragging
	var source: int = _source
	var target: int = box_at(point)
	cancel()
	if was_dragging:
		drag_ended.emit(target, canceled)
	elif not canceled and target == source:
		tapped.emit(source)


## 根据实际控件变换命中盒位，适应页面缩放与竖屏留边。
func box_at(viewport_position: Vector2) -> int:
	for index: int in _boxes.size():
		var box: DonutBox = _boxes[index]
		if box.is_visible_in_tree():
			var local_point: Vector2 = box.get_global_transform_with_canvas().affine_inverse() * viewport_position
			if Rect2(Vector2.ZERO, box.size).has_point(local_point):
				return index
	return -1


## 供页面在取消、暂停和切关时判断是否有尚未结束的手势。
func is_active() -> bool:
	return _pointer != NO_POINTER


## 清理按下与拖动状态，旧指针随后抬起也不会变成新的点击。
func cancel() -> void:
	_pointer = NO_POINTER
	_source = -1
	_dragging = false
