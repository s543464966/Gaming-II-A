class_name CardGrowth
extends RefCounted
## 永久星级、碎片进度和章节强化的统一只读投影，不负责获得或保存。

## 满星不再计算碎片收益；每档必须收集到完整需求比例。
static func fragment_steps(quantity: int, star: int, policy: Dictionary) -> int:
	var cost = fragment_cost(star, policy)
	if cost == 0: return 0
	var steps = int(policy.fragment_step_count)
	@warning_ignore("integer_division")
	return clampi(quantity, 0, cost) / (cost / steps)

## 数组长度定义永久星级上限，最后一星没有再次升星需求。
static func fragment_cost(star: int, policy: Dictionary) -> int:
	return int(policy.star_fragment_costs[star - 1]) if star >= 1 and star <= policy.star_fragment_costs.size() else 0

## 星级系数只定义有限培养阶段，碎片与章节收益由属性加成池计算。
static func permanent_multiplier(growth: Dictionary, policy: Dictionary) -> float:
	var star = int(growth.get("star_level", 1))
	return float(policy.star_stat_multipliers[star - 1])

## 星级和碎片档位是模式锁定的成长事实，不接受派生属性或主能力等级。
static func validate(growth: Variant, policy: Dictionary) -> bool:
	if not growth is Dictionary or growth.size() != 2: return false
	var star: Variant = growth.get("star_level")
	var steps: Variant = growth.get("fragment_steps")
	if not star is int or star < 1 or star > policy.star_fragment_costs.size() + 1: return false
	if not steps is int or steps < 0 or steps > int(policy.fragment_step_count): return false
	return steps == 0 or star <= policy.star_fragment_costs.size()

## 只增长生命与六类输出；冷却、控制时长、概率和离散次数不盲目放大。
static func project(definition: Dictionary, growth: Dictionary, copies: int, policy: Dictionary) -> Dictionary:
	var result = definition.duplicate(true)
	var level = DuplicateGrowth.level(copies)
	var permanent = permanent_multiplier(growth, policy)
	result.max_health = DeterministicMath.f32(float(result.max_health) * permanent)
	for key in CombatTypes.OUTPUT_STATS: result[key] = DeterministicMath.f32(float(result.get(key, 0)) * permanent)
	result.fragment_bonus_ratio = int(growth.get("fragment_steps", 0)) * float(policy.fragment_step_bonus_ratio)
	result.growth_bonus_ratio = result.fragment_bonus_ratio + level * float(policy.chapter_level_bonus_ratio)
	# 功能参数与最终固定贡献不随培养增长，数值动作只读取成长后的输出。
	result.main_ability_strength_multiplier = 1.0
	result.modifiers = CombatAttributes.self_modifiers(result.get("modifier_sources", []), result.get("card_tag_ids", []))
	result.star_level = int(growth.get("star_level", 1))
	result.fragment_steps = int(growth.get("fragment_steps", 0))
	result.chapter_level = level
	result.chapter_progress = DuplicateGrowth.progress(copies)
	result.chapter_next = DuplicateGrowth.required_next(copies)
	return result
