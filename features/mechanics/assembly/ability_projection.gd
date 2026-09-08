class_name AbilityProjection
extends RefCounted
## 将内容能力清单投影为运行贡献，保留来源身份且不持有目录服务。

const T = preload("res://features/mechanics/contracts/combat_types.gd")

## 每次生成独立贡献，静态定义保持只读。
static func empty() -> Dictionary:
	return {"main_abilities": [], "rules": [], "modifier_sources": [], "conditional_passives": [], "modifiers": CombatAttributes.combine_modifiers([])}

## 展开已规范化的能力清单，来源机制的成长策略在进入此层前完成。
static func project(parts: Array, source: Dictionary, main_ability_definitions: Dictionary) -> Dictionary:
	var result = empty()
	for original in parts:
		var part: Dictionary = original.duplicate(true)
		var origin = AbilitySource.for_part(source, part.id)
		part.source = origin
		part.source_id = source.instance_id
		match part.execution_kind:
			T.AbilityExecution.CooldownMain:
				var main_ability: Dictionary = main_ability_definitions.get(part.main_ability_id, {}).duplicate(true)
				if main_ability.is_empty(): continue
				main_ability.source_id = source.instance_id + ":" + part.id
				main_ability.source = origin
				result.main_abilities.append(main_ability)
			T.AbilityExecution.TriggeredPassive:
				part.id += source.get("rule_suffix", "")
				part.erase("execution_kind")
				result.rules.append(part)
			_:
				if part.execution_kind == T.AbilityExecution.ConditionalPassive: result.conditional_passives.append(part)
				else: result.modifier_sources.append(part)
	refresh(result)
	return result

## 预览与装配追加相同的贡献集合，不维护第二份内容配置。
static func append(target: Dictionary, contribution: Dictionary) -> void:
	for key in ["main_abilities", "rules", "modifier_sources", "conditional_passives"]:
		if not target.has(key): target[key] = []
		target[key].append_array(contribution[key])
	refresh(target)

## 卡牌自身常驻属性可在开战前预览，群体修正在内核实例化时解析。
static func refresh(value: Dictionary) -> void:
	value.modifiers = CombatAttributes.self_modifiers(value.modifier_sources, value.get("card_tag_ids", []))
