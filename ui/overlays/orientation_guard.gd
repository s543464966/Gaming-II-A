extends ColorRect
## 横屏时的设备状态遮罩；输入止于全局层，暂停状态仍由 App 唯一管理。

## 可见时先拦截键盘、触摸与鼠标，防止暂停中的设置或模态继续提交。
func _input(event: InputEvent) -> void:
	if visible and (event is InputEventKey or event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		get_viewport().set_input_as_handled()
