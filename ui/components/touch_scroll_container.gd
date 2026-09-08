class_name TouchScrollContainer
extends ScrollContainer
## 统一移动端滚动：让可点击后代把触摸拖动交给最近的滚动容器。

const PRESERVE_FILTER_META: StringName = &"preserve_touch_scroll_filter"
const TouchButton = preload("res://ui/components/touch_button.gd")

@export_range(0, 64, 1) var touch_drag_deadzone: int = 12
@export var forward_descendant_input: bool = true

var _original_filters: Dictionary[int, int] = {}
var _tracked_controls: Dictionary[int, WeakRef] = {}


## 入树后监听动态内容，并使用统一拖动阈值区分轻点和滑动。
func _enter_tree() -> void:
	scroll_deadzone = touch_drag_deadzone
	if not get_tree().node_added.is_connected(_on_node_added): get_tree().node_added.connect(_on_node_added)
	if not get_tree().node_removed.is_connected(_on_node_removed): get_tree().node_removed.connect(_on_node_removed)
	_refresh_descendants.call_deferred()


## 离树时解除全局监听并恢复被组件接管的控件配置。
func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added): get_tree().node_added.disconnect(_on_node_added)
	if get_tree().node_removed.is_connected(_on_node_removed): get_tree().node_removed.disconnect(_on_node_removed)
	_restore_descendants()


## 允许固定布局页签关闭触摸转发，不建立另一套滚动控件。
func set_touch_scrolling_enabled(enabled: bool) -> void:
	forward_descendant_input = enabled
	if enabled:
		_refresh_descendants()
	else:
		_restore_descendants()


## 新增动态卡片时立即接管最近滚动容器内的输入传播。
func _on_node_added(node: Node) -> void:
	if not forward_descendant_input or node == self or not is_ancestor_of(node): return
	if _has_nested_scroll_parent(node) or _has_preserved_filter(node): return
	_adopt_branch(node)


## 动态条目离开本容器时恢复其原始过滤模式，避免影响复用位置。
func _on_node_removed(node: Node) -> void:
	_restore_control(node.get_instance_id())


## 扫描已有稳定场景内容；嵌套滚动区域由其自身组件管理。
func _refresh_descendants() -> void:
	if not is_inside_tree() or not forward_descendant_input: return
	for child: Node in get_children(): _adopt_branch(child)


## 将阻断输入的后代改为向父级传播，同时保留显式隔离子树。
func _adopt_branch(node: Node) -> void:
	if node is ScrollContainer: return
	if _has_preserved_filter(node): return
	if node is Control: _adopt_control(node)
	for child: Node in node.get_children(): _adopt_branch(child)


## 只改 STOP 的传播方式；按钮另接取消保护，显式 PASS 或 IGNORE 保持原值。
func _adopt_control(control: Control) -> void:
	if control.mouse_filter != Control.MOUSE_FILTER_STOP and not control is BaseButton: return
	var id: int = control.get_instance_id()
	if _original_filters.has(id): return
	_original_filters[id] = int(control.mouse_filter)
	_tracked_controls[id] = weakref(control)
	if control.mouse_filter == Control.MOUSE_FILTER_STOP: control.mouse_filter = Control.MOUSE_FILTER_PASS
	if control is BaseButton: control.gui_input.connect(TouchButton.cancel_press.bind(control))


## 最近祖先已有滚动容器时不越权修改其内容。
func _has_nested_scroll_parent(node: Node) -> bool:
	var parent: Node = node.get_parent()
	while parent != null and parent != self:
		if parent is ScrollContainer: return true
		parent = parent.get_parent()
	return parent != self


## 元数据可为需要独占手势的控件或整棵子树保留原始过滤模式。
func _has_preserved_filter(node: Node) -> bool:
	var current: Node = node
	while current != null and current != self:
		if bool(current.get_meta(PRESERVE_FILTER_META, false)): return true
		current = current.get_parent()
	return false


## 恢复仍存活且仍由本组件控制的单个后代。
func _restore_control(id: int) -> void:
	if not _original_filters.has(id): return
	var reference: WeakRef = _tracked_controls.get(id)
	var control: Control = reference.get_ref() if reference != null else null
	if is_instance_valid(control) and control.mouse_filter == Control.MOUSE_FILTER_PASS:
		control.mouse_filter = _original_filters[id]
	if is_instance_valid(control) and control is BaseButton:
		var cancel: Callable = TouchButton.cancel_press.bind(control)
		if control.gui_input.is_connected(cancel): control.gui_input.disconnect(cancel)
	_original_filters.erase(id)
	_tracked_controls.erase(id)


## 批量恢复后清空追踪，不让缓存页面或重入树累积旧引用。
func _restore_descendants() -> void:
	for id: int in _original_filters.keys(): _restore_control(id)
