class_name MechanicSchema
extends RefCounted
## 组合机制的参数契约；嵌套效果仍由唯一能力解析器校验，不接受任意脚本。

const T = preload("res://features/mechanics/contracts/combat_types.gd")
const MAX_NESTING = 4
const MAIN_ABILITY_REFERENCES = [T.CombatAction.GrantMainAbility, T.CombatAction.CopyMainAbility, T.CombatAction.Transform]

## 十二类基础效果之外的机制使用受限参数对象。
static func is_mechanic(kind: int) -> bool:
	return kind >= T.CombatAction.Accumulate and kind <= T.CombatAction.Sacrifice

## 效果与规则的边界共享有限数字验证。
static func number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum

## 技术键只做身份，不直接翻译或显示给玩家。
static func valid_key(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 64 and value.is_valid_identifier()

## 各种机制只接受自身有意义的字段，子效果最多嵌套四层。
static func parameters(action: Dictionary, errors: Array[String], owner: String, decode_action: Callable) -> Dictionary:
	var defaults: Dictionary = {}
	match int(action.kind):
		T.CombatAction.Accumulate: defaults = {"key": "", "threshold": 1, "limit": 10}
		T.CombatAction.Detonate: defaults = {"count": 5, "multiplier": 1.2}
		T.CombatAction.Mark: defaults = {"key": "focus"}
		T.CombatAction.Empower: defaults = {"limit": 2.0}
		T.CombatAction.Convert: defaults = {"resource": "Shield", "key": "", "payload": []}
		T.CombatAction.Transfer: defaults = {"resource": "Shield", "key": ""}
		T.CombatAction.CopyMainAbility, T.CombatAction.Echo: defaults = {"multiplier": 0.5}
		T.CombatAction.Overload: defaults = {"limit": 3, "recovery_seconds": 2.0, "payload": []}
		T.CombatAction.Chain: defaults = {"jumps": 3, "multiplier": 0.7, "payload": []}
		T.CombatAction.Sacrifice: defaults = {"payload": []}
	var input: Variant = action.get("parameters", {})
	if not input is Dictionary:
		errors.append(owner + " 机制参数必须是对象。")
		return defaults
	for key in input:
		if not defaults.has(key): errors.append(owner + " 未知机制参数: " + str(key))
		else: defaults[key] = input[key]
	for key in ["count", "jumps", "threshold", "limit"]:
		if not defaults.has(key): continue
		var maximum: int = 100 if key in ["threshold", "limit"] else 10
		if action.kind == T.CombatAction.Empower:
			if not number(defaults[key], 0.01, 3): errors.append(owner + " 蓄力上限必须在 0.01～3。")
		elif not number(defaults[key], 1, maximum) or defaults[key] != floorf(defaults[key]): errors.append(owner + " 机制计数必须是有界正整数。")
	if action.kind == T.CombatAction.Accumulate and number(defaults.threshold, 1, 100) and number(defaults.limit, 1, 100) and defaults.threshold > defaults.limit: errors.append(owner + " 阈值不能超过计数上限。")
	if defaults.has("multiplier") and not number(defaults.multiplier, 0.01, 3): errors.append(owner + " 机制倍率必须在 0.01～3。")
	if action.kind in [T.CombatAction.Chain, T.CombatAction.Echo, T.CombatAction.CopyMainAbility] and not number(defaults.multiplier, 0.01, 1): errors.append(owner + " 派生强度必须在 1%～100%，不能逐跳放大。")
	if defaults.has("recovery_seconds") and not number(defaults.recovery_seconds, 0.1, 60): errors.append(owner + " 停机时间必须在 0.1～60 秒。")
	if action.kind in [T.CombatAction.Accumulate, T.CombatAction.Mark] and not valid_key(defaults.key): errors.append(owner + " 计数或标记键无效。")
	if defaults.has("resource"):
		var allowed: Array = ["Shield", "Health", "Ammo", "Counter"] if action.kind == T.CombatAction.Convert else ["Shield", "Burn", "Poison", "Counter"]
		if not defaults.resource in allowed: errors.append(owner + " 资源类别不支持此操作。")
		if defaults.resource == "Counter" and not valid_key(defaults.key): errors.append(owner + " 计数资源必须指定键。")
		elif defaults.resource != "Counter" and defaults.key != "": errors.append(owner + " 非计数资源不能夹带计数键。")
	if defaults.has("payload"):
		if not defaults.payload is Array or defaults.payload.is_empty() or defaults.payload.size() > 4:
			errors.append(owner + " 机制必须有 1～4 项真实子效果。")
			defaults.payload = []
		else:
			var compiled: Array = []
			for index in range(defaults.payload.size()): compiled.append(decode_action.call(defaults.payload[index], owner + ".payload[%d]" % index))
			defaults.payload = compiled
			if action.kind == T.CombatAction.Chain and (compiled.size() != 1 or T.output_kind(compiled[0]) == T.Output.Special): errors.append(owner + " 连锁只传播一个数值效果。")
	return defaults

## 连携进度按规则记录；默认一次即触发，零窗口表示本场累计。
static func progress(value: Variant, errors: Array[String], owner: String) -> Dictionary:
	var result: Dictionary = {"count": 1, "window_seconds": 0.0, "unique_sources": false}
	if not value is Dictionary:
		errors.append(owner + " 连携进度必须是对象。")
		return result
	for key in value:
		if not result.has(key): errors.append(owner + " 未知连携参数: " + str(key))
		else: result[key] = value[key]
	if not number(result.count, 1, 100) or result.count != floorf(result.count): errors.append(owner + " 连携次数必须为 1～100 整数。")
	if not number(result.window_seconds, 0, 120) or not result.unique_sources is bool: errors.append(owner + " 连携窗口或去重参数无效。")
	return result

## 预设不能通过直接或嵌套授予绕过复制与变形的数量边界。
static func snapshot_supported(kind: int, actions: Array) -> bool:
	for action in flatten(actions):
		if action.get("kind") in [T.CombatAction.GrantMainAbility, T.CombatAction.CopyMainAbility, T.CombatAction.Transform]: return false
		if kind == T.CombatAction.CopyMainAbility and action.get("kind") == T.CombatAction.Echo: return false
	return true

## 引用、宿主和资源检查必须遍历全部子效果，不能绕过外层契约。
static func flatten(values: Array, depth: int = 0) -> Array:
	var result: Array = []
	if depth > MAX_NESTING: return result
	for value in values:
		if not value is Dictionary: continue
		result.append(value)
		var parameters_value: Variant = value.get("parameters", {})
		if parameters_value is Dictionary and parameters_value.get("payload", []) is Array:
			result.append_array(flatten(parameters_value.get("payload", []), depth + 1))
	return result
