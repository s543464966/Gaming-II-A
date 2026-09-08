@tool
extends Button
## 保留原生按钮与键盘操作，系统取消指针时撤销按压而不触发点击。

## Godot 4.5 的原生按钮不区分 canceled；在原生松手逻辑前撤销点击候选。
func _gui_input(event: InputEvent) -> void:
	cancel_press(event, self)

## 滚动容器内的原生按钮也可接入同一取消语义，不吞掉父级的释放事件。
static func cancel_press(event: InputEvent, button: BaseButton) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.canceled:
		button.notification(Control.NOTIFICATION_SCROLL_BEGIN)
