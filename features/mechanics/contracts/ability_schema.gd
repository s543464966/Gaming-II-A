class_name AbilitySchema
extends RefCounted
## 能力契约的唯一语义校验与规范化，不访问内容目录或运行状态。

const T = preload("res://features/mechanics/contracts/combat_types.gd")
const MAX_HASTE = 0.8
const MAX_CRIT_MULTIPLIER = 3.0
const MAX_MULTICAST = 8
const MODIFIER_STATS = ["physical_damage", "witchcraft_damage", "burn_damage", "poison_damage", "healing_power", "shield_power", "crit_chance", "crit_multiplier", "haste_ratio", "lifesteal_ratio", "ammo_capacity", "multicast_bonus", "team_bonus_add"]
const RATIO_STATS = ["max_health", "physical_damage", "witchcraft_damage", "burn_damage", "poison_damage", "healing_power", "shield_power"]

var errors: Array[String] = []
var names_only = true
var _action_depth: int = 0

## 解析效果、条件、规则、能力清单或常驻修正对象。
func decode(value: Variant, kind: String, owner: String, source_names_only: bool = true) -> Variant:
	names_only = source_names_only
	if kind == "modifiers": return _modifiers(value, owner)
	if not value is Array:
		errors.append(owner + " 必须是数组。")
		return []
	var result: Array = []
	for i in range(value.size()):
		var label = "%s[%d]" % [owner, i]
		match kind:
			"actions": result.append(_action(value[i], label))
			"conditions": result.append(_condition(value[i], label))
			"rules": result.append(_rule(value[i], label))
			"ability_parts": result.append(_part(value[i], label))
	if kind == "ability_parts":
		var ids: Array = []
		for part in result:
			if part.id in ids: errors.append(owner + " 能力局部 ID 重复。")
			ids.append(part.id)
	return result

## 按完整字段集合验证对象并补齐显式默认值。
func _object(value: Variant, defaults: Dictionary, required: Array, owner: String) -> Dictionary:
	var result = defaults.duplicate(true)
	if not value is Dictionary:
		errors.append(owner + " 必须是对象。")
		return result
	for key in value:
		if not defaults.has(key): errors.append(owner + " 含未知字段 " + str(key))
		else: result[key] = value[key]
	for key in required:
		if not value.has(key): errors.append(owner + " 缺少 " + key)
	return result

## 创作定义可要求名称枚举，规范化运行值允许已校验的整数。
func _enum(value: Variant, options: Dictionary, owner: String) -> int:
	if value is String and options.has(value): return options[value]
	if not names_only and (value is int or value is float) and float(value) == floorf(value) and int(value) in options.values():
		return int(value)
	errors.append(owner + " 使用无效枚举 " + str(value))
	return 0

## 将所有运算数值规范为有限单精度数。
func _number(value: Variant, owner: String, negative: bool = false) -> float:
	if not (value is int or value is float) or not is_finite(float(value)) or (not negative and float(value) < 0.0):
		errors.append(owner + " 必须是" + ("有限数值。" if negative else "有限非负数值。"))
		return 0.0
	return DeterministicMath.f32(float(value))

