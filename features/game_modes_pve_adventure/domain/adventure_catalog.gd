class_name AdventureCatalog
extends RefCounted
## 从唯一内容目录生成合法奖励候选与章节敌人，不保存第二份内容名单。

const C = preload("res://game_content/runtime/content_types.gd")
var assembly: BattleAssembly
var content: RefCounted

## 目录与装配器供本模式查询，玩家拥有状态由每次调用传入。
func _init(catalog: RefCounted) -> void:
	content = catalog
	assembly = BattleAssembly.new(catalog)

## 冒险卡牌定义在共享装配完成后叠加本章奇遇减益，预览与战斗读取同一结果。
func player_definition(build: RefCounted, card: Dictionary, team_id: int, options: Dictionary) -> Dictionary:
	var result: Dictionary = assembly.definition(build, card, team_id, options)
	if result.is_empty(): return {}
	_apply_event_debuffs(result, build.event_debuffs)
	return result

## 整队装配保留共享能力宿主，只调整每张玩家卡牌的最终固定输出点数。
func assemble_player(build: RefCounted, team_id: int, options: Dictionary) -> Dictionary:
	var result: Dictionary = assembly.assemble(build, team_id, options)
	if result.is_empty(): return {}
	for snapshot: Dictionary in result.cards: _apply_event_debuffs(snapshot.definition, build.event_debuffs)
	return result

## 减益进入队伍固定点数层，成长比例不会放大或缩小明确的负一点代价。
func _apply_event_debuffs(definition: Dictionary, debuffs: Dictionary) -> void:
	var modifiers: Dictionary = definition.get("modifiers", {})
	var team: Dictionary = modifiers.get("team_bonuses", {})
	for stat in debuffs: team[stat] = int(team.get(stat, 0)) - int(debuffs[stat])
	modifiers.team_bonuses = team
	definition.modifiers = modifiers

## 按真实节点类别查询发放数量；非战斗节点不发骰子。
func dice_count(node_type: int) -> int:
	var rule: Dictionary = content.data.dice_reward_rules[0]
	match node_type:
		C.NodeType.Start, C.NodeType.NormalBattle: return rule.normal_dice_count
		C.NodeType.EliteBattle: return rule.elite_dice_count
		C.NodeType.BossBattle: return rule.boss_dice_count
	return 0

## 骰子目录按类型定位，身份不由 ID 编号推断。
func die_definition(kind: int) -> Dictionary:
	for row in content.data.reward_dice:
		if row.dice_kind == kind: return row
	return {}

## 两层抽样先选有效类别，再选该类别内的实际内容，内容数量不改变类别权重。
func pick_reward(kind: int, build: RefCounted, collection: RefCounted, random: RefCounted, excluded: Array = []) -> Dictionary:
	var pools: Array = []
	for pool in content.data.dice_reward_pools:
		if pool.dice_kind != kind: continue
		var entries = _entries(pool.reward_kind, build, collection)
		var distinct = entries.filter(func(entry): return not reward_key(entry) in excluded)
		if not distinct.is_empty(): entries = distinct
		if not entries.is_empty(): pools.append({"rule": pool, "entries": entries, "selection_weight": pool.selection_weight})
	if pools.is_empty(): return {}
	var selected = weighted(pools, random)
	var entry: Dictionary = selected.entries[random.next_int(selected.entries.size())].duplicate(true)
	var rule: Dictionary = selected.rule
	entry.pool_id = rule.id
	entry.amount = rule.amount_min + random.next_int(1 + (rule.amount_max - rule.amount_min) / rule.amount_step) * rule.amount_step
	return entry


## 静态引用的类别与数量统一用于读取存档和提交领取。
func validate_reward(reward: Variant, dice_kind: int = -1) -> String:
	if not reward is Dictionary or reward.size() != 4: return "奖励记录格式损坏。"
	if not reward.get("kind") is int or not reward.kind in C.DiceReward.values() or not reward.get("content_id") is String or not reward.get("pool_id") is String or not reward.get("amount") is int or reward.amount <= 0: return "奖励类别或数量损坏。"
	var pool: Dictionary = content.get_record("dice_reward_pools", reward.pool_id)
	if pool.is_empty():
		var aurora: Dictionary = content.get_record("aurora_rewards", reward.pool_id)
		if dice_kind >= 0 or reward.kind != C.DiceReward.Relic or aurora.get("aurora_reward_kind") != C.AuroraReward.Relic: return "奖励来源引用无效。"
	elif pool.reward_kind != reward.kind or (dice_kind >= 0 and pool.dice_kind != dice_kind): return "奖励池引用或骰子类别不符。"
	if reward.kind == C.DiceReward.StarStone: return "" if reward.content_id.is_empty() else "星石奖励不能夹带内容。"
	if reward.amount != 1: return "卡牌、强化和碎片每次只能获得一份。"
	if reward.kind == C.DiceReward.Fragment:
		return "" if fragment_ids().has(reward.content_id) else "专属碎片必须对应英雄、随从或道具。"
	var row = reward_record(reward)
	if row.is_empty(): return "奖励内容不存在。"
	if reward.kind in [C.DiceReward.Minion, C.DiceReward.ItemCard, C.DiceReward.HeroGrowth]:
		var expected: int = {C.DiceReward.Minion: CardTypes.Kind.Minion, C.DiceReward.ItemCard: CardTypes.Kind.ItemCard, C.DiceReward.HeroGrowth: CardTypes.Kind.CoreHero}[reward.kind]
		if row.card_kind != expected: return "奖励卡牌类别不符。"
	return ""

