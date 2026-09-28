class_name DonutAddBoxRules
extends RefCounted
## 选择可启用的周转盒位，并计算通关时应归还的额外空盒。


## 按盒位编号选择首个锁定周转盒。
static func next_turnover(slots: Array) -> int:
	for index: int in slots.size():
		if slots[index].kind == "turnover" and not slots[index].open:
			return index
	return -1


## 通关时归还道具额外增加的等量空盒，优先周转位；其盒已出餐时使用其他空盒抵还。
static func returnable_empty_boxes(slots: Array) -> Array[int]:
	var extra_count: int = 0
	var preferred: Array[int] = []
	var ordinary: Array[int] = []
	for index: int in slots.size():
		var slot: Dictionary = slots[index]
		if slot.kind == "turnover" and slot.open:
			extra_count += 1
		if slot.box == null or not slot.box.items.is_empty():
			continue
		if slot.kind == "turnover":
			preferred.append(index)
		else:
			ordinary.append(index)
	preferred.append_array(ordinary)
	return preferred.slice(0, extra_count)