## 六类数值效果可声明弹道，功能效果与状态每跳不伪造发射。
func _action(value: Variant, owner: String) -> Dictionary:
	var result = _object(value, {"kind": "PhysicalDamage", "target": "Self", "target_tags": {}, "amount": 0.0, "power_multiplier": 0.0, "status": "None", "duration_seconds": 0.0, "projectile_key": "", "main_ability_id": "", "lifesteal_ratio": 0.0, "parameters": {}}, ["kind", "target", "amount"], owner)
	result.target_tags = _tag_query(result.target_tags, owner + ".target_tags")
	result.kind = _enum(result.kind, T.CombatAction, owner + ".kind")
	result.target = _enum(result.target, T.Target, owner + ".target")
	result.status = _enum(result.status, T.Status, owner + ".status")
	result.amount = _number(result.amount, owner + ".amount", result.kind == T.CombatAction.ChangePollution)
	result.power_multiplier = _number(result.power_multiplier, owner + ".power_multiplier")
	result.duration_seconds = _number(result.duration_seconds, owner + ".duration_seconds")
	if MechanicSchema.is_mechanic(result.kind):
		_action_depth += 1
		if _action_depth > MechanicSchema.MAX_NESTING: errors.append(owner + " 子效果嵌套过深。")
		else: result.parameters = MechanicSchema.parameters(result, errors, owner, _action)
		_action_depth -= 1
		_mechanic_action(result, owner)
		return result
	if result.parameters != {}: errors.append(owner + " 基础效果不能夹带组合机制参数。")
	if names_only and (T.output_kind(result) != T.Output.Special or result.kind == T.CombatAction.ChangePollution) and result.amount != floorf(result.amount): errors.append(owner + " 固定点数必须为整数，系数与秒数独立配置。")
	if result.power_multiplier > 0:
		if T.output_kind(result) == T.Output.Special or result.amount != 0:
			errors.append(owner + " 数值倍率必须匹配六类输出，且不能同时保存固定强度。")
	result.lifesteal_ratio = _number(result.lifesteal_ratio, owner + ".lifesteal_ratio")
	if result.lifesteal_ratio > 1 or (result.lifesteal_ratio > 0 and not (result.kind in [T.CombatAction.PhysicalDamage, T.CombatAction.Witchcraft] or (result.kind == T.CombatAction.ApplyStatus and result.status in [T.Status.Burn, T.Status.Poison]))):
		errors.append(owner + " 吸血比例仅用于伤害及持续伤害，范围为 0～1。")
	if not result.main_ability_id is String: errors.append(owner + " 主能力 ID 必须是字符串。")
	if not result.projectile_key is String:
		errors.append(owner + " 弹道键必须是字符串。")
		result.projectile_key = ""
	if result.kind == T.CombatAction.ApplyStatus:
		if result.status == T.Status.None or result.duration_seconds <= 0.0:
			errors.append(owner + " 施加状态必须提供状态和正持续时间。")
		if result.status in [T.Status.Freeze, T.Status.Slow, T.Status.Stun] and (result.amount != 0):
			errors.append(owner + " 控制状态只配置时长，不接受无效强度。")
	elif result.kind == T.CombatAction.GrantMainAbility:
		if not result.main_ability_id is String or result.main_ability_id.is_empty() or result.amount != 0 or result.status != T.Status.None:
			errors.append(owner + " 主能力授予必须指定 ID，只接受固定持续时间且不配置强度或状态。")
	elif result.kind == T.CombatAction.Haste:
		if result.status != T.Status.None or result.amount > DeterministicMath.f32(MAX_HASTE):
			errors.append(owner + " 急速比例范围为 0～0.8，不能夹带状态。")
	elif result.status != T.Status.None or result.duration_seconds != 0.0:
		errors.append(owner + " 非状态效果不能夹带状态参数。")
	if not result.projectile_key.is_empty() and T.output_kind(result) == T.Output.Special:
		errors.append(owner + " 只有六类数值效果可以指定弹道。")
	if not result.kind in [T.CombatAction.GrantMainAbility, T.CombatAction.Charge, T.CombatAction.DelayCooldown, T.CombatAction.Haste] and result.main_ability_id != "": errors.append(owner + " 只有主能力授予或冷却效果允许指定主能力 ID。")
	if result.kind in [T.CombatAction.RefillAmmo, T.CombatAction.ExpandAmmo]:
		if result.amount != floorf(result.amount): errors.append(owner + " 弹药扩充次数必须为整数。")
	return result

## 组合机制不伪装成输出属性；身份、费用和时限在入场前校验。
func _mechanic_action(value: Dictionary, owner: String) -> void:
	if value.power_multiplier != 0 or value.status != T.Status.None or value.lifesteal_ratio != 0 or value.projectile_key != "": errors.append(owner + " 组合机制不能夹带主效倍率、状态、吸血或弹道。")
	if value.kind in [T.CombatAction.CopyMainAbility, T.CombatAction.Transform]:
		if not value.main_ability_id is String or value.main_ability_id.is_empty() or value.duration_seconds <= 0: errors.append(owner + " 主能力复制或形态需要预设主能力及正持续时间。")
	elif value.main_ability_id != "": errors.append(owner + " 此机制不接受主能力引用。")
	if value.kind == T.CombatAction.Mark and value.duration_seconds <= 0: errors.append(owner + " 标记必须有正持续时间。")
	if not value.kind in [T.CombatAction.Mark, T.CombatAction.Empower, T.CombatAction.Guard, T.CombatAction.Link, T.CombatAction.CopyMainAbility, T.CombatAction.Transform] and value.duration_seconds != 0: errors.append(owner + " 此机制不接受持续时间。")
	if value.kind in [T.CombatAction.Accumulate, T.CombatAction.Guard, T.CombatAction.Convert, T.CombatAction.Transfer, T.CombatAction.Overload]:
		if value.amount <= 0 or value.amount > 1000000000 or value.amount != floorf(value.amount): errors.append(owner + " 计数或支付数量必须是十亿以内的正整数。")
	elif value.kind == T.CombatAction.Empower:
		if value.amount <= 0 or value.amount > 3: errors.append(owner + " 蓄力增量必须在 0～3 之间。")
	elif value.amount != 0: errors.append(owner + " 此机制没有独立强度，amount 必须为 0。")

