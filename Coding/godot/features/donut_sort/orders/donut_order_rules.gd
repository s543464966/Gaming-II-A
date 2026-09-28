class_name DonutOrderRules
extends RefCounted
## 维护四个订单位的初始状态、显式开放与确定性匹配规则。

const DEFAULT_OPEN_SLOTS: int = 2


## 初始默认只开放左侧两位，显式配置供未来解锁流程和独立场景使用。
static func create_positions(definitions: Array) -> Array:
	var positions: Array = []
	for index: int in definitions.size():
		var entry: Dictionary = definitions[index]
		positions.append({"sequence": entry.sequence.map(func(value: Variant) -> int: return int(value)),
			"cursor": 0, "open": entry.get("initially_open", index < DEFAULT_OPEN_SLOTS)})
	return positions


## 仅切换有效锁定位的开放状态，不定义解锁条件、费用或玩家入口。
static func unlock_position(demands: Array, index: int) -> bool:
	if index < 0 or index >= demands.size() or demands[index].open:
		return false
	demands[index].open = true
	return true


## 计算本关全部需求，包含锁定和后续序列。
static func total_orders(demands: Array) -> int:
	var total: int = 0
	for position: Dictionary in demands:
		total += position.sequence.size()
	return total


## 锁定或耗尽位置返回负一，避免提前泄露隐藏订单。
static func demand_flavor(demands: Array, index: int) -> int:
	var position: Dictionary = demands[index]
	if not position.open or position.cursor >= position.sequence.size():
		return -1
	return int(position.sequence[position.cursor])


## 同口味需求并存时优先最左侧开放位置。
static func matching_demand(demands: Array, flavor: int) -> int:
	for index: int in demands.size():
		if demand_flavor(demands, index) == flavor:
			return index
	return -1
