class_name DataValidator
extends RefCounted
## 验证完整内容表、派生定义、跨表引用及实际可执行参数，拒绝部分有效目录。

const T = preload("res://features/mechanics/contracts/combat_types.gd")
const C = preload("res://game_content/runtime/content_types.gd")
const Schema = preload("res://game_content/runtime/content_schema.gd")
const Format = preload("res://game_content/runtime/snapshot_format.gd")
const Codec = preload("res://game_content/runtime/rule_codec.gd")
var errors: Array[String] = []
var assets: Dictionary = {}
var indices: Dictionary = {}

## 先检查完整形状，再验证引用和规则；所有错误都阻止快照发布。
func validate(document: Dictionary, registry: Dictionary, check_resources: bool = true, deferred_assets: Dictionary = {}) -> Array[String]:
	errors.clear()
	indices.clear()
	assets = registry
	for key in document:
		if key not in Format.TABLES and key != "metadata": errors.append("快照包含未声明的表: " + str(key))
	if not document.get("metadata") is Dictionary: return ["快照缺少 metadata。"]
	if document.metadata.get("schema_version") != Format.VERSION: return ["不支持的快照 Schema。"]
	if document.metadata.get("content_hash", "") != Format.content_hash(document): errors.append("快照内容指纹不匹配。")
	if not document.metadata.get("sources") is Array or document.metadata.sources.size() != Schema.FILES.size(): errors.append("快照必须记录完整策划来源。")
	_sources(document.metadata)
	var all_ids: Dictionary = {}
	for table in Format.TABLES:
		if not document.get(table) is Array:
			errors.append(table + " 必须是数组。")
			continue
		var index: Dictionary = {}
		var orders: Array = []
		for row in document[table]:
			if not _shape(row, table): continue
			if row.has("sort_order"):
				if row.sort_order < 0 or row.sort_order in orders: errors.append(table + " 展示顺序负数或重复。")
				orders.append(row.sort_order)
			var id: String = row.alias_id if table == "ability_aliases" else row.id
			if id.is_empty() or index.has(id): errors.append(table + " 含空或重复 ID: " + id)
			index[id] = row
			if table == "ability_aliases": continue
			if all_ids.has(id): errors.append("内容 ID 跨表重复: " + id)
			all_ids[id] = true
			_short_id(id, _prefix(table, row))
			for field in Schema.TEXT_FIELDS.get(table, []):
				if field == "flavor_text" and row[field + "_key"].is_empty(): continue
				if row[field + "_key"] != Schema.text_key(table, id, field): errors.append("内容文本键不符合身份: " + id + "." + field)
		indices[table] = index
	if not errors.is_empty(): return errors
	for table: String in Format.TABLES:
		for row: Dictionary in document[table]: _tag_references(row, str(row.get("id", table)))
	for table in ["cards", "chapters", "relics", "shop_offers", "reward_dice", "dice_reward_pools"]:
		if document[table].is_empty(): errors.append(table + " 不能为空。")
	for alias in document.ability_aliases:
		if all_ids.has(alias.alias_id): errors.append("能力别名覆盖正式 ID: " + alias.alias_id)
		if not Schema.ABILITY_TABLES.any(func(table): return indices[table].has(alias.ability_id)):
			errors.append("旧能力别名引用不存在的定义: " + alias.alias_id)
	for card in document.cards: _card(card)
	for id in ["H001", "H002"]:
		if indices.cards.get(id, {}).get("card_kind") != CardTypes.Kind.CoreHero: errors.append("缺少初始英雄: " + id)
	for value in document.monster_sets:
		if value.card_ids.is_empty(): errors.append("怪物集合为空: " + value.id)
		var seen: Array = []
		for id in value.card_ids:
			if not id is String:
				errors.append("怪物成员必须为 ID: " + value.id)
				continue
			if id in seen: errors.append("怪物集合重复成员: " + id)
			seen.append(id)
			if indices.cards.get(id, {}).get("card_kind") != CardTypes.Kind.Monster: errors.append("怪物集合引用非怪物: " + id)
	for table in Schema.ABILITY_TABLES:
		for row in document[table]: _ability(row, table)
	_talent_prerequisites(document)
	_adventure_requirements(document)
	_growth_rules(document.growth_rules)
	_dice(document)
	var chapter_keys: Array = []
	for chapter in document.chapters:
		var key = str(chapter.difficulty) + ":" + str(chapter.chapter_index)
		if key in chapter_keys: errors.append("章节难度和顺序重复: " + chapter.id)
		chapter_keys.append(key)
		_chapter(chapter)
	_monster_pool_requirements(document.chapters)
	_node_rules(document.adventure_node_rules)
	for item in document.items:
		if item.item_kind not in [C.Item.Prop, C.Item.Material]: errors.append("背包物品类别无效: " + item.id)
		_positive(item.max_stack, item.id + " 每组展示数量")
		_asset(item.texture_key, "Texture", item.id)
	for gear in document.relics: _relic(gear)
	_shop(document.shop_offers)
	if check_resources: _resources(deferred_assets)
	return errors

