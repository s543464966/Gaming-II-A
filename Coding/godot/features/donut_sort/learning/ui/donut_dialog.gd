class_name DonutDialog
extends ColorRect
## 展示机制说明或玩家操作确认，仅转发按钮结果，不修改会话。

signal answered(accepted: bool)


## 按钮关闭当前卡片后才交回页面处理，避免输入穿透。
func _ready() -> void:
	$Card/Accept.pressed.connect(_answer.bind(true))
	$Card/Cancel.pressed.connect(_answer.bind(false))


## 使用现有纸托和甜甜圈作示意，确认流程可隐藏示意保持文字清楚。
func present(title: String, message: String, accept: String = "知道了", cancel: String = "", illustration: bool = true) -> void:
	$Card/FrozenExample.hide()
	$Card/Title.text = title
	$Card/Message.text = message
	$Card/Accept.text = accept
	$Card/Cancel.text = cancel
	$Card/Cancel.visible = not cancel.is_empty()
	$Card/Donut.visible = illustration
	$Card/Holder.visible = illustration
	$Card/Accept.position.x = 425.0 if not cancel.is_empty() else 225.0
	$Card/Accept.size.x = 315.0 if not cancel.is_empty() else 350.0
	$Card/Message.position.y = 390.0 if illustration else 145.0
	$Card/Message.size.y = 260.0 if illustration else 480.0
	show()


## 隐藏卡片后发送答案，调用方负责验证其对应操作仍然有效。
func _answer(accepted: bool) -> void:
	hide()
	answered.emit(accepted)


## 冰冻说明复用正式盒子，展示透明冰壳中的口味及数字冰冻的剩余次数。
func show_frozen_example(numbered: bool) -> void:
	$Card/Donut.hide()
	$Card/Holder.hide()
	var sample: DonutBox = $Card/FrozenExample
	sample.present({"kind": "regular", "open": true, "box": {
		"kind": "number_frozen" if numbered else "frozen", "frozen": true,
		"lid": 2 if numbered else 0, "items": [
			{"flavor": 0, "revealed": true}, {"flavor": 1, "revealed": true},
			{"flavor": 2, "revealed": true}, {"flavor": 4, "revealed": true}]}})
	sample.show()
