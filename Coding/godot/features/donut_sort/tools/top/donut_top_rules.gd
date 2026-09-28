class_name DonutTopRules
extends RefCounted
## 判定盒内下层是否可置顶，并执行盒内重排。


## 下层需能改变排列或揭示未知口味，已知同味的无效重排不扣道具。
static func can_reorder(items: Array, item_index: int) -> bool:
	if item_index <= 0 or item_index >= items.size():
		return false
	var next: Array = items.duplicate(true)
	bring_to_top(next, item_index)
	return next != items


## 在已校验的盒内把指定食物移到顶层。
static func bring_to_top(items: Array, item_index: int) -> void:
	var item: Dictionary = items.pop_at(item_index)
	items.push_front(item)