## 来源列和组装列必须完整且没有额外字段，结构化字段保留实际类型。
func _shape(row: Variant, table: String, child: bool = false) -> bool:
	if not row is Dictionary:
		errors.append(table + " 含非对象记录。")
		return false
	var fields = Schema.fields(table, not child)
	if child:
		for join in Schema.JOINS:
			if join[1] == table: fields.erase(join[2])
	var valid = true
	for key in fields:
		if not row.has(key):
			errors.append(table + " 缺少字段 " + key)
			valid = false
			continue
		var value: Variant = row[key]
		if value == null and Schema.nullable(table, key): continue
		var type_ok: bool
		if key in Schema.JSON_FIELDS or key in ["card_ids", "layers", "sections"]: type_ok = value is Array
		elif key in Schema.INTEGERS or not Schema.enum_values(table, key).is_empty(): type_ok = value is int
		elif key in Schema.FLOATS: type_ok = (value is int or value is float) and is_finite(float(value))
		else: type_ok = value is String
		if not type_ok:
			errors.append(table + "." + key + " 类型无效。")
			valid = false
		var options = Schema.enum_values(table, key)
		if not options.is_empty() and value not in options.values():
			errors.append(table + "." + key + " 枚举无效。")
			valid = false
	for key in row:
		if key not in fields:
			errors.append(table + " 含未知字段 " + str(key))
			valid = false
	return valid

## 短编码只做标识校验，分类、难度和基础定义关系均读取字段。
func _prefix(table: String, row: Dictionary) -> String:
	if table == "card_tags": return "TG"
	if table == "growth_rules": return "GR"
	if table == "cards":
		if row.card_kind == CardTypes.Kind.Monster: return {C.MonsterRole.Normal: "M", C.MonsterRole.Elite: "ME", C.MonsterRole.Boss: "MB"}.get(row.monster_role, "INVALID")
		return {CardTypes.Kind.CoreHero: "H", CardTypes.Kind.Minion: "HS", CardTypes.Kind.ItemCard: "PC" if row.id.begins_with("PC") else "IC"}.get(row.card_kind, "INVALID")
	if table == "items": return "FR" if row.item_kind == C.Item.Material else "IT"
	return {"main_abilities": "SK", "innate_abilities": "EN", "talents": "TA", "synergies": "SY", "aurora_rewards": "AR", "aurora_reward_rules": "AS", "black_market_rules": "BM", "adventure_encounter_rules": "EC", "relics": "GA", "monster_sets": "MS", "chapters": "CH", "reward_dice": "DI", "dice_reward_rules": "DR", "dice_reward_pools": "DP", "shop_offers": "SH", "adventure_node_rules": "NR"}.get(table, "INVALID")

## 阶段曲线与碎片档位分别校验，升星不能使满档属性倒退。
func _growth_rules(rows: Array) -> void:
	if rows.size() != 1:
		errors.append("成长规则必须且只能包含一行。")
		return
	var row: Dictionary = rows[0]
	for key in ["chapter_level_bonus_ratio", "training_step_bonus_ratio"]:
		_positive(row[key], "成长规则 " + key)
	var hero_bonus: Variant = row.hero_damage_bonus_ratio_per_star
	if not (hero_bonus is int or hero_bonus is float) or not is_finite(float(hero_bonus)) or hero_bonus < 0:
		errors.append("英雄每星伤害加值必须为有限非负比例。")
	if row.training_step_count < 1:
		errors.append("培养档数必须为正整数。")
		return
	if row.star_stone_step_costs.size() != 4 or row.star_stat_multipliers.size() != 5:
		errors.append("五星成长必须包含四次需求和五个星级系数。")
		return
	var previous = 0
	for cost in row.star_stone_step_costs:
		if not cost is int or cost <= previous: errors.append("每档星石费用必须为递增正整数。")
		previous = int(cost)
	if row.star_stat_multipliers[0] != 1: errors.append("一星基准必须为1。")
	for index in range(1, row.star_stat_multipliers.size()):
		if row.star_stat_multipliers[index] < row.star_stat_multipliers[index - 1] * (1 + row.training_step_count * row.training_step_bonus_ratio): errors.append("升星系数不能低于前一星满培养基准。")

## 分类前缀之后为三至六位正序号，零号不发布。
func _short_id(id: String, prefix: String) -> void:
	var pattern = RegEx.new()
	pattern.compile("^" + prefix + "[0-9]{3,6}$")
	if pattern.search(id) == null or int(id.trim_prefix(prefix)) <= 0: errors.append("内容 ID 格式或分类错误: " + id)