## 条件阈值限制在百分比范围，状态参数只属于状态条件。
func _condition(value: Variant, owner: String) -> Dictionary:
	var result = _object(value, {"kind": "Always", "threshold": 0.0, "status": "None", "key": "", "tag_query": {}}, ["kind"], owner)
	result.kind = _enum(result.kind, T.Condition, owner + ".kind")
	result.tag_query = _tag_query(result.tag_query, owner + ".tag_query")
	var tag_condition: bool = result.kind in [T.Condition.OwnerHasTags, T.Condition.EventSourceHasTags, T.Condition.EventTargetHasTags]
	if tag_condition != CardTagQuery.restricted(result.tag_query): errors.append(owner + " 标签条件必须声明非空查询，其他条件不能夹带标签。")
	result.status = _enum(result.status, T.Status, owner + ".status")
	result.threshold = _number(result.threshold, owner + ".threshold")
	var threshold = result.kind in [T.Condition.OwnerHealthAtMostPercent, T.Condition.PollutionAtLeast, T.Condition.PollutionAtMost, T.Condition.OwnerCounterAtLeast, T.Condition.EventTargetStatusStacksAtLeast]
	if (threshold and result.threshold > 100.0) or (not threshold and result.threshold != 0.0):
		errors.append(owner + " 条件阈值无效。")
	if (result.kind in [T.Condition.OwnerHasStatus, T.Condition.EventTargetStatusStacksAtLeast]) != (result.status != T.Status.None):
		errors.append(owner + " 只有持有状态条件必须指定状态。")
	if result.kind in [T.Condition.OwnerCounterAtLeast, T.Condition.EventCounterKey, T.Condition.EventTargetMarked]:
		if not MechanicSchema.valid_key(result.key): errors.append(owner + " 计数或标记条件需要有效键。")
	elif result.key != "": errors.append(owner + " 此条件不能夹带标记键。")
	if result.kind in [T.Condition.OwnerCounterAtLeast, T.Condition.EventTargetStatusStacksAtLeast] and (result.threshold < 1 or result.threshold != floorf(result.threshold)): errors.append(owner + " 层数阈值必须是正整数。")
	return result

## 只接受结构化集合查询，具体 ID 是否存在由内容目录校验。
func _tag_query(value: Variant, owner: String) -> Dictionary:
	if not CardTagQuery.valid(value):
		errors.append(owner + " 标签查询无效、重复或互相排斥。")
		return {}
	return value.duplicate(true)

## 一条事件规则必须有局部 ID、效果和正整数预算。
func _rule(value: Variant, owner: String) -> Dictionary:
	value = _expand_trigger(value, owner)
	var result = _object(value, {"id": "", "trigger_event": "BattleStarted", "priority": 0, "conditions": [], "actions": [], "max_triggers_per_second": 1, "max_triggers_per_battle": 99, "multicast_count": 1, "progress": {}, "internal_cooldown_seconds": 0.0}, ["id", "trigger_event", "conditions", "actions", "max_triggers_per_second", "max_triggers_per_battle"], owner)
	result.internal_cooldown_seconds = _number(result.internal_cooldown_seconds, owner + ".internal_cooldown_seconds")
	result.progress = MechanicSchema.progress(result.progress, errors, owner)
	result.multicast_count = _multicast(result.multicast_count, owner)
	result.trigger_event = _enum(result.trigger_event, T.Event, owner + ".trigger_event")
	if result.trigger_event in [T.Event.BattleCompleted, T.Event.ActionReleased, T.Event.TimeLimitResolved]: errors.append(owner + " 战斗结束、时间裁决和效果发射事件只能用于只读通知。")
	result.conditions = decode(result.conditions, "conditions", owner + ".conditions", names_only)
	result.actions = decode(result.actions, "actions", owner + ".actions", names_only)
	if not result.id is String or str(result.id).strip_edges().is_empty(): errors.append(owner + " 规则 ID 为空。")
	for key in ["priority", "max_triggers_per_second", "max_triggers_per_battle"]:
		var number = _number(result[key], owner + "." + key, key == "priority")
		if number != floorf(number) or (key != "priority" and number <= 0): errors.append(owner + " 预算必须为正整数。")
		result[key] = int(number)
	if result.actions.is_empty(): errors.append(owner + " 规则必须有实际效果。")
	return result

