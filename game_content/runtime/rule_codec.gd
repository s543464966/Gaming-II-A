class_name RuleCodec
extends AbilitySchema
## 内容格式适配：成长、分类与羁绊字段归内容侧，能力语义交给共享契约。

## 内容专属结构在此解释，战斗能力复用同一规范化入口。
func decode(value: Variant, kind: String, owner: String, source_names_only: bool = true) -> Variant:
	if not kind in ["innate_ability_ids", "card_tag_ids", "synergy_ids", "star_fragment_costs", "star_stat_multipliers", "activation_conditions", "applies_to_kinds", "required_outputs"]:
		return super.decode(value, kind, owner, source_names_only)
	names_only = source_names_only
	if not value is Array:
		errors.append(owner + " 必须是数组。")
		return []
	var result: Array = []
	for i in range(value.size()):
		var label = "%s[%d]" % [owner, i]
		match kind:
			"innate_ability_ids", "card_tag_ids", "synergy_ids":
				if not value[i] is String or value[i].is_empty() or value[i] in result: errors.append(label + " 内容引用无效或重复。")
				else: result.append(value[i])
			"star_stat_multipliers":
				result.append(_number(value[i], label))
			"star_fragment_costs":
				if not (value[i] is int or value[i] is float) or not is_finite(float(value[i])) or value[i] != floorf(value[i]) or value[i] <= 0:
					errors.append(label + " 碎片需求必须为正整数。")
				else: result.append(int(value[i]))
			"activation_conditions": result.append(_activation(value[i], label))
			"required_outputs":
				var output = _enum(value[i], T.Output, label)
				if output in result: errors.append(label + " 输出类型重复。")
				else: result.append(output)
			_:
				var card_kind = _enum(value[i], CardTypes.Kind, label)
				if card_kind in result: errors.append(label + " 卡牌类别重复。")
				else: result.append(card_kind)
	return result

## 羁绊条件使用受校验的分类统计，不接受脚本或任意表达式。
func _activation(value: Variant, owner: String) -> Dictionary:
	var result = _object(value, {"kind": "", "groups": [], "minimum": 0}, ["kind"], owner)
	if result.kind == "RequiredOutputs":
		if not result.groups is Array or result.groups.is_empty() or result.minimum != 0:
			errors.append(owner + " 输出组合必须有组且不能有数量阈值。")
		else:
			for group in result.groups:
				if not group is Array or group.is_empty(): errors.append(owner + " 输出组不能为空。")
				else:
					for role in group:
						if not role is String or not T.Output.has(role): errors.append(owner + " 输出分类无效。")
	elif result.kind in ["DistinctOutputs", "CardCount"]:
		if not (result.minimum is int or result.minimum is float) or not is_finite(float(result.minimum)) or result.minimum != floorf(result.minimum) or result.minimum <= 0 or result.groups != []: errors.append(owner + " 数量条件必须有正整数阈值且没有输出组。")
		else: result.minimum = int(result.minimum)
	else: errors.append(owner + " 未知羁绊激活条件。")
	return result
