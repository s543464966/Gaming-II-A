class_name CombatText
extends RefCounted
## 只解释战报完成原因与内核状态帧；静态内容说明统一使用 RuleText。

const T = preload("res://features/mechanics/contracts/combat_types.gd")

## 完成原因使用语义枚举，模拟器中的诊断说明不作为运行时翻译原文。
static func completion(reason: int, duration: float, judgment: Dictionary = {}) -> String:
	if not judgment.is_empty():
		var result_key: String = "judgment_tie" if judgment.tied else "judgment_victory" if reason == T.Completion.Victory else "judgment_defeat"
		return ContentText.format_key("rules.completion." + result_key, {"seconds": "%.0f" % duration})
	var key = String(CombatTypes.Completion.find_key(reason)).to_snake_case()
	return ContentText.format_key("rules.completion." + key, {"seconds": "%.1f" % duration})

## 只展示内核记录的剩余时限和临时修正，不重新判定被动。
static func runtime(state: Dictionary) -> String:
	var lines: Array = _runtime_lines(state)
	return "" if lines.is_empty() else "\n" + RuleText._tr("section.current") + "\n" + "\n".join(lines)

## 玩家说明不展示来源名称或执行器预算，只保留有意义的运行变化。
static func _runtime_lines(state: Dictionary) -> Array:
	var lines: Array = []
	for value in state.get("modifier_sources", {}).values():
		if value.remaining <= 0: continue
		var duration: String = RuleText._tr("duration.seconds", {"seconds": RuleText.number(value.remaining)})
		lines.append(RuleText.modifier_text(value.modifiers) + " · " + duration)
	return lines

## 卡面与触屏详情共用当前战斗说明，不向玩家暴露内部技能名称。
static func battle_card(definition: Dictionary, state: Dictionary) -> String:
	var result = RuleText.card(definition, state) + runtime(state)
	var tags: Array = RuleText.card_tags(definition)
	if not tags.is_empty(): result = " · ".join(tags) + "\n" + result
	var lines: Array = _main_ability_lines(state)
	if not lines.is_empty(): result += "\n" + "\n".join(lines)
	for line in _condition_lines(state): result += "\n" + line
	return result

## 准备详情保留全部已装配能力、当前生命护盾、计时、弹药和有效来源。
static func battle_detail(definition: Dictionary, state: Dictionary) -> Dictionary:
	var detail: Dictionary = ContentPreview.card_detail(definition, state)
	detail.scope = ContentText.format_key("ui.adventure.actual_definition", {"level": definition.get("chapter_level", 0)})
	var current: Array = []
	if not state.is_empty(): current.append(AttributeIcons.format_rule("ui.adventure.current_health", {"current": RuleText.number(state.health), "shield": RuleText.number(state.shield)}, true))
	current.append_array(_condition_lines(state, true))
	current.append_array(_runtime_lines(state))
	if not current.is_empty(): detail.sections.append({"title": "rules.section.current", "entries": current.map(func(line): return {"body": line})})
	for section in detail.sections:
		if section.get("category", -1) != T.AbilityCategory.Main: continue
		for entry in section.entries:
			for active in state.get("main_abilities", []):
				if entry.id != active.get("content_id", active.id): continue
				entry.meta = AttributeIcons.format_rule("ui.detail.main_ability_clock", {"remaining": "%.1f" % active.remaining, "cooldown": "%.1f" % active.cooldown,
					"haste": AttributeIcons.format_rule("ui.combat.haste", {"percent": RuleText.number(active.get("haste_ratio", 0) * 100)}, true) if active.get("haste_ratio", 0) > 0 else ""}, true) + entry.multicast
	return detail

## 主能力周期直接取运行帧；来源身份留在战报，不附加技能或来源名称。
static func _main_ability_lines(state: Dictionary) -> Array:
	var lines: Array = []
	for active in state.get("main_abilities", []):
		lines.append(AttributeIcons.format_rule("ui.detail.main_ability_clock", {"remaining": "%.1f" % active.remaining, "cooldown": "%.1f" % active.cooldown,
			"haste": AttributeIcons.format_rule("ui.combat.haste", {"percent": RuleText.number(active.get("haste_ratio", 0) * 100)}, false) if active.get("haste_ratio", 0) > 0 else ""}, false))
	return lines

## 弹药摘要只读当前状态，不改写基础属性或创建第二份规则。
static func _condition_lines(state: Dictionary, iconic: bool = false) -> Array:
	var lines: Array = []
	if state.get("ammo_capacity", 0) > 0: lines.append(AttributeIcons.format_rule("ui.combat.ammo", {"remaining": state.ammo_remaining, "capacity": state.ammo_capacity}, iconic))
	return lines

## 卡面只显示当前存在的状态和机制短标签，不显示操作教学或内部计数键。
static func status_labels(state: Dictionary) -> Array:
	var labels: Array = []
	for status in state.get("statuses", []):
		var label: String = RuleText.enum_label("status", T.Status, status)
		var count: int = int(state.get("status_stacks", {}).get(status, 1))
		labels.append(label + ("×%d" % count if count > 1 else ""))
	var mechanics: Dictionary = state.get("mechanics", {})
	if not mechanics.get("marks", []).is_empty(): labels.append(RuleText._tr("action.mark"))
	if mechanics.get("guard_charges", 0) > 0: labels.append(RuleText._tr("action.guard") + "×" + str(mechanics.guard_charges))
	if mechanics.get("empower", 0) > 0: labels.append(RuleText._tr("action.empower"))
	if mechanics.get("downtime", 0) > 0: labels.append(RuleText._tr("action.overload"))
	if not str(mechanics.get("form_main_ability_id", "")).is_empty(): labels.append(RuleText._tr("action.transform"))
	return labels
