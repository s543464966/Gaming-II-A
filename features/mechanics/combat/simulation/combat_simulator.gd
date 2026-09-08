class_name CombatSimulator
extends RefCounted
## 固定步长结算通用战斗输入；模式选择规则，表现只读取事件、状态帧与结果。

const T = preload("res://features/mechanics/contracts/combat_types.gd")
var cards: Array = []
var hosts: Array = []
var events: Array = []
var frames: Array = []
var rules: Dictionary = {}
var main_abilities: Dictionary = {}
var passives: SustainedContributions
var triggers: TriggeredPassives
var pollution: PollutionMechanic
var random: DeterministicRandom
var time: float = 0.0
var actions: CombatActionExecutor
var health: HealthResolution
var running: bool:
	get: return _running
var result: Dictionary:
	get: return _result if not _result.is_empty() else {}
var _running: bool = false
var _result: Dictionary = {}
var _seed: int = 0
var _maximum: float = 0.0
var _delta: float = 0.1
var _initial_health: Dictionary = {}
var _judgment: Dictionary = {}

## 无界面消费者同步驱动同一个分步内核，不另维护第二套战斗循环。
func simulate(request: Dictionary) -> Dictionary:
	cancel()
	begin(request)
	while running: advance(4000)
	return result

## 开始只初始化本场并锁定输入；后续帧预算不参与游戏时钟或随机序列。
func begin(request: Dictionary) -> Array[String]:
	if _running: return ["当前模拟尚未完成，请先取消。"]
	cancel()
	var errors = BattleRequestValidator.validate(request)
	var seed_value: int = request.get("seed", 0) if request.get("seed", 0) is int else 0
	if not errors.is_empty():
		_result = BattleReport.seal({"seed": seed_value, "reason": T.Completion.InvalidRequest, "duration": 0.0, "pollution": 0, "cards": [], "events": [], "frames": [], "errors": errors, "explanation": "战斗输入不符合本场规则。"})
		return errors
	_seed = seed_value
	rules = request.rules.duplicate(true)
	_maximum = float(rules.maximum_duration)
	_delta = DeterministicMath.f32(float(rules.step))
	main_abilities = request.get("main_ability_definitions", {}).duplicate(true)
	for main_ability in main_abilities.values(): main_ability.actions = AbilitySchema.new().decode(main_ability.actions, "actions", main_ability.id, false)
	triggers = TriggeredPassives.new()
	passives = SustainedContributions.new()
	pollution = PollutionMechanic.new(request.get("resources", {}).get("pollution", {}))
	for value in request.cards: cards.append(CombatUnit.new(value, rules.columns))
	hosts = request.get("ability_hosts", []).duplicate(true)
	random = DeterministicRandom.new(seed_value)
	health = HealthResolution.new(cards, random)
	actions = CombatActionExecutor.new(cards, random, pollution, main_abilities, health)
	_refresh_passives()
	if not rules.get("health_judgment", {}).is_empty(): _initial_health = BattleRules.initial_health(cards)
	_publish(T.Event.BattleStarted, null, null, 0, "战斗开始", 0)
	_drain_ready()
	_capture()
	_running = true
	if _complete(): _finish()
	return []

## 每次至少一个完整固定步；预算只在步间让出，绝不截断同步触发链。
func advance(budget_usec: int = 4000, max_steps: int = 128) -> bool:
	if not _running: return not _result.is_empty()
	var deadline: int = Time.get_ticks_usec() + maxi(1, budget_usec)
	for index: int in range(maxi(1, max_steps)):
		if time + 0.0001 >= _maximum or _complete():
			_finish()
			return true
		_step(minf(_delta, _maximum - time))
		_capture()
		if time + 0.0001 >= _maximum or _complete():
			_finish()
			return true
		if Time.get_ticks_usec() >= deadline: break
	return false

