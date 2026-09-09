class_name CombatActionExecutor
extends RefCounted
## 所有能力来源共用的效果执行入口；生命结算、来源策略和触发预算各有独立 Owner。

const T = preload("res://features/mechanics/contracts/combat_types.gd")

var cards: Array
var random: DeterministicRandom
var pollution: PollutionMechanic
var main_ability_definitions: Dictionary
var health: HealthResolution

## 只借用实际所需的战斗状态；同步操作回调仅在调用栈中传递。
func _init(units: Array, random_source: DeterministicRandom, resource: PollutionMechanic, definitions: Dictionary, health_resolution: HealthResolution) -> void:
	cards = units
	random = random_source
	pollution = resource
	main_ability_definitions = definitions
	health = health_resolution

## 每段效果重新解析目标，多目标分别执行完整强度。
func execute(context: Dictionary, actions: Array, source: Variant, target: Variant, depth: int, publish: Callable, refresh: Callable, complete: Callable, activation: bool = false) -> void:
	# 组合中的单体与群攻共用本次敌方目标预算，击杀后重寻敌也不能绕过上限。
	var target_budget: int = 0
	for action: Dictionary in actions: target_budget = maxi(target_budget, int(action.get("max_targets", 0)))
	var affected_enemies: Dictionary = {}
	for index in range(actions.size()):
		if not CombatConditions.host_alive(context, cards) or complete.call(): return
		var action: Dictionary = actions[index]
		var targets = CombatTargeting.select(cards, random, context, int(action.target), source, target, action.get("target_tags", {}), int(action.get("max_targets", 0)))
		for recipient in targets:
			if not recipient.alive(): continue
			if target_budget > 0 and recipient.team_id != context.team_id:
				if not affected_enemies.has(recipient.id) and affected_enemies.size() >= target_budget: continue
			var specific: Dictionary = context.duplicate()
			specific.action_index = index
			var affected: CombatUnit = recipient
			if MechanicSchema.is_mechanic(int(action.kind)):
				MechanicActions.execute(self, specific, recipient, action, depth, publish, refresh, complete, activation)
			else:
				specific.single_target = not int(action.target) in [T.Target.AllAllies, T.Target.AllEnemies, T.Target.AllUnits, T.Target.AdjacentAllies, T.Target.LinkedAlly]
				affected = apply_action(specific, recipient, action, depth, activation, index, publish)
			if target_budget > 0 and affected != null and affected.team_id != context.team_id: affected_enemies[affected.id] = true
			refresh.call()

## 原子效果只改变单场状态并返回实际接收者，使守护转移也计入目标预算。
func apply_action(context: Dictionary, target: CombatUnit, action: Dictionary, depth: int, activation: bool, index: int, publish: Callable) -> CombatUnit:
	if not CardTagQuery.matches(target.definition.get("card_tag_ids", []), action.get("target_tags", {})): return null
	if context.unit != null:
		context.unit.refresh_modifiers()
		context.modifiers = context.unit.definition.modifiers
	context = context.duplicate()
	context.action_index = index
	var definition: Dictionary = context.unit.definition if context.unit != null else {"modifiers": context.modifiers}
	var amount = CombatAttributes.action_amount(definition, action, float(definition.get("main_ability_strength_multiplier", 1)) if activation else 1.0)
	var source: CombatUnit = context.unit
	var output = T.output_kind(action)
	if output != T.Output.Special:
		if context.has("fixed_amount"): amount = float(context.fixed_amount)
		elif action.has("snapshot_amount"): amount = float(action.snapshot_amount)
		else: amount *= float(context.get("empower_multiplier", 1))
		amount *= float(context.get("action_scale", 1))
		if source != null and not context.get("synthetic", false):
			source.mechanics.last_action = {"action": action.duplicate(true), "amount": amount, "damage_stats": CombatAttributes.stats(definition)}
	if int(action.kind) in [T.CombatAction.PhysicalDamage, T.CombatAction.Witchcraft] and context.get("single_target", false):
		target = health.intercept(source, target, depth, publish, context)
	if output != T.Output.Special:
		var projectile = str(action.get("projectile_key", ""))
		if projectile.is_empty() and activation and source != null:
			projectile = str(context.modifiers.get("projectile_key", ""))
			if projectile.is_empty(): projectile = source.definition.get("projectile", "")
		if source == null or source == target: projectile = ""
		publish.call(T.Event.ActionReleased, source, target, amount, "效果发动", depth, projectile, context, {"output_type": output, "action_index": index})
	match int(action.kind):
		T.CombatAction.PhysicalDamage, T.CombatAction.Witchcraft:
			health.damage(source, target, amount, depth, publish, "", context, float(action.get("lifesteal_ratio", 0)), output)
		T.CombatAction.Heal:
			health.heal(source, target, amount, depth, publish, context)
		T.CombatAction.GrantShield:
			health.grant_shield(source, target, amount, depth, publish, context)
		T.CombatAction.ApplyStatus:
			var duration = float(action.get("duration_seconds", 0))
			var status = int(action.get("status", T.Status.None))
			if status != T.Status.None:
				var origin = context.duplicate(true)
				origin.erase("unit")
				origin.action_index = index
				origin.damage_stats = CombatAttributes.stats(source.definition if source != null else {"modifiers": context.modifiers})
				origin.lifesteal_ratio = float(action.get("lifesteal_ratio", 0))
				if CombatStatuses.apply(target, status, maxf(0, amount), duration, origin):
					var value: float = CombatAttributes.points(amount) if status in [T.Status.Burn, T.Status.Poison] else duration
					publish.call(T.Event.StatusApplied, source, target, value, T.Status.keys()[status], depth, "", context, {"status": status, "stacks": target.status_stacks().get(status, 0)})
		T.CombatAction.ChangePollution:
			var change = pollution.change(target.team_id, amount)
			if change.delta != 0:
				publish.call(T.Event.PollutionChanged, source, target, change.delta, "污染变为 %d" % change.value, depth, "", context)
				if change.crossed: publish.call(T.Event.PollutionThresholdReached, source, target, change.value, "污染跨越阈值", depth, "", context)
		T.CombatAction.Charge: target.main_abilities.change_cooldown(-maxf(0, amount), action.get("main_ability_id", ""))
		T.CombatAction.DelayCooldown: target.main_abilities.change_cooldown(maxf(0, amount), action.get("main_ability_id", ""))
		T.CombatAction.Haste:
			var gained = target.main_abilities.haste(AbilitySource.key(context.id, context.source_id, str(index)), amount, float(action.get("duration_seconds", 0)), action.get("main_ability_id", ""), context.get("source", {}))
			if gained: publish.call(T.Event.HasteGained, source, target, amount, "获得加速", depth, "", context, {"duration_seconds": action.duration_seconds})
		T.CombatAction.RefillAmmo:
			if target.ammo_capacity > 0: target.ammo_remaining = mini(target.ammo_capacity, target.ammo_remaining + int(amount))
		T.CombatAction.ExpandAmmo:
			if target.kind == CardTypes.Kind.ItemCard and target.ammo_capacity > 0:
				target.ammo_expansion += int(amount)
				target.ammo_capacity += int(amount)
				target.ammo_remaining += int(amount)
		T.CombatAction.GrantMainAbility:
			var origin = AbilitySource.key(context.id, context.source_id, "action:%d" % index)
			var granted: Dictionary = main_ability_definitions[action.main_ability_id].duplicate(true)
			granted.source = context.get("source", {}).duplicate(true)
			granted.source.action_index = index
			target.main_abilities.grant(granted, origin, float(action.get("duration_seconds", 0)))
	return target
