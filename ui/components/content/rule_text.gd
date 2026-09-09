class_name RuleText
extends RefCounted
## 跨页面共用的内容规则说明与数值格式；不把翻译文案当成游戏定义。

const C = preload("res://game_content/runtime/content_types.gd")
const T = preload("res://features/mechanics/contracts/combat_types.gd")

## 规则计算保留原数值精度，显示最多三位小数。
static func number(value: float) -> String:
	return ("%.3f" % value).trim_suffix("0").trim_suffix("0").trim_suffix("0").trim_suffix(".")

## 展示模板使用命名参数，使每种语言可以调整语序。
static func _tr(key: String, args: Dictionary = {}, iconic: bool = false) -> String:
	if iconic and key.begins_with("stat.") and AttributeIcons.TEXTURES.has(key.trim_prefix("stat.")): return AttributeIcons.symbol(key.trim_prefix("stat."), true)
	return AttributeIcons.format_rule("rules." + key, args, iconic)

## 枚举身份始终不变，只本地化对应的显示名称。
static func enum_label(group: String, values: Dictionary, value: int, iconic: bool = false) -> String:
	if iconic:
		var stat: String = ""
		if group == "output": stat = T.output_stat(value)
		elif group == "status": stat = {T.Status.Burn: "burn_damage", T.Status.Poison: "poison_damage"}.get(value, "")
		elif group == "action": stat = T.output_stat(T.output_kind({"kind": value}))
		if AttributeIcons.TEXTURES.has(stat): return AttributeIcons.symbol(stat, true)
	var name = values.find_key(value)
	return _tr(group + "." + String(name).to_snake_case(), {}, iconic) if name != null else _tr("unknown", {}, iconic)

## 被动卡不显示零秒冷却。
static func cooldown(value: Variant, iconic: bool = false) -> String:
	return _tr("cooldown.passive", {}, iconic) if value == null else _tr("cooldown.seconds", {"seconds": number(value)}, iconic)

## 卡牌详情采用实际成长与常驻修正公式，主能力不另设展示名称。
static func card(definition: Dictionary, state: Dictionary = {}) -> String:
	var content = card_sections(definition, state)
	var lines: Array = []
	if not content.attribute_text.is_empty(): lines.append(content.attribute_text)
	for main in content.main: lines.append(main.text)
	for passive in content.passive: lines.append(passive.body)
	for bonus in content.bonus: lines.append(bonus.body)
	return "\n".join(lines)

