extends Control
## 可编辑的通用确认对话框；只发出用户意图，不执行任何业务事务。

signal accepted
signal canceled
var tokens: DesignTokens = preload("res://ui/design_system/tokens/default_tokens.tres")
var title: Variant = "ui.common.confirm_title"
var message: Variant = ""
var platform: Node

## 依赖入树前赋值，布局始终由场景节点持有。
func _ready() -> void:
	$Shade.color = tokens.modal_shade
	$SafeArea.configure(platform)
	_bind($SafeArea/Center/Panel/Column/Title, title)
	_bind($SafeArea/Center/Panel/Column/Scroll/Message, message)
	$SafeArea/Center/Panel/Column/Actions/Cancel.pressed.connect(func(): canceled.emit())
	$SafeArea/Center/Panel/Column/Actions/Confirm.pressed.connect(func(): accepted.emit())
	$SafeArea/Center.resized.connect(_layout)
	_layout()
	$SafeArea/Center/Panel/Column/Actions/Confirm.grab_focus()

## 固定文案直接使用原生翻译，动态参数由调用方按当前语言只读生成。
func _bind(label: Label, value: Variant) -> void:
	if value is Callable: GameUI.bind_text(label, value)
	else: label.text = str(value)

## 长文限高滚动，操作区保持在实际安全区内。
func _layout() -> void:
	var available: Vector2 = $SafeArea/Center.size
	$SafeArea/Center/Panel.custom_minimum_size.x = minf(620, maxf(240, available.x - tokens.page_margin * 2))
	$SafeArea/Center/Panel/Column/Scroll.custom_minimum_size.y = minf(300, available.y * 0.5)

## 返回键只取消当前确认，不提交业务动作。
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		canceled.emit()