## 所有棋盘载体读取同一基础契约，精英与首领固定横向两格且外观变体不得覆盖。
func _card(card: Dictionary) -> void:
	if not CardTagQuery.valid_card(card.card_tag_ids, card.output_type): errors.append("卡牌标签需唯一；特殊主效须 2～3 个，其他须 1～2 个: " + card.id)
	var codec := Codec.new()
	for field: String in ["card_tag_ids", "synergy_ids"]:
		codec.decode(card[field], field, card.id, false)
		for id: Variant in card[field]:
			if id is String: _reference("card_tags" if field == "card_tag_ids" else "synergies", id, card.id)
	errors.append_array(codec.errors)
	if not card.initially_unlocked in [0, 1] or (card.initially_unlocked == 1 and not card.card_kind in [CardTypes.Kind.CoreHero, CardTypes.Kind.Minion]): errors.append("初始解锁标记只允许用于英雄和随从: " + card.id)
	var item = card.card_kind == CardTypes.Kind.ItemCard
	var monster = card.card_kind == CardTypes.Kind.Monster
	if monster != (card.monster_role != C.MonsterRole.None): errors.append("只有怪物必须声明普通、精英或首领职责: " + card.id)
	_positive(card.max_health, card.id + " 生命")
	errors.append_array(CombatAttributes.validation_errors(card))
	if (card.crit_chance != 0 and not (card.id == "H004" and is_equal_approx(card.crit_chance, 0.15))) or not is_equal_approx(card.crit_multiplier, 1.5) or card.haste_ratio != 0 or card.lifesteal_ratio != 0: errors.append("卡牌不配置百分比能力；仅保留待确认的德里暴击率及通用暴击倍率: " + card.id)
	if BattleGrid.footprint_mask(0, card.footprint_width, card.footprint_height) == 0: errors.append("卡牌占位无效: " + card.id)
	if monster and card.monster_role in [C.MonsterRole.Elite, C.MonsterRole.Boss] and (card.footprint_width != 2 or card.footprint_height != 1): errors.append("精英与首领必须横向占用两格: " + card.id)
	_asset(card.texture_key, "Texture", card.id, item)
	_asset(card.default_projectile_key, "Projectile", card.id, card.output_type == T.Output.Special)
	var parts: Array = _parts(card.ability_parts, card.id, [card.card_kind]) if not card.ability_parts.is_empty() else []
	var main_abilities = parts.filter(func(part): return part.execution_kind == T.AbilityExecution.CooldownMain).map(func(part): return part.main_ability_id)
	if parts.is_empty() and card.innate_ability_ids.is_empty(): errors.append("卡牌至少需要一项实际能力: " + card.id)
	_card_kit(card, main_abilities)
	_card_output(card, main_abilities)
	if monster or card.card_kind == CardTypes.Kind.CoreHero: _restricted_actions(card)
	if card.ammo_capacity < 0 or (card.ammo_capacity > 0 and (not item or main_abilities.is_empty())): errors.append("弹药容量只用于有主能力的道具: " + card.id)
	if not card.combat_base_id.is_empty():
		var base: Dictionary = indices.cards.get(card.combat_base_id, {})
		if not monster or base.is_empty() or base.card_kind != CardTypes.Kind.Monster or not base.combat_base_id.is_empty() or base.monster_role != card.monster_role:
			errors.append("怪物基础引用无效: " + card.id)
		else:
			for field in Schema.COMBAT_FIELDS:
				if card[field] != base[field]: errors.append("怪物变体与基础战斗参数不一致: " + card.id + "." + field)

## 分表能力只验证自己拥有的参数，不以大量空列表示不适用职责。
func _ability(row: Dictionary, table: String) -> void:
	_asset(row.texture_key, "Texture", row.id)
	if table == "main_abilities":
		if row.multicast_count != 1: errors.append("当前正式内容只允许单次施法，multicast_count 必须为 1: " + row.id)
		_actions(row.actions, row.id)
		if row.actions.is_empty(): errors.append("主能力必须包含实际效果动作: " + row.id)
		for action in row.actions:
			if T.output_kind(action) != T.Output.Special and action.get("amount_source", T.AmountSource.Fixed) == T.AmountSource.Fixed: errors.append("主能力数值必须直接读取卡牌输出或配置追加效果整数基数: " + row.id)
		_positive(row.cooldown_seconds, row.id + " 冷却")
		return
	var codec = Codec.new()
	var kinds: Array = []
	if table == "innate_abilities":
		kinds = codec.decode(row.applies_to_kinds, "applies_to_kinds", row.id, false)
		codec.decode(row.required_outputs, "required_outputs", row.id, false)
		if row.required_outputs.is_empty(): errors.append("固有能力必须声明输出资格: " + row.id)
		if kinds.is_empty(): errors.append("固有能力必须显式声明适用卡牌类别: " + row.id)
		if row.ability_parts.is_empty() or row.ability_parts.any(func(part): return part.execution_kind == T.AbilityExecution.CooldownMain): errors.append("固有能力来源应提供被动或增益，主能力在卡牌上明确配置: " + row.id)
	if table == "synergies":
		codec.decode(row.activation_conditions, "activation_conditions", row.id, false)
	errors.append_array(codec.errors)
	_parts(row.ability_parts, row.id, kinds)

## 任意层级的标签查询都必须引用正式标签，嵌套效果不能绕过校验。
func _tag_references(value: Variant, owner: String) -> void:
	if value is Dictionary:
		for key: Variant in value:
			if key in ["tag_query", "target_tags"] and value[key] is Dictionary:
				for ids: Variant in value[key].values():
					if ids is Array:
						for id: Variant in ids:
							if id is String: _reference("card_tags", id, owner)
			_tag_references(value[key], owner)
	elif value is Array:
		for child: Variant in value: _tag_references(child, owner)

## 天赋的前置引用与无环关系不依赖任何玩法模式。
func _talent_prerequisites(document: Dictionary) -> void:
	for talent in document.talents:
		var seen: Dictionary = {talent.id: true}
		var next: String = talent.prerequisite_id
		while not next.is_empty():
			if seen.has(next):
				errors.append("天赋前置循环: " + talent.id)
				break
			seen[next] = true
			var previous: Dictionary = indices.talents.get(next, {})
			if previous.is_empty():
				errors.append("天赋前置不存在: " + talent.id)
				break
			next = previous.prerequisite_id