## 详情布局与纯文字说明共享同一数值投影，核心属性和修正属性保持独立。
static func card_sections(definition: Dictionary, state: Dictionary = {}, iconic: bool = false) -> Dictionary:
	definition = definition.duplicate(true)
	if state.has("modifiers"): definition.modifiers = state.modifiers
	var stats: Dictionary = state.get("stats", CombatAttributes.stats(definition))
	var core_attributes: Array = []
	var modifier_attributes: Array = []
	var lines: Array = []
	var maximum_health: float = state.get("maximum_health", CombatAttributes.max_health(definition))
	core_attributes.append({"stat": "max_health", "label": _tr("stat.max_health", {}, iconic), "value": number(maximum_health)})
	lines.append(_tr("stat.max_health", {}, iconic) + " " + number(maximum_health))
	for index in range(T.OUTPUT_STATS.size()):
		var stat: String = T.OUTPUT_STATS[index]
		if stats.get(stat, 0) <= 0: continue
		var value = number(stats[stat])
		if index in [T.Output.Burn, T.Output.Poison]: value = _tr("output.stacks", {"amount": value}, iconic)
		core_attributes.append({"stat": stat, "label": enum_label("output", T.Output, index, iconic), "value": value})
		lines.append(enum_label("output", T.Output, index, iconic) + " " + value)
	if definition.main_abilities.size() == 1:
		var seconds: float = CombatAttributes.cooldown(definition.main_abilities[0], definition.modifiers, definition.get("haste_ratio", 0))
		var value: String = _tr("duration.seconds", {"seconds": number(seconds)}, iconic)
		core_attributes.append({"stat": "cooldown_seconds", "label": _tr("stat.cooldown_seconds", {}, iconic), "value": value})
		lines.append(_tr("stat.cooldown_seconds", {}, iconic) + " " + value)
	# 零暴击率与默认倍率不占位；显式数值变化仍按真实有效属性展示。
	for stat: String in ["crit_chance", "crit_multiplier"]:
		if is_equal_approx(stats[stat], CombatAttributes.BASE_STATS[stat]): continue
		var value: String = number(stats[stat] * 100) + "%"
		modifier_attributes.append({"stat": stat, "label": _tr("stat." + stat, {}, iconic), "value": value})
		lines.append(_tr("stat." + stat, {}, iconic) + " " + value)
	for stat in ["haste_ratio", "lifesteal_ratio"]:
		if stats[stat] <= 0: continue
		var description = _tr("card.haste" if stat == "haste_ratio" else "card.lifesteal", {"percent": number(stats[stat] * 100)}, iconic)
		modifier_attributes.append({"stat": stat, "label": _tr("stat." + stat, {}, iconic), "value": number(stats[stat] * 100) + "%", "hint": description})
		lines.append(description)
	var capacity = CombatAttributes.ammo_capacity(definition)
	if capacity > 0:
		var description = _tr("card.ammo", {"count": capacity}, iconic)
		modifier_attributes.append({"stat": "ammo_capacity", "label": ContentText.text("ui.detail.ammo"), "value": str(capacity), "hint": description})
		lines.append(description)
	if definition.main_abilities.size() == 1:
		var multicast: int = CombatAttributes.multicast(definition, definition.main_abilities[0])
		if multicast > 1:
			modifier_attributes.append({"stat": "multicast_bonus", "label": _tr("stat.multicast_bonus", {}, iconic), "value": str(multicast)})
	var result = {"core_attributes": core_attributes, "modifier_attributes": modifier_attributes,
		"attributes": core_attributes + modifier_attributes, "attribute_text": "\n".join(lines), "main": [], "passive": [], "bonus": []}
	for active in definition.main_abilities:
		var args = {"multicast": multicast_label(CombatAttributes.multicast(definition, active), iconic),
			"cooldown": cooldown(CombatAttributes.cooldown(active, definition.modifiers, definition.get("haste_ratio", 0)), iconic),
			"actions": actions(active.actions, definition, float(definition.get("main_ability_strength_multiplier", 1)), iconic)}
		result.main.append({"id": active.id, "multicast": args.multicast, "meta": args.cooldown + args.multicast, "body": args.actions, "text": _tr("card.main_ability", args, iconic)})
	for entry in definition.rules:
		var projected: Dictionary = entry.duplicate(true)
		projected.multicast_count = CombatAttributes.multicast(definition, entry)
		var body: String = rule(projected, definition, iconic)
		var source_id: String = str(entry.get("source_id", entry.id))
		for observed: Dictionary in state.get("ability_states", []):
			if observed.get("execution_kind") != T.AbilityExecution.TriggeredPassive or observed.id != entry.id or observed.get("source_id") != source_id: continue
			if observed.get("internal_cooldown_remaining", 0) > 0:
				body += "\n" + _tr("ability.internal_cooldown_remaining", {"seconds": number(observed.internal_cooldown_remaining)}, iconic)
			break
		result.passive.append({"id": entry.id, "source_id": source_id, "body": body})
	var parts: Array = definition.get("modifier_sources", []) + definition.get("conditional_passives", [])
	var team_contributions = CombatAttributes.team_contributions(parts.map(func(part): return part.modifiers), int(definition.modifiers.get("team_bonus_add", 0)))
	for index in range(parts.size()):
		var part: Dictionary = parts[index]
		var shown: Dictionary = part.duplicate(true)
		var team = shown.modifiers.get("team_bonuses", {})
		if not team.is_empty():
			var identity = AbilitySource.key(state.get("id", ""), part.source_id, part.id)
			shown.modifiers = state.get("modifier_sources", {}).get(identity, {}).get("modifiers", team_contributions[index])
		var category: int = T.ability_category(part.execution_kind)
		var group: String = "bonus" if category == T.AbilityCategory.Bonus else "passive"
		result[group].append({"id": part.id, "body": _passive_modifiers(shown, iconic)})
	return result

