class_name DonutToolsView
extends Control
## 集中显示三种道具次数并发出玩家操作意图。

signal undo_pressed
signal add_box_pressed
signal top_pressed


## 连接独立按钮场景并提供一致的按压反馈。
func _ready() -> void:
	$Undo.pressed.connect(undo_pressed.emit)
	$AddBox.pressed.connect(add_box_pressed.emit)
	$Top.pressed.connect(top_pressed.emit)
	for button: BaseButton in [$Undo, $AddBox, $Top]:
		button.button_down.connect(func() -> void: button.self_modulate = Color(0.82, 0.82, 0.82, 1))
		button.button_up.connect(func() -> void: button.self_modulate = Color.WHITE)
		button.mouse_exited.connect(func() -> void: button.self_modulate = Color.WHITE)


## 根据会话快照更新次数与置顶选择状态。
func present(counts: Dictionary, top_mode: bool) -> void:
	$Undo/Count.text = str(counts.undo)
	$AddBox/Count.text = str(counts.add_box)
	$Top/Count.text = str(counts.top)
	$Top.modulate = Color(1, 0.9, 0.6) if top_mode else Color.WHITE


## 动效和页面中断时恢复所有按钮的普通外观。
func reset_feedback() -> void:
	for button: BaseButton in [$Undo, $AddBox, $Top]:
		button.self_modulate = Color.WHITE
