class_name TriggeredPassives
extends RefCounted
## 单场被动的同步触发、独立冷却、预算与观察结果，不承担效果算法。

const T = preload("res://features/mechanics/contracts/combat_types.gd")
const MAX_TRIGGER_DEPTH = 8
var _chain_rules: Dictionary = {}
var _dispatch_depth: int = 0
var consumed_hosts: Dictionary = {}
var _chain_consumptions: Dictionary = {}
var ledgers: Dictionary = {}
var observations: Dictionary = {}
var progress_states: Dictionary = {}

## 先检查再消耗单个宿主来源的预算，递归无法在记录前重复触发。
func consume(owner_id: String, rule: Dictionary, time: float) -> bool:
	var key = _key(owner_id, rule)
	var second = floori(DeterministicMath.f32(time + DeterministicMath.f32(0.0001)))
	if not ledgers.has(key): ledgers[key] = {"second": second, "second_count": 0, "battle_count": 0, "next_eligible_time": 0.0}
	var ledger: Dictionary = ledgers[key]
	if not ready(owner_id, rule, time): return false
	if ledger.second != second:
		ledger.second = second
		ledger.second_count = 0
	if ledger.battle_count >= rule.max_triggers_per_battle or ledger.second_count >= rule.max_triggers_per_second: return false
	ledger.second_count += 1
	ledger.battle_count += 1
	ledger.next_eligible_time = DeterministicMath.f32(time + float(rule.get("internal_cooldown_seconds", 0.0)))
	return true

## 被动冷却独立于主能力；期间事件不排队，边界到时仍需新的匹配事件。
func ready(owner_id: String, rule: Dictionary, time: float) -> bool:
	return time >= float(ledgers.get(_key(owner_id, rule), {}).get("next_eligible_time", 0.0))

## 记录最近一次相关事件的条件结果，展示不自行推算条件。
func observe(owner_id: String, rule: Dictionary, time: float, matched: bool) -> void:
	var key = _key(owner_id, rule)
	observations[key] = {"last_event_time": time, "condition_met": matched}

## 宿主、来源和局部规则共同标识一次预算。
static func _key(owner_id: String, rule: Dictionary) -> String:
	return AbilitySource.key(owner_id, str(rule.get("source_id", rule.id)), rule.id)

## 无相关事件时显示等待，有事件后显示条件及剩余预算。
func capture(owner_id: String, rules: Array, time: float, alive: bool) -> Array:
	var result: Array = []
	for rule in rules:
		var key = _key(owner_id, rule)
		var ledger: Dictionary = ledgers.get(key, {})
		var state: Dictionary = observations.get(key, {}).duplicate(true)
		var status = "waiting" if state.is_empty() else "condition_passed" if state.condition_met else "condition_failed"
		if not alive: status = "inactive"
		elif ledger.get("battle_count", 0) >= rule.max_triggers_per_battle: status = "battle_limit"
		elif not ready(owner_id, rule, time): status = "internal_cooldown"
		elif ledger.get("second", -1) == floori(DeterministicMath.f32(time + DeterministicMath.f32(0.0001))) and ledger.get("second_count", 0) >= rule.max_triggers_per_second: status = "second_limit"
		state.merge({"id": rule.id, "source_id": str(rule.get("source_id", rule.id)), "source": rule.get("source", {}).duplicate(true), "owner_id": owner_id,
			"execution_kind": CombatTypes.AbilityExecution.TriggeredPassive, "status": status,
			"battle_count": ledger.get("battle_count", 0), "battle_limit": rule.max_triggers_per_battle,
			"internal_cooldown_seconds": rule.get("internal_cooldown_seconds", 0.0),
			"internal_cooldown_remaining": maxf(0.0, float(ledger.get("next_eligible_time", 0.0)) - time)})
		state.progress = progress_states.get(key, {}).duplicate(true)
		result.append(state)
	return result

