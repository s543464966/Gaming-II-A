class_name MechanicActions
extends RefCounted
## 组合机制共用基础效果与生命结算；只借用执行器，不持有反向引用。

const T = preload("res://features/mechanics/contracts/combat_types.gd")

## 成本、状态和关系先原子落地，再执行受限子效果。
static func execute(executor: Variant, context: Dictionary, target: CombatUnit, action: Dictionary, depth: int, publish: Callable, refresh: Callable, complete: Callable, activation: bool) -> void:
	if depth >= TriggeredPassives.MAX_TRIGGER_DEPTH: return
	var owner: CombatUnit = context.get("unit")
	if owner == null: return
	var parameters: Dictionary = action.get("parameters", {})
	var amount: float = float(action.get("amount", 0))
	var duration: float = float(action.get("duration_seconds", 0))
	match int(action.kind):
		T.CombatAction.Accumulate:
			var previous: int = int(target.mechanics.counters.get(parameters.key, 0))
			var current: int = mini(int(parameters.limit), previous + int(amount))
			target.mechanics.counter_rules[parameters.key] = {"threshold": int(parameters.threshold), "limit": int(parameters.limit)}
			target.mechanics.counters[parameters.key] = current
			_counter_event(context, target, parameters.key, previous, depth, publish)
		T.CombatAction.Detonate:
			var consumed: Array = CombatStatuses.take(target, T.Status.Burn, int(parameters.count), owner.team_id)
			if consumed.is_empty(): return
			var burst: float = CombatStatuses.remaining_damage(consumed) * float(parameters.multiplier)
			executor.health.damage(owner, target, burst, depth, publish, "", context, false, 0, T.Output.Burn)
		T.CombatAction.Mark:
			target.mechanics.marks[str(owner.team_id) + ":" + parameters.key] = {"team": owner.team_id, "key": parameters.key, "remaining": duration}
			publish.call(T.Event.MarkApplied, owner, target, duration, "标记", depth, "", context, {"mark_key": parameters.key})
		T.CombatAction.Empower:
			if target.team_id != owner.team_id: return
			target.mechanics.empower = minf(float(parameters.limit), target.mechanics.empower + amount)
			target.mechanics.empower_remaining = duration
		T.CombatAction.Guard:
			if target.team_id != owner.team_id: return
			target.mechanics.guard = {"charges": int(amount), "remaining": duration}
		T.CombatAction.Link:
			if target == owner or target.team_id != owner.team_id: return
			owner.mechanics.links[target.id] = duration
		T.CombatAction.Convert:
			var previous: int = int(target.mechanics.counters.get(parameters.key, 0))
			if target.team_id != owner.team_id or not _pay(target, parameters.resource, parameters.key, int(amount)): return
			if parameters.resource == "Shield" and target.shield <= 0: CombatStatuses.breach_poison(target)
			if parameters.resource == "Counter": _counter_event(context, target, parameters.key, previous, depth, publish)
			_payload(executor, context, parameters.payload, owner, target, depth, publish, refresh, complete, activation)
		T.CombatAction.Transfer:
			var before_owner: int = int(owner.mechanics.counters.get(parameters.key, 0))
			var before_target: int = int(target.mechanics.counters.get(parameters.key, 0))
			if not _transfer(owner, target, parameters, int(amount)): return
			if parameters.resource == "Counter":
				_counter_event(context, owner, parameters.key, before_owner, depth, publish)
				_counter_event(context, target, parameters.key, before_target, depth, publish)
		T.CombatAction.Sacrifice:
			if target == owner or target.team_id != owner.team_id or target.kind != CardTypes.Kind.Minion: return
			executor.health.resolution_depth += 1
			executor.health.defeat(owner, target, depth, publish, context, "sacrifice")
			_payload(executor, context, parameters.payload, owner, target, depth, publish, refresh, complete, activation)
			executor.health.resolution_depth -= 1
		T.CombatAction.Overload:
			if target.kind != CardTypes.Kind.ItemCard or target.team_id != owner.team_id or target.mechanics.downtime > 0: return
			target.mechanics.heat += int(amount)
			if target.mechanics.heat >= int(parameters.limit): target.mechanics.downtime = float(parameters.recovery_seconds)
			_payload(executor, context, parameters.payload, owner, target, depth, publish, refresh, complete, activation)
		T.CombatAction.Chain:
			_chain(executor, context, target, parameters, depth, publish, activation, action.get("target_tags", {}))
		T.CombatAction.Echo:
			if context.get("synthetic", false) or target.mechanics.last_action.is_empty(): return
			var snapshot: Dictionary = target.mechanics.last_action
			var replay: Dictionary = context.duplicate()
			replay.synthetic = true
			replay.fixed_amount = float(snapshot.amount) * float(parameters.multiplier)
			replay.damage_stats = snapshot.damage_stats.duplicate(true)
			_payload(executor, replay, [snapshot.action], owner, target, depth, publish, refresh, complete, false)
		T.CombatAction.CopyMainAbility:
			if not _copy(executor, owner, target, action, context): return
		T.CombatAction.Transform:
			if not _transform(executor, owner, target, action, context): return
	refresh.call()
	publish.call(T.Event.MechanicResolved, owner, target, amount, T.CombatAction.keys()[int(action.kind)], depth, "", context, {"mechanic": int(action.kind)})

