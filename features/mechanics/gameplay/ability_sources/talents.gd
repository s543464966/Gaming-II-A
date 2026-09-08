class_name TalentMechanic
extends RefCounted
## 天赋前置与永久贡献策略；账号获得、点数及保存由天赋 Feature 拥有。

## 返回解锁错误，不提前扣点或修改已有选择。
static func can_unlock(row: Dictionary, selected: Array, points: int) -> String:
	if row.is_empty() or not row.has("prerequisite_id"): return "ui.talents.invalid"
	if row.id in selected: return "ui.talents.learned"
	if points <= 0: return "ui.talents.no_points"
	if not row.prerequisite_id.is_empty() and not row.prerequisite_id in selected: return "ui.talents.prerequisite"
	return ""

## 全队永久常驻贡献落实到每张玩家卡；其余能力及自身加值只交给英雄。
static func parts_for_card(row: Dictionary, kind: int) -> Array:
	if not kind in [CardTypes.Kind.CoreHero, CardTypes.Kind.Minion, CardTypes.Kind.ItemCard]: return []
	var result: Array = []
	for original: Dictionary in row.ability_parts:
		var part: Dictionary = original.duplicate(true)
		if part.execution_kind == CombatTypes.AbilityExecution.PersistentBonus and part.target == CombatTypes.Target.AllAllies:
			part.target = CombatTypes.Target.Self
			result.append(part)
		elif kind == CardTypes.Kind.CoreHero:
			result.append(part)
	return result

## 恢复已有天赋时校验类型、唯一性与完整前置。
static func validate(selected: Array, catalog: RefCounted) -> String:
	var seen: Array = []
	for id in selected:
		if not id is String or id in seen: return "天赋 ID 无效或重复。"
		var row: Dictionary = catalog.get_record("talents", id)
		var error = can_unlock(row, selected.filter(func(value): return value != id), 1)
		if not error.is_empty(): return error
		seen.append(id)
	return ""
