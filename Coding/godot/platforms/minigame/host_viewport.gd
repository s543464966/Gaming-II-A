extends RefCounted
## 读取小游戏宿主窗口与安全区，将逻辑像素映射为 Godot 页面可用区域。

## 原生桌面沿用完整视口，只有 Web 宿主读取小游戏 API。
static func read_metrics() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var bridge: JavaScriptObject = JavaScriptBridge.get_interface("__donutHostViewport")
	if bridge == null:
		return {}
	var encoded: Variant = bridge.read()
	if not encoded is String:
		return {}
	var decoded: Variant = JSON.parse_string(encoded)
	return decoded if decoded is Dictionary else {}


## 只换算系统安全区，不把局部胶囊扩大为整页禁区；无有效数据时保留完整页面。
static func content_rect(viewport_size: Vector2, metrics: Dictionary) -> Rect2:
	var bounds := Rect2(Vector2.ZERO, viewport_size)
	var width: float = float(metrics.get("width", 0))
	var height: float = float(metrics.get("height", 0))
	if not is_finite(width) or not is_finite(height) or width <= 0 or height <= 0:
		return bounds
	var safe: Dictionary = metrics.get("safeArea", {})
	var left: float = clampf(float(safe.get("left", 0)), 0, width)
	var top: float = clampf(float(safe.get("top", metrics.get("statusBarHeight", 0))), 0, height)
	var right: float = clampf(float(safe.get("right", width)), left, width)
	var bottom: float = clampf(float(safe.get("bottom", height)), top, height)
	if right <= left or bottom <= top:
		return bounds
	var units: Vector2 = viewport_size / Vector2(width, height)
	return Rect2(Vector2(left, top) * units, Vector2(right - left, bottom - top) * units)


## 独立报告胶囊矩形；旧宿主缺少横坐标时按右侧位置保守回退，由页面决定避让。
static func menu_rect(viewport_size: Vector2, metrics: Dictionary) -> Rect2:
	var width: float = float(metrics.get("width", 0))
	var height: float = float(metrics.get("height", 0))
	var menu: Dictionary = metrics.get("menu", {})
	var menu_width: float = float(menu.get("width", 0))
	var menu_height: float = float(menu.get("height", 0))
	if not is_finite(width) or not is_finite(height) or width <= 0 or height <= 0 \
		or not is_finite(menu_width) or not is_finite(menu_height) or menu_width <= 0 or menu_height <= 0:
		return Rect2()
	var left: float = float(menu.get("left", float(menu.get("right", width)) - menu_width))
	var top: float = float(menu.get("top", float(menu.get("bottom", 0)) - menu_height))
	if not is_finite(left) or not is_finite(top):
		return Rect2()
	var units: Vector2 = viewport_size / Vector2(width, height)
	return Rect2(Vector2(left, top) * units, Vector2(menu_width, menu_height) * units).intersection(Rect2(Vector2.ZERO, viewport_size))