## 载体与输出分类各自展示，分类不隐含触发方式。
static func identity(definition: Dictionary) -> String:
	return _tr("identity", {"kind": enum_label("card_kind", CardTypes.Kind, definition.kind),
		"output": enum_label("output", T.Output, definition.output_type), "width": definition.width, "height": definition.height})

## 目录与战前详情共用卡牌标签名称，不从输出或已施加状态反推。
static func card_tags(definition: Dictionary) -> Array:
	return definition.get("card_tag_ids", []).map(func(id): return ContentText.text(GameContentSchema.text_key("card_tags", id, "name")))

## 每种效果使用完整句子模板，目标与数值是只读插值。
static func actions(values: Array, definition: Dictionary = {}, strength_multiplier: float = 1.0, iconic: bool = false) -> String:
	var lines: Array = []
	definition = definition.duplicate(true)
	for action in values:
		if MechanicSchema.is_mechanic(int(action.kind)):
			lines.append(_mechanic_description(action, definition, strength_multiplier, iconic))
			continue
		var strength = CombatAttributes.action_amount(definition, action, strength_multiplier)
		if T.output_kind(action) in [T.Output.Physical, T.Output.Witchcraft, T.Output.Burn, T.Output.Poison] or (action.kind in [T.CombatAction.Heal, T.CombatAction.GrantShield] and strength >= 1): strength = CombatAttributes.points(strength)
		var duration = float(action.duration_seconds)
		var args = {"target": target_label(action), "amount": number(strength), "seconds": number(duration),
			"main_ability": _main_ability_reference(str(action.get("main_ability_id", "")), iconic)}
		if action.get("amount_source", T.AmountSource.Fixed) == T.AmountSource.CardOutput and not definition.has(T.output_stat(T.output_kind(action))):
			args.amount = _tr("actions.card_output_points", {"type": enum_label("output", T.Output, T.output_kind(action), iconic)}, iconic)
		elif action.get("power_multiplier", 0) > 0 and not definition.has(T.output_stat(T.output_kind(action))):
			args.amount = _tr("actions.card_power_ratio", {"percent": number(action.power_multiplier * 100), "type": enum_label("output", T.Output, T.output_kind(action), iconic)}, iconic)
		match int(action.kind):
			T.CombatAction.PhysicalDamage: lines.append(_tr("actions.physical_damage", args, iconic))
			T.CombatAction.Witchcraft: lines.append(_tr("actions.witchcraft", args, iconic))
			T.CombatAction.Heal: lines.append(_tr("actions.heal", args, iconic))
			T.CombatAction.GrantShield: lines.append(_tr("actions.shield", args, iconic))
			T.CombatAction.ApplyStatus:
				args.status = enum_label("status", T.Status, action.status, iconic)
				lines.append(_tr("actions.status_stacks" if action.status in [T.Status.Burn, T.Status.Poison] else "actions.status_control", args, iconic))
			T.CombatAction.ChangePollution: lines.append(_tr("actions.pollution", args, iconic))
			T.CombatAction.Charge: lines.append(_tr("actions.charge", args, iconic))
			T.CombatAction.DelayCooldown: lines.append(_tr("actions.delay", args, iconic))
			T.CombatAction.Haste:
				args.percent = number(strength * 100)
				args.duration = _tr("duration.battle", {}, iconic) if duration == 0 else _tr("duration.seconds", args, iconic)
				lines.append(_tr("actions.haste", args, iconic))
			T.CombatAction.RefillAmmo: lines.append(_tr("actions.refill", args, iconic))
			T.CombatAction.ExpandAmmo: lines.append(_tr("actions.expand", args, iconic))
			T.CombatAction.GrantMainAbility:
				args.duration = _tr("duration.source", {}, iconic) if duration == 0 else _tr("duration.seconds", args, iconic)
				lines.append(_tr("actions.grant_main_ability", args, iconic))
		if action.get("lifesteal_ratio", 0) > 0: lines.append(_tr("actions.lifesteal", {"percent": number(action.lifesteal_ratio * 100)}, iconic))
	return _tr("separator.sentences", {}, iconic).join(lines)

