class_name BattleRequestValidator
extends RefCounted
## 战前验证完整请求、机制依赖与宿主约束；不创建或推进战斗状态。

const T = preload("res://features/mechanics/contracts/combat_types.gd")

## 内容来源和机制依赖必须在开战前完整；不补造英雄或默认模式。
static func validate(request: Dictionary) -> Array[String]:
	var errors = _deployment(request)
	if not errors.is_empty(): return errors
	if not request.get("resources", {}) is Dictionary or not request.get("ability_hosts", []) is Array or not request.get("main_ability_definitions", {}) is Dictionary: return ["机制资源或宿主集合格式无效。"]
	if not request.get("seed", 0) is int: return ["随机种子必须为整数。"]
	# 模拟会复制主能力索引；未引用项也须有合法形状，但不附加未启用的资源依赖。
	for id: Variant in request.get("main_ability_definitions", {}):
		var preset: Variant = request.main_ability_definitions[id]
		if not id is String or not preset is Dictionary or not preset.get("id") is String or preset.id != id:
			errors.append("主能力索引定义或标识不一致。")
			continue
		_main_ability_sources(preset, [], errors)
	if not request.get("resources", {}).get("pollution", {}) is Dictionary: return ["污染资源格式无效。"]
	var resource: Dictionary = request.get("resources", {}).get("pollution", {})
	if not resource.is_empty():
		if not resource.get("scope") in ["battle", "team"] or not resource.get("values") is Dictionary: return ["污染资源作用域或初始值无效。"]
		var keys = ["battle"] if resource.scope == "battle" else request.rules.team_ids.map(func(id): return str(id))
		if resource.values.size() != keys.size(): errors.append("污染资源必须覆盖且只覆盖声明作用域。")
		for key in keys:
			if not resource.values.get(key) is int or resource.values[key] < 0 or resource.values[key] > 100: errors.append("污染初始值必须为 0～100 整数。")
	var sources: Array = []
	var host_ids: Array = []
	for card in request.cards:
		host_ids.append(card.id)
		var known: Dictionary = {}
		for main_ability in card.definition.main_abilities:
			_main_ability_sources(main_ability, sources, errors)
			if not main_ability is Dictionary or not main_ability.get("id") is String: continue
			var copy: Dictionary = main_ability.duplicate(true)
			copy.erase("source_id")
			copy.erase("source")
			copy.erase("duration_seconds")
			if known.has(main_ability.id) and known[main_ability.id] != copy: errors.append("同单位同主能力 ID 不能有不同执行定义。")
			known[main_ability.id] = copy
		_rule_sources(card.definition.rules, "card", sources, errors)
		_passive_sources(card.definition, "card", sources, errors, request.cards, card.id, card.definition.team_id)
	for host in request.get("ability_hosts", []):
		if not host is Dictionary or not host.get("id") is String or host.id.is_empty() or host.id in host_ids:
			errors.append("规则宿主 ID 无效或重复。")
			continue
		host_ids.append(host.id)
		if not host.get("consumption_order", 0) is int or host.get("consumption_order", 0) < 0: errors.append("来源消耗顺序必须为非负整数。")
		if not host.get("scope") in ["team", "battle"] or (host.scope == "team" and not host.get("team_id") in request.rules.team_ids):
			errors.append("规则宿主作用域无效。")
			continue
		if not host.get("consumable", false) is bool or not host.get("consumption_group", "") is String:
			errors.append("来源消耗规则格式无效。")
		elif host.get("consumable", false):
			if host.get("consumption_group", "").is_empty() or not host.get("rules") is Array or host.rules.size() != 1:
				errors.append("一次性来源必须有单一触发与稳定消耗分组。")
			elif not host.rules[0] is Dictionary or host.rules[0].get("max_triggers_per_battle") != 1:
				errors.append("一次性来源每场最多执行一次。")
			if host.get("modifier_sources", []) != [] or host.get("conditional_passives", []) != []: errors.append("一次性来源不能混入常驻贡献。")
		_rule_sources(host.get("rules"), host.scope, sources, errors)
		if not host.get("main_abilities", []) is Array or not host.get("main_abilities", []).is_empty(): errors.append("非卡牌宿主的主能力集合必须为空数组。")
		if not host.get("modifiers", {}) is Dictionary:
			errors.append("非卡牌宿主修正格式无效。")
		else:
			var codec = AbilitySchema.new()
			codec.decode(host.get("modifiers", {}), "modifiers", host.id, false)
			errors.append_array(codec.errors)
			errors.append_array(AbilitySchema.runtime_modifier_errors(host.get("modifiers", {})))
		_passive_sources(host, host.scope, sources, errors, request.cards, host.id, host.get("team_id", -1))
	var visited: Array = []
	var index = 0
	while index < sources.size():
		var source: Dictionary = sources[index]
		index += 1
		for condition in source.conditions:
			if source.scope != "card" and condition.kind in [T.Condition.OwnerCounterAtLeast, T.Condition.EventSourceIsLinked, T.Condition.OwnerHasTags]: errors.append("非卡牌宿主不能读取自身计数、连接或标签。")
			if condition.kind in [T.Condition.PollutionAtLeast, T.Condition.PollutionAtMost]:
				if resource.is_empty(): errors.append("规则依赖尚未启用的污染机制。")
				elif source.scope == "battle" and resource.scope == "team": errors.append("整场宿主不能隐式选择某队污染。")
			if source.scope != "card" and condition.kind in [T.Condition.OwnerHealthAtMostPercent, T.Condition.EventSourceIsOwner, T.Condition.EventTargetIsOwner, T.Condition.OwnerHasStatus, T.Condition.EventSourceIsAdjacent]: errors.append("非卡牌宿主不能使用自身生命、状态或位置条件。")
			if source.scope == "battle" and condition.kind in [T.Condition.EventSourceIsAlly, T.Condition.EventSourceIsEnemy, T.Condition.EventTargetIsEnemy]: errors.append("整场宿主没有默认所属队伍。")
		for action in MechanicSchema.flatten(source.actions):
			if source.scope != "card" and MechanicSchema.is_mechanic(int(action.kind)): errors.append("组合机制需要明确的卡牌宿主。")
			if source.scope != "card" and (action.get("power_multiplier", 0) > 0 or action.get("amount_source", T.AmountSource.Fixed) != T.AmountSource.Fixed): errors.append("非卡牌宿主没有可引用的输出属性。")
			if action.kind == T.CombatAction.ChangePollution and resource.is_empty(): errors.append("效果依赖尚未启用的污染机制。")
			if action.kind in MechanicSchema.MAIN_ABILITY_REFERENCES and not action.main_ability_id in visited:
				visited.append(action.main_ability_id)
				var granted: Variant = request.get("main_ability_definitions", {}).get(action.main_ability_id, {})
				if not granted is Dictionary or granted.is_empty() or granted.get("id") != action.main_ability_id: errors.append("主能力授予引用缺失或标识不一致。")
				else: _main_ability_sources(granted, sources, errors)
			if action.kind in [T.CombatAction.CopyMainAbility, T.CombatAction.Transform]:
				var preset: Variant = request.get("main_ability_definitions", {}).get(action.main_ability_id, {})
				if preset is Dictionary and preset.get("actions", []) is Array:
					if not MechanicSchema.snapshot_supported(action.kind, preset.get("actions", [])): errors.append("复制或形态预设不能递归创建主能力或回放副本。")
			if source.scope != "card" and action.target in [T.Target.Self, T.Target.NearestEnemy, T.Target.FarthestEnemy, T.Target.AdjacentAllies, T.Target.LinkedAlly, T.Target.NearestAlly, T.Target.MarkedEnemy, T.Target.AlliedMinion]: errors.append("非卡牌宿主必须使用明确的事件或群体目标。")
			if source.scope == "battle" and action.target not in [T.Target.EventSource, T.Target.EventTarget, T.Target.AllUnits]: errors.append("整场宿主没有默认友军或敌军。")
	return errors