## 骰子类型、发放规则和分层奖励池分别校验，宝物不进入普通随机池。
func _dice(document: Dictionary) -> void:
	var seen: Array = []
	for row in document.reward_dice:
		if row.dice_kind in seen: errors.append("骰子类型重复: " + row.id)
		seen.append(row.dice_kind)
		if row.selection_weight < 0 or (row.dice_kind == C.DiceKind.Treasure and row.selection_weight != 0) or (row.dice_kind != C.DiceKind.Treasure and row.selection_weight <= 0): errors.append("骰子出现权重无效: " + row.id)
		_asset(row.texture_key, "Texture", row.id)
	if seen.size() != C.DiceKind.size(): errors.append("必须完整配置全部奖励骰类型。")
	if document.dice_reward_rules.size() != 1: errors.append("必须且只能有一份冒险骰子发放规则。")
	for rule in document.dice_reward_rules:
		for field in Schema.fields("dice_reward_rules"):
			if field != "id": _positive(rule[field], rule.id + "." + field)
		if rule.elite_treasure_dice_count > rule.elite_dice_count: errors.append("精英保底骰不能超过总数。")
		if rule.choice_count != 3 or rule.refreshes_per_choice != 1: errors.append("当前奖励交互要求三选一且每项刷新一次。")
	var allowed = {
		C.DiceKind.Relic: [C.DiceReward.Relic],
		C.DiceKind.Card: [C.DiceReward.Minion, C.DiceReward.ItemCard, C.DiceReward.HeroGrowth],
		C.DiceKind.StarStone: [C.DiceReward.StarStone],
		C.DiceKind.Treasure: [C.DiceReward.Fragment, C.DiceReward.StarStone],
	}
	var pairs: Array = []
	for pool in document.dice_reward_pools:
		var key = "%d:%d" % [pool.dice_kind, pool.reward_kind]
		if key in pairs: errors.append("骰子奖励类别重复: " + pool.id)
		pairs.append(key)
		if not pool.reward_kind in allowed[pool.dice_kind]: errors.append("奖励不属于该骰子: " + pool.id)
		if pool.selection_weight <= 0 or pool.amount_min <= 0 or pool.amount_max < pool.amount_min or pool.amount_step <= 0:
			errors.append("骰子奖励权重或数量范围无效: " + pool.id)
			continue
		if (pool.amount_max - pool.amount_min) % pool.amount_step != 0: errors.append("骰子数量范围必须整除步长: " + pool.id)
		if pool.reward_kind != C.DiceReward.StarStone:
			if pool.amount_min != 1 or pool.amount_max != 1 or pool.amount_step != 1: errors.append("卡牌、强化与专属碎片每次只发一份: " + pool.id)
	for kind in allowed:
		for reward in allowed[kind]:
			if not "%d:%d" % [kind, reward] in pairs: errors.append("骰子缺少已声明的奖励类别。")

## 每层数量及每段奖励必须与实际路线精确对应。
func _chapter(chapter: Dictionary) -> void:
	_reference("monster_sets", chapter.monster_set_id, chapter.id)
	for field in ["chapter_index", "stamina_cost", "enemy_health_multiplier", "enemy_power_multiplier", "elite_guard_health_multiplier", "boss_guard_health_multiplier"]: _positive(chapter[field], chapter.id + "." + field)
	_asset(chapter.unlocked_background_key, "Texture", chapter.id, false)
	_asset(chapter.locked_background_key, "Texture", chapter.id, false)
	_asset(chapter.route_music_key, "Audio", chapter.id, false)
	_asset(chapter.battle_music_key, "Audio", chapter.id, false)
	var layer_count = 2
	var elites = 0
	if chapter.sections.is_empty(): errors.append("章节缺少路线段: " + chapter.id)
	for i in range(chapter.sections.size()):
		var section: Variant = chapter.sections[i]
		if not _shape(section, "chapters.sections", true): continue
		if section.section_index != i: errors.append("路线段序号无效: " + chapter.id)
		var count = 0
		for key in ["normal_battle_count", "elite_battle_count", "relic_count", "black_market_count", "adventure_count"]:
			if section[key] < 0: errors.append("节点配额不能为负: " + chapter.id + "." + key)
			count += section[key]
		elites += section.elite_battle_count
		if count < 2: errors.append("路线段至少需要两个分支节点: " + chapter.id)
		layer_count += ceili(float(maxi(0, count)) / 3.0)
	if chapter.layers.size() != layer_count: errors.append("怪物数量配置必须对应实际 %d 层: %s" % [layer_count, chapter.id])
	for i in range(chapter.layers.size()):
		var layer: Variant = chapter.layers[i]
		if not _shape(layer, "chapters.layers", true): continue
		if layer.layer_index != i or layer.normal_monster_count < 1 or layer.normal_monster_count > 6: errors.append("每层普通怪数量须为1～6且序号连续: " + chapter.id)
		for field in ["enemy_health_multiplier", "enemy_power_multiplier"]:
			_positive(layer[field], "%s.layers[%d].%s" % [chapter.id, i, field])
	var members: Array = indices.monster_sets.get(chapter.monster_set_id, {}).get("card_ids", [])
	var roles = members.map(func(id): return indices.cards.get(id, {}).get("monster_role", C.MonsterRole.None))
	if roles.count(C.MonsterRole.Normal) != 6 or roles.count(C.MonsterRole.Boss) != 1 or (elites > 0 and C.MonsterRole.Elite not in roles): errors.append("怪物集合必须包含六种普通怪、唯一首领和所需精英: " + chapter.id)
	if not members.any(func(id): return indices.cards.get(id, {}).get("monster_role") == C.MonsterRole.Normal and indices.cards[id].output_type in [T.Output.Physical, T.Output.Witchcraft, T.Output.Burn, T.Output.Poison]):
		errors.append("章节怪物池缺少可独立出场的攻击普通怪: " + chapter.id)