## 主能力展示唯一执行定义的冷却与完整效果。
static func main_ability(value: Dictionary, iconic: bool = false) -> String:
	return _tr("main_ability.description", {"multicast": multicast_label(value.get("multicast_count", 1), iconic),
		"cooldown": cooldown(maxf(CombatAttributes.MIN_COOLDOWN, value.cooldown_seconds), iconic), "actions": actions(value.actions, {}, 1.0, iconic)}, iconic)

## 主能力引用只区分全部与指定主动，不为运行定义生成名称。
static func _main_ability_reference(id: String, iconic: bool = false) -> String:
	return _tr("main_ability.all", {}, iconic) if id.is_empty() else _tr("main_ability.specific", {}, iconic)

## 默认单次不增加噪声，多次使用总次数标签。
static func multicast_label(count: int, iconic: bool = false) -> String:
	return _tr("multicast", {"count": count}, iconic) if count > 1 else ""

## 节点按钮说明使用与实际结算相同的条款。
static func node_rule(value: Dictionary) -> String:
	if value.is_empty(): return _tr("node.missing")
	var args = {"amount": value.reward_amount, "reward": enum_label("currency", C.Currency, value.reward_currency),
		"cost": value.cost_amount, "currency": enum_label("currency", C.Currency, value.cost_currency)}
	match int(value.effect_type):
		C.NodeEffect.AuroraChoice: return _tr("node.aurora")
		C.NodeEffect.GrantCurrency: return _tr("node.reward", args)
		C.NodeEffect.ExchangeCurrency: return _tr("node.exchange", args)
	return ContentText.field(value, "description")

## 触发、条件与预算由统一规则生成，语言切换不改变规则对象。
static func rule(value: Dictionary, definition: Dictionary = {}, iconic: bool = false) -> String:
	var conditions: Array = []
	for item in value.conditions:
		if item.kind != T.Condition.Always: conditions.append(condition(item, iconic))
	var progress: Dictionary = value.get("progress", {})
	if int(progress.get("count", 1)) > 1:
		conditions.append(_tr("mechanic.combo", {"count": progress.count, "seconds": number(progress.get("window_seconds", 0)), "unique": _tr("mechanic.distinct", {}, iconic) if progress.get("unique_sources", false) else _tr("mechanic.any_source", {}, iconic)}, iconic))
	var description: String = _tr("rule", {"trigger": enum_label("trigger", T.Event, value.trigger_event, iconic),
		"conditions": _tr("rule.conditions", {"conditions": _tr("separator.and", {}, iconic).join(conditions)}, iconic) if not conditions.is_empty() else "",
		"actions": actions(value.actions, definition, 1.0, iconic), "per_second": value.max_triggers_per_second,
		"per_battle": value.max_triggers_per_battle, "multicast": multicast_label(value.get("multicast_count", 1), iconic)}, iconic)
	var interval: float = float(value.get("internal_cooldown_seconds", 0.0))
	if interval > 0: description += _tr("separator.sentences", {}, iconic) + _tr("ability.internal_cooldown", {"seconds": number(interval)}, iconic)
	return description

## 条件类型到文案键一对一映射，阈值仍取当前规则。
static func condition(value: Dictionary, iconic: bool = false) -> String:
	return _tr("condition." + String(T.Condition.find_key(value.kind)).to_snake_case(), {"threshold": number(value.get("threshold", 0)),
		"status": enum_label("status", T.Status, value.get("status", T.Status.None), iconic), "tags": tag_query(value.get("tag_query", {}))}, iconic)

## 标签查询使用同一内容名称，不把标签 ID 或创作 JSON 展示给玩家。
static func tag_query(query: Dictionary) -> String:
	var clauses: Array = []
	for mode: String in ["any", "all", "none"]:
		var ids: Array = query.get(mode, [])
		if ids.is_empty(): continue
		var names: Array = ids.map(func(id): return ContentText.text(GameContentSchema.text_key("card_tags", id, "name")))
		clauses.append(_tr("tags." + mode, {"tags": _tr("separator.list").join(names)}))
	return _tr("separator.and").join(clauses)