## 创作词条只展开一次为事件与过滤；运行时不再读取词条或执行第二条路径。
func _expand_trigger(value: Variant, owner: String) -> Variant:
	if not value is Dictionary or not value.has("trigger_keyword"): return value
	var result: Dictionary = value.duplicate(true)
	if not names_only: errors.append(owner + " 运行规则必须先展开触发词条。")
	if result.has("trigger_event"): errors.append(owner + " 触发词条与原始事件只能二选一。")
	var keyword: int = _enum(result.trigger_keyword, T.TriggerKeyword, owner + ".trigger_keyword")
	result.erase("trigger_keyword")
	var required: Array[String] = []
	match keyword:
		T.TriggerKeyword.BattleStart:
			result.trigger_event = "BattleStarted"
		T.TriggerKeyword.Kill:
			result.trigger_event = "UnitDefeated"
			required = ["EventSourceIsOwner", "EventTargetIsEnemy", "EventHasKillCredit"]
		T.TriggerKeyword.Deathrattle:
			result.trigger_event = "UnitDefeated"
			required = ["EventTargetIsOwner"]
	if not result.get("conditions", []) is Array: return result
	result.conditions = result.get("conditions", []).duplicate(true)
	for kind: String in required:
		if not result.conditions.any(func(condition): return condition is Dictionary and condition.get("kind") == kind):
			result.conditions.append({"kind": kind})
	return result

## 固定点数与百分比加值分别声明，次数、冷却和未知属性不能混入倍率。
func _modifiers(value: Variant, owner: String) -> Dictionary:
	var defaults = {"max_health": 0.0, "cooldown_seconds": 0.0, "action_modifiers": [], "stat_bonus_ratios": {}, "team_bonuses": {}, "projectile_key": ""}
	for key in MODIFIER_STATS: defaults[key] = 0
	var result = _object(value, defaults, [], owner)
	for key in MODIFIER_STATS:
		result[key] = _number(result[key], owner + "." + key, true)
		if key in ["ammo_capacity", "multicast_bonus", "team_bonus_add"]:
			if result[key] != floorf(result[key]): errors.append(owner + "." + key + " 必须为整数。")
			result[key] = int(result[key])
	result.max_health = _number(result.max_health, owner + ".max_health", true)
	result.cooldown_seconds = _number(result.cooldown_seconds, owner + ".cooldown_seconds", true)
	if names_only:
		for key in ["max_health"] + T.OUTPUT_STATS:
			if result[key] != floorf(result[key]): errors.append(owner + "." + key + " 固定点数必须为整数。")
	if not result.action_modifiers is Array:
		errors.append(owner + " 效果参数修正必须是数组。")
		result.action_modifiers = []
	var bonuses: Array = []
	for value_bonus in result.action_modifiers:
		var bonus = _object(value_bonus, {"kind": "PhysicalDamage", "status": "None", "amount": 0.0}, ["kind", "amount"], owner)
		bonus.kind = _enum(bonus.kind, T.CombatAction, owner + ".kind")
		bonus.status = _enum(bonus.status, T.Status, owner + ".status")
		_validate_action_selector(bonus, owner)
		if bonus.kind == T.CombatAction.GrantMainAbility: errors.append(owner + " 主能力授予没有可修正的强度参数。")
		bonus.amount = _number(bonus.amount, owner + ".amount", true)
		if names_only and (T.output_kind(bonus) != T.Output.Special or bonus.kind == T.CombatAction.ChangePollution) and bonus.amount != floorf(bonus.amount): errors.append(owner + " 固定效果点数必须为整数。")
		if bonus.kind in [T.CombatAction.RefillAmmo, T.CombatAction.ExpandAmmo] and bonus.amount != floorf(bonus.amount): errors.append(owner + " 次数效果的强化必须为整数。")
		bonuses.append(bonus)
	result.action_modifiers = bonuses
	result.stat_bonus_ratios = _bonus_ratios(result.stat_bonus_ratios, owner)
	if not result.team_bonuses is Dictionary:
		errors.append(owner + " 队伍增益必须是属性到整数点数的对象。")
		result.team_bonuses = {}
	else:
		result.team_bonuses = result.team_bonuses.duplicate()
	for key in result.team_bonuses:
		var amount: float = _number(result.team_bonuses[key], owner + ".team_bonuses." + str(key))
		if not key in T.OUTPUT_STATS or amount != floorf(amount): errors.append(owner + " 队伍增益只支持六类输出的非负整数点数。")
		result.team_bonuses[key] = int(amount)
	if not result.projectile_key is String:
		errors.append(owner + " 弹道键必须是字符串。")
		result.projectile_key = ""
	return result

