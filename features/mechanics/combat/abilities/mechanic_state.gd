class_name MechanicState
extends RefCounted
## 卡牌单场计数、标记、蓄力、守护、连接与临时形态；不进入账号或章节存档。

var counters: Dictionary = {}
var counter_rules: Dictionary = {}
var marks: Dictionary = {}
var links: Dictionary = {}
var guard: Dictionary = {}
var empower: float = 0.0
var empower_remaining: float = 0.0
var heat: int = 0
var downtime: float = 0.0
var last_action: Dictionary = {}
var form: Dictionary = {}
var status_sequence: int = 0

## 标记属于施加队伍，同名标记不让敌方自动取得查询资格。
func marked(team: int, key: String = "") -> bool:
	for mark in marks.values():
		if mark.team == team and (key.is_empty() or mark.key == key): return true
	return false

## 所有时限跟随内核时间；冻结不延长标记、关系或停机时间。
func tick(owner: Variant, delta: float) -> void:
	for key in marks.keys():
		marks[key].remaining -= delta
		if marks[key].remaining <= 0.0001: marks.erase(key)
	for key in links.keys():
		if links[key] <= 0: continue
		links[key] -= delta
		if links[key] <= 0.0001: links.erase(key)
	if not guard.is_empty() and guard.remaining > 0:
		guard.remaining -= delta
		if guard.remaining <= 0.0001: guard.clear()
	if empower_remaining > 0:
		empower_remaining -= delta
		if empower_remaining <= 0.0001: empower = 0.0
	if downtime > 0:
		downtime = maxf(0, downtime - delta)
		if downtime <= 0.0001:
			downtime = 0.0
			heat = 0
	if not form.is_empty():
		CombatMainAbilities.expire_sources(form.slots, delta)
		form.remaining -= delta
		if form.remaining <= 0.0001:
			_restore_form(owner)

## 恢复原形时只撤销形态来源，期间另获的主能力继续保留各自来源和剩余时间。
func _restore_form(owner: Variant) -> void:
	var original: Dictionary = form.slots
	var origin: String = "form:" + owner.id
	for id in owner.main_abilities.slots:
		var current: Dictionary = owner.main_abilities.slots[id]
		current.sources.erase(origin)
		current.source_details.erase(origin)
		if current.sources.is_empty(): continue
		if not original.has(id): original[id] = current
		else:
			for source in current.sources:
				original[id].sources[source] = current.sources[source]
				original[id].source_details[source] = current.source_details[source]
	owner.main_abilities.slots = original
	form.clear()

## 下一次原生主动发动只消费一次蓄力，多重施法共用该次增量。
func spend_empower() -> float:
	var value: float = empower
	empower = 0.0
	empower_remaining = 0.0
	return value

## 表现只读可见事实，不泄露用于恢复原主能力的内部定义。
func capture() -> Dictionary:
	return {"counters": counters.duplicate(true), "marks": marks.values().duplicate(true), "links": links.keys(),
		"guard_charges": guard.get("charges", 0), "empower": empower, "heat": heat, "downtime": downtime,
		"form_main_ability_id": form.get("main_ability_id", ""), "form_remaining": form.get("remaining", 0)}