## 封存已有帧和事件，不在最后一帧深拷贝整场，也不再捕获第二套最终卡牌。
func _finish() -> void:
	var outcome = BattleRules.outcome(cards, rules)
	if not outcome.finished and time + 0.0001 >= _maximum and not rules.get("health_judgment", {}).is_empty():
		var standings: Array = BattleRules.health_standings(cards, _initial_health, rules.team_ids)
		outcome = BattleRules.judge_health(standings, rules)
		var eliminated: Array = []
		for card: CombatUnit in cards:
			if card.team_id in outcome.defeated_teams and card.alive():
				eliminated.append(card.id)
				card.health = 0.0
				card.shield = 0.0
				card.defeated = true
		_judgment = {"standings": standings, "winner_team": outcome.winner_team, "tied": outcome.tied, "eliminated_ids": eliminated}
		_publish(T.Event.TimeLimitResolved, null, null, 0, "生命裁决", 0, "", {}, _judgment)
	if not outcome.finished and rules.get("survival_team") != null and not rules.survival_team in outcome.defeated_teams:
		outcome.finished = true
		outcome.winner_team = rules.survival_team
	var reason = _reason(outcome)
	_publish(T.Event.BattleCompleted, null, null, 0, T.Completion.keys()[reason], 0)
	_capture()
	var final_frame: Dictionary = frames.back() if not frames.is_empty() else {"cards": cards.map(_card_frame), "host_states": _host_frames()}
	_result = BattleReport.seal({"seed": _seed, "reason": reason, "winner_team": outcome.winner_team, "defeated_teams": outcome.defeated_teams,
		"duration": time, "pollution": pollution.value(rules.view_team), "resources": {"pollution": pollution.capture()},
		"cards": final_frame.cards, "events": events, "frames": frames, "host_states": final_frame.host_states,
		"errors": [], "explanation": _explanation(reason), "judgment": _judgment,
		"time_limit": {"duration": _maximum, "warning_seconds": rules.get("health_judgment", {}).get("warning_seconds", 0.0)}})
	_running = false

## 取消只丢弃单场运行对象，不发布完成或修改已交付的只读战报。
func cancel() -> void:
	_running = false
	_result = {}
	cards = []
	hosts = []
	events = []
	frames = []
	rules = {}
	main_abilities = {}
	passives = null
	triggers = null
	pollution = null
	random = null
	actions = null
	health = null
	time = 0.0
	_initial_health = {}
	_judgment = {}

## 状态先推进，所有单位的到期主能力再按优先级、单位 ID 和主能力 ID 排序。
func _step(delta: float) -> void:
	time = DeterministicMath.f32(roundf(DeterministicMath.f32(time + delta) * 1000.0) / 1000.0)
	var ordered = cards.duplicate()
	ordered.sort_custom(func(a, b): return a.id < b.id)
	for card in ordered:
		if not card.alive(): continue
		CombatStatuses.tick(cards, health.damage, _publish, card, delta)
		if card.alive(): card.tick_abilities(delta)
		_refresh_passives()
	_drain_ready()

## 充能产生的就绪主能力在同一时间结算；同一主能力在一条即时链中最多发动一组。
func _drain_ready() -> void:
	var processed: Dictionary = {}
	while not _complete():
		var ready: Array = []
		for card in cards:
			if not card.can_activate(): continue
			for main_ability_id in card.main_abilities.ready():
				var key = card.id + "|" + main_ability_id
				if not processed.has(key): ready.append({"card": card, "main_ability_id": main_ability_id, "key": key, "priority": card.main_abilities.slots[main_ability_id].definition.priority})
		if ready.is_empty(): break
		ready.sort_custom(func(a, b):
			if a.priority != b.priority: return a.priority < b.priority
			if a.card.id != b.card.id: return a.card.id < b.card.id
			return a.main_ability_id < b.main_ability_id)
		var invocation: Dictionary = ready[0]
		processed[invocation.key] = true
		_activate(invocation.card, invocation.main_ability_id)

## 所有语义事件统一派发，宿主和来源共同决定规则预算。
func _publish(kind: int, source: Variant, target: Variant, value: float, detail: String, depth: int, projectile: String = "", origin: Dictionary = {}, metadata: Dictionary = {}) -> void:
	if kind != T.Event.ActionReleased: _refresh_passives()
	var event = {"sequence": events.size(), "time": time, "kind": kind, "source": source.id if source != null else "",
		"target": target.id if target != null else "", "value": value, "detail": detail, "projectile": projectile,
		"owner_id": origin.get("id", ""), "source_id": origin.get("source_id", ""), "cast_index": origin.get("cast_index", 1), "main_ability_id": origin.get("main_ability_id", ""), "ability_source": origin.get("source", {}).duplicate(true), "grant_sources": origin.get("grant_sources", {}).duplicate(true)}
	event.synthetic = origin.get("synthetic", false)
	event.merge(metadata)
	events.append(event)
	if kind != T.Event.TimeLimitResolved:
		triggers.dispatch(kind, source, target, depth, cards, hosts, pollution, time, actions, _publish, _refresh_passives, _complete, event)
	BattleReport.seal(event)

