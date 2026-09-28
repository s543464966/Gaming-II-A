class_name DonutTopChoices
extends HBoxContainer
## 保留已知下层的真实口味，未揭示下层允许盲选后置顶揭晓。

signal picked(box_index: int, item_index: int)


## 以当前盒内层序创建置顶选择项。
func present(items: Array, box_index: int, can_pick: Callable) -> void:
	clear()
	for item_index: int in items.size():
		var item: Dictionary = items[item_index]
		var choice := Button.new()
		choice.custom_minimum_size = Vector2(160, 155)
		choice.icon = DonutArt.FOOD[int(item.flavor)] if item.revealed else DonutArt.HIDDEN
		choice.expand_icon = true
		choice.add_theme_constant_override("icon_max_width", 143)
		choice.disabled = not can_pick.call(box_index, item_index)
		choice.pressed.connect(picked.emit.bind(box_index, item_index))
		add_child(choice)


## 删除上一次临时选择内容，供切关和中断复用。
func clear() -> void:
	for choice: Node in get_children():
		remove_child(choice)
		choice.queue_free()
