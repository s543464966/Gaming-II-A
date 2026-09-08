class_name CombatMainAbilities
extends RefCounted
## 单位的多主能力与授予来源；同主能力共用冷却，最后一个来源移除时撤销。

var slots: Dictionary = {}
var modifiers: CombatModifiers
var base_haste: float

## 基础主能力与附着授予使用同一实例模型，零时长表示来源存在期间持续有效。
func _init(definitions: Array = [], bonuses: Dictionary = {}, haste: float = 0.0, ledger: CombatModifiers = null) -> void:
	modifiers = ledger if ledger != null else CombatModifiers.new(bonuses)
	base_haste = haste
	for main_ability in definitions:
		grant(main_ability, main_ability.get("source_id", "base:" + main_ability.id), float(main_ability.get("duration_seconds", 0)))

## 重复来源刷新时长，不复制主能力或重置已经推进的冷却。
func grant(main_ability: Dictionary, source_id: String, duration: float = 0) -> void:
	if not slots.has(main_ability.id):
		slots[main_ability.id] = {"definition": main_ability.duplicate(true), "remaining": _cooldown(main_ability), "cooldown": _cooldown(main_ability), "sources": {}, "source_details": {}}
	slots[main_ability.id].source_details[source_id] = main_ability.get("source", {"content_id": main_ability.id, "source_kind": "main_ability", "part_id": main_ability.id}).duplicate(true)
	var sources: Dictionary = slots[main_ability.id].sources
	if not sources.has(source_id): sources[source_id] = duration
	elif sources[source_id] == 0 or duration == 0: sources[source_id] = 0.0
	else: sources[source_id] = maxf(sources[source_id], duration)

## 只撤销指定来源，其余基础或附着授予仍保留主能力。
func revoke_source(source_id: String) -> void:
	for id in slots.keys():
		slots[id].sources.erase(source_id)
		slots[id].source_details.erase(source_id)
		if slots[id].sources.is_empty(): slots.erase(id)

## 只推进授予和冷却；修正账本由宿主先推进，控制只限制主动冷却。
func tick(delta: float, blocked: bool, slow: bool, stopped_seconds: float = 0.0) -> void:
	refresh_modifiers()
	expire_sources(slots, delta)
	for slot in slots.values():
		if not blocked and slot.remaining > 0:
			slot.remaining = _remaining(slot.remaining - DeterministicMath.f32(maxf(0, delta - stopped_seconds) * (0.5 if slow else 1.0)))

## 隐藏的原形主能力同样消耗授予时限，不因变形而延长临时复制。
static func expire_sources(values: Dictionary, delta: float) -> void:
	for id in values.keys():
		var slot: Dictionary = values[id]
		for source in slot.sources.keys():
			if slot.sources[source] <= 0: continue
			slot.sources[source] = float(slot.sources[source]) - delta
			if slot.sources[source] <= 0.0001:
				slot.sources.erase(source)
				slot.source_details.erase(source)
		if slot.sources.is_empty():
			values.erase(id)

## 返回稳定主能力顺序，到期主能力的跨单位优先级由模拟器统一排序。
func ready() -> Array:
	refresh_modifiers()
	var result: Array = slots.keys().filter(func(id): return slots[id].remaining <= 0)
	result.sort()
	return result

## 发动时仅重置该主能力的冷却，后续自身充能保留在新周期。
func reset(id: String) -> void:
	refresh_modifiers()
	if slots.has(id): slots[id].remaining = slots[id].cooldown

## 通用冷却效果作用于目标当前拥有的每个主能力。
func change_cooldown(delta: float, main_ability_id: String = "") -> void:
	for id in slots:
		if main_ability_id.is_empty() or id == main_ability_id: slots[id].remaining = _remaining(slots[id].remaining + delta)

## 剩余秒数保留双精度累减，避免长冷却的逐步取整误差错过截止时刻。
func _remaining(value: float) -> float:
	return 0.0 if value <= 0.0001 else value

## 急速按来源叠加，同来源刷新；零时长持续本场，空主能力 ID 作用于所有主能力。
func haste(source_id: String, ratio: float, duration: float, main_ability_id: String = "", source: Dictionary = {}) -> bool:
	var gained = modifiers.haste(source_id, ratio, duration, main_ability_id, source)
	refresh_modifiers()
	return gained

## 当前主能力读取同一来源账本，基础急速只加一次。
func haste_ratio(main_ability_id: String) -> float:
	return clampf(base_haste + float(modifiers.values(main_ability_id).get("haste_ratio", 0)), 0.0, AbilitySchema.MAX_HASTE)

## 主能力公式消费统一聚合结果，指定主能力的急速不影响其他主能力。
func _cooldown(main_ability: Dictionary) -> float:
	return CombatAttributes.cooldown(main_ability, modifiers.values(main_ability.id), base_haste)

## 修正变化时保留已完成比例，已就绪主能力保持就绪。
func refresh_modifiers() -> void:
	for id in slots:
		var slot: Dictionary = slots[id]
		var current = _cooldown(slot.definition)
		if slot.cooldown != current:
			slot.remaining = _remaining(slot.remaining * current / slot.cooldown)
			slot.cooldown = current

## 输出每项主能力的独立进度及来源，界面不再推导另一份冷却。
func capture() -> Array:
	refresh_modifiers()
	var result: Array = []
	var ids = slots.keys()
	ids.sort()
	for id in ids:
		var slot: Dictionary = slots[id]
		result.append({"id": id, "content_id": slot.definition.get("content_id", id), "cooldown": _cooldown(slot.definition),
			"haste_ratio": haste_ratio(id), "remaining": slot.remaining, "sources": slot.sources.duplicate(), "source_details": slot.source_details.duplicate(true)})
	return result