## 同步深度优先派发；先记录预算再递归，保留事件、宿主和局部能力的稳定顺序。
func dispatch(kind: int, source: Variant, target: Variant, depth: int, cards: Array, hosts: Array, pollution: PollutionMechanic, time: float, executor: CombatActionExecutor, publish: Callable, refresh: Callable, complete: Callable, event: Dictionary = {}) -> void:
	if depth >= MAX_TRIGGER_DEPTH or kind in [T.Event.BattleCompleted, T.Event.ActionReleased]: return
	if _dispatch_depth == 0:
		_chain_rules.clear()
		_chain_consumptions.clear()
	_dispatch_depth += 1
	var invocations: Array = []
	for card in cards:
		var last_words: bool = kind == T.Event.UnitDefeated and card == target
		if not card.alive() and not last_words: continue
		for rule in card.definition.rules:
			if int(rule.trigger_event) != kind: continue
			var context: Dictionary = card.ability_context(rule.get("source_id", rule.id))
			context.death_resolution = last_words
			invocations.append({"context": context, "rule": rule})
	for host in hosts:
		if consumed_hosts.has(host.id): continue
		var context = {"id": host.id, "team_id": host.get("team_id", -1), "scope": host.scope, "unit": null,
			"modifiers": host.get("modifiers", {}), "source_id": "",
			"consumable": host.get("consumable", false), "consumption_group": host.get("consumption_group", "")}
		context.consumption_order = host.get("consumption_order", 0) if context.consumable else -1
		for rule in host.rules:
			if int(rule.trigger_event) != kind: continue
			var specific = context.duplicate()
			specific.source_id = rule.get("source_id", rule.id)
			invocations.append({"context": specific, "rule": rule})
	invocations.sort_custom(func(a, b):
		if a.rule.priority != b.rule.priority: return a.rule.priority < b.rule.priority
		if a.context.get("consumption_order", -1) != b.context.get("consumption_order", -1): return a.context.get("consumption_order", -1) < b.context.get("consumption_order", -1)
		if a.context.id != b.context.id: return a.context.id < b.context.id
		return a.rule.id < b.rule.id)
	for invocation in invocations:
		var context: Dictionary = invocation.context
		var rule: Dictionary = invocation.rule
		if consumed_hosts.has(context.id): continue
		if context.get("consumable", false) and _chain_consumptions.has(context.consumption_group): continue
		var fallback = AbilitySource.for_part(AbilitySource.create("trigger", rule.id, str(rule.get("source_id", rule.id))), rule.id)
		context.source = AbilitySource.for_host(rule.get("source", fallback), context.id)
		var matched = CombatConditions.matches(context, rule.conditions, source, target, pollution, event)
		observe(context.id, rule, time, matched)
		if not CombatConditions.host_alive(context, cards) or not matched: continue
		var chain_key = _key(context.id, rule)
		if _chain_rules.has(chain_key): continue
		if not ready(context.id, rule, time): continue
		if not _advance(context.id, rule, time, event): continue
		if not consume(context.id, rule, time): continue
		if context.get("consumable", false):
			consumed_hosts[context.id] = true
			_chain_consumptions[context.consumption_group] = true
		progress_states.erase(chain_key)
		context.synthetic = event.get("synthetic", false)
		var count = CombatAttributes.multicast(context.unit.definition, rule) if context.unit != null else 1
		_chain_rules[chain_key] = true
		for index in range(count):
			context.cast_index = index + 1
			executor.execute(context, rule.actions, source, target, depth + 1, publish, refresh, complete)
	_dispatch_depth -= 1
	if _dispatch_depth == 0:
		_chain_rules.clear()
		_chain_consumptions.clear()

## 连携按原生事件累计；多重施法追加段和派生回放不充填进度。
func _advance(owner_id: String, rule: Dictionary, time: float, event: Dictionary) -> bool:
	var config: Dictionary = rule.get("progress", {})
	if int(config.get("count", 1)) <= 1: return true
	if event.get("synthetic", false) or int(event.get("cast_index", 1)) > 1: return false
	var key: String = _key(owner_id, rule)
	var state: Dictionary = progress_states.get(key, {"count": 0, "started": time, "sources": []})
	var window: float = float(config.get("window_seconds", 0))
	if window > 0 and time - float(state.started) > window + 0.0001: state = {"count": 0, "started": time, "sources": []}
	var source: String = str(event.get("source", ""))
	if config.get("unique_sources", false) and source in state.sources: return false
	state.sources.append(source)
	state.count += 1
	progress_states[key] = state
	return state.count >= int(config.count)