## 只遍历实际引用的授予主能力，未启用内容不产生额外机制依赖。
static func _main_ability_sources(main_ability: Variant, sources: Array, errors: Array[String]) -> void:
	if not main_ability is Dictionary or not main_ability.get("id") is String or main_ability.id.is_empty() or not main_ability.get("priority") is int or not _positive(main_ability.get("cooldown_seconds")):
		errors.append("主能力定义无效。")
		return
	if main_ability.has("source"): errors.append_array(AbilitySource.validation_errors(main_ability.source))
	var duration = main_ability.get("duration_seconds", 0)
	var count: Variant = main_ability.get("multicast_count", 1)
	if not count is int or count < 1 or count > AbilitySchema.MAX_MULTICAST: errors.append("主能力多重施法次数无效。")
	if not (duration is int or duration is float) or not is_finite(float(duration)) or duration < 0: errors.append("主能力授予时长无效。")
	if not main_ability.get("source_id", "base:" + main_ability.id) is String or str(main_ability.get("source_id", "base:" + main_ability.id)).is_empty(): errors.append("主能力授予来源无效。")
	var codec = AbilitySchema.new()
	var actions = codec.decode(main_ability.get("actions"), "actions", main_ability.id, false)
	_runtime_enums(main_ability.get("actions"), [], errors)
	errors.append_array(codec.errors)
	if codec.errors.is_empty(): sources.append({"actions": actions, "conditions": [], "scope": "card"})