## 子效果沿用事件宿主和来源，嵌套深度与事件递归共用上限。
static func _payload(executor: Variant, context: Dictionary, payload: Array, source: CombatUnit, target: CombatUnit, depth: int, publish: Callable, refresh: Callable, complete: Callable, activation: bool) -> void:
	executor.execute(context, payload, source, target, depth + 1, publish, refresh, complete, activation)

## 转化不能透支，支付生命至少保留一点；成本不受输出加成或暴击影响。
static func _pay(target: CombatUnit, resource: String, key: String, cost: int) -> bool:
	match resource:
		"Shield":
			if target.shield < cost: return false
			target.shield -= cost
		"Health":
			if target.health <= cost: return false
			target.health -= cost
		"Ammo":
			if target.kind != CardTypes.Kind.ItemCard or target.ammo_remaining < cost: return false
			target.ammo_remaining -= cost
		"Counter":
			if int(target.mechanics.counters.get(key, 0)) < cost: return false
			target.mechanics.counters[key] -= cost
		_: return false
	return true

## 传递现有资源或完整状态层，不新建强度、不刷新计时；容量不足整次取消。
static func _transfer(owner: CombatUnit, target: CombatUnit, parameters: Dictionary, amount: int) -> bool:
	if owner == target: return false
	var resource: String = parameters.resource
	if resource in ["Shield", "Counter"]:
		if resource == "Counter" and int(target.mechanics.counters.get(parameters.key, 0)) + amount > int(target.mechanics.counter_rules.get(parameters.key, {}).get("limit", 100)): return false
		if target.team_id != owner.team_id or not _pay(owner, resource, parameters.key, amount): return false
		if resource == "Shield":
			target.shield += amount
			if owner.shield <= 0: CombatStatuses.breach_poison(owner)
		else: target.mechanics.counters[parameters.key] = int(target.mechanics.counters.get(parameters.key, 0)) + amount
		return true
	var status: int = T.Status.Burn if resource == "Burn" else T.Status.Poison
	var existing: Dictionary = target.statuses.get(status, {}).get("sources", {})
	if status == T.Status.Burn and existing.size() + amount > MechanicSchema.MAX_BURN_STACKS: return false
	var layers: Array = CombatStatuses.take(owner, status, amount, -1)
	if layers.is_empty(): return false
	if not target.statuses.has(status): target.statuses[status] = {"sources": {}}
	for layer in layers:
		target.mechanics.status_sequence += 1
		if status == T.Status.Poison: layer.penetrated = target.shield <= 0
		target.statuses[status].sources["transfer:%s:%d" % [owner.id, target.mechanics.status_sequence]] = layer
	return true

