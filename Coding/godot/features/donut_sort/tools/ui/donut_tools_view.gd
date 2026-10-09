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


## 未领取显示加号，已领取显示一次，用完隐藏角标并禁用按钮。
func present(counts: Dictionary, claimed: Dictionary, top_mode: bool, pending: bool = false) -> void:
	$Top.modulate = Color(1, 0.9, 0.6) if top_mode else Color.WHITE
	for entry: Array in [[$Undo, "undo"], [$AddBox, "add_box"], [$Top, "top"]]:
		var available: bool = int(counts.get(entry[1], 0)) > 0
		var can_claim: bool = not claimed.get(entry[1], false)
		var spent: bool = not available and not can_claim
		var button: BaseButton = entry[0]
		button.disabled = spent or pending
		button.get_node("Count").text = "1" if available else "+"
		button.get_node("Count").visible = not spent
		button.get_node("Badge").visible = not spent
		button.get_node("Icon").modulate = Color(0.72, 0.72, 0.72, 0.65) if spent else Color.WHITE
		button.tooltip_text = "本关次数已用完" if spent else ("领取一次使用机会" if can_claim else "")


## 动效和页面中断时恢复所有按钮的普通外观。
func reset_feedback() -> void:
	for button: BaseButton in [$Undo, $AddBox, $Top]:
		button.self_modulate = Color.WHITE
