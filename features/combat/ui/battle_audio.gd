class_name BattleAudioPresenter
extends RefCounted
## 将只读战报语义映射成限频音效，不参与模拟或修改回放状态。

const T = preload("res://features/mechanics/contracts/combat_types.gd")
const OUTPUT_CUES: Array[String] = [
	"sfx.combat.physical", "sfx.combat.witchcraft", "sfx.combat.burn", "sfx.combat.poison",
	"sfx.combat.healing", "sfx.combat.shield", "sfx.combat.physical"
]
const MINIMUM_GAPS: Dictionary[String, int] = {
	"sfx.combat.cast": 240, "sfx.combat.physical": 110, "sfx.combat.witchcraft": 130,
	"sfx.combat.burn": 260, "sfx.combat.poison": 260, "sfx.combat.healing": 180,
	"sfx.combat.shield": 180, "sfx.combat.status": 300,
}
var service: AudioService
var _last_played: Dictionary[String, int] = {}
var _pending: Dictionary = {}
var _revision: int = 0
var _last_output: int = -1000
var _last_priority: int = 0
var _completed: bool = false

## 新战斗绑定同一应用服务，并清空上一场的限频窗口。
func configure(audio: AudioService) -> void:
	service = audio
	reset()

## 清除待播事件与局部尾音，取消旧代次回调，不影响全局音乐。
func reset() -> void:
	_revision += 1
	_last_played.clear()
	_pending.clear()
	_last_output = -1000
	_last_priority = 0
	_completed = false
	if is_instance_valid(service): service.stop_sfx("sfx.combat.")

## 同一画面帧只保留最重要的反馈；同优先级选择数值较大的命中。
func play_event(event: Dictionary) -> void:
	if not is_instance_valid(service) or _completed: return
	var cue := _cue(event)
	if cue.is_empty(): return
	var priority := _priority(cue)
	var weight := absf(float(event.get("value", 0.0)))
	if _pending.is_empty(): _flush.call_deferred(_revision)
	elif priority < _pending.priority or (priority == _pending.priority and weight <= _pending.weight): return
	_pending = {"cue": cue, "priority": priority, "weight": weight}

## 使用真实时间限制跨类别密度，加速回放不压缩听觉间隔，也不排队补播旧命中。
func _flush(revision: int) -> void:
	if revision != _revision or _pending.is_empty(): return
	var cue: String = _pending.cue
	var priority: int = _pending.priority
	_pending.clear()
	if not is_instance_valid(service): return
	var now := Time.get_ticks_msec()
	var gap := 90 if priority >= 4 else 125
	if priority > _last_priority: gap = 45
	if now - _last_output < gap or now - _last_played.get(cue, -1000) < MINIMUM_GAPS.get(cue, 100): return
	_last_played[cue] = now
	_last_output = now
	_last_priority = priority
	service.play_sfx(cue, -3.0 if priority >= 4 else (-9.0 if priority <= 1 else -6.0))

## 核心受损与退场先于普通命中，施法和状态只占用空闲的声音空间。
func _priority(cue: String) -> int:
	match cue:
		"sfx.combat.core_damage": return 6
		"sfx.combat.unit_defeat": return 5
		"sfx.combat.critical", "sfx.combat.start": return 4
		"sfx.combat.physical", "sfx.combat.witchcraft": return 3
		"sfx.combat.burn", "sfx.combat.poison", "sfx.combat.healing", "sfx.combat.shield": return 2
	return 1

## 完整命中表现结束后才播放胜负标志音，不提前泄露战报结果。
func play_completion(result: Dictionary) -> void:
	if not is_instance_valid(service) or _completed: return
	reset()
	_completed = true
	service.play_sfx("sfx.combat.victory" if result.get("reason") == T.Completion.Victory else "sfx.combat.defeat", -3.0)

## 稳定事件契约决定声音类别，诊断字符串不参与映射。
func _cue(event: Dictionary) -> String:
	match int(event.get("kind", -1)):
		T.Event.BattleStarted: return "sfx.combat.start"
		T.Event.BeforeMainAbilityCast: return "sfx.combat.cast"
		T.Event.DamageResolved:
			if float(event.get("value", 0.0)) <= 0.0: return "sfx.combat.shield"
			if event.get("critical", false): return "sfx.combat.critical"
			var output := clampi(int(event.get("output_type", T.Output.Physical)), 0, OUTPUT_CUES.size() - 1)
			return OUTPUT_CUES[output]
		T.Event.HealingResolved: return "sfx.combat.healing"
		T.Event.ShieldGained, T.Event.DamageGuarded: return "sfx.combat.shield"
		T.Event.StatusApplied, T.Event.MarkApplied: return "sfx.combat.status"
		T.Event.UnitDefeated: return "sfx.combat.unit_defeat"
		T.Event.CoreDamaged: return "sfx.combat.core_damage"
	return ""