## 属性百分比只作用于明确的连续属性，零基础值不会凭空获得新机制。
func _bonus_ratios(value: Variant, owner: String) -> Dictionary:
	if not value is Dictionary:
		errors.append(owner + " 属性加成必须是对象。")
		return {}
	var result: Dictionary = {}
	for key in value:
		if not key in RATIO_STATS:
			errors.append(owner + " 不支持百分比的属性: " + str(key))
			continue
		result[key] = _number(value[key], owner + ".stat_bonus_ratios." + str(key))
	return result

## 施放次数是有限正整数，防止内容配置制造无限循环。
func _multicast(value: Variant, owner: String) -> int:
	var number = _number(value, owner + ".multicast_count")
	if number != floorf(number) or number < 1 or number > MAX_MULTICAST:
		errors.append(owner + " 多重施法总次数必须为 1～8。")
	return int(number)

## 三类内容能力使用四种执行方式，事件条件不能冒充持续状态条件。
func _part(value: Variant, owner: String) -> Dictionary:
	var kind = _enum(value.get("execution_kind", "") if value is Dictionary else "", T.AbilityExecution, owner + ".execution_kind")
	if kind == T.AbilityExecution.TriggeredPassive: value = _expand_trigger(value, owner)
	var defaults = {"id": "", "execution_kind": kind}
	var required: Array = ["id", "execution_kind"]
	match kind:
		T.AbilityExecution.CooldownMain:
			defaults.main_ability_id = ""
			required.append("main_ability_id")
		T.AbilityExecution.TriggeredPassive:
			defaults.merge({"trigger_event": "BattleStarted", "priority": 0, "conditions": [], "actions": [], "max_triggers_per_second": 1, "max_triggers_per_battle": 99, "multicast_count": 1, "progress": {}, "internal_cooldown_seconds": 0.0})
			required.append_array(["trigger_event", "conditions", "actions", "max_triggers_per_second", "max_triggers_per_battle"])
		_:
			defaults.merge({"modifiers": {}, "target": "Self", "target_tags": {}})
			required.append("modifiers")
			if kind == T.AbilityExecution.PersistentBonus: defaults.lifetime = "Battlefield"
			if kind == T.AbilityExecution.ConditionalPassive:
				defaults.conditions = []
				required.append("conditions")
	var result = _object(value, defaults, required, owner)
	result.execution_kind = kind
	if not result.id is String or str(result.id).strip_edges().is_empty() or "|" in str(result.id): errors.append(owner + " 能力 ID 不能为空或含来源分隔符。")
	match kind:
		T.AbilityExecution.CooldownMain:
			if not result.main_ability_id is String or str(result.main_ability_id).strip_edges().is_empty(): errors.append(owner + " 主能力引用不能为空。")
		T.AbilityExecution.TriggeredPassive:
			var rule = result.duplicate(true)
			rule.erase("execution_kind")
			result.merge(_rule(rule, owner), true)
		_:
			result.modifiers = _modifiers(result.modifiers, owner + ".modifiers")
			result.target_tags = _tag_query(result.target_tags, owner + ".target_tags")
			result.target = _enum(result.target, T.Target, owner + ".target")
			if not result.modifiers.team_bonuses.is_empty() and not result.target in [T.Target.Self, T.Target.AllAllies, T.Target.AdjacentAllies, T.Target.LinkedAlly]: errors.append(owner + " 固定输出增益必须作用于自身或友军范围。")
			if result.target != T.Target.Self and not result.modifiers.stat_bonus_ratios.is_empty(): errors.append(owner + " 百分比属性修正只能作用于自身，队伍增益必须使用整数点数。")
			if result.target != T.Target.Self and result.modifiers.team_bonus_add != 0: errors.append(owner + " 队伍增益强化只能作用于自身，不能递归增强队伍。")
			if not result.target in [T.Target.Self, T.Target.AllAllies, T.Target.AllEnemies, T.Target.AllUnits, T.Target.AdjacentAllies, T.Target.LinkedAlly]: errors.append(owner + " 持续修正必须指定稳定宿主或队伍范围。")
			var numeric: Dictionary = result.modifiers.duplicate(true)
			numeric.projectile_key = ""
			if not has_contribution(numeric): errors.append(owner + " 持续能力必须有实际数值贡献；单独的弹道覆盖不是能力。")
			if kind == T.AbilityExecution.PersistentBonus:
				result.lifetime = _enum(result.lifetime, T.ContributionLifetime, owner + ".lifetime")
				if result.lifetime == T.ContributionLifetime.TeamMembership:
					var other: Dictionary = result.modifiers.duplicate(true)
					other.team_bonuses = {}
					if result.target != T.Target.AllAllies or result.modifiers.team_bonuses.is_empty() or has_contribution(other):
						errors.append(owner + " 队伍成员常驻只能提供全队输出增益，不能混入战场光环或其他修正。")
			if kind == T.AbilityExecution.ConditionalPassive:
				result.conditions = decode(result.conditions, "conditions", owner + ".conditions", names_only)
				if result.conditions.is_empty(): errors.append(owner + " 条件持续被动必须声明条件。")
				for condition in result.conditions:
					if not is_state_condition(condition.kind): errors.append(owner + " 持续被动不能读取事件来源或目标。")
					if condition.kind == T.Condition.OwnerHealthAtMostPercent and (result.modifiers.max_health != 0 or result.modifiers.stat_bonus_ratios.get("max_health", 0) != 0): errors.append(owner + " 生命阈值不能依赖自身会改变的生命上限。")
	return result

