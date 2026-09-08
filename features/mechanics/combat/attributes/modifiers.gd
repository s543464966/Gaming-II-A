class_name CombatModifiers
extends RefCounted
## 单个宿主的修正来源账本；常驻、条件和限时修正共用聚合与撤销。

var base: Dictionary = {}
var sources: Dictionary = {}
## 聚合值只在来源变化时重算，对外仍返回独立副本。
var _combined: Dictionary = {}

## 原始战斗输入可直接提供基础修正，内容装配使用独立来源。
func _init(initial: Dictionary = {}) -> void:
	base = initial.duplicate(true)

## 相同来源替换原贡献，零时长表示来源存在期间有效。
func set_source(key: String, value: Dictionary, source: Dictionary = {}, duration: float = 0, main_ability_id: String = "") -> void:
	_combined.clear()
	sources[key] = {"modifiers": value.duplicate(true), "source": source.duplicate(true), "remaining": duration, "main_ability_id": main_ability_id}

## 撤销只影响指定来源，其他同类加成仍然有效。
func remove_source(key: String) -> void:
	if sources.erase(key): _combined.clear()

## 急速保留同来源取较大强度和较长时限的既有规则。
func haste(key: String, ratio: float, duration: float, main_ability_id: String = "", source: Dictionary = {}) -> bool:
	var identity = key + "|" + main_ability_id
	var gained = ratio > 0 and (not sources.has(identity) or ratio > sources[identity].modifiers.haste_ratio)
	if sources.has(identity):
		var old: Dictionary = sources[identity]
		ratio = maxf(ratio, old.modifiers.haste_ratio)
		duration = 0.0 if duration == 0 or old.remaining == 0 else maxf(duration, old.remaining)
	set_source(identity, {"haste_ratio": ratio}, source, duration, main_ability_id)
	return gained

## 有限时长即使控制中也到期，不影响无限时长来源。
func tick(delta: float) -> void:
	for key in sources.keys():
		if sources[key].remaining == 0: continue
		sources[key].remaining -= delta
		if sources[key].remaining <= 0.0001: remove_source(key)

## 全局属性忽略指定主能力修正，主能力查询包含全局及匹配来源。
func values(main_ability_id: String = "") -> Dictionary:
	if _combined.has(main_ability_id): return _combined[main_ability_id].duplicate(true)
	var contributions: Array = [base]
	var keys = sources.keys()
	keys.sort()
	for key in keys:
		var entry: Dictionary = sources[key]
		if entry.main_ability_id.is_empty() or (not main_ability_id.is_empty() and entry.main_ability_id == main_ability_id): contributions.append(entry.modifiers)
	_combined[main_ability_id] = CombatAttributes.combine_modifiers(contributions)
	# 数值求和按稳定身份排序，弹道覆盖仍沿用来源最后生效顺序。
	for entry in sources.values():
		if not entry.main_ability_id.is_empty() and entry.main_ability_id != main_ability_id: continue
		if not str(entry.modifiers.get("projectile_key", "")).is_empty(): _combined[main_ability_id].projectile_key = entry.modifiers.projectile_key
	return _combined[main_ability_id].duplicate(true)

## 展示获得独立来源快照，不暴露可写账本。
func capture() -> Dictionary:
	return sources.duplicate(true)