## 英雄与怪物按实际动作校验职责，固有或授予能力不能绕过恢复限制。
func _restricted_actions(card: Dictionary) -> void:
	var hero: bool = card.card_kind == CardTypes.Kind.CoreHero
	var leader: bool = card.monster_role in [C.MonsterRole.Elite, C.MonsterRole.Boss]
	if hero and card.output_type in [T.Output.Healing, T.Output.Shield]: errors.append("英雄只能为伤害或特殊类型，治疗与护盾交给随从: " + card.id)
	if leader and card.output_type not in [T.Output.Physical, T.Output.Witchcraft, T.Output.Burn, T.Output.Poison]:
		errors.append("精英与首领必须为攻击类型: " + card.id)
	if card.lifesteal_ratio > 0: errors.append("英雄和怪物不配置原生吸血: " + card.id)
	var parts: Array = card.ability_parts.duplicate()
	for id: String in card.innate_ability_ids: parts.append_array(indices.innate_abilities.get(id, {}).get("ability_parts", []))
	var actions: Array = []
	var pending: Array = []
	var visited: Array = []
	for part: Dictionary in parts:
		if part.get("modifiers", {}).get("lifesteal_ratio", 0) > 0:
			errors.append("英雄和怪物的原生能力不能授予吸血: " + card.id)
		actions.append_array(MechanicSchema.flatten(part.get("actions", [])))
		if part.has("main_ability_id"): pending.append(part.main_ability_id)
	var cursor: int = 0
	while cursor < actions.size() or not pending.is_empty():
		while not pending.is_empty():
			var id: String = pending.pop_back()
			if id in visited: continue
			visited.append(id)
			actions.append_array(MechanicSchema.flatten(indices.main_abilities.get(id, {}).get("actions", [])))
		if cursor >= actions.size(): break
		var action: Dictionary = actions[cursor]
		cursor += 1
		if not str(action.get("main_ability_id", "")).is_empty(): pending.append(action.main_ability_id)
		var output: int = T.output_kind(action)
		if action.kind == T.CombatAction.Transfer and action.get("parameters", {}).get("resource") == "Shield": output = T.Output.Shield
		if output in [T.Output.Healing, T.Output.Shield] and (hero or leader or output != card.output_type):
			errors.append("英雄、精英与首领禁止原生治疗或护盾，普通怪辅助必须匹配主输出: " + card.id)
		if action.get("lifesteal_ratio", 0) > 0: errors.append("英雄和怪物的原生动作不能配置吸血: " + card.id)

## 同一章节索引的不同难度共用六种普通怪，强度只由章节和层倍率投影。
func _monster_pool_requirements(chapters: Array) -> void:
	var pools: Dictionary = {}
	for chapter: Dictionary in chapters:
		var members: Array = indices.monster_sets.get(chapter.monster_set_id, {}).get("card_ids", [])
		var normal_ids: Array = members.filter(func(id): return indices.cards.get(id, {}).get("monster_role", C.MonsterRole.None) == C.MonsterRole.Normal)
		normal_ids.sort()
		if pools.has(chapter.chapter_index) and pools[chapter.chapter_index] != normal_ids:
			errors.append("同一章节的不同难度必须共用普通怪物池: " + chapter.id)
		else:
			pools[chapter.chapter_index] = normal_ids

## 三种事件各自绑定唯一效果，具体随机条款在进入节点时锁定。
func _node_rules(rules: Array) -> void:
	var seen: Array = []
	var actions = {C.NodeType.Relic: C.NodeEffect.AuroraChoice, C.NodeType.BlackMarket: C.NodeEffect.BlackMarket, C.NodeType.Adventure: C.NodeEffect.Encounter}
	for rule in rules:
		if rule.node_type in seen or not actions.has(rule.node_type): errors.append("节点规则类型重复或无效: " + rule.id)
		if rule.effect_type != actions.get(rule.node_type): errors.append("节点效果与关卡类型不符: " + rule.id)
		seen.append(rule.node_type)
		for field in ["title_key", "description_key", "action_label_key"]:
			if rule[field].strip_edges().is_empty(): errors.append("节点文案为空: " + rule.id)
		if rule.cost_currency not in [C.Currency.Gold, C.Currency.StarStone] or rule.reward_currency not in [C.Currency.Gold, C.Currency.StarStone]: errors.append("节点只支持账号金币或星石: " + rule.id)
		if rule.cost_amount != 0 or rule.reward_amount != 0 or rule.cost_currency != C.Currency.Gold or rule.reward_currency != C.Currency.Gold: errors.append("事件节点固定条款必须留空，实际结果由专用规则生成: " + rule.id)
		if rule.cost_amount < 0 or rule.reward_amount < 0: errors.append("节点数值不能为负: " + rule.id)
		if not rule.effect_type in [C.NodeEffect.AuroraChoice, C.NodeEffect.BlackMarket, C.NodeEffect.Encounter]: errors.append("节点缺少实际效果: " + rule.id)
	if seen.size() != 3: errors.append("必须覆盖三种非战斗节点。")


## 遗物允许全队固定点数与加法比例池，或开战一次性效果。
func _relic(row: Dictionary) -> void:
	_asset(row.texture_key, "Texture", row.id)
	var parts: Array = _parts(row.ability_parts, row.id)
	if parts.size() != 1:
		errors.append("遗物必须只有一个简单能力: " + row.id)
		return
	var part: Dictionary = parts[0]
	if row.usage == C.RelicUsage.Persistent:
		if part.execution_kind != T.AbilityExecution.PersistentBonus or part.target != T.Target.AllAllies:
			errors.append("常驻遗物必须提供全队加成: " + row.id)
			return
		var expected: Dictionary = AbilitySchema.new().decode({}, "modifiers", row.id, false)
		expected.team_bonuses = part.modifiers.team_bonuses
		expected.stat_bonus_ratios = part.modifiers.stat_bonus_ratios
		for key in ["crit_chance", "crit_multiplier", "haste_ratio", "lifesteal_ratio"]: expected[key] = part.modifiers[key]
		if not AbilitySchema.has_contribution(expected) or expected != part.modifiers: errors.append("常驻遗物只支持全队固定输出或属性比例修正: " + row.id)
	else:
		if part.execution_kind != T.AbilityExecution.TriggeredPassive:
			errors.append("一次性遗物必须使用触发能力: " + row.id)
			return
		if part.trigger_event != T.Event.BattleStarted or part.max_triggers_per_battle != 1 or part.actions.size() != 1 or not part.conditions.is_empty(): errors.append("一次性遗物必须是无条件开战单次效果: " + row.id)
		for action in part.actions:
			if action.target not in [T.Target.AllAllies, T.Target.AllEnemies] or action.kind not in [T.CombatAction.PhysicalDamage, T.CombatAction.Witchcraft, T.CombatAction.GrantShield, T.CombatAction.ApplyStatus, T.CombatAction.Charge, T.CombatAction.Haste] or action.power_multiplier != 0 or action.amount_source != T.AmountSource.Fixed: errors.append("一次性遗物必须是独立队伍效果，不能读取卡牌输出: " + row.id)

