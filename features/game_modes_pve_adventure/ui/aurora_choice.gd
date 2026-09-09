extends "res://ui/components/touch_button.gd"
## 星能纸牌保留原生点击与滚动取消，明度只反映当前按钮状态。

## 按压、悬停和键盘焦点共用同一纸面反馈，不影响奖励选择。
func _ready() -> void:
	for event: Signal in [button_down, button_up, mouse_entered, mouse_exited, focus_entered, focus_exited]:
		event.connect(_refresh_tint)

## 取消及暂停后也以原生状态重算，避免纸牌停留在按下颜色。
func _notification(what: int) -> void:
	if what in [NOTIFICATION_SCROLL_BEGIN, NOTIFICATION_VISIBILITY_CHANGED, NOTIFICATION_PAUSED] and is_node_ready():
		$Paper.modulate = Color.WHITE
		$Margin/Content/Title/Frame.modulate = Color.WHITE

## 只调背景与标题牌，文字和内容插画保持原色。
func _refresh_tint() -> void:
	var brightness: float = 0.86 if button_pressed else (1.06 if is_hovered() or has_focus() else 1.0)
	$Paper.modulate = Color(brightness, brightness, brightness)
	$Margin/Content/Title/Frame.modulate = Color(brightness, brightness, brightness)
