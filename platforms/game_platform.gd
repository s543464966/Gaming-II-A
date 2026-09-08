class_name GamePlatform
extends Node
## 统一的平台状态边界；宿主绑定由各适配器负责，玩法只消费信号与安全区。

signal suspended_changed(value: bool)
signal safe_area_changed
var suspended: bool = false
var safe_insets: Vector4 = Vector4.ZERO
var _bridge: RefCounted

## 只创建当前真实宿主的适配器；普通桌面无需浏览器桥接。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		if OS.has_feature("android") or OS.has_feature("ios"):
			get_viewport().size_changed.connect(_refresh_native_safe_area)
			_refresh_native_safe_area()
		return
	if OS.has_feature("tt"): _bridge = preload("res://platforms/douyin/douyin_bridge.gd").new()
	elif OS.has_feature("wechat"): _bridge = preload("res://platforms/wechat/wechat_bridge.gd").new()
	if _bridge != null and _bridge.bind(self): return
	_bridge = preload("res://platforms/web/web_bridge.gd").new()
	_bridge.bind(self)

## 重复隐藏事件只提交一次状态变化。
func set_suspended(value: bool) -> void:
	if suspended == value: return
	suspended = value
	suspended_changed.emit(value)

## 适配器提交宿主信息，统一在此完成几何校验与发布。
func update_safe_area(flavor_text: Dictionary) -> void:
	var insets = normalized_insets(flavor_text)
	if insets == safe_insets: return
	safe_insets = insets
	safe_area_changed.emit()

## 原生前后台通知不依赖浏览器或小游戏 SDK。
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED: set_suspended(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED: set_suspended(false)

## 原生移动平台使用系统安全矩形，不把桌面任务栏当成手机刘海。
func _refresh_native_safe_area() -> void:
	var screen = DisplayServer.screen_get_size()
	var safe = DisplayServer.get_display_safe_area()
	var window = get_window()
	update_safe_area({"screenWidth": screen.x, "screenHeight": screen.y,
		"windowWidth": window.size.x, "windowHeight": window.size.y,
		"screenLeft": window.position.x, "screenTop": window.position.y,
		"safeArea": {"left": safe.position.x, "top": safe.position.y, "right": safe.end.x, "bottom": safe.end.y}})

## 安全区先与实际窗口求交，避免宿主已缩小画布时二次避让；胶囊坐标以窗口为基准。
static func normalized_insets(flavor_text: Dictionary) -> Vector4:
	var width = _number(flavor_text.get("screenWidth"), 0)
	var height = _number(flavor_text.get("screenHeight"), 0)
	var safe: Variant = flavor_text.get("safeArea", {})
	if not is_finite(width) or not is_finite(height) or width <= 0 or height <= 0 or not safe is Dictionary: return Vector4.ZERO
	var left = _number(safe.get("left"), 0)
	var top = _number(safe.get("top"), 0)
	var right = _number(safe.get("right"), width)
	var bottom = _number(safe.get("bottom"), height)
	if not is_finite(left) or not is_finite(top) or not is_finite(right) or not is_finite(bottom): return Vector4.ZERO
	if left < 0 or top < 0 or right > width or bottom > height or right <= left or bottom <= top: return Vector4.ZERO
	var window_width = _number(flavor_text.get("windowWidth"), width)
	var window_height = _number(flavor_text.get("windowHeight"), height)
	var origin = Vector2(_number(flavor_text.get("screenLeft"), 0), _number(flavor_text.get("screenTop"), 0))
	if window_width <= 0 or window_height <= 0: return Vector4.ZERO
	var bounds = Rect2(origin, Vector2(window_width, window_height))
	var safe_rect = Rect2(Vector2(left, top), Vector2(right - left, bottom - top)).intersection(bounds)
	if not safe_rect.has_area(): return Vector4.ZERO
	left = safe_rect.position.x - origin.x
	top = safe_rect.position.y - origin.y
	right = safe_rect.end.x - origin.x
	bottom = safe_rect.end.y - origin.y
	var menu: Variant = flavor_text.get("menuButton", {})
	if menu is Dictionary:
		var menu_left = _number(menu.get("left"), -1)
		var menu_top = _number(menu.get("top"), -1)
		var menu_right = _number(menu.get("right"), -1)
		var menu_bottom = _number(menu.get("bottom"), -1)
		if menu_left >= 0 and menu_right > menu_left and menu_right <= window_width and menu_top >= 0 and menu_bottom > menu_top and menu_bottom + 8 < bottom:
			top = maxf(top, menu_bottom + 8)
	return Vector4(left / window_width, top / window_height, (window_width - right) / window_width, (window_height - bottom) / window_height)

## 字符串、空值和非有限数值不能进入几何运算。
static func _number(value: Variant, fallback: float) -> float:
	return float(value) if (value is int or value is float) and is_finite(value) else fallback


## 释放应用前解除外部回调，不留下指向已销毁节点的宿主引用。
func _exit_tree() -> void:
	if _bridge != null: _bridge.unbind()
	_bridge = null