## 能力局部 ID、执行定义与引用只校验一份，适用类别不能绕过机制限制。
func _parts(values: Array, owner: String, kinds: Array = []) -> Array:
	var codec = Codec.new()
	var decoded: Array = codec.decode(values, "ability_parts", owner, false)
	errors.append_array(codec.errors)
	if not codec.errors.is_empty(): return []
	if decoded.is_empty(): errors.append("内容必须有实际能力: " + owner)
	for part in decoded:
		var multicast = false
		match part.execution_kind:
			T.AbilityExecution.CooldownMain:
				_main_ability(part.main_ability_id, owner)
				multicast = indices.main_abilities.get(part.main_ability_id, {}).get("multicast_count", 1) > 1
			T.AbilityExecution.TriggeredPassive:
				_actions(part.actions, owner)
				multicast = part.multicast_count > 1
			_:
				_asset(part.modifiers.projectile_key, "Projectile", owner)
				multicast = part.modifiers.multicast_bonus != 0
				if part.modifiers.ammo_capacity != 0 and not kinds.is_empty() and kinds != [CardTypes.Kind.ItemCard]: errors.append("弹药扩充修正只能绑定道具: " + owner)
		if not indices.relics.has(owner): _card_percentage_policy(part, owner)
		if multicast: errors.append("当前正式内容不启用双重或多重施法，也不允许增加施法次数: " + owner)
	return decoded

## 账号商城只解锁一份收藏，价格与章节奖励相互独立。
func _shop(offers: Array) -> void:
	var rewards: Array = []
	var fragments: Array = []
	for offer in offers:
		var record: Dictionary = indices.cards.get(offer.reward_id, indices.relics.get(offer.reward_id, {}))
		if record.is_empty() or C.shop_tab(record) == C.ShopTab.Recommend or C.shop_tab(record) != offer.shop_tab: errors.append("商城奖励分类错误: " + offer.id)
		if offer.reward_id in rewards: errors.append("商城奖励重复报价: " + offer.id)
		rewards.append(offer.reward_id)
		if offer.purchase_limit != 1: errors.append("账号收藏必须限购一份: " + offer.id)
		if record.get("card_kind") == CardTypes.Kind.CoreHero and offer.account_star_stone_price != null: errors.append("英雄仅支持金币购买与专属碎片解锁: " + offer.id)
		for key in ["account_gold_price", "account_star_stone_price"]:
			if offer[key] != null and offer[key] < 0: errors.append("商城价格不能为负: " + offer.id)
		if offer.payable_percent < 1 or offer.payable_percent > 100: errors.append("商城支付比例无效: " + offer.id)
		if offer.fragment_item_id.is_empty():
			if offer.fragment_amount != 0: errors.append("无碎片入口时数量应为零: " + offer.id)
		else:
			var fragment: Dictionary = indices.items.get(offer.fragment_item_id, {})
			if fragment.is_empty() or fragment.item_kind != C.Item.Material or offer.fragment_amount <= 0: errors.append("专属碎片引用无效: " + offer.id)
			if offer.fragment_item_id in fragments: errors.append("专属碎片被多个商品使用。")
			fragments.append(offer.fragment_item_id)

## 主能力必须直接引用正式配方表；历史别名只服务导入。
func _main_ability(id: String, owner: String) -> void:
	if not indices.main_abilities.has(id): errors.append(owner + " 主能力引用不存在: " + id)

## 动作参数使用同一解析器，授予与指定主能力充能均检查引用。
func _actions(value: Variant, owner: String) -> void:
	var codec = Codec.new()
	var actions: Array = codec.decode(value, "actions", owner, false)
	errors.append_array(codec.errors)
	if actions.is_empty(): errors.append(owner + " 缺少效果。")
	for action in MechanicSchema.flatten(actions):
		if action.target in [T.Target.AllEnemies, T.Target.AllUnits] and not action.max_targets in [3, 4, 5]:
			errors.append("正式群攻必须显式限制目标：默认3个，少数4或5个，禁止全场攻击: " + owner)
		if not indices.relics.has(owner):
			if action.power_multiplier != 0 or action.lifesteal_ratio != 0 or action.kind in [T.CombatAction.Haste, T.CombatAction.Empower] or (action.kind == T.CombatAction.ApplyStatus and action.status == T.Status.Slow) or action.parameters.has("multiplier"):
				errors.append("卡牌能力禁止百分比强度、急速、缓速及比例派生，改用点数或固定秒数: " + owner)
		_asset(action.projectile_key, "Projectile", owner)
		if action.kind == T.CombatAction.GrantMainAbility or not action.main_ability_id.is_empty(): _main_ability(action.main_ability_id, owner)
		if action.kind in [T.CombatAction.CopyMainAbility, T.CombatAction.Transform] and not MechanicSchema.snapshot_supported(action.kind, indices.main_abilities.get(action.main_ability_id, {}).get("actions", [])): errors.append(owner + " 复制或形态预设不能包含主能力授予链或回放副本。")

