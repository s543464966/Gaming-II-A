class_name CombatConditions
extends RefCounted
## 共用纯条件判定，事件上下文与可持续读取的战斗状态明确区分。

const T = preload("res://features/mechanics/contracts/combat_types.gd")

## 条件全部按且判断，卡牌宿主和队伍宿主保留不同的事件归属。
static func matches(context: Dictionary, conditions: Array, source: Variant, target: Variant, pollution: PollutionMechanic, event: Dictionary = {}) -> bool:
	var owner = context.get("unit")
	for condition in conditions:
		var threshold = float(condition.get("threshold", 0))
		match int(condition.kind):
			T.Condition.OwnerHasTags:
				if owner == null or not CardTagQuery.matches(owner.definition.get("card_tag_ids", []), condition.tag_query): return false
			T.Condition.EventSourceHasTags:
				if source == null or not CardTagQuery.matches(source.definition.get("card_tag_ids", []), condition.tag_query): return false
			T.Condition.EventTargetHasTags:
				if target == null or not CardTagQuery.matches(target.definition.get("card_tag_ids", []), condition.tag_query): return false
			T.Condition.EventIsPrimary:
				if event.get("synthetic", false) or event.get("cast_index", 1) != 1: return false
			T.Condition.OwnerCounterAtLeast:
				if owner == null or owner.mechanics.counters.get(condition.key, 0) < threshold: return false
			T.Condition.EventCounterKey:
				if event.get("counter_key", "") != condition.key: return false
			T.Condition.EventTargetMarked:
				if target == null or not target.mechanics.marked(context.team_id, condition.key): return false
			T.Condition.EventSourceIsLinked:
				if owner == null or source == null or not owner.mechanics.links.has(source.id): return false
			T.Condition.EventTargetStatusStacksAtLeast:
				if target == null or target.status_stacks().get(condition.status, 0) < threshold: return false
			T.Condition.EventIsCritical:
				if not event.get("critical", false): return false
			T.Condition.EventSourceHasAmmo:
				if source == null or source.ammo_capacity <= 0: return false
			T.Condition.OwnerHealthAtMostPercent:
				if owner == null or DeterministicMath.f32(DeterministicMath.f32(owner.health / owner.maximum_health) * 100) > threshold: return false
			T.Condition.PollutionAtLeast:
				if pollution.value(context.team_id) < threshold: return false
			T.Condition.PollutionAtMost:
				if pollution.value(context.team_id) > threshold: return false
			T.Condition.EventSourceIsOwner:
				if owner == null or source != owner: return false
			T.Condition.EventTargetIsOwner:
				if owner == null or target != owner: return false
			T.Condition.EventSourceIsMinion:
				if source == null or source.kind != CardTypes.Kind.Minion: return false
			T.Condition.EventTargetIsCore:
				if target == null or target.kind != CardTypes.Kind.CoreHero: return false
			T.Condition.OwnerHasStatus:
				if owner == null or not owner.statuses.has(int(condition.get("status", 0))): return false
			T.Condition.EventSourceIsAdjacent:
				if owner == null or source == null or not CombatTargeting.adjacent(owner, source): return false
			T.Condition.EventSourceIsAlly:
				if source == null or source.team_id != context.team_id: return false
			T.Condition.EventSourceIsEnemy:
				if source == null or source.team_id == context.team_id: return false
			T.Condition.EventTargetIsEnemy:
				if target == null or target.team_id == context.team_id: return false
			T.Condition.EventHasKillCredit:
				if event.get("kind", -1) != T.Event.UnitDefeated or event.get("kill_credit", false) != true: return false
	return true

## 队伍宿主在队伍仍有存活载体时有效，整场宿主随本场结束销毁。
static func host_alive(context: Dictionary, cards: Array) -> bool:
	if context.scope == "card": return context.unit.alive() or context.get("death_resolution", false)
	return context.scope == "battle" or cards.any(func(card): return card.team_id == context.team_id and card.alive())
