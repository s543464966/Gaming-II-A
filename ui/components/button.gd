@tool
extends "res://ui/components/touch_button.gd"
## 标准按钮至少达到触摸高度令牌，场景指定的更大卡面尺寸保持不变。

var tokens: DesignTokens = preload("res://ui/design_system/tokens/default_tokens.tres")
var _standard_height: float = 0
## 紧凑弹窗使用独立触控令牌，不以场景小尺寸绕过标准按钮下限。
@export var compact: bool = false:
	set(value):
		compact = value
		if is_node_ready(): _apply_tokens()

## 编辑器与游戏使用相同默认尺寸，不覆盖实例自己的布局尺寸。
func _ready() -> void:
	_apply_tokens()
	tokens.changed.connect(_apply_tokens)

## 令牌同时是最小触摸高度；旧场景的小尺寸不能绕过规范，更大实例继续保留。
func _apply_tokens() -> void:
	var height: float = tokens.detail_action_height if compact else tokens.button_height
	if custom_minimum_size.y == _standard_height or custom_minimum_size.y < height:
		custom_minimum_size.y = height
	_standard_height = height

## 场景卸载时解除共享资源监听。
func _exit_tree() -> void:
	if tokens.changed.is_connected(_apply_tokens): tokens.changed.disconnect(_apply_tokens)