## 引用必须存在，不猜测替代内容。
func _reference(table: String, id: String, owner: String) -> void:
	if not indices[table].has(id): errors.append(owner + " 引用了不存在的 " + table + ": " + id)

## 运行参数必须为有限正数。
func _positive(value: Variant, label: String) -> void:
	if not (value is int or value is float) or not is_finite(float(value)) or value <= 0: errors.append(label + " 必须为有限正数。")

## 资源必须登记正确类别，必填素材不允许为空。
func _asset(key: String, kind: String, owner: String, optional: bool = true) -> void:
	if key.is_empty():
		if not optional: errors.append(owner + " 的资源键为空。")
	elif not assets.has(key) or not assets[key] is Dictionary or assets[key].get("kind") != kind: errors.append(owner + " 的资源键不存在或类别错误: " + key)

## 制作阶段就拒绝类别不符、不可播放音频、空动画和无效帧，避免运行时才失败。
func _resources(deferred_assets: Dictionary = {}) -> void:
	for key in assets:
		var entry: Variant = assets[key]
		if not entry is Dictionary or not entry.get("path") is String or not entry.get("kind") in ["Texture", "Audio", "Effect", "Projectile"]:
			errors.append("资源登记格式错误: " + str(key))
			continue
		if deferred_assets.has(key):
			if entry.kind != "Texture" or entry.path != deferred_assets[key].path:
				errors.append("延迟资源身份与登记表不符: " + str(key))
			continue
		if not ResourceLoader.exists(entry.path):
			errors.append("资源文件不存在: " + key)
			continue
		var resource = load(entry.path)
		if entry.kind == "Texture":
			if not resource is Texture2D: errors.append("静态图登记必须指向 Texture2D: " + key)
			continue
		if entry.kind == "Audio":
			if not resource is AudioStream: errors.append("音频登记必须指向 AudioStream: " + key)
			continue
		if not resource is SpriteFrames:
			errors.append("特效或弹道必须指向 SpriteFrames: " + key)
			continue
		if resource.get_animation_names().is_empty(): errors.append("动画资源没有动画: " + key)
		for animation in resource.get_animation_names():
			if resource.get_frame_count(animation) <= 0 or resource.get_animation_speed(animation) <= 0: errors.append("动画帧数或帧率无效: " + key)
			for index in range(resource.get_frame_count(animation)):
				if resource.get_frame_texture(animation, index) == null or resource.get_frame_duration(animation, index) <= 0: errors.append("动画包含空帧或无效时长: " + key)
		if entry.kind == "Projectile":
			if not key.begins_with("projectile.") or not entry.path.begins_with("res://game_content/projectiles/"): errors.append("弹道命名或目录错误: " + key)
			if int(entry.get("width", 0)) <= 0 or int(entry.get("height", 0)) <= 0: errors.append("弹道尺寸无效: " + key)


## 来源列表必须逐一对应声明的固定表，不能重复或伪造文件名。
func _sources(metadata: Dictionary) -> void:
	if not metadata.get("sources") is Array: return
	var files: Array = []
	var pattern = RegEx.new()
	pattern.compile("^[0-9a-f]{64}$")
	for source in metadata.sources:
		if not source is Dictionary or not source.get("file") is String or not source.get("table") is String or not source.get("sha256") is String:
			errors.append("来源指纹记录损坏。")
			continue
		if not Schema.FILES.has(source.file) or source.file in files or Schema.FILES.get(source.file, [""])[0] != source.table: errors.append("来源文件重复或不符合来源契约。")
		files.append(source.file)
		if pattern.search(source.sha256) == null: errors.append("来源文件指纹格式无效。")


## 星能、黑市与奇遇规则保持唯一，所有随机权重和数量均为正数。
func _adventure_requirements(document: Dictionary) -> void:
	if document.aurora_reward_rules.size() != 1 or document.aurora_reward_rules[0].max_triggers != 5 or document.aurora_reward_rules[0].offer_count != 3:
		errors.append("星能每章触发上限必须为五次。")
	if document.black_market_rules.size() != 1: errors.append("黑市规则必须且只能包含一行。")
	else:
		var market: Dictionary = document.black_market_rules[0]
		for field in Schema.fields("black_market_rules"):
			if field != "id": _positive(market[field], market.id + "." + field)
		if market.fragment_offer_count != 3 or market.fragment_amount != 10 or market.minion_weight + market.item_weight + market.hero_weight != 100: errors.append("黑市必须提供三件十片碎片商品，分类权重合计一百。")
	if document.adventure_encounter_rules.size() != 1: errors.append("奇遇规则必须且只能包含一行。")
	else:
		var encounter: Dictionary = document.adventure_encounter_rules[0]
		for field in Schema.fields("adventure_encounter_rules"):
			if field != "id": _positive(encounter[field], encounter.id + "." + field)
		if encounter.refresh_count != 1 or encounter.star_stone_max < encounter.star_stone_min: errors.append("奇遇必须允许一次刷新并使用有效星石区间。")
		if encounter.dice_reward_weight + encounter.star_stone_reward_weight + encounter.relic_reward_weight + encounter.card_reward_weight != 100: errors.append("奇遇收获权重合计必须为一百。")
		if encounter.stamina_cost_weight + encounter.team_debuff_cost_weight + encounter.card_cost_weight + encounter.die_cost_weight != 100: errors.append("奇遇代价权重合计必须为一百。")
		if encounter.card_minion_weight + encounter.card_item_weight != 100: errors.append("奇遇卡牌类别权重合计必须为一百。")
	var kinds: Array = []
	for row: Dictionary in document.aurora_rewards:
		if row.aurora_reward_kind in kinds: errors.append("星能奖励类别重复。")
		kinds.append(row.aurora_reward_kind)
		if row.amount_min <= 0 or row.amount_max < row.amount_min: errors.append("星能奖励数量区间无效。")
		var fragment_tab: int = {C.AuroraReward.MinionFragments: C.ShopTab.Minion, C.AuroraReward.RelicFragments: C.ShopTab.Relic, C.AuroraReward.HeroFragment: C.ShopTab.Hero}.get(row.aurora_reward_kind, -1)
		var expected_count: int = 3 if row.aurora_reward_kind in [C.AuroraReward.MinionFragments, C.AuroraReward.RelicFragments] else 1 if fragment_tab >= 0 else 0
		if row.distinct_count != expected_count: errors.append("星能碎片种数与类别不符。")
		if fragment_tab >= 0:
			var fragments: Array = document.shop_offers.filter(func(offer): return offer.shop_tab == fragment_tab and not offer.fragment_item_id.is_empty()).map(func(offer): return offer.fragment_item_id)
			if fragments.size() < expected_count: errors.append("星能碎片候选不足。")
		if row.aurora_reward_kind in [C.AuroraReward.CardUpgrade, C.AuroraReward.Relic, C.AuroraReward.MinionFragments, C.AuroraReward.RelicFragments, C.AuroraReward.HeroFragment] and (row.amount_min != 1 or row.amount_max != 1):
			errors.append("星能卡牌、装备与每种碎片固定一份。")
	if kinds.size() != C.AuroraReward.size(): errors.append("星能必须提供八种不同奖励。")

