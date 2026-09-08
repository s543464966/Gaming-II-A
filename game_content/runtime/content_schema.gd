class_name GameContentSchema
extends RefCounted
## 策划来源的唯一字段契约；奖励配置与内容定义按职责分表。

const C = preload("res://game_content/runtime/content_types.gd")
const FILES = {
	"Cards/cards.csv": ["cards", "id,sort_order,card_kind,monster_role,combat_base_id,name,texture_key,output_type,max_health,physical_damage,witchcraft_damage,burn_damage,poison_damage,healing_power,shield_power,footprint_width,footprint_height,ability_parts,innate_ability_ids,default_projectile_key,crit_chance,crit_multiplier,haste_ratio,lifesteal_ratio,ammo_capacity,initially_unlocked,card_tag_ids,synergy_ids"],
	"Cards/card_tags.csv": ["card_tags", "id,sort_order,name"],
	"Cards/monster_sets.csv": ["monster_sets", "id,name"],
	"Cards/monster_set_members.csv": ["monster_sets.members", "monster_set_id,member_index,card_id"],
	"Combat/main_abilities.csv": ["main_abilities", "id,sort_order,texture_key,cooldown_seconds,priority,multicast_count,actions"],
	"Combat/growth_rules.csv": ["growth_rules", "id,chapter_level_bonus_ratio,fragment_step_bonus_ratio,star_fragment_costs,fragment_step_count,star_stat_multipliers"],
	"Combat/innate_abilities.csv": ["innate_abilities", "id,sort_order,name,texture_key,flavor_text,required_outputs,applies_to_kinds,ability_parts"],
	"Combat/talents.csv": ["talents", "id,sort_order,name,texture_key,flavor_text,prerequisite_id,ability_parts"],
	"Combat/synergies.csv": ["synergies", "id,sort_order,name,texture_key,flavor_text,activation_conditions,ability_parts"],
	"Progression/aurora_rewards.csv": ["aurora_rewards", "id,sort_order,name,description,aurora_reward_kind,amount_min,amount_max,distinct_count"],
	"Progression/aurora_reward_rules.csv": ["aurora_reward_rules", "id,max_triggers"],
	"Combat/ability_aliases.csv": ["ability_aliases", "alias_id,ability_id"],
	"Inventory/relics.csv": ["relics", "id,sort_order,name,texture_key,flavor_text,usage,ability_parts"],
	"Inventory/items.csv": ["items", "id,sort_order,name,texture_key,flavor_text,item_kind,max_stack"],
	"Progression/reward_dice.csv": ["reward_dice", "id,sort_order,name,texture_key,flavor_text,dice_kind,selection_weight"],
	"Progression/dice_reward_rules.csv": ["dice_reward_rules", "id,normal_dice_count,elite_dice_count,elite_treasure_dice_count,boss_dice_count,rerolls_per_node,choice_count,choice_seconds,refreshes_per_choice"],
	"Progression/dice_reward_pools.csv": ["dice_reward_pools", "id,sort_order,dice_kind,reward_kind,selection_weight,amount_min,amount_max,amount_step"],
	"Progression/chapters.csv": ["chapters", "id,sort_order,chapter_index,difficulty,monster_set_id,name,flavor_text,stamina_cost,unlocked_background_key,locked_background_key,enemy_health_multiplier,enemy_power_multiplier,elite_guard_health_multiplier,boss_guard_health_multiplier"],
	"Progression/chapter_sections.csv": ["chapters.sections", "chapter_id,section_index,normal_battle_count,elite_battle_count,relic_count,black_market_count,adventure_count"],
	"Progression/chapter_layers.csv": ["chapters.layers", "chapter_id,layer_index,normal_monster_count,enemy_health_multiplier,enemy_power_multiplier"],
	"Progression/adventure_node_rules.csv": ["adventure_node_rules", "id,node_type,title,description,action_label,effect_type,cost_currency,cost_amount,reward_currency,reward_amount"],
	"Shop/shop_offers.csv": ["shop_offers", "id,shop_tab,sort_order,reward_id,account_gold_price,account_star_stone_price,fragment_item_id,fragment_amount,purchase_limit,payable_percent"],
}
## 能力配方与来源按表查询；不再派生混合了来源和执行分类的 content_kind。
const ABILITY_TABLES = ["main_abilities", "innate_abilities", "talents", "synergies"]
const COMBAT_FIELDS = ["output_type", "max_health", "physical_damage", "witchcraft_damage", "burn_damage", "poison_damage", "healing_power", "shield_power",  "footprint_width", "footprint_height", "ability_parts", "innate_ability_ids", "default_projectile_key", "crit_chance", "crit_multiplier", "haste_ratio", "lifesteal_ratio", "ammo_capacity"]
const JOINS = [
	["monster_sets", "monster_sets.members", "monster_set_id", "member_index", "card_ids", "card_id"],
	["chapters", "chapters.layers", "chapter_id", "layer_index", "layers", ""],
	["chapters", "chapters.sections", "chapter_id", "section_index", "sections", ""],
]
const DIRECTORIES = ["Cards", "Combat", "Progression", "Inventory", "Shop"]
## 只有这些玩家可见字段进入翻译；中文仍由业务主表维护。
const TEXT_FIELDS = {
	"cards": ["name"], "card_tags": ["name"],
	"innate_abilities": ["name", "flavor_text"], "talents": ["name", "flavor_text"],
	"synergies": ["name", "flavor_text"], "aurora_rewards": ["name", "description"],
	"relics": ["name", "flavor_text"], "items": ["name", "flavor_text"],
	"reward_dice": ["name", "flavor_text"], "chapters": ["name", "flavor_text"],
	"adventure_node_rules": ["title", "description", "action_label"],
}
const EDITOR_FIELDS = {"monster_sets": ["name"]}
const TRANSLATION_FILES = ["Cards/translations.csv", "Combat/translations.csv", "Inventory/translations.csv", "Progression/translations.csv"]
const JSON_FIELDS = ["actions", "ability_parts", "innate_ability_ids", "card_tag_ids", "synergy_ids", "activation_conditions", "applies_to_kinds", "required_outputs", "star_fragment_costs", "star_stat_multipliers"]
const INTEGERS = ["physical_damage", "witchcraft_damage", "burn_damage", "poison_damage", "healing_power", "shield_power", "max_health", "fragment_step_count", "priority", "footprint_width", "footprint_height", "member_index", "chapter_index", "section_index", "layer_index", "normal_monster_count", "stamina_cost", "normal_battle_count", "elite_battle_count", "relic_count", "black_market_count", "adventure_count", "cost_amount", "reward_amount", "max_stack", "selection_weight", "sort_order", "fragment_amount", "purchase_limit", "payable_percent", "account_gold_price", "account_star_stone_price", "ammo_capacity", "multicast_count", "initially_unlocked", "normal_dice_count", "elite_dice_count", "elite_treasure_dice_count", "boss_dice_count", "rerolls_per_node", "choice_count", "choice_seconds", "refreshes_per_choice", "amount_min", "amount_max", "amount_step", "distinct_count", "max_triggers"]
const FLOATS = ["cooldown_seconds", "enemy_health_multiplier", "enemy_power_multiplier", "elite_guard_health_multiplier", "boss_guard_health_multiplier", "crit_chance", "crit_multiplier", "haste_ratio", "lifesteal_ratio", "chapter_level_bonus_ratio", "fragment_step_bonus_ratio"]

