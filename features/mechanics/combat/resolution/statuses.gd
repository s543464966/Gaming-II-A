class_name CombatStatuses
extends RefCounted
## 状态按类型收录；灼伤与中毒保留每个施加来源的独立周期和毒盾顺序。

const T = preload("res://features/mechanics/contracts/combat_types.gd")

## 灼烧每次施加增加独立层，满层不续旧层；中毒仍按来源刷新并保持毒盾顺序。
static func apply(unit: CombatUnit, status: int, amount: float, duration: float, origin: Dictionary = {}) -> bool:
	if not status in [T.Status.Burn, T.Status.Poison]:
		unit.statuses[status] = {"kind": status, "remaining": maxf(duration, unit.statuses.get(status, {}).get("remaining", 0))}
		return true
	if not unit.statuses.has(status): unit.statuses[status] = {"kind": status, "sources": {}}
	var sources: Dictionary = unit.statuses[status].sources
	var part = str(origin.get("source", {}).get("part_id", "")) + ":" + str(origin.get("action_index", 0))
	var key = AbilitySource.key(origin.get("id", ""), origin.get("source_id", ""), part)
	if status == T.Status.Burn:
		if sources.size() >= MechanicSchema.MAX_BURN_STACKS: return false
		unit.mechanics.status_sequence += 1
		key += ":" + str(unit.mechanics.status_sequence)
	if sources.has(key):
		var current: Dictionary = sources[key]
		if amount >= current.amount: current.origin = origin.duplicate(true)
		current.amount = maxf(current.amount, amount)
		current.remaining = maxf(current.remaining, duration)
		if status == T.Status.Poison and unit.shield <= 0: current.penetrated = true
	else:
		sources[key] = {"amount": amount, "remaining": duration, "next_tick": 1.0,
			"penetrated": status == T.Status.Poison and unit.shield <= 0, "origin": origin.duplicate(true)}
	return true

## 原子取出指定队伍最早施加的完整来源；数量不足时不消费任何状态。
static func take(unit: CombatUnit, kind: int, count: int, team: int) -> Array:
	var sources: Dictionary = unit.statuses.get(kind, {}).get("sources", {})
	var keys: Array = sources.keys().filter(func(key): return team < 0 or sources[key].origin.get("team_id", team) == team)
	if keys.size() < count: return []
	var result: Array = []
	for key in keys.slice(0, count):
		result.append(sources[key].duplicate(true))
		sources.erase(key)
	if sources.is_empty(): unit.statuses.erase(kind)
	return result

## 未结算基础伤害按剩余完整跳数计算，不包含未来暴击或二次成长。
static func remaining_damage(sources: Array) -> float:
	var total: float = 0.0
	for source in sources:
		var ticks: int = maxi(0, int(floorf(source.remaining - source.next_tick + 0.0001)) + 1)
		total += source.amount * ticks
	return total

## 旧盾归零即将当时全部毒来源标记入体，事件补盾不能改变已有判定。
static func breach_poison(unit: CombatUnit) -> void:
	for source in unit.statuses.get(T.Status.Poison, {}).get("sources", {}).values(): source.penetrated = true

## 每个来源只推进有效存续时间，借用同步伤害入口，避免与生命解析器循环依赖。
static func tick(cards: Array, damage: Callable, publish: Callable, card: CombatUnit, delta: float) -> void:
	for kind in card.statuses.keys():
		if not card.statuses.has(kind): continue
		var status: Dictionary = card.statuses[kind]
		if not kind in [T.Status.Burn, T.Status.Poison]:
			status.remaining = DeterministicMath.f32(status.remaining - delta)
			if status.remaining <= 0.0001: card.statuses.erase(kind)
			continue
		for key in status.sources.keys():
			if not status.sources.has(key): continue
			var source_state: Dictionary = status.sources[key]
			var elapsed = minf(delta, source_state.remaining)
			source_state.remaining = DeterministicMath.f32(source_state.remaining - elapsed)
			source_state.next_tick = DeterministicMath.f32(source_state.next_tick - elapsed)
			if source_state.next_tick <= 0.0001 and card.alive():
				source_state.next_tick = DeterministicMath.f32(source_state.next_tick + 1.0)
				var origin: Dictionary = source_state.origin.duplicate(true)
				origin.periodic = true
				var owners = cards.filter(func(unit): return unit.id == origin.get("id", ""))
				var source: Variant = owners[0] if not owners.is_empty() else null
				var poisoned: bool = kind == T.Status.Poison
				if poisoned and card.shield <= 0: source_state.penetrated = true
				damage.call(source, card, source_state.amount, 0, publish, "", origin, poisoned and source_state.penetrated, origin.get("lifesteal_ratio", 0), T.Output.Poison if poisoned else T.Output.Burn)
			if source_state.remaining <= 0.0001: status.sources.erase(key)
		if status.sources.is_empty() and is_same(card.statuses.get(kind), status): card.statuses.erase(kind)