## 专属碎片关系复用账号兑换定义，不按 FR 编号猜测目标。
func fragment_ids() -> Array:
	var result: Array = []
	for offer in content.data.shop_offers:
		if offer.shop_tab in [C.ShopTab.Hero, C.ShopTab.Minion, C.ShopTab.Item] and not offer.fragment_item_id.is_empty():
			result.append(offer.fragment_item_id)
	return result

## 奖励详情查询真实所属表，不复制遗物或卡牌定义。
func reward_record(reward: Dictionary) -> Dictionary:
	var table: String = {C.DiceReward.Relic: "relics", C.DiceReward.Minion: "cards", C.DiceReward.ItemCard: "cards",
		C.DiceReward.Fragment: "items", C.DiceReward.HeroGrowth: "cards"}.get(reward.get("kind"), "")
	return content.get_record(table, reward.get("content_id", ""))


## 同屏去重按内容身份进行，不依赖随机金额。
static func reward_key(reward: Dictionary) -> String:
	return "%d:%s" % [reward.kind, reward.content_id]

## 稳定加权抽样只消费注入随机源，不依赖动画时长。
static func weighted(rows: Array, random: RefCounted) -> Dictionary:
	var total: int = 0
	for row in rows: total += row.selection_weight
	if total <= 0: return {}
	var roll: int = random.next_int(total)
	for row in rows:
		if roll < row.selection_weight: return row
		roll -= row.selection_weight
	return rows.back()

## 所有候选从真实目录与当前资格推导，不向池内补造锁定卡或无效目标。
func _entries(kind: int, build: RefCounted, collection: RefCounted) -> Array:
	var result: Array = []
	if kind == C.DiceReward.StarStone: return [{"kind": kind, "content_id": ""}]
	if kind == C.DiceReward.HeroGrowth:
		var core: Dictionary = build.core()
		return [{"kind": kind, "content_id": core.definition_id}] if not core.is_empty() else []
	if kind == C.DiceReward.Fragment:
		for id in fragment_ids(): result.append({"kind": kind, "content_id": id})
		return result
	if not kind in [C.DiceReward.Relic, C.DiceReward.Minion, C.DiceReward.ItemCard]: return []
	var table = "relics" if kind == C.DiceReward.Relic else "cards"
	for row in content.data[table]:
		var reward = {"kind": kind, "content_id": row.id}
		if kind in [C.DiceReward.Minion, C.DiceReward.ItemCard, C.DiceReward.HeroGrowth]:
			var expected = CardTypes.Kind.Minion if kind == C.DiceReward.Minion else CardTypes.Kind.ItemCard
			if row.card_kind != expected: continue
			if kind == C.DiceReward.Minion and not collection.owns(row.id): continue
			if build.cards.any(func(card): return card.definition_id == row.id and card.kind == CardTypes.Kind.Minion and card.health <= 0): continue
			if not build.can_add_card(assembly.base_definition(row.id)): continue
			if _requires_ammo_ally(row) and not build.cards.any(func(card): return card.position >= 0 and (card.kind == CardTypes.Kind.ItemCard or card.health > 0) and content.get_record("cards", card.definition_id).ammo_capacity > 0): continue
		result.append(reward)
	return result

## 补弹卡的候选资格读取真实效果，不以某个卡牌 ID 硬编码。
func _requires_ammo_ally(row: Dictionary) -> bool:
	for part in row.ability_parts:
		var actions: Array = content.get_record("main_abilities", part.main_ability_id).actions if part.execution_kind == CombatTypes.AbilityExecution.CooldownMain else part.get("actions", [])
		if actions.any(func(action): return action.kind == CombatTypes.CombatAction.RefillAmmo): return true
	return false

## 预览与战斗共用章节、路线层及护卫倍率；不指定层时仅预览章节基准。
func enemy_definition(id: String, chapter: Dictionary = {}, layer_index: int = -1, encounter_type: int = C.NodeType.NormalBattle) -> Dictionary:
	var definition = assembly.base_definition(id, 1, CardTypes.Kind.Monster)
	if definition.is_empty(): return {}
	var layer: Dictionary = {}
	if layer_index != -1:
		if layer_index < 0 or layer_index >= chapter.get("layers", []).size(): return {}
		layer = chapter.layers[layer_index]
	definition.max_health *= float(chapter.get("enemy_health_multiplier", 1.0)) * float(layer.get("enemy_health_multiplier", 1.0))
	# 护卫承伤与本体输出分别配置，避免用过厚护卫血量掩盖精英和首领的攻击压力。
	if content.get_record("cards", id).monster_role == C.MonsterRole.Normal:
		if encounter_type == C.NodeType.EliteBattle: definition.max_health *= float(chapter.get("elite_guard_health_multiplier", 1.0))
		elif encounter_type == C.NodeType.BossBattle: definition.max_health *= float(chapter.get("boss_guard_health_multiplier", 1.0))
	definition.base_point_multiplier = float(chapter.get("enemy_power_multiplier", 1.0)) * float(layer.get("enemy_power_multiplier", 1.0))
	for key in CombatTypes.OUTPUT_STATS: definition[key] *= definition.base_point_multiplier
	return definition