## 只有业务上没有对应值的字段可空；怪物变体继承由制作器单独验证。
static func nullable(table: String, column: String) -> bool:
	return column in {"shop_offers": ["account_gold_price", "account_star_stone_price"]}.get(table, [])

## 人工来源使用名称枚举，生成快照使用稳定整数。
static func enum_values(_table: String, column: String) -> Dictionary:
	match column:
		"card_kind": return CardTypes.Kind
		"monster_role": return C.MonsterRole
		"output_type": return CombatTypes.Output
		"difficulty": return C.Difficulty
		"node_type": return C.NodeType
		"dice_kind": return C.DiceKind
		"reward_kind": return C.DiceReward
		"aurora_reward_kind": return C.AuroraReward
		"effect_type": return C.NodeEffect
		"cost_currency", "reward_currency": return C.Currency
		"shop_tab": return C.ShopTab
		"item_kind": return C.Item
		"usage": return C.RelicUsage
	return {}

## 来源列与组装字段共用契约，不在静态行上重复编码所属表。
static func fields(table: String, assembled: bool = false) -> Array:
	var result: Array = []
	for entry in FILES.values():
		if entry[0] == table: result.assign(entry[1].split(","))
	if assembled:
		for field in TEXT_FIELDS.get(table, []):
			result.erase(field)
			result.append(field + "_key")
		for field in EDITOR_FIELDS.get(table, []): result.erase(field)
		for join in JOINS:
			if join[0] == table: result.append(join[4])
	return result

## 内容键由表语义、稳定 ID 和字段构成，不依赖中文或行号。
static func text_key(table: String, id: String, field: String) -> String:
	return "content.%s.%s.%s" % [table, id, field]
