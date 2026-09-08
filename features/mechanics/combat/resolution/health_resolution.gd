class_name HealthResolution
extends RefCounted
## 单场生命与护盾结算；即时伤害和持续伤害共用暴击、吸血与击败顺序。

const T = preload("res://features/mechanics/contracts/combat_types.gd")
var cards: Array
var random: DeterministicRandom
var remainders: Dictionary = {}
var resolution_depth: int = 0

## 借用同场单位与随机源，不复制状态或持有应用、模拟器及回调。
func _init(units: Array, random_source: DeterministicRandom) -> void:
	cards = units
	random = random_source

## 全部伤害共用暴击和吸血，毒入体后绕过护盾；战报分别记录护盾与生命损失。
func damage(source: Variant, target: CombatUnit, amount: float, depth: int, publish: Callable, projectile: String = "", context: Dictionary = {}, bypass_shield: bool = false, lifesteal: float = 0, output: int = T.Output.Physical) -> float:
	if not target.alive(): return 0.0
	resolution_depth += 1
	var stats: Dictionary = context.get("damage_stats", CombatAttributes.stats(source.definition if source != null else {"modifiers": context.get("modifiers", {})}))
	var critical = amount > 0 and stats.crit_chance > 0 and random.next_unit() < stats.crit_chance
	var pending = _points(amount * (stats.crit_multiplier if critical else 1.0), source, target, context, "damage", context.get("periodic", false))
	var damage = pending
	var shield_multiplier = 1.2 if output == T.Output.Witchcraft else 1.0
	var absorbed = 0.0 if bypass_shield else minf(target.shield, CombatAttributes.points(pending * shield_multiplier))
	target.shield = DeterministicMath.f32(target.shield - absorbed)
	# 旧盾耗尽即确定已有毒的穿透，事件里补上的新盾不能倒转先后关系。
	if target.shield <= 0: CombatStatuses.breach_poison(target)
	pending = CombatAttributes.points(pending - absorbed / shield_multiplier)
	var actual = minf(target.health, pending)
	target.health = DeterministicMath.f32(target.health - actual)
	publish.call(T.Event.DamageResolved, source, target, actual, "暴击" if critical else "造成伤害", depth, projectile, context,
		{"output_type": output, "critical": critical, "damage": damage, "shield_damage": absorbed, "health_damage": actual, "bypassed_shield": bypass_shield})
	if source != null and source != target and source.alive():
		var healing = context.duplicate()
		healing.accumulate = true
		healing.rounding_channel = "lifesteal:" + target.id
		heal(source, source, actual * clampf(stats.lifesteal_ratio + lifesteal, 0.0, 1.0), depth, publish, healing)
	if target.kind == CardTypes.Kind.CoreHero and actual > 0: publish.call(T.Event.CoreDamaged, source, target, actual, "英雄受伤", depth, "", context)
	if target.health <= 0 and not target.defeated: defeat(source, target, depth, publish, context)
	resolution_depth -= 1
	return actual

## 死亡只结算一次；遗言和同次死亡反应完成后才允许判断胜负。
func defeat(source: Variant, target: CombatUnit, depth: int, publish: Callable, context: Dictionary, reason: String = "damage") -> void:
	if target.defeated: return
	resolution_depth += 1
	target.health = 0
	target.defeated = true
	for card in cards: card.mechanics.links.erase(target.id)
	publish.call(T.Event.UnitDefeated, source, target, 0, "卡牌离场", depth, "", context, {"death_reason": reason, "kill_credit": reason != "sacrifice"})
	if target.kind == CardTypes.Kind.Minion:
		publish.call(T.Event.MinionDefeated, source, target, 0, "随从倒下", depth, "", context)
		var allies = cards.filter(func(card): return card.alive() and card.team_id == target.team_id)
		allies.sort_custom(func(a, b): return a.id < b.id)
		for ally in allies: publish.call(T.Event.AlliedMinionDefeated, target, ally, 0, "友方随从倒下", depth, "", context)
		if not cards.any(func(card): return card.alive() and card.team_id == target.team_id and card.kind == CardTypes.Kind.Minion):
			for ally in allies: publish.call(T.Event.LastMinionDefeated, target, ally, 0, "最后一名随从倒下", depth, "", context)
	elif target.kind == CardTypes.Kind.ItemCard: publish.call(T.Event.ItemDisabled, source, target, 0, "道具卡停用", depth, "", context)
	resolution_depth -= 1

## 守护截获单目标即时伤害，在弹道和扣盾扣血前选择一个相邻守护者。
func intercept(source: Variant, target: CombatUnit, depth: int, publish: Callable, context: Dictionary) -> CombatUnit:
	if source == null or source.team_id == target.team_id or context.get("periodic", false): return target
	var guards: Array = cards.filter(func(card): return card != target and card.alive() and card.team_id == target.team_id and card.mechanics.guard.get("charges", 0) > 0 and CombatTargeting.adjacent(card, target))
	guards.sort_custom(func(a, b): return a.id < b.id)
	if guards.is_empty(): return target
	var guard: CombatUnit = guards[0]
	guard.mechanics.guard.charges -= 1
	publish.call(T.Event.DamageGuarded, source, target, 0, "守护", depth, "", context, {"guard_id": guard.id})
	return guard

## 治疗必须有明确效果来源，不恢复护盾，也不复活或超过生命上限。
func heal(source: Variant, target: CombatUnit, amount: float, depth: int, publish: Callable, context: Dictionary) -> void:
	if not target.alive(): return
	var previous = target.health
	var value = maxf(0, amount) * (0.8 if target.statuses.has(T.Status.Poison) else 1.0)
	var gained = _points(value, source, target, context, context.get("rounding_channel", "heal"), context.get("accumulate", false) or value < 1.0)
	target.health = minf(target.maximum_health, target.health + gained)
	var actual = DeterministicMath.f32(target.health - previous)
	if actual > 0: publish.call(T.Event.HealingResolved, source, target, actual, "恢复生命", depth, "", context)

## 护盾先写入状态再同步发布，后续效果能观察到完整结算结果。
func grant_shield(source: Variant, target: CombatUnit, amount: float, depth: int, publish: Callable, context: Dictionary) -> void:
	var gained = _points(amount, source, target, context, "shield", amount < 1.0)
	target.shield = DeterministicMath.f32(target.shield + gained)
	if gained <= 0: return
	publish.call(T.Event.ShieldGained, source, target, gained, "获得护盾", depth, "", context)

## 小额连续效果按来源、目标和效果独立累计余数；普通单次结算只取整一次。
func _points(amount: float, source: Variant, target: CombatUnit, context: Dictionary, channel: String, accumulate: bool) -> float:
	var value = maxf(0, DeterministicMath.f32(amount))
	if not accumulate: return CombatAttributes.points(value)
	var key = [source.id if source != null else context.get("id", ""), target.id, context.get("source_id", ""), context.get("source", {}).get("part_id", ""), context.get("action_index", 0), channel]
	var total = value + float(remainders.get(key, 0.0))
	var rounded = CombatAttributes.points(total)
	remainders[key] = DeterministicMath.f32(total - rounded)
	return rounded
