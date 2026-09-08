class_name SynergyMechanic
extends RefCounted
## 卡牌显式提供羁绊，阵容门槛可选；标签本身不产生规则。

## 只统计调用方传入的阵容；统计范围与重算时机由模式选择。
static func active(definitions: Array, rows: Array) -> Array:
	var result: Array = []
	for row in rows:
		if not definitions.any(func(card): return row.id in card.get("synergy_ids", [])): continue
		if matches(definitions, row.activation_conditions): result.append(row.id)
	return result

## 多项阵容条件按且判断，输出组内部按或匹配。
static func matches(definitions: Array, conditions: Array) -> bool:
	for condition in conditions:
		match condition.kind:
			"RequiredOutputs":
				for group in condition.groups:
					if not definitions.any(func(card): return CombatTypes.Output.find_key(card.output_type) in group): return false
			"DistinctOutputs":
				var outputs: Array = []
				for card in definitions:
					if not card.output_type in outputs: outputs.append(card.output_type)
				if outputs.size() < condition.minimum: return false
			"CardCount":
				if definitions.size() < condition.minimum: return false
			_: return false
	return true