## 运行修正只接受已编译效果枚举，不能把名称交给整数结算。
static func runtime_modifier_errors(value: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for field in ["action_modifiers"]:
		if not value.get(field, []) is Array: continue
		for bonus in value.get(field, []):
			if bonus is Dictionary and not bonus.get("kind") is int: result.append("运行效果修正枚举未转换。")
	return result


## 持续条件不读取某次事件的来源、目标或位置关系。
static func is_state_condition(kind: int) -> bool:
	return kind in [T.Condition.Always, T.Condition.OwnerHealthAtMostPercent, T.Condition.PollutionAtLeast, T.Condition.PollutionAtMost, T.Condition.OwnerHasStatus, T.Condition.OwnerCounterAtLeast, T.Condition.OwnerHasTags]

## 判断修正是否有实际贡献，不以默认字段数量推断。
static func has_contribution(value: Dictionary) -> bool:
	return value.get("max_health", 0) != 0 or value.get("cooldown_seconds", 0) != 0 or not value.get("action_modifiers", []).is_empty() or value.get("stat_bonus_ratios", {}).values().any(func(ratio): return ratio != 0) or value.get("team_bonuses", {}).values().any(func(ratio): return ratio != 0) or not value.get("projectile_key", "").is_empty() or MODIFIER_STATS.any(func(key): return value.get(key, 0) != 0)

## 状态强度修正必须精确指定灼伤或中毒，不能同时增幅两者或控制时长。
func _validate_action_selector(value: Dictionary, owner: String) -> void:
	if MechanicSchema.is_mechanic(int(value.kind)): errors.append(owner + " 组合机制的费用与门槛不接受效果强度修正。")
	if value.kind == T.CombatAction.ApplyStatus:
		if not value.status in [T.Status.Burn, T.Status.Poison]: errors.append(owner + " 状态强度修正必须指定灼伤或中毒。")
	elif value.status != T.Status.None: errors.append(owner + " 非状态效果修正不能指定状态。")
