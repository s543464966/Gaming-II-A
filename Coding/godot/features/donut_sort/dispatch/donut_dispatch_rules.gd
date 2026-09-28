class_name DonutDispatchRules
extends RefCounted
## 判定可打包盒和下一组盒位订单匹配，不持有备货或结算状态。


## 满四颗同味且机关解除的普通盒才能参与打包。
static func packable(slots: Array, index: int) -> bool:
	if not DonutMoveRules.can_handle(slots, index) or slots[index].kind == "single":
		return false
	var items: Array = slots[index].box.items
	return items.size() == DonutMoveRules.CAPACITY and items.all(func(item: Dictionary) -> bool: return item.flavor == items[0].flavor)


## 按盒位顺序寻找下一次真实回收所需的盒位和需求位置。
static func next_match(slots: Array, demands: Array) -> Vector2i:
	for index: int in slots.size():
		if packable(slots, index):
			var demand_index: int = DonutOrderRules.matching_demand(demands, int(slots[index].box.items[0].flavor))
			if demand_index >= 0:
				return Vector2i(index, demand_index)
	return Vector2i(-1, -1)
