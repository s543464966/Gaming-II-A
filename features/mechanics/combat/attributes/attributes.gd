class_name CombatAttributes
extends RefCounted
## 基础属性与常驻修正的唯一数值计算；不保存成长或模式状态。

const DEFAULT_CRIT_CHANCE = 0.0
const DEFAULT_CRIT_MULTIPLIER = 1.5
const MIN_COOLDOWN = 0.1
const BASE_STATS = {"physical_damage": 0.0, "witchcraft_damage": 0.0, "burn_damage": 0.0, "poison_damage": 0.0, "healing_power": 0.0, "shield_power": 0.0, "crit_chance": DEFAULT_CRIT_CHANCE, "crit_multiplier": DEFAULT_CRIT_MULTIPLIER, "haste_ratio": 0.0, "lifesteal_ratio": 0.0}

## 内容和运行请求共用基础属性范围，不将非法概率静默修正为正常配置。
static func validation_errors(value: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in BASE_STATS:
		var number: Variant = value.get(key, BASE_STATS[key])
		var minimum = 1.0 if key == "crit_multiplier" else 0.0
		var maximum = INF if key in CombatTypes.OUTPUT_STATS else AbilitySchema.MAX_CRIT_MULTIPLIER if key == "crit_multiplier" else DeterministicMath.f32(AbilitySchema.MAX_HASTE) if key == "haste_ratio" else 1.0
		if not (number is float or number is int) or not is_finite(float(number)) or number < minimum or number > maximum:
			errors.append("战斗属性范围无效: " + key)
	return errors

## 个人成长按原属性池计算，队伍整数贡献直接加到最终输出。
static func stats(definition: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var modifiers: Dictionary = definition.get("modifiers", {})
	for key in BASE_STATS:
		var base = float(definition.get(key, BASE_STATS[key])) + float(modifiers.get(key, 0.0))
		result[key] = attribute_points(definition, key) if key in CombatTypes.OUTPUT_STATS else base
	result.crit_chance = clampf(result.crit_chance, 0.0, 1.0)
	result.crit_multiplier = clampf(result.crit_multiplier, 1.0, AbilitySchema.MAX_CRIT_MULTIPLIER)
	result.haste_ratio = clampf(result.haste_ratio, 0.0, AbilitySchema.MAX_HASTE)
	result.lifesteal_ratio = clampf(result.lifesteal_ratio, 0.0, 1.0)
	return result

## 成长与个人百分比进入同一比例池，队伍固定点数不进入此池。
static func bonus_ratio(definition: Dictionary, key: String) -> float:
	var modifiers: Dictionary = definition.get("modifiers", {})
	return maxf(-1.0, float(definition.get("growth_bonus_ratio", 0)) + float(modifiers.get("stat_bonus_ratios", {}).get(key, 0)))

## 同一提供者对每种属性只追加一次装备点数，拆分能力不复制强化收益。
static func team_contributions(contributions: Array, bonus: int) -> Array:
	var result = contributions.duplicate(true)
	var remaining: Dictionary = {}
	for modifiers in result:
		for stat in modifiers.get("team_bonuses", {}):
			var amount: int = int(modifiers.team_bonuses[stat])
			var change: int = maxi(-amount, int(remaining.get(stat, bonus)))
			modifiers.team_bonuses[stat] = amount + change
			remaining[stat] = int(remaining.get(stat, bonus)) - change
	return result

## 碎片只提升本星基准，避免升星清空档位时削减装备固定收益。
static func attribute_points(definition: Dictionary, key: String) -> float:
	var base = float(definition.get(key, 0))
	var flat = float(definition.get("modifiers", {}).get(key, 0))
	var ratio = bonus_ratio(definition, key)
	var team: int = int(definition.get("modifiers", {}).get("team_bonuses", {}).get(key, 0)) if key in CombatTypes.OUTPUT_STATS else 0
	return points(base * (1 + ratio) + flat * (1 + ratio - float(definition.get("fragment_bonus_ratio", 0)))) + team

## 点数在结算边界四舍五入，不将秒数、概率或系数误作整数。
static func points(value: float) -> float:
	return maxf(0.0, roundf(DeterministicMath.f32(value)))

## 仅英雄和随从可重复施放，次数是总次数而非额外次数。
static func multicast(definition: Dictionary, ability: Dictionary) -> int:
	if not definition.get("kind") in [CardTypes.Kind.CoreHero, CardTypes.Kind.Minion]: return 1
	return clampi(int(ability.get("multicast_count", 1)) + int(definition.get("modifiers", {}).get("multicast_bonus", 0)), 1, AbilitySchema.MAX_MULTICAST)

## 零容量表示未启用弹药扩充；非道具永远没有弹药池。
static func ammo_capacity(definition: Dictionary) -> int:
	if definition.get("kind") != CardTypes.Kind.ItemCard or int(definition.get("ammo_capacity", 0)) <= 0: return 0
	return maxi(1, int(definition.ammo_capacity) + int(definition.get("modifiers", {}).get("ammo_capacity", 0)))

## 主动强度随卡牌成长；伤害直接读已成长的卡牌属性，不重复乘成长倍率。
static func action_amount(definition: Dictionary, action: Dictionary, strength_multiplier: float = 1.0) -> float:
	var bonus = 0.0
	for entry in definition.get("modifiers", {}).get("action_modifiers", []):
		if ratio_applies(entry, action):
			bonus = DeterministicMath.f32(bonus + float(entry.amount))
	var discrete = int(action.kind) in [CombatTypes.CombatAction.GrantMainAbility, CombatTypes.CombatAction.RefillAmmo, CombatTypes.CombatAction.ExpandAmmo]
	var base = stats(definition).get(CombatTypes.output_stat(CombatTypes.output_kind(action)), 0.0) * float(action.power_multiplier) if action.get("power_multiplier", 0) > 0 else float(action.get("amount", 0)) * (1.0 if discrete else strength_multiplier)
	var value = DeterministicMath.f32(base + bonus)
	if int(action.kind) == CombatTypes.CombatAction.Haste: return clampf(value, 0.0, AbilitySchema.MAX_HASTE)
	return value if int(action.kind) == CombatTypes.CombatAction.ChangePollution else maxf(0.0, value)

## 效果加成只匹配同一原子效果及具体状态，物理不再隐式强化其他伤害。
static func ratio_applies(selector: Dictionary, action: Dictionary) -> bool:
	return int(selector.kind) == int(action.kind) and (int(action.kind) != CombatTypes.CombatAction.ApplyStatus or selector.get("status", CombatTypes.Status.None) == action.get("status"))

## 来源投影与成长共用自身常驻聚合，不依赖装配器或可变战斗实例。
static func self_modifiers(sources: Array, card_tags: Array = []) -> Dictionary:
	var values: Array[Dictionary] = []
	for part: Dictionary in sources:
		if part.target == CombatTypes.Target.Self and CardTagQuery.matches(card_tags, part.get("target_tags", {})):
			values.append(part.modifiers)
	return combine_modifiers(values)

## 按附着顺序合并属性与效果加成，最后一个非空弹道覆盖生效。
static func combine_modifiers(sources: Array) -> Dictionary:
	var result = {"max_health": 0.0, "cooldown_seconds": 0.0, "action_modifiers": [], "stat_bonus_ratios": {}, "team_bonuses": {}, "projectile_key": ""}
	for key in AbilitySchema.MODIFIER_STATS: result[key] = 0
	for source in sources:
		result.max_health = DeterministicMath.f32(result.max_health + float(source.get("max_health", 0.0)))
		result.cooldown_seconds = DeterministicMath.f32(result.cooldown_seconds + float(source.get("cooldown_seconds", 0.0)))
		result.action_modifiers.append_array(source.get("action_modifiers", []).duplicate(true))
		for key in source.get("stat_bonus_ratios", {}):
			result.stat_bonus_ratios[key] = float(result.stat_bonus_ratios.get(key, 0.0)) + float(source.stat_bonus_ratios[key])
		for key in source.get("team_bonuses", {}):
			result.team_bonuses[key] = int(result.team_bonuses.get(key, 0)) + int(source.team_bonuses[key])
		for key in AbilitySchema.MODIFIER_STATS: result[key] += source.get(key, 0)
		if not str(source.get("projectile_key", "")).is_empty():
			result.projectile_key = source.projectile_key
	return result

## 成长已由装配器投影；这里只计算当前有效装备与被动来源。
static func max_health(definition: Dictionary) -> float:
	return maxf(1.0, attribute_points(definition, "max_health"))

## 主能力的实际冷却由自身定义与载体修正计算，最短为 0.1 秒。
static func cooldown(main_ability: Dictionary, modifiers: Dictionary = {}, haste: float = 0.0) -> float:
	var base = maxf(MIN_COOLDOWN, float(main_ability.cooldown_seconds) + float(modifiers.get("cooldown_seconds", 0.0)))
	return maxf(DeterministicMath.f32(MIN_COOLDOWN), DeterministicMath.f32(base * (1.0 - clampf(haste + float(modifiers.get("haste_ratio", 0.0)), 0.0, AbilitySchema.MAX_HASTE))))
