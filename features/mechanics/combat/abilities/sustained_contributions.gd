class_name SustainedContributions
extends RefCounted
## 在战斗状态边界维护常驻及条件贡献，条件翻转只增删对应来源。

const T = preload("res://features/mechanics/contracts/combat_types.gd")
var bindings: Dictionary = {}
var observations: Dictionary = {}

## 先读取同一状态判定全部条件，再统一更新账本，避免遍历顺序改变条件。
func refresh(cards: Array, hosts: Array, pollution: PollutionMechanic) -> void:
	var planned: Dictionary = {}
	var contexts: Array = []
	for host in hosts:
		var context: Dictionary = host.duplicate()
		context.team_id = host.get("team_id", -1)
		context.unit = null
		contexts.append(context)
	for card in cards:
		contexts.append({"id": card.id, "scope": "card", "team_id": card.team_id, "unit": card,
			"modifier_sources": card.definition.get("modifier_sources", []), "conditional_passives": card.definition.get("conditional_passives", [])})
	observations.clear()
	for context in contexts:
		var alive: bool = context.scope == "battle" or (context.get("unit") != null and context.unit.alive()) or (context.scope == "team" and cards.any(func(card): return card.team_id == context.team_id and card.alive()))
		for part in context.get("modifier_sources", []) + context.get("conditional_passives", []):
			var key = AbilitySource.key(context.id, part.source_id, part.id)
			var conditional: bool = part.execution_kind == T.AbilityExecution.ConditionalPassive
			var matched = not conditional or CombatConditions.matches(context, part.conditions, null, null, pollution)
			var targets: Array = []
			var retained_self = not conditional and context.get("unit") != null and part.target == T.Target.Self
			var retained_team: bool = not conditional and context.get("unit") != null and part.get("lifetime", T.ContributionLifetime.Battlefield) == T.ContributionLifetime.TeamMembership
			var active: bool = (alive and matched) or retained_self or retained_team
			if active:
				for card in cards:
					if not card.alive() and not retained_team and not (retained_self and context.unit == card): continue
					if _target(context, part.target, card) and CardTagQuery.matches(card.definition.get("card_tag_ids", []), part.get("target_tags", {})): targets.append(card)
			observations[key] = {"id": part.id, "source": part.source.duplicate(true), "owner_id": context.id,
				"execution_kind": part.execution_kind, "active": active, "condition_met": matched, "targets": targets.map(func(card): return card.id)}
			var modifiers: Dictionary = part.modifiers.duplicate(true)
			for card in targets:
				planned[key + "|" + card.id] = {"key": key, "unit": card, "part": part, "owner_id": context.id, "owner_unit": context.get("unit"), "modifiers": modifiers.duplicate(true)}
	var changed: Array = []
	_resolve_team_contributions(planned)
	for identity in bindings:
		if not planned.has(identity):
			bindings[identity].unit.modifiers.remove_source(bindings[identity].key)
			if not bindings[identity].unit in changed: changed.append(bindings[identity].unit)
	for identity in planned:
		var binding: Dictionary = planned[identity]
		# 已激活贡献保持原顺序；重复刷新不会累加数值或改变覆盖优先级。
		if not bindings.has(identity) or bindings[identity].modifiers != binding.modifiers:
			var source = AbilitySource.for_host(binding.part.source, binding.owner_id)
			binding.unit.modifiers.set_source(binding.key, binding.modifiers, source)
			if not binding.unit in changed: changed.append(binding.unit)
	bindings = planned
	for card in changed: card.refresh_modifiers()

## 持续修正只支持稳定的自身或队伍范围，不消费随机源。
static func _target(context: Dictionary, target: int, card: CombatUnit) -> bool:
	match target:
		T.Target.Self: return context.get("unit") == card
		T.Target.AllAllies: return card.team_id == context.get("team_id")
		T.Target.AllEnemies: return card.team_id != context.get("team_id")
		T.Target.AllUnits: return true
		T.Target.AdjacentAllies: return context.get("unit") != null and context.unit != card and card.team_id == context.team_id and CombatTargeting.adjacent(context.unit, card)
		T.Target.LinkedAlly: return context.get("unit") != null and card.team_id == context.team_id and context.unit.mechanics.links.has(card.id)
	return false

## 界面读取内核判定结果，不再次运行条件表达式。
func capture(owner_id: String) -> Array:
	return observations.values().filter(func(state): return state.owner_id == owner_id).map(func(state): return state.duplicate(true))

## 同一提供者按目标合并贡献，拆分能力项不能多次获得装备整数加值。
func _resolve_team_contributions(planned: Dictionary) -> void:
	var groups: Dictionary = {}
	var owner_bonuses: Dictionary = {}
	for binding in planned.values():
		if binding.unit == binding.owner_unit:
			owner_bonuses[binding.owner_id] = int(owner_bonuses.get(binding.owner_id, 0)) + int(binding.modifiers.get("team_bonus_add", 0))
		var key = binding.owner_id + "|" + binding.unit.id
		if not groups.has(key): groups[key] = []
		groups[key].append(binding)
	for group in groups.values():
		var owner: Variant = group[0].owner_unit
		var bonus: int = int(owner.modifiers.base.get("team_bonus_add", 0)) + int(owner_bonuses.get(group[0].owner_id, 0)) if owner != null else 0
		var contributions = CombatAttributes.team_contributions(group.map(func(binding): return binding.modifiers), bonus)
		for index in range(group.size()): group[index].modifiers = contributions[index]