## 运行来源标识不进入静态规则格式，结束事件只用于通知模式结算。
static func _rule_sources(rules: Variant, scope: String, sources: Array, errors: Array[String]) -> void:
	if not rules is Array:
		errors.append("事件规则集合格式无效。")
		return
	var ids: Array = []
	for rule in rules:
		if not rule is Dictionary:
			errors.append("事件规则格式无效。")
			continue
		if not rule.get("id") is String or not rule.get("priority") is int or not rule.get("conditions") is Array or not rule.get("max_triggers_per_second") is int or not rule.get("max_triggers_per_battle") is int:
			errors.append("运行规则缺少已编译的身份、顺序、条件或预算。")
			continue
		if not rule.get("source_id", rule.get("id", "")) is String or str(rule.get("source_id", rule.get("id", ""))).is_empty(): errors.append("触发规则来源标识无效。")
		if rule.has("source"): errors.append_array(AbilitySource.validation_errors(rule.source))
		var copy: Dictionary = rule.duplicate(true)
		copy.erase("source_id")
		copy.erase("source")
		var codec = AbilitySchema.new()
		var decoded: Array = codec.decode([copy], "rules", str(copy.get("id", "")), false)
		_runtime_enums(copy.get("actions"), copy.get("conditions"), errors)
		if not copy.get("trigger_event") is int: errors.append("运行请求的触发事件必须经过枚举转换。")
		errors.append_array(codec.errors)
		if not codec.errors.is_empty(): continue
		if rule.id in ids: errors.append("同一宿主规则 ID 重复。")
		ids.append(rule.id)
		if rule.trigger_event in [T.Event.BattleCompleted, T.Event.TimeLimitResolved]: errors.append("战斗结束和时间裁决是只读结果通知，不能再改变战斗状态。")
		if scope != "card" and decoded[0].multicast_count > 1: errors.append("多重施法不能用于队伍或整场规则宿主。")
		sources.append({"actions": decoded[0].actions, "conditions": decoded[0].conditions, "scope": scope})

## 运行请求只接受已编译枚举，避免名称通过校验却被整数执行误解。
static func _runtime_enums(actions: Variant, conditions: Variant, errors: Array[String]) -> void:
	if actions is Array:
		for action in MechanicSchema.flatten(actions):
			if action is Dictionary:
				for key in ["kind", "target", "status"]:
					if action.has(key) and not action[key] is int: errors.append("运行效果枚举未转换: " + key)
	if conditions is Array:
		for condition in conditions:
			if condition is Dictionary:
				for key in ["kind", "status"]:
					if condition.has(key) and not condition[key] is int: errors.append("运行条件枚举未转换: " + key)

