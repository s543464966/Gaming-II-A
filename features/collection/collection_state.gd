class_name CollectionState
extends RefCounted
## 账号收藏与唯一英雄选择；与章节临时构筑分离。

var content: RefCounted
## 借用账号天赋 Owner，只读取已提交的永久能力。
var talents: TalentState
var cards: Dictionary = {}
var relics: Dictionary = {}
var dices: Dictionary = {}
## 旧存档未启用的 rank/grade 原值仅作迁移凭据，不参与新成长。
var migration_receipt: Dictionary = {}
var selected_hero: String = "H001"
var hero_position: int = 22

## 注入唯一静态内容目录。
func _init(catalog: RefCounted) -> void:
	content = catalog

## 新账号按静态内容的初始解锁配置建立收藏，不直接创建章节实例。
func initialize_new() -> void:
	cards.clear()
	relics.clear()
	dices.clear()
	migration_receipt.clear()
	ensure_initial_unlocks()
	selected_hero = "H001"
	hero_position = 22

## 幂等补齐初始内容；已有卡牌的生命与养成保持原值。
func ensure_initial_unlocks() -> void:
	for row in content.data.cards:
		if row.initially_unlocked == 1: unlock(row.id)

## 英雄、随从和道具卡解锁只影响账号收藏，不直接发放章节实例。
func unlock(id: String) -> bool:
	var row: Dictionary = content.get_record("cards", id)
	if not row.is_empty() and row.card_kind in [CardTypes.Kind.CoreHero, CardTypes.Kind.Minion, CardTypes.Kind.ItemCard]:
		if cards.has(id): return false
		cards[id] = {"health_ratio": 1.0, "star_level": 1}
		return true
	if relics.has(id) or not _is_relic(id): return false
	relics[id] = 1
	return true

## 遗物解锁进入遗物收藏，道具卡与其他卡牌共用永久成长。
func _is_relic(id: String) -> bool:
	return not content.get_record("relics", id).is_empty()

## 专属碎片沿用静态兑换关系，不按编号猜测或复制背包数量。
func fragment_id(id: String) -> String:
	for offer in content.data.shop_offers:
		if offer.reward_id == id and not offer.fragment_item_id.is_empty(): return offer.fragment_item_id
	return ""

## 账号即时成长只保存星级，碎片档位始终读取资产事实。
func growth(id: String, assets: RefCounted) -> Dictionary:
	var star = int(cards.get(id, {}).get("star_level", 1))
	var quantity = int(assets.items.get(fragment_id(id), 0)) if cards.has(id) else 0
	return {"star_level": star, "fragment_steps": CardGrowth.fragment_steps(quantity, star, content.data.growth_rules[0])}

## 开章锁定所有可用卡牌的成长事实，途中获得同名卡也使用这份记录。
func growth_snapshot(assets: RefCounted) -> Dictionary:
	var result: Dictionary = {}
	for row in content.data.cards:
		if row.card_kind != CardTypes.Kind.Monster: result[row.id] = growth(row.id, assets)
	return result

## 收藏与 Home 读取永久投影，不混入遗物和章节强化。
func definition(id: String, assets: RefCounted) -> Dictionary:
	return BattleAssembly.new(content).permanent_definition(id, growth(id, assets), talents.learned if talents != null else [])

## 账号只记录生命比例，碎片或星级变化后不会保留过时的生命上限。
func current_health(id: String, assets: RefCounted) -> float:
	return CombatAttributes.points(float(cards.get(id, {}).get("health_ratio", 0)) * CombatAttributes.max_health(definition(id, assets)))

## 升星状态供收藏 UI 和提交前复核，满星没有新的碎片进度。
func star_status(id: String, assets: RefCounted) -> Dictionary:
	var fact = growth(id, assets)
	var item = fragment_id(id)
	var cost = CardGrowth.fragment_cost(fact.star_level, content.data.growth_rules[0])
	var quantity = int(assets.items.get(item, 0))
	return {"star": fact.star_level, "steps": fact.fragment_steps, "fragment_id": item, "quantity": quantity, "cost": cost,
		"can_upgrade": cards.has(id) and cost > 0 and quantity >= cost,
		"progress_percent": float(fact.fragment_steps) * 100 / content.data.growth_rules[0].fragment_step_count, "multiplier": CardGrowth.permanent_multiplier(fact, content.data.growth_rules[0]) * (1 + fact.fragment_steps * content.data.growth_rules[0].fragment_step_bonus_ratio)}