## 每项主能力独立施放，发动事件明确携带主能力来源。
func _activate(actor: CombatUnit, main_ability_id: String) -> void:
	var context = actor.ability_context("main_ability:" + main_ability_id)
	context.main_ability_id = main_ability_id
	context.source = AbilitySource.for_host(AbilitySource.for_part(AbilitySource.create("main_ability", main_ability_id, actor.id + ":main_ability:" + main_ability_id), main_ability_id), actor.id)
	context.grant_sources = actor.main_abilities.slots[main_ability_id].source_details.duplicate(true)
	_publish(T.Event.MainAbilityCooldownReady, actor, actor, 0, main_ability_id, 0, "", context)
	if not actor.can_activate() or not main_ability_id in actor.main_abilities.ready(): return
	_publish(T.Event.BeforeMainAbilityCast, actor, actor, 0, main_ability_id, 0, "", context)
	if not actor.can_activate() or not main_ability_id in actor.main_abilities.ready(): return
	var active: Dictionary = actor.main_abilities.slots[main_ability_id].definition
	var count = CombatAttributes.multicast(actor.definition, active)
	context.empower_multiplier = 1.0 + actor.mechanics.spend_empower()
	context.synthetic = active.get("copied", false)
	if actor.ammo_capacity > 0: actor.ammo_remaining -= 1
	# 先开始新周期，再执行自身充能，避免收益被重置覆盖。
	actor.main_abilities.reset(main_ability_id)
	for index in range(count):
		if not actor.alive() or actor.blocked() or _complete(): break
		context.cast_index = index + 1
		actions.execute(context, active.actions, actor, actor, 0, _publish, _refresh_passives, _complete, true)
		_publish(T.Event.AfterMainAbilityCast, actor, actor, 0, main_ability_id, 0, "", context)
		var neighbors = cards.filter(func(card): return card.alive() and card.team_id == actor.team_id and card != actor and CombatTargeting.adjacent(card, actor))
		neighbors.sort_custom(func(a, b): return a.id < b.id)
		for neighbor in neighbors: _publish(T.Event.AdjacentMainAbilityCast, actor, neighbor, 0, main_ability_id, 0, "", context)
		var linked: Array = cards.filter(func(card): return card.alive() and card.team_id == actor.team_id and card.mechanics.links.has(actor.id))
		linked.sort_custom(func(a, b): return a.id < b.id)
		for watcher in linked: _publish(T.Event.LinkedMainAbilityCast, actor, watcher, 0, main_ability_id, 0, "", context)

## 完成条件只来自本场规则，不查找固定玩家英雄。
func _complete() -> bool:
	return (health == null or health.resolution_depth == 0) and BattleRules.outcome(cards, rules).finished

## 根据结果视角生成通用完成原因，超时目标由模式显式声明。
func _reason(outcome: Dictionary) -> int:
	if not outcome.finished: return T.Completion.Timeout
	if outcome.winner_team == null: return T.Completion.Draw
	return T.Completion.Victory if outcome.winner_team == rules.view_team else T.Completion.Defeat

## 同一时间只保留最终状态帧，同时记录机制资源。
func _capture() -> void:
	if not frames.is_empty() and frames.back().time == time: frames.pop_back()
	var frame: Dictionary = {"time": time, "cards": cards.map(_card_frame), "host_states": _host_frames(), "resources": {"pollution": pollution.capture()}}
	if not _initial_health.is_empty():
		frame.health_standings = _judgment.standings if not _judgment.is_empty() else BattleRules.health_standings(cards, _initial_health, rules.team_ids)
	frames.append(BattleReport.seal(frame))

## 通用结果只描述完成原因，奖励和章节推进归对应模式。
func _explanation(reason: int) -> String:
	match reason:
		T.Completion.Victory: return "本队在 %.1f 秒内达成本场胜利条件。" % time
		T.Completion.Defeat: return "本队触发了本场失败条件。"
		T.Completion.Draw: return "本场双方同时触发失败条件，结果为平局。"
		_: return "自动战斗达到本场时间上限。"

## 状态写入后统一刷新可逆贡献，表现和模式不参与条件判定。
func _refresh_passives() -> void:
	if passives != null: passives.refresh(cards, hosts, pollution)

## 每张卡的被动观察结果来自运行模块，独立于静态规则说明。
func _card_frame(card: CombatUnit) -> Dictionary:
	var result = card.capture()
	result.ability_states = triggers.capture(card.id, card.definition.rules, time, card.alive()) + passives.capture(card.id)
	return result

## 队伍和整场能力也有可追踪状态，不伪装成卡牌字段。
func _host_frames() -> Array:
	var result: Array = []
	for host in hosts:
		result.append({"id": host.id, "scope": host.scope, "team_id": host.get("team_id", -1), "consumed": triggers.consumed_hosts.has(host.id), "ability_states": triggers.capture(host.id, host.rules, time, CombatConditions.host_alive(host, cards)) + passives.capture(host.id)})
	return result

## 模式可提交已触发的一次性来源，读取不推进战斗或暴露可变账本。
func consumed_source_ids() -> Array:
	return triggers.consumed_hosts.keys() if triggers != null else []
