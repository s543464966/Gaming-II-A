@tool
extends "res://ui/components/touch_button.gd"
## 图标按钮只用明度表达悬停、按下和焦点，不绘制背景或改变布局。

## 保留原生按钮输入与信号；明度不依赖每帧轮询或额外计时器。
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	button_down.connect(_refresh_tint)
	button_up.connect(_refresh_tint)
	_refresh_tint()

## 原生绘制状态覆盖鼠标、触屏、键盘、禁用和可见性变化。
func _notification(what: int) -> void:
	if what in [NOTIFICATION_DRAW, NOTIFICATION_THEME_CHANGED, NOTIFICATION_VISIBILITY_CHANGED,
		NOTIFICATION_MOUSE_ENTER, NOTIFICATION_MOUSE_EXIT, NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT]:
		if is_node_ready(): _refresh_tint()

## 隐藏或禁用时恢复常态，缓存页面重开不残留按下反馈。
func _refresh_tint() -> void:
	var state: String = "normal"
	if is_visible_in_tree() and not disabled:
		match get_draw_mode():
			DRAW_PRESSED, DRAW_HOVER_PRESSED: state = "pressed"
			DRAW_HOVER: state = "hover"
		if state == "normal" and has_focus(): state = "hover"
	modulate = get_theme_color(state + "_tint")