## 持续贡献在战前校验，缺失资源或不兼容宿主不能静默跳过。
static func _passive_sources(value: Dictionary, scope: String, sources: Array, errors: Array[String], participants: Array, owner_id: String, team_id: int) -> void:
	var identities: Array = []
	for field in ["modifier_sources", "conditional_passives"]:
		if not value.get(field, []) is Array:
			errors.append("持续能力集合格式无效。")
			continue
		for part in value.get(field, []):
			if not part is Dictionary or not part.get("id") is String or not part.get("source_id") is String or not part.get("source") is Dictionary or not part.get("modifiers") is Dictionary:
				errors.append("持续能力缺少来源。")
				continue
			errors.append_array(AbilitySource.validation_errors(part.source))
			if part.source_id.is_empty(): errors.append("持续能力来源标识为空。")
			if not part.get("execution_kind") is int or not part.get("target") is int: errors.append("运行持续能力枚举未转换。")
			if part.has("lifetime") and not part.lifetime is int: errors.append("运行持续能力的存续枚举未转换。")
			_runtime_enums([], part.get("conditions", []), errors)
			var copy: Dictionary = part.duplicate(true)
			copy.erase("source")
			copy.erase("source_id")
			var codec = AbilitySchema.new()
			var decoded = codec.decode([copy], "ability_parts", "持续能力", false)
			errors.append_array(codec.errors)
			if not codec.errors.is_empty(): continue
			errors.append_array(AbilitySchema.runtime_modifier_errors(part.modifiers))
			var ability: Dictionary = decoded[0]
			if scope != "card" and ability.get("lifetime") == T.ContributionLifetime.TeamMembership: errors.append("队伍成员常驻必须保留具体卡牌宿主身份。")
			var expected = T.AbilityExecution.PersistentBonus if field == "modifier_sources" else T.AbilityExecution.ConditionalPassive
			if ability.execution_kind != expected: errors.append("持续能力执行类别与集合不匹配。")
			var identity = part.source_id + "|" + part.id
			if identity in identities: errors.append("持续能力来源重复。")
			identities.append(identity)
			if scope != "card" and ability.target in [T.Target.Self, T.Target.AdjacentAllies, T.Target.LinkedAlly]: errors.append("非卡牌宿主没有自身载体或位置关系。")
			if scope == "battle" and ability.target != T.Target.AllUnits: errors.append("整场宿主必须显式选择所有单位。")
			for card in participants:
				var selected: bool = (ability.target == T.Target.Self and card.id == owner_id) or (ability.target == T.Target.AllAllies and card.definition.team_id == team_id) or (ability.target == T.Target.AllEnemies and card.definition.team_id != team_id) or ability.target == T.Target.AllUnits
				if not selected or not CardTagQuery.matches(card.definition.get("card_tag_ids", []), ability.get("target_tags", {})): continue
				if ability.modifiers.multicast_bonus != 0 and not card.definition.kind in [CardTypes.Kind.CoreHero, CardTypes.Kind.Minion]: errors.append("多重修正只适用于英雄或随从。")
				if ability.modifiers.ammo_capacity != 0 and card.definition.kind != CardTypes.Kind.ItemCard: errors.append("弹药修正只适用于道具。")
			sources.append({"actions": [], "conditions": ability.get("conditions", []), "scope": scope})

