class_name DonutTopChoices
extends Control
## 在底部操作区选择置顶层，保留已知口味并允许灰色层盲选。

signal picked(box_index: int, item_index: int)
signal canceled


## 将取消操作交给页面统一收敛选择状态。
func _ready() -> void:
	$Row/Cancel.pressed.connect(canceled.emit)


## 以当前盒内层序创建置顶选择项。
func present(items: Array, box_index: int, can_pick: Callable) -> void:
	clear()
	for item_index: int in items.size():
		var item: Dictionary = items[item_index]
		var choice := Button.new()
		choice.custom_minimum_size = Vector2(160, 155)
		choice.focus_mode = Control.FOCUS_NONE
		choice.icon = DonutArt.FOOD[int(item.flavor)] if item.revealed else DonutArt.HIDDEN
		choice.expand_icon = true
		choice.add_theme_constant_override("icon_max_width", 143)
		choice.disabled = not can_pick.call(box_index, item_index)
		choice.pressed.connect(picked.emit.bind(box_index, item_index))
		$Row.add_child(choice)
		$Row.move_child(choice, item_index)
	show()


## 删除上一次临时选择内容，供切关和中断复用。
func clear() -> void:
	hide()
	for choice: Node in $Row.get_children():
		if choice == $Row/Cancel:
			continue
		$Row.remove_child(choice)
		choice.queue_free()
