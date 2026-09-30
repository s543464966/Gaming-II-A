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
