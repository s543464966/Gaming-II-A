extends "res://ui/components/button.gd"
## 目录条目就是卡牌本身，交互只轻调亮度，不再增加外层底板或第二道边框。

## 鼠标、键盘和按压共享轻量反馈，触摸仍由外层滚动容器处理。
func _ready() -> void:
	super._ready()
	for event: Signal in [mouse_entered, mouse_exited, focus_entered, focus_exited, button_down, button_up]:
		event.connect(_refresh_feedback, CONNECT_DEFERRED)

## 只修改本实例显示亮度，不改变强化框贴图和拥有状态。
func _refresh_feedback() -> void:
	if not is_inside_tree(): return
	$Picture.modulate = Color(0.88, 0.88, 0.88) if is_pressed() else Color(1.12, 1.12, 1.12) if is_hovered() or has_focus() else Color.WHITE
