class_name DonutMoveRules
extends RefCounted
## 提供盒位容量、顶层连续同味拿取与落点的无状态判定。

const CAPACITY: int = 4


## 单颗暂存容量为一，其余盒子容量为四。
static func capacity(slots: Array, index: int) -> int:
	return 1 if slots[index].kind == "single" else CAPACITY


## 只有实际容器存在且机关限制解除时才能取放。
static func can_handle(slots: Array, index: int) -> bool:
	if index < 0 or index >= slots.size():
		return false
	var slot: Dictionary = slots[index]
	return slot.open and slot.box != null and int(slot.box.lid) == 0 and not slot.box.frozen


## 从可操作盒的明牌顶层开始拿取。
static func can_pick_top(slots: Array, started: bool, won: bool, source: int) -> bool:
	if not started or won or not can_handle(slots, source):
		return false
	var items: Array = slots[source].box.items
	return not items.is_empty() and items[0].revealed


## 统计操作开始时顶层连续同味明牌，遇到灰色或不同口味即停止。
static func pick_count(slots: Array, started: bool, won: bool, source: int) -> int:
	if not can_pick_top(slots, started, won, source):
		return 0
	var items: Array = slots[source].box.items
	var count: int = 0
	for item: Dictionary in items:
		if not item.revealed or item.flavor != items[0].flavor:
			break
		count += 1
	return count


## 连续同味组按目标剩余容量截取，单颗暂存沿用自身容量限制。
static func move_count(slots: Array, started: bool, won: bool, source: int, target: int) -> int:
	if not can_pick_top(slots, started, won, source) or source == target or not can_handle(slots, target):
		return 0
	var destination: Array = slots[target].box.items
	if destination.size() >= capacity(slots, target):
		return 0
	if not destination.is_empty() and (not destination[0].revealed or destination[0].flavor != slots[source].box.items[0].flavor):
		return 0
	return mini(pick_count(slots, started, won, source), capacity(slots, target) - destination.size())