## 手动升星由账号事务调用，失败不扣碎片；升星消耗策略按已确认规则执行。
func upgrade(id: String, assets: RefCounted) -> String:
	var status = star_status(id, assets)
	if not status.can_upgrade: return "ui.collection.star_unavailable"
	if not assets.remove_item(status.fragment_id, status.cost): return "ui.collection.star_unavailable"
	cards[id].star_level += 1
	return ""

## 未获得内容不属于拥有状态，仍可在目录查看。
func owns(id: String) -> bool:
	return cards.has(id) or int(relics.get(id, 0)) > 0 or dices.has(id)

## 只允许选择已拥有且生命大于零的合法英雄。
func select(id: String, position: int) -> String:
	var row: Dictionary = content.get_record("cards", id)
	if row.is_empty() or row.card_kind != CardTypes.Kind.CoreHero or not cards.has(id): return "尚未拥有该英雄。"
	if cards[id].health_ratio <= 0: return "生命为零的英雄不能出场。"
	if BattleGrid.footprint_mask(position, row.footprint_width, row.footprint_height) == 0: return "英雄占位越界。"
	selected_hero = id
	hero_position = position
	return ""

## 返回紧凑收藏快照。
func capture() -> Dictionary:
	return {"cards": cards.duplicate(true), "relics": relics.duplicate(true), "dices": dices.duplicate(true),
		"selected_hero": selected_hero, "hero_position": hero_position, "migration_receipt": migration_receipt.duplicate(true)}

## 恢复时拒绝损坏定义，不静默删除已有收藏。
func restore(state: Dictionary) -> String:
	for key in ["cards", "relics", "dices", "migration_receipt"]:
		if not state.get(key) is Dictionary: return "收藏格式损坏。"
	for id in state.cards:
		var row: Dictionary = content.get_record("cards", id)
		var saved: Variant = state.cards[id]
		if row.is_empty() or not row.card_kind in [CardTypes.Kind.CoreHero, CardTypes.Kind.Minion, CardTypes.Kind.ItemCard] or not saved is Dictionary or saved.size() != 2: return "收藏卡牌定义损坏。"
		if not (saved.get("health_ratio") is int or saved.get("health_ratio") is float) or not is_finite(float(saved.health_ratio)) or saved.health_ratio < 0 or saved.health_ratio > 1: return "收藏生命比例损坏。"
		if not saved.get("star_level") is int or saved.star_level < 1 or saved.star_level > content.data.growth_rules[0].star_fragment_costs.size() + 1: return "收藏星级损坏。"
	for id in state.migration_receipt:
		var receipt: Variant = state.migration_receipt[id]
		if not state.cards.has(id) or not receipt is Dictionary or receipt.size() != 2: return "收藏迁移凭据损坏。"
		for key in ["rank", "grade"]:
			if not receipt.get(key) is int or receipt[key] < 0: return "收藏迁移凭据损坏。"
	for id in state.relics:
		if not _is_relic(id) or not state.relics[id] is int or state.relics[id] < 0: return "遗物收藏损坏。"
	for id in state.dices:
		var saved: Variant = state.dices[id]
		if content.get_record("reward_dice", id).is_empty() or not saved is Dictionary or not saved.get("quantity") is int or saved.quantity < 0 or not saved.get("equipped") is bool: return "骰子收藏损坏。"
	if not state.get("selected_hero") is String or not state.get("hero_position") is int: return "英雄选择格式损坏。"
	var hero: Dictionary = content.get_record("cards", state.selected_hero)
	if hero.is_empty() or hero.card_kind != CardTypes.Kind.CoreHero or not state.cards.has(state.selected_hero) or BattleGrid.footprint_mask(state.hero_position, hero.footprint_width, hero.footprint_height) == 0: return "英雄选择无效。"
	cards = state.cards.duplicate(true)
	# JSON 整数归一化不应改变领域生命字段的浮点类型。
	for card in cards.values(): card.health_ratio = float(card.health_ratio)
	relics = state.relics.duplicate(true)
	dices = state.dices.duplicate(true)
	migration_receipt = state.migration_receipt.duplicate(true)
	ensure_initial_unlocks()
	selected_hero = state.selected_hero
	hero_position = state.hero_position
	return ""