## 连锁每跳只找目标同队的未命中单位，按直线距离及 ID 排序并逐跳衰减。
static func _chain(executor: Variant, context: Dictionary, first: CombatUnit, parameters: Dictionary, depth: int, publish: Callable, activation: bool, tag_query: Dictionary = {}) -> void:
	var current: CombatUnit = first
	var visited: Array = []
	var scale: float = 1.0
	for hop in range(int(parameters.jumps)):
		if current == null: break
		visited.append(current.id)
		var child: Dictionary = context.duplicate()
		child.synthetic = true
		child.action_scale = float(context.get("action_scale", 1.0)) * scale
		executor.apply_action(child, current, parameters.payload[0], depth + 1, activation, hop, publish)
		scale *= float(parameters.multiplier)
		var candidates: Array = executor.cards.filter(func(card): return card.alive() and card.team_id == first.team_id and not card.id in visited and CardTagQuery.matches(card.definition.get("card_tag_ids", []), tag_query) and CardTagQuery.matches(card.definition.get("card_tag_ids", []), parameters.payload[0].get("target_tags", {})))
		candidates.sort_custom(func(a, b): return a.id < b.id if CombatTargeting.distance_squared(current, a) == CombatTargeting.distance_squared(current, b) else CombatTargeting.distance_squared(current, a) < CombatTargeting.distance_squared(current, b))
		current = candidates[0] if not candidates.is_empty() else null

## 复制白名单主能力快照，独立冷却与时限；重复同来源只续期，不重置冷却。
static func _copy(executor: Variant, owner: CombatUnit, target: CombatUnit, action: Dictionary, context: Dictionary) -> bool:
	if target.team_id != owner.team_id or context.get("synthetic", false): return false
	var main_ability: Dictionary = executor.main_ability_definitions.get(action.main_ability_id, {}).duplicate(true)
	if main_ability.is_empty() or not MechanicSchema.snapshot_supported(T.CombatAction.CopyMainAbility, main_ability.actions): return false
	var origin: String = AbilitySource.key(owner.id, context.source_id, str(context.get("source", {}).get("part_id", "")) + ":copy:" + str(context.get("action_index", 0)))
	main_ability.id = "copy:" + origin + ":" + action.main_ability_id
	var copies: Dictionary = {}
	for slots in [target.main_abilities.slots, target.mechanics.form.get("slots", {})]:
		for id in slots:
			if slots[id].definition.get("copied", false): copies[id] = true
	if not copies.has(main_ability.id) and copies.size() >= 8: return false
	main_ability.content_id = action.main_ability_id
	main_ability.copied = true
	main_ability.source = context.get("source", {}).duplicate(true)
	for child in MechanicSchema.flatten(main_ability.actions):
		if T.output_kind(child) != T.Output.Special:
			child.amount = CombatAttributes.action_amount(owner.definition, child, float(owner.definition.get("main_ability_strength_multiplier", 1))) * float(action.parameters.multiplier)
			child.power_multiplier = 0.0
			child.snapshot_amount = child.amount
	main_ability.multicast_count = 1
	target.main_abilities.grant(main_ability, origin, float(action.duration_seconds))
	return true

## 首版变形是临时主能力形态，保留载体、战损、弹药和原冷却，不重建单位。
static func _transform(executor: Variant, owner: CombatUnit, target: CombatUnit, action: Dictionary, context: Dictionary) -> bool:
	if target.team_id != owner.team_id: return false
	if not target.mechanics.form.is_empty():
		if target.mechanics.form.main_ability_id != action.main_ability_id or target.mechanics.form.remaining >= float(action.duration_seconds): return false
		target.mechanics.form.remaining = float(action.duration_seconds)
		return true
	var main_ability: Dictionary = executor.main_ability_definitions.get(action.main_ability_id, {}).duplicate(true)
	if main_ability.is_empty() or not MechanicSchema.snapshot_supported(T.CombatAction.Transform, main_ability.actions): return false
	target.mechanics.form = {"slots": target.main_abilities.slots, "main_ability_id": action.main_ability_id, "remaining": float(action.duration_seconds)}
	target.main_abilities.slots = {}
	main_ability.source = context.get("source", {}).duplicate(true)
	target.main_abilities.grant(main_ability, "form:" + target.id)
	return true

## 积累、支付和传递共用计数事件，未变化或未跨线不重复触发。
static func _counter_event(context: Dictionary, target: CombatUnit, key: String, previous: int, depth: int, publish: Callable) -> void:
	var current: int = int(target.mechanics.counters.get(key, 0))
	if current == previous: return
	var threshold: int = int(target.mechanics.counter_rules.get(key, {}).get("threshold", 0))
	publish.call(T.Event.CounterChanged, context.unit, target, current - previous, "计数变化", depth, "", context, {"counter_key": key, "counter_value": current})
	if threshold > 0 and previous < threshold and current >= threshold:
		publish.call(T.Event.CounterThresholdReached, context.unit, target, current, "达到阈值", depth, "", context, {"counter_key": key})
