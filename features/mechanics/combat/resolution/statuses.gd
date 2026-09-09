class_name CombatStatuses
extends RefCounted
## 灼烧与中毒按整数层数结算，来源批次只用于伤害归属；控制状态独立计时。

const T = preload("res://features/mechanics/contracts/combat_types.gd")

## 每次施加追加层数且不重置跳点；持续时间仅用于控制状态。
static func apply(unit: CombatUnit, status: int, amount: float, duration: float, origin: Dictionary = {}) -> bool:
	if not status in [T.Status.Burn, T.Status.Poison]:
		if status == T.Status.None or duration <= 0: return false
		unit.statuses[status] = {"kind": status, "remaining": maxf(duration, unit.statuses.get(status, {}).get("remaining", 0))}
		return true
	var stacks: int = int(CombatAttributes.points(amount))
	if stacks <= 0: return false
	_append(unit, status, [{"stacks": stacks, "origin": origin.duplicate(true)}], 1.0)
	return true

## 按施加顺序原子取出指定队伍的层数，支持拆分来源批次；不足时完全不消费。
static func take(unit: CombatUnit, kind: int, count: int, team: int) -> Array:
	var sources: Dictionary = unit.statuses.get(kind, {}).get("sources", {})
	var keys: Array = sources.keys().filter(func(key): return team < 0 or sources[key].origin.get("team_id", team) == team)
	var available: int = 0
	for key in keys: available += int(sources[key].stacks)
	if count <= 0 or available < count: return []
	var result: Array = []
	var remaining: int = count
	for key in keys:
		var taken: Dictionary = sources[key].duplicate(true)
		taken.stacks = mini(remaining, int(taken.stacks))
		result.append(taken)
		sources[key].stacks -= taken.stacks
		remaining -= taken.stacks
		if sources[key].stacks == 0: sources.erase(key)
		if remaining == 0: break
	if sources.is_empty(): unit.statuses.erase(kind)
	return result

## 转移真实层数及来源；新状态继承原跳点，已有状态保持自身节奏。
static func transfer(owner: CombatUnit, target: CombatUnit, kind: int, count: int) -> bool:
	if owner == target: return false
	var next_tick: float = owner.statuses.get(kind, {}).get("next_tick", 1.0)
	var batches: Array = take(owner, kind, count, -1)
	if batches.is_empty(): return false
	_append(target, kind, batches, next_tick)
	return true

## 来源按批保存，层数再多也不为每一层创建独立对象或计时器。
static func _append(unit: CombatUnit, kind: int, batches: Array, next_tick: float) -> void:
	if not unit.statuses.has(kind): unit.statuses[kind] = {"kind": kind, "sources": {}, "next_tick": next_tick}
	for batch: Dictionary in batches:
		unit.mechanics.status_sequence += 1
		unit.statuses[kind].sources[unit.mechanics.status_sequence] = batch

## 每个状态共用一秒跳点；灼烧消耗总层数的一半向上取整，中毒不衰减。
static func tick(cards: Array, damage: Callable, publish: Callable, card: CombatUnit, delta: float) -> void:
	if not card.alive(): return
	for kind in card.statuses.keys():
		if not card.statuses.has(kind): continue
		var status: Dictionary = card.statuses[kind]
		if not kind in [T.Status.Burn, T.Status.Poison]:
			status.remaining = DeterministicMath.f32(status.remaining - delta)
			if status.remaining <= 0.0001: card.statuses.erase(kind)
			continue
		status.next_tick = DeterministicMath.f32(status.next_tick - delta)
		while status.next_tick <= 0.0001 and card.alive() and is_same(card.statuses.get(kind), status):
			status.next_tick = DeterministicMath.f32(status.next_tick + 1.0)
			var batches: Array
			if kind == T.Status.Burn:
				var stacks: int = card.status_stacks()[kind]
				@warning_ignore("integer_division")
				var consumed: int = stacks / 2 + stacks % 2
				batches = take(card, kind, consumed, -1)
			else:
				batches = status.sources.values().duplicate(true)
			for batch: Dictionary in batches:
				if not card.alive(): break
				var origin: Dictionary = batch.origin.duplicate(true)
				origin.periodic = true
				var owners: Array = cards.filter(func(unit): return unit.id == origin.get("id", ""))
				var source: Variant = owners[0] if not owners.is_empty() else null
				damage.call(source, card, batch.stacks, 0, publish, "", origin, origin.get("lifesteal_ratio", 0), T.Output.Poison if kind == T.Status.Poison else T.Output.Burn)