## 先说明目标范围，再说明标签限制，避免让友敌或位置条件消失。
static func target_label(value: Dictionary) -> String:
	var label: String = enum_label("target", T.Target, value.target)
	if int(value.get("max_targets", 0)) > 0:
		label = _tr("target.limited_enemies" if value.target == T.Target.AllEnemies else "target.limited_units", {"count": value.max_targets})
	var query: Dictionary = value.get("target_tags", {})
	return _tr("tags.target", {"target": label, "tags": tag_query(query)}) if CardTagQuery.restricted(query) else label

## 组合机制从真实参数生成说明，费用、持续和子效果都不另存描述副本。
static func _mechanic_description(action: Dictionary, definition: Dictionary, strength: float, iconic: bool = false) -> String:
	var parameters: Dictionary = action.get("parameters", {})
	var args: Dictionary = {"target": target_label(action), "amount": number(action.amount),
		"count": parameters.get("count", parameters.get("jumps", 0)), "threshold": parameters.get("threshold", 0),
		"limit": parameters.get("limit", 0), "percent": number(float(parameters.get("multiplier", action.amount)) * 100),
		"seconds": number(action.duration_seconds), "recovery": number(parameters.get("recovery_seconds", 0)),
		"resource": _tr("resource." + str(parameters.get("resource", "Counter")).to_snake_case(), {}, iconic),
		"payload": actions(parameters.get("payload", []), definition, strength, iconic)}
	args.duration = _tr("duration.battle", {}, iconic) if action.duration_seconds == 0 else _tr("duration.seconds", args, iconic)
	return _tr("mechanic." + String(T.CombatAction.find_key(action.kind)).to_snake_case(), args, iconic)

## 遗物只显示队伍加值或触发时机与效果，不展示执行器预算。
static func relic(row: Dictionary, iconic: bool = false) -> String:
	var part: Dictionary = row.ability_parts[0]
	if part.execution_kind == T.AbilityExecution.PersistentBonus: return _passive_modifiers(part, iconic)
	return _tr("ability.scope", {"target": enum_label("trigger", T.Event, part.trigger_event, iconic), "description": actions(part.actions, {}, 1.0, iconic)}, iconic)

## 属性修正共用同一说明，来源内容类别不影响数值含义。
static func modifier_text(modifiers: Dictionary, iconic: bool = false) -> String:
	var lines: Array = []
	if modifiers.get("max_health", 0) != 0: lines.append(_tr("modifier.health", {"amount": signed_number(modifiers.max_health)}, iconic))
	if modifiers.get("cooldown_seconds", 0) != 0: lines.append(_tr("modifier.cooldown", {"seconds": signed_number(modifiers.cooldown_seconds)}, iconic))
	for key in ["crit_chance", "crit_multiplier", "haste_ratio", "lifesteal_ratio"]:
		if modifiers.get(key, 0) != 0: lines.append(_tr("modifier.percent", {"stat": _tr("stat." + key, {}, iconic), "amount": signed_number(modifiers[key] * 100)}, iconic))
	for key in T.OUTPUT_STATS:
		if modifiers.get(key, 0) != 0: lines.append(_tr("modifier.action", {"action": _tr("stat." + key, {}, iconic), "amount": signed_number(modifiers[key])}, iconic))
	if modifiers.get("ammo_capacity", 0) != 0: lines.append(_tr("modifier.ammo", {"count": signed_number(modifiers.ammo_capacity)}, iconic))
	if modifiers.get("multicast_bonus", 0) != 0: lines.append(_tr("modifier.multicast", {"count": signed_number(modifiers.multicast_bonus)}, iconic))
	if not modifiers.get("projectile_key", "").is_empty(): lines.append(_tr("modifier.projectile", {}, iconic))
	for action in modifiers.get("action_modifiers", []): lines.append(_tr("modifier.action", {"action": action_label(action, iconic), "amount": signed_number(action.amount)}, iconic))
	for key in modifiers.get("stat_bonus_ratios", {}): lines.append(_tr("modifier.stat_ratio", {"stat": _tr("stat." + key, {}, iconic), "percent": number(modifiers.stat_bonus_ratios[key] * 100)}, iconic))
	if modifiers.get("team_bonus_add", 0) != 0: lines.append(_tr("modifier.team_buff", {"amount": signed_number(modifiers.team_bonus_add)}, iconic))
	for key in modifiers.get("team_bonuses", {}): lines.append(_tr("modifier.team_bonus", {"stat": _tr("stat." + key, {}, iconic), "amount": signed_number(modifiers.team_bonuses[key])}, iconic))
	return _tr("separator.sentences", {}, iconic).join(lines)

