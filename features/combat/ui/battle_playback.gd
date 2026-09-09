class_name BattlePlayback
extends RefCounted
## 确定性战报的只读回放时钟；不在动画回调中结算伤害。

signal projectile_launched(event: Dictionary)
signal event_cued(event: Dictionary)
signal event_played(event: Dictionary)
signal frame_played(frame: Dictionary)
signal cooldowns_sampled(progress: Dictionary)
signal completed(result: Dictionary)
const T = preload("res://features/mechanics/contracts/combat_types.gd")
const FLIGHT_SECONDS = 0.24
const DEFEAT_TAIL_SECONDS = 0.42
const EFFECT_TAIL_SECONDS = 0.82
var result: Dictionary = {}
var presentation_time: float = 0
var playback_time: float = 0
var running: bool = false
var impact_delay: float = 0
var tail_delay: float = 0
var _event: int = 0
var _frame: int = 0
var _projectile: int = 0

## 只读战报按契约共享；外部可变战报先复制封存，下一次 tick 才发出表现事件。
func start(completed_battle: Dictionary) -> String:
	if running: return "已有一场自动战斗正在回放。"
	reset()
	if completed_battle.get("reason") == T.Completion.InvalidRequest: return "\n".join(completed_battle.get("errors", []))
	if not completed_battle.get("reason") in T.Completion.values() or not completed_battle.get("events") is Array or not completed_battle.get("frames") is Array or not (completed_battle.get("duration") is float or completed_battle.get("duration") is int): return "回放需要完整的已结算战报。"
	result = completed_battle if completed_battle.is_read_only() else BattleReport.seal(completed_battle.duplicate(true))
	impact_delay = FLIGHT_SECONDS if result.events.any(func(event): return not event.projectile.is_empty()) else 0.0
	for event in result.events:
		var kind := int(event.get("kind", -1))
		var tail := DEFEAT_TAIL_SECONDS if kind == T.Event.UnitDefeated else 0.0
		if kind in [T.Event.ActionReleased, T.Event.DamageResolved, T.Event.HealingResolved, T.Event.ShieldGained, T.Event.StatusApplied]: tail = EFFECT_TAIL_SECONDS
		tail_delay = maxf(tail_delay, float(event.time) + tail - float(result.duration))
	running = true
	return ""

## 回放暂停时不推进弹道、状态帧、伤害事件或胜负通知。
func tick(delta: float) -> void:
	if not running or delta <= 0: return
	var identity = result
	var advanced = presentation_time + delta
	var presentation_duration: float = result.duration + impact_delay + tail_delay
	var reached_end = advanced >= presentation_duration
	presentation_time = presentation_duration if reached_end else advanced
	playback_time = minf(float(result.duration), maxf(0, presentation_time - impact_delay))
	while _projectile < result.events.size() and result.events[_projectile].time <= presentation_time:
		var event: Dictionary = result.events[_projectile]
		_projectile += 1
		event_cued.emit(event)
		if not is_same(identity, result) or not running: return
		if not event.projectile.is_empty() and presentation_time < event.time + impact_delay: projectile_launched.emit(event)
		if not is_same(identity, result) or not running: return
	if presentation_time < impact_delay: return
	while _event < result.events.size() and result.events[_event].time <= playback_time:
		var event: Dictionary = result.events[_event]
		_event += 1
		event_played.emit(event)
		if not is_same(identity, result) or not running: return
	while _frame < result.frames.size() and result.frames[_frame].time <= playback_time:
		var frame: Dictionary = result.frames[_frame]
		_frame += 1
		frame_played.emit(frame)
		if not is_same(identity, result) or not running: return
	cooldowns_sampled.emit(_sample_cooldowns())
	if not is_same(identity, result) or not running: return
	if reached_end:
		running = false
		completed.emit(result)

## 提示只读取已播放帧及同一战斗时钟，不泄露未来裁决结果。
func judgment_status() -> Dictionary:
	var limit: Dictionary = result.get("time_limit", {})
	var warning: float = float(limit.get("warning_seconds", 0.0))
	var duration: float = float(limit.get("duration", 0.0))
	if not running or warning <= 0 or _frame == 0 or playback_time + 0.00001 < duration - warning: return {}
	return {"remaining": maxi(0, ceili(duration - playback_time - 0.00001)),
		"standings": result.frames[_frame - 1].get("health_standings", [])}

## 从已结算的相邻状态帧采样连续冷却，不预测后续技能或为数值插帧。
func _sample_cooldowns() -> Dictionary:
	if _frame == 0: return {}
	var current: Dictionary = result.frames[_frame - 1]
	var next: Dictionary = result.frames[_frame] if _frame < result.frames.size() else current
	var span: float = next.time - current.time
	var weight = clampf((playback_time - current.time) / span, 0.0, 1.0) if span > 0.0 else 0.0
	var upcoming: Dictionary = {}
	for card in next.get("cards", []): upcoming[card.id] = card
	var casts: Dictionary = {}
	for index in range(_event, result.events.size()):
		var event: Dictionary = result.events[index]
		if event.time > next.time: break
		if event.get("kind") == T.Event.AfterMainAbilityCast:
			var actor: String = event.get("source", "")
			if not casts.has(actor): casts[actor] = []
			casts[actor].append(event.get("main_ability_id", ""))
	var progress: Dictionary = {}
	for card in current.get("cards", []):
		var duration: float = float(card.get("cooldown", 0.0)) if card.get("cooldown") != null else 0.0
		if duration <= 0.0 or card.get("defeated", false): continue
		var remaining: float = card.remaining
		var following: Dictionary = upcoming.get(card.id, {})
		var main_abilities: Array = card.get("main_abilities", [])
		var next_main_abilities: Array = following.get("main_abilities", [])
		var same_main_ability = not main_abilities.is_empty() and not next_main_abilities.is_empty() and main_abilities[0].id == next_main_abilities[0].id
		if same_main_ability and following.get("cooldown") == duration and not following.get("defeated", false):
			var decrease: float = remaining - float(following.remaining)
			# 只连接正常递减；重置、延迟、周期变化和明显充能跳变在实际帧到达时生效。
			if decrease >= 0.0 and decrease <= span + 0.0001:
				remaining = lerpf(remaining, float(following.remaining), weight)
			elif main_abilities[0].id in casts.get(card.id, []) and remaining <= span + 0.0001:
				# 已结算施放确认旧周期结束，先扫到最底部；施放帧到达后才从顶部重启。
				remaining = lerpf(remaining, 0.0, weight)
		progress[card.id] = clampf(1.0 - remaining / duration, 0.0, 1.0)
	return progress

## 退出或重开清除结果，阻止残余回调进入下一场。
func reset() -> void:
	result = {}
	presentation_time = 0
	playback_time = 0
	running = false
	impact_delay = 0
	tail_delay = 0
	_event = 0
	_frame = 0
	_projectile = 0