## 原生输出保持单一分类；主能力可以组合附加动作，但必须包含对应输出。
func _card_output(card: Dictionary, main_abilities: Array) -> void:
	var field = T.output_stat(card.output_type)
	for key in T.OUTPUT_STATS:
		if key != field and card[key] != 0: errors.append("卡牌含非主类型数值: " + card.id + "." + key)
	if not field.is_empty() and card[field] <= 0: errors.append("数值卡必须有正主数值: " + card.id)
	var found = false
	for id in main_abilities:
		for action in indices.main_abilities.get(id, {}).get("actions", []):
			var output = T.output_kind(action)
			if output == card.output_type: found = true
	if not found and not main_abilities.is_empty(): errors.append("卡牌主能力缺少匹配原生输出的动作: " + card.id)

## 三类能力按实际清单配置；主能力可缺省，固有来源仍逐项校验资格。
func _card_kit(card: Dictionary, main_abilities: Array) -> void:
	var codec = Codec.new()
	codec.decode(card.innate_ability_ids, "innate_ability_ids", card.id, false)
	errors.append_array(codec.errors)
	for id in card.innate_ability_ids:
		var entry: Dictionary = indices.innate_abilities.get(id, {})
		if entry.is_empty() or not card.card_kind in entry.applies_to_kinds or not card.output_type in entry.required_outputs:
			errors.append("卡牌固有能力引用或资格无效: " + card.id)
	if main_abilities.size() > 1: errors.append("卡牌原生主能力最多一项，多个动作应在同一主能力内组合: " + card.id)
	if card.card_kind == CardTypes.Kind.Monster: return
	var bonuses: Array = card.ability_parts.filter(func(part): return part.execution_kind == T.AbilityExecution.PersistentBonus and not part.modifiers.get("team_bonuses", {}).is_empty())
	if bonuses.is_empty(): return
	if bonuses.size() > 1:
		errors.append("卡牌原生固定输出奖励最多一项: " + card.id)
		return
	var bonus: Dictionary = bonuses[0]
	var values: Dictionary = bonus.modifiers.team_bonuses
	var self_only: bool = bonus.target == T.Target.Self
	if values.size() != 1 or not bonus.target in [T.Target.Self, T.Target.AllAllies]:
		errors.append("卡牌常驻奖励只增加一项属性，范围为自身或全队: " + card.id)
	for stat: String in values:
		if values[stat] < (3 if self_only else 1) or values[stat] > (5 if self_only else 2): errors.append("卡牌常驻奖励要求自身3～5、全队1～2点: " + card.id)
		if card.card_kind == CardTypes.Kind.CoreHero and stat in ["healing_power", "shield_power"]: errors.append("英雄常驻奖励不承担治疗或护盾强化: " + card.id)

## 非遗物不新增百分比修正；仅精确保留待玩家确认的暴击与低生命门槛。
func _card_percentage_policy(part: Dictionary, owner: String) -> void:
	var modifiers: Dictionary = part.get("modifiers", {})
	if not modifiers.get("stat_bonus_ratios", {}).is_empty() or modifiers.get("haste_ratio", 0) != 0 or modifiers.get("lifesteal_ratio", 0) != 0 or modifiers.get("crit_multiplier", 0) != 0:
		errors.append("非遗物能力必须使用固定点数或秒数，禁止百分比修正: " + owner)
	if modifiers.get("crit_chance", 0) != 0 and not (owner == "EN014" and part.id == "precision" and part.target == T.Target.Self and is_equal_approx(modifiers.crit_chance, 0.15)):
		errors.append("非遗物不新增暴击概率；现有精准瞄准为待确认例外: " + owner)
	for action in modifiers.get("action_modifiers", []):
		if action.kind == T.CombatAction.Haste: errors.append("非遗物不允许通过效果修正增加百分比急速: " + owner)
	for condition in part.get("conditions", []):
		if condition.kind == T.Condition.OwnerHealthAtMostPercent and not (owner == "EN004" and part.id == "resolve" and condition.threshold == 50):
			errors.append("非遗物不新增百分比生命条件；绝境咒能门槛为待确认例外: " + owner)