## 多段能力逐项说明运行方式，不再把整个内容视为单条事件规则。
static func ability_parts(row: Dictionary, definition: Dictionary = {}, iconic: bool = false) -> String:
	var lines: Array = []
	var parts: Array = row.ability_parts
	for original in parts:
		var part: Dictionary = original.duplicate(true)
		var description = ""
		match part.execution_kind:
			T.AbilityExecution.CooldownMain:
				description = _tr("modifier.main_ability", {}, iconic)
			T.AbilityExecution.TriggeredPassive:
				if not definition.is_empty(): part.multicast_count = CombatAttributes.multicast(definition, part)
				description = rule(part, definition, iconic)
			_:
				description = _passive_modifiers(part, iconic)
		lines.append(description)
	return "\n".join(lines)

## 详情只显示目标与数值，条件能力保留实际条件，不追加底层存续说明。
static func _passive_modifiers(part: Dictionary, iconic: bool) -> String:
	var description: String = modifier_text(part.modifiers, iconic)
	if part.target == T.Target.AllAllies and not CardTagQuery.restricted(part.get("target_tags", {})):
		description = _tr("ability.team_scope", {"description": description}, iconic)
	elif part.target != T.Target.Self or not part.modifiers.get("team_bonuses", {}).is_empty() or CardTagQuery.restricted(part.get("target_tags", {})):
		description = _tr("ability.scope", {"target": target_label(part), "description": description}, iconic)
	if part.execution_kind == T.AbilityExecution.ConditionalPassive:
		return _tr("ability.conditional_description", {"conditions": _tr("separator.and", {}, iconic).join(part.conditions.map(func(item): return condition(item, iconic))), "modifiers": description}, iconic)
	return description

## 加法修正明确显示正负号。
static func signed_number(value: float) -> String:
	return ("+" if value >= 0 else "") + number(value)

## 羁绊门槛直接解释同一条件定义，不写死某项羁绊名称。
static func synergy_conditions(conditions: Array) -> String:
	var lines: Array = []
	for item in conditions:
		match item.kind:
			"RequiredOutputs":
				var groups: Array = []
				for group in item.groups: groups.append(_tr("separator.or").join(group.map(func(role): return _tr("output." + String(role).to_snake_case()))))
				lines.append(_tr("synergy.outputs", {"groups": _tr("separator.list").join(groups)}))
			"DistinctOutputs": lines.append(_tr("synergy.distinct_outputs", {"count": item.minimum}))
			"CardCount": lines.append(_tr("synergy.cards", {"count": item.minimum}))
	return _tr("separator.sentences").join(lines)

## 主能力来源使用通用类型名，其余内容来源解析各自展示名称。
static func source_name(source: Dictionary) -> String:
	if source.get("source_kind", "") == "main_ability": return _tr("ability_execution.cooldown_main")
	var table = {"card": "cards", "relic": "relics", "innate_ability": "innate_abilities", "talent": "talents", "team_synergy": "synergies"}.get(source.get("source_kind", ""), "")
	var id: String = source.get("content_id", "")
	return ContentText.field({"id": id, "name_key": GameContentSchema.text_key(table, id, "name")}) if not table.is_empty() else id


## 状态加成显示具体灼伤或中毒，避免被误解为全部状态强度。
static func action_label(action: Dictionary, iconic: bool = false) -> String:
	return enum_label("status", T.Status, action.get("status", T.Status.None), iconic) if action.kind == T.CombatAction.ApplyStatus else enum_label("action", T.CombatAction, action.kind, iconic)