## 校验输入结构与声明约束，内容类别和队伍身份独立。
static func _deployment(request: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not request.get("rules") is Dictionary or not request.get("cards") is Array: return ["战斗规则或载体集合格式错误。"]
	var rules: Dictionary = request.rules
	if rules.is_empty(): return ["战斗缺少模式规则。"]
	if not rules.get("team_ids") is Array or not rules.get("defeat_order") is Array or not rules.get("constraints") is Dictionary or not rules.get("protected_units") is Dictionary: return ["队伍规则集合格式错误。"]
	var teams: Array = rules.team_ids
	if teams.size() < 2 or teams.any(func(id): return not id is int or id < 0) or _unique(teams).size() != teams.size():
		return ["战斗需要至少两个不同的有效队伍。"]
	if not rules.get("columns") is int or not rules.get("rows") is int or rules.columns < 1 or rules.rows < 1 or rules.columns > 63 or rules.rows > 63 or rules.columns * rules.rows > 63:
		return ["棋盘尺寸必须为正且不超过 63 格。"]
	if not rules.get("view_team") in teams or _unique(rules.get("defeat_order", [])).size() != teams.size() or not rules.defeat_order.all(func(id): return id in teams):
		return ["结果视角或失败判定顺序无效。"]
	if not _positive(rules.get("maximum_duration")) or not _positive(rules.get("step")) or rules.step < 0.01 or rules.step > 0.5:
		return ["模拟时长和步长必须是有限正数，步长为 0.01～0.5 秒。"]
	if rules.get("survival_team") != null and not rules.survival_team in teams: errors.append("生存目标队伍无效。")
	var judgment: Variant = rules.get("health_judgment", {})
	if not judgment is Dictionary: return ["生命裁决配置必须为对象。"]
	if not judgment.is_empty():
		if teams.size() != 2 or rules.get("survival_team") != null: errors.append("生命裁决仅支持两队，不能同时配置生存胜利。")
		if judgment.size() != 2 or not judgment.get("tie_winner_team") is int or not judgment.get("tie_winner_team") in teams: errors.append("生命裁决必须明确指定平分时的获胜队伍。")
		if not _positive(judgment.get("warning_seconds")) or judgment.warning_seconds > rules.maximum_duration: errors.append("裁决提醒时长必须为正且不超过战斗上限。")
	for key in rules.constraints:
		if not key is String or not key in teams.map(func(team): return str(team)) or not rules.constraints[key] is Dictionary: return ["队伍部署约束格式错误。"]
		var limits: Dictionary = rules.constraints[key]
		for field in limits:
			if not field in ["min_heroes", "max_heroes", "max_minions", "allowed_positions"]: return ["未知部署约束。"]
		for count in ["min_heroes", "max_heroes", "max_minions"]:
			if limits.has(count) and (not limits[count] is int or limits[count] < 0): return ["部署数量约束必须是非负整数。"]
		if limits.has("allowed_positions") and (not limits.allowed_positions is Array or limits.allowed_positions.any(func(position): return not position is int or position < 0 or position >= rules.rows * rules.columns)): return ["部署区域无效。"]
	for key in rules.protected_units:
		if not key is String or not key in teams.map(func(team): return str(team)) or not rules.protected_units[key] is Array or rules.protected_units[key].any(func(id): return not id is String): return ["保护目标集合格式错误。"]
	var ids: Dictionary = {}
	var occupied = 0
	var grouped: Dictionary = {}
	for team in teams: grouped[team] = []
	for card in request.get("cards", []):
		if not card is Dictionary or not card.get("definition") is Dictionary:
			errors.append("战斗包含无效载体快照。")
			continue
		var definition: Dictionary = card.definition
		# 通用内核允许不携带内容分类的测试输入；带标签的正式投影必须满足同一数量契约。
		if definition.has("card_tag_ids") and not CardTagQuery.valid_card(definition.card_tag_ids, int(definition.get("output_type", T.Output.Special))): errors.append("卡牌标签集合或数量无效。")
		if not card.get("id") is String or card.id.is_empty() or ids.has(card.id): return ["载体实例 ID 为空或重复。"]
		ids[card.get("id", "")] = card
		if not definition.get("team_id") in teams:
			errors.append("载体所属队伍未声明。")
			continue
		if not definition.get("kind") is int or not definition.kind in CardTypes.Kind.values(): return ["载体类别无效。"]
		grouped[definition.team_id].append(card)
		if not definition.get("projectile", "") is String: errors.append("默认弹道必须是字符串；缺省表示无表现。")
		errors.append_array(CombatAttributes.validation_errors(definition))
		var ammo: Variant = definition.get("ammo_capacity", 0)
		if not ammo is int or ammo < 0 or (ammo > 0 and definition.kind != CardTypes.Kind.ItemCard): errors.append("弹药扩充容量仅允许道具使用非负整数。")
		var growth_bonus: Variant = definition.get("growth_bonus_ratio", 0)
		var training_bonus: Variant = definition.get("training_bonus_ratio", 0)
		var damage_growth: Variant = definition.get("base_damage_growth_ratio", 0)
		if not (damage_growth is int or damage_growth is float) or not is_finite(float(damage_growth)) or damage_growth < 0: errors.append("基础伤害成长必须是有限非负比例。")
		var valid_growth = (growth_bonus is int or growth_bonus is float) and is_finite(float(growth_bonus)) and growth_bonus >= 0
		if not valid_growth: errors.append("成长加成必须是有限非负比例。")
		if not (training_bonus is int or training_bonus is float) or not is_finite(float(training_bonus)) or training_bonus < 0 or (valid_growth and training_bonus > growth_bonus): errors.append("培养加值必须属于成长加值。")
		if not _positive(definition.get("max_health")) or not _positive(definition.get("main_ability_strength_multiplier", 1)) or not _positive(definition.get("base_point_multiplier", 1)): errors.append("载体生命或主能力强度无效。")
		if not (card.get("health") is int or card.get("health") is float) or not is_finite(float(card.health)) or card.health < 0: errors.append("载体当前生命无效。")
		if not definition.get("output_type") in T.Output.values() or not definition.get("main_abilities") is Array or not definition.get("rules") is Array or not definition.get("modifiers") is Dictionary: return ["载体分类或能力集合格式错误。"]
		var codec = AbilitySchema.new()
		codec.decode(definition.modifiers, "modifiers", card.id, false)
		errors.append_array(AbilitySchema.runtime_modifier_errors(definition.modifiers))
		errors.append_array(codec.errors)
		if definition.get("modifiers", {}).get("multicast_bonus", 0) != 0 and not definition.kind in [CardTypes.Kind.CoreHero, CardTypes.Kind.Minion]: errors.append("多重施法强化只适用于英雄和随从。")
		if definition.get("modifiers", {}).get("ammo_capacity", 0) != 0 and definition.kind != CardTypes.Kind.ItemCard: errors.append("弹药扩充强化只适用于道具。")
		for ability in definition.main_abilities + definition.rules:
			if not ability is Dictionary: continue
			var count: Variant = ability.get("multicast_count", 1)
			if not count is int or count < 1 or count > AbilitySchema.MAX_MULTICAST: errors.append("多重施法总次数必须为 1～8。")
			elif count > 1 and not definition.kind in [CardTypes.Kind.CoreHero, CardTypes.Kind.Minion]: errors.append("多重施法只适用于英雄和随从。")
		if not card.get("position") is int or not definition.get("width") is int or not definition.get("height") is int: return ["载体占位参数必须是整数。"]
		var mask = BattleGrid.footprint_mask(card.position, definition.width, definition.height, rules.columns, rules.rows)
		if mask == 0: errors.append("载体超出本场棋盘。")
		elif occupied & mask: errors.append("载体占位重叠。")
		occupied |= mask
		for main_ability in definition.get("main_abilities", []):
			if not main_ability is Dictionary or str(main_ability.get("id", "")).is_empty() or not _positive(main_ability.get("cooldown_seconds")): errors.append("主能力定义无效。")
	for team in teams:
		if grouped[team].is_empty(): errors.append("队伍必须有实际参战载体。")
		var limits: Dictionary = rules.get("constraints", {}).get(str(team), {})
		var heroes = grouped[team].filter(func(card): return card.definition.kind == CardTypes.Kind.CoreHero).size()
		var minions = grouped[team].filter(func(card): return card.definition.kind == CardTypes.Kind.Minion).size()
		if heroes < limits.get("min_heroes", 0) or (limits.get("max_heroes", -1) >= 0 and heroes > limits.max_heroes): errors.append("英雄数量不符合本场规则。")
		if limits.get("max_minions", -1) >= 0 and minions > limits.max_minions: errors.append("随从数量不符合本场规则。")
		for card in grouped[team]:
			if limits.has("allowed_positions"):
				var mask = BattleGrid.footprint_mask(card.position, card.definition.width, card.definition.height, rules.columns, rules.rows)
				for position in range(rules.columns * rules.rows):
					if mask & (1 << position) and not position in limits.allowed_positions: errors.append("载体不在本队部署区域。")
		for id in rules.get("protected_units", {}).get(str(team), []):
			if not ids.has(id) or ids[id].definition.team_id != team: errors.append("保护目标不属于对应队伍。")
	return errors

## 校验有限正数，不接受字符串或无穷值。
static func _positive(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value > 0

## 复制去重集合以验证规则列表，不修改模式输入。
static func _unique(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if not value in result: result.append(value)
	return result
