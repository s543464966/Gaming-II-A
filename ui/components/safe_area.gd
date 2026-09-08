extends MarginContainer
## 仅内容避让安全区，背景仍铺满屏幕；窗口缩放后按当前逻辑视口重新计算。

var _platform: Node

## 绑定当前应用的平台服务；独立编辑器预览没有依赖时使用零边距。
func configure(platform: Node) -> void:
	if _platform != null and _platform.safe_area_changed.is_connected(_refresh):
		_platform.safe_area_changed.disconnect(_refresh)
	_platform = platform
	if _platform != null: _platform.safe_area_changed.connect(_refresh)
	if is_inside_tree(): _refresh()

## 监听逻辑视口变化，不查找全局节点。
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_refresh)
	_refresh()

## 将归一化边距转换为当前逻辑像素，背景无需缩入安全区。
func _refresh() -> void:
	if not is_inside_tree(): return
	var insets: Vector4 = _platform.safe_insets if _platform != null else Vector4.ZERO
	var viewport_size = get_viewport().get_visible_rect().size
	add_theme_constant_override("margin_left", ceili(insets.x * viewport_size.x))
	add_theme_constant_override("margin_top", ceili(insets.y * viewport_size.y))
	add_theme_constant_override("margin_right", ceili(insets.z * viewport_size.x))
	add_theme_constant_override("margin_bottom", ceili(insets.w * viewport_size.y))

## 模态移出场景时立即解绑，不能等排队销毁后才停止接收窗口事件。
func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(_refresh): get_viewport().size_changed.disconnect(_refresh)
	if is_instance_valid(_platform) and _platform.safe_area_changed.is_connected(_refresh): _platform.safe_area_changed.disconnect(_refresh)
