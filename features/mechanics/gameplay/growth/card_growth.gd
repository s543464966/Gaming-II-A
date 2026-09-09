class_name CardGrowth
extends RefCounted
## 永久星级、已支付培养进度和章节强化的只读投影，不读取货币或碎片余额。

## 每次培养支付一档星石，满星不再收费。
static func training_cost(star: int, policy: Dictionary) -> int:
	return int(policy.star_stone_step_costs[star - 1]) if star >= 1 and star <= policy.star_stone_step_costs.size() else 0

## 星级系数只定义有限培养阶段，培养与章节收益由属性加成池计算。
static func permanent_multiplier(growth: Dictionary, policy: Dictionary) -> float:
	var star = int(growth.get("star_level", 1))
	return float(policy.star_stat_multipliers[star - 1])

## 星级和培养档位是模式锁定的成长事实，不接受派生属性或主能力等级。
static func validate(growth: Variant, policy: Dictionary) -> bool:
	if not growth is Dictionary or growth.size() != 2: return false
	var star: Variant = growth.get("star_level")
	var steps: Variant = growth.get("training_steps")
	if not star is int or star < 1 or star > policy.star_stone_step_costs.size() + 1: return false
	if not steps is int or steps < 0 or steps > int(policy.training_step_count): return false
	return steps == 0 or star <= policy.star_stone_step_costs.size()

## 只增长生命与六类输出；冷却、控制时长、概率和离散次数不盲目放大。
static func project(definition: Dictionary, growth: Dictionary, copies: int, policy: Dictionary) -> Dictionary:
	var result = definition.duplicate(true)
	var level = DuplicateGrowth.level(copies)
	var permanent = permanent_multiplier(growth, policy)
	result.base_point_multiplier = permanent
	result.max_health = DeterministicMath.f32(float(result.max_health) * permanent)
	for key in CombatTypes.OUTPUT_STATS: result[key] = DeterministicMath.f32(float(result.get(key, 0)) * permanent)
	result.training_bonus_ratio = int(growth.get("training_steps", 0)) * float(policy.training_step_bonus_ratio)
	result.growth_bonus_ratio = result.training_bonus_ratio + level * float(policy.chapter_level_bonus_ratio)
	# 英雄的长期优势进入基础伤害加法池；不放大生命与最终固定奖励。
	result.base_damage_growth_ratio = (int(growth.get("star_level", 1)) - 1) * float(policy.hero_damage_bonus_ratio_per_star) if result.kind == CardTypes.Kind.CoreHero else 0.0
	# 功能参数与最终固定贡献不随培养增长，数值动作只读取成长后的输出。
	result.main_ability_strength_multiplier = 1.0
	result.modifiers = CombatAttributes.self_modifiers(result.get("modifier_sources", []), result.get("card_tag_ids", []))
	result.star_level = int(growth.get("star_level", 1))
	result.training_steps = int(growth.get("training_steps", 0))
	result.chapter_level = level
	result.chapter_progress = DuplicateGrowth.progress(copies)
	result.chapter_next = DuplicateGrowth.required_next(copies)
	return result
