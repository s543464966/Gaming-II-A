class_name AdventureEvents
extends RefCounted
## 锁定黑市商品与奇遇组合，使非战斗节点可保存、恢复并逐项结算。

const C = preload("res://game_content/runtime/content_types.gd")
const RandomSource = preload("res://features/mechanics/foundation/deterministic_random.gd")
enum MarketKind { Fragment, Exchange, Stamina }
var node_index: int = -1
var node_type: int = -1
var seed: int = 0
var market: Dictionary = {}
var encounter: Dictionary = {}

## 活动事件必须绑定当前路线的黑市或奇遇节点。
func is_active() -> bool:
	return node_index >= 0 and node_type in [C.NodeType.BlackMarket, C.NodeType.Adventure]

## 首次进入时生成一次并保留实际商品、奖励、代价及随机目标。
func begin(index: int, type: int, value_seed: int, catalog: RefCounted, build: RefCounted) -> String:
	if is_active(): return "已有尚未结束的事件。"
	if index < 0 or not type in [C.NodeType.BlackMarket, C.NodeType.Adventure]: return "事件节点无效。"
	node_index = index
	node_type = type
	seed = value_seed
	var error: String = _generate_market(catalog, build) if type == C.NodeType.BlackMarket else _generate_encounter(catalog, build, 0, "")
	if not error.is_empty(): clear()
	return error

## 奇遇只允许配置次数内刷新，且新组合不能与被放弃的类别组合相同。
func refresh_encounter(catalog: RefCounted, build: RefCounted) -> String:
	if node_type != C.NodeType.Adventure or encounter.is_empty(): return "当前没有可刷新的奇遇。"
	var rule: Dictionary = catalog.content.data.adventure_encounter_rules[0]
	if encounter.refreshes >= rule.refresh_count: return "本次奇遇已经刷新过。"
	var previous: String = "%d:%d" % [encounter.reward.kind, encounter.cost.kind]
	return _generate_encounter(catalog, build, encounter.refreshes + 1, previous)

## 黑市生成三件不重复碎片商品、两种兑换与两档体力，价格随商品一起锁定。
func _generate_market(catalog: RefCounted, _build: RefCounted) -> String:
	var rule: Dictionary = catalog.content.data.black_market_rules[0]
	var random := RandomSource.new(seed)
	var actions: Array = []
	var used_rewards: Array = []
	for index: int in range(rule.fragment_offer_count):
		var categories: Array = [
			{"tab": C.ShopTab.Minion, "selection_weight": rule.minion_weight},
			{"tab": C.ShopTab.Item, "selection_weight": rule.item_weight},
			{"tab": C.ShopTab.Hero, "selection_weight": rule.hero_weight},
		]
		categories = categories.filter(func(category): return catalog.content.data.shop_offers.any(func(offer): return offer.shop_tab == category.tab and not offer.fragment_item_id.is_empty() and not offer.reward_id in used_rewards))
		if categories.is_empty(): return "黑市碎片商品候选不足。"
		var tab: int = _weighted(categories, random).tab
		var candidates: Array = catalog.content.data.shop_offers.filter(func(offer): return offer.shop_tab == tab and not offer.fragment_item_id.is_empty() and not offer.reward_id in used_rewards)
		var source: Dictionary = candidates[random.next_int(candidates.size())]
		used_rewards.append(source.reward_id)
		actions.append(_market_action("fragment:%d" % index, MarketKind.Fragment, source.fragment_item_id, source.reward_id,
			rule.fragment_amount, _fragment_price(source, C.Currency.Gold, rule.fragment_amount),
			_fragment_price(source, C.Currency.StarStone, rule.fragment_amount)))
	actions.append(_exchange_action("exchange:gold_to_star", C.Currency.Gold, rule.gold_to_star_cost, C.Currency.StarStone, rule.gold_to_star_reward))
	actions.append(_exchange_action("exchange:star_to_gold", C.Currency.StarStone, rule.star_to_gold_cost, C.Currency.Gold, rule.star_to_gold_reward))
	actions.append(_market_action("stamina:small", MarketKind.Stamina, "", "", rule.stamina_small_amount, rule.stamina_small_gold_price, rule.stamina_small_star_stone_price))
	actions.append(_market_action("stamina:large", MarketKind.Stamina, "", "", rule.stamina_large_amount, rule.stamina_large_gold_price, rule.stamina_large_star_stone_price))
	market = {"actions": actions}
	encounter.clear()
	return ""

## 账号商品缺少某种支付方式时按一金币一百星石换算，黑市仍固定提供两种支付按钮。
func _fragment_price(source: Dictionary, currency: int, amount: int) -> int:
	var field: String = "account_gold_price" if currency == C.Currency.Gold else "account_star_stone_price"
	var value: Variant = source.get(field)
	if value == null:
		var other: int = int(source.get("account_star_stone_price" if currency == C.Currency.Gold else "account_gold_price", 0))
		value = ceili(float(other) / 100.0) if currency == C.Currency.Gold else other * 100
	return maxi(1, ceili(float(int(value) * amount) / int(source.fragment_amount)))

## 固定形状让购买入口无需按不同商品补造默认字段。
func _market_action(id: String, kind: int, content_id: String, reward_id: String, amount: int, gold_price: int, stone_price: int) -> Dictionary:
	return {"id": id, "kind": kind, "purchased": false, "content_id": content_id, "reward_id": reward_id,
		"amount": amount, "gold_price": gold_price, "stone_price": stone_price,
		"cost_currency": -1, "cost_amount": 0, "reward_currency": -1, "reward_amount": 0}

## 双向兑换保存确定的支付与入账方向，不接受购买时改变方向。
func _exchange_action(id: String, cost_currency: int, cost_amount: int, reward_currency: int, reward_amount: int) -> Dictionary:
	var result: Dictionary = _market_action(id, MarketKind.Exchange, "", "", 0, 0, 0)
	result.cost_currency = cost_currency
	result.cost_amount = cost_amount
	result.reward_currency = reward_currency
	result.reward_amount = reward_amount
	return result

## 查询已锁定的未购项目，页面顺序不能代替商品身份。
func available_market_action(id: String) -> Dictionary:
	if node_type != C.NodeType.BlackMarket: return {}
	for action: Dictionary in market.get("actions", []):
		if action.id == id and not action.purchased: return action
	return {}

## 每项成功交付后标记一次；保存失败由外层会话恢复整份事件。
func mark_purchased(id: String) -> String:
	var action: Dictionary = available_market_action(id)
	if action.is_empty(): return "该商品已经购买或不存在。"
	action.purchased = true
	return ""

## 新奇遇独立抽取收获和代价，目标缺失时仍保留该无操作代价。
func _generate_encounter(catalog: RefCounted, build: RefCounted, refreshes: int, excluded: String) -> String:
	var rule: Dictionary = catalog.content.data.adventure_encounter_rules[0]
	var random := RandomSource.new((seed ^ ((refreshes + 1) * 1103515245)) & 0xffffffff)
	var reward: Dictionary = {}
	var cost: Dictionary = {}
	for _attempt in range(32):
		reward = _encounter_reward(rule, catalog, random)
		cost = _encounter_cost(rule, build, random)
		if "%d:%d" % [reward.get("kind", -1), cost.get("kind", -1)] != excluded: break
	if reward.is_empty() or cost.is_empty() or "%d:%d" % [reward.kind, cost.kind] == excluded: return "奇遇无法生成不同的新组合。"
	encounter = {"reward": reward, "cost": cost, "refreshes": refreshes}
	market.clear()
	return ""

## 收获类别等权抽取，卡牌类别再按随从六成、道具四成抽取。
func _encounter_reward(rule: Dictionary, catalog: RefCounted, random: RefCounted) -> Dictionary:
	var rows: Array = [
		{"kind": C.EncounterReward.Dice, "selection_weight": rule.dice_reward_weight},
		{"kind": C.EncounterReward.StarStone, "selection_weight": rule.star_stone_reward_weight},
		{"kind": C.EncounterReward.Relic, "selection_weight": rule.relic_reward_weight},
		{"kind": C.EncounterReward.Card, "selection_weight": rule.card_reward_weight},
	]
	var kind: int = _weighted(rows, random).kind
	var result: Dictionary = {"kind": kind, "amount": 1, "content_id": ""}
	if kind == C.EncounterReward.StarStone:
		result.amount = rule.star_stone_min + random.next_int(rule.star_stone_max - rule.star_stone_min + 1)
	elif kind == C.EncounterReward.Relic:
		if catalog.content.data.relics.is_empty(): return {}
		result.content_id = catalog.content.data.relics[random.next_int(catalog.content.data.relics.size())].id
	elif kind == C.EncounterReward.Card:
		var card_kind: int = _weighted([{"kind": CardTypes.Kind.Minion, "selection_weight": rule.card_minion_weight}, {"kind": CardTypes.Kind.ItemCard, "selection_weight": rule.card_item_weight}], random).kind
		var cards: Array = catalog.content.data.cards.filter(func(card): return card.card_kind == card_kind)
		if cards.is_empty(): return {}
		result.content_id = cards[random.next_int(cards.size())].id
	return result

## 代价类别独立抽取；卡牌和骰子不存在时锁定空目标，接受后不改扣其他资源。
func _encounter_cost(rule: Dictionary, build: RefCounted, random: RefCounted) -> Dictionary:
	var rows: Array = [
		{"kind": C.EncounterCost.Stamina, "selection_weight": rule.stamina_cost_weight},
		{"kind": C.EncounterCost.TeamDebuff, "selection_weight": rule.team_debuff_cost_weight},
		{"kind": C.EncounterCost.Card, "selection_weight": rule.card_cost_weight},
		{"kind": C.EncounterCost.Dice, "selection_weight": rule.die_cost_weight},
	]
	var kind: int = _weighted(rows, random).kind
	var result: Dictionary = {"kind": kind, "amount": 1, "stat": "", "target_id": ""}
	if kind == C.EncounterCost.Stamina: result.amount = rule.stamina_cost_amount
	elif kind == C.EncounterCost.TeamDebuff:
		var stats: Array = ["physical_damage", "witchcraft_damage", "burn_damage", "poison_damage"]
		result.amount = rule.team_debuff_amount
		result.stat = stats[random.next_int(stats.size())]
	elif kind == C.EncounterCost.Card:
		var cards: Array = build.cards.filter(func(card): return card.kind in [CardTypes.Kind.Minion, CardTypes.Kind.ItemCard])
		if not cards.is_empty(): result.target_id = cards[random.next_int(cards.size())].id
	elif kind == C.EncounterCost.Dice:
		var ids: Array = build.rewards.unused_ids()
		if not ids.is_empty(): result.target_id = str(ids[random.next_int(ids.size())])
	return result

## 加权抽取只使用传入随机源，内容数量不会暗改类别概率。
func _weighted(rows: Array, random: RefCounted) -> Dictionary:
	var total: int = 0
	for row: Dictionary in rows: total += row.selection_weight
	var roll: int = random.next_int(total)
	for row: Dictionary in rows:
		if roll < row.selection_weight: return row
		roll -= row.selection_weight
	return rows.back()

## 离开、接受或结束章节时清除活动事件，不撤销已提交的单项购买。
func clear() -> void:
	node_index = -1
	node_type = -1
	seed = 0
	market.clear()
	encounter.clear()

## 保存随机结果、刷新次数和逐项购买标记，不保存静态规则副本。
func capture() -> Dictionary:
	return {"node_index": node_index, "node_type": node_type, "seed": seed, "market": market.duplicate(true), "encounter": encounter.duplicate(true)}

## 完整检查事件形状和内容引用，拒绝用新随机结果修补损坏存档。
func restore(state: Variant, content: RefCounted) -> String:
	if not state is Dictionary or state.size() != 5 or not state.get("node_index") is int or not state.get("node_type") is int or not state.get("seed") is int or not state.get("market") is Dictionary or not state.get("encounter") is Dictionary: return "章节事件存档格式损坏。"
	if state.node_index == -1:
		if state.node_type != -1 or not state.market.is_empty() or not state.encounter.is_empty(): return "空事件夹带活动内容。"
		clear()
		return ""
	if state.node_index < 0 or not state.node_type in [C.NodeType.BlackMarket, C.NodeType.Adventure]: return "章节事件节点无效。"
	var error: String = _validate_market(state.market, content) if state.node_type == C.NodeType.BlackMarket else _validate_encounter(state.encounter, content)
	if not error.is_empty(): return error
	if state.node_type == C.NodeType.BlackMarket and not state.encounter.is_empty(): return "黑市夹带奇遇状态。"
	if state.node_type == C.NodeType.Adventure and not state.market.is_empty(): return "奇遇夹带黑市状态。"
	node_index = state.node_index
	node_type = state.node_type
	seed = state.seed
	market = state.market.duplicate(true)
	encounter = state.encounter.duplicate(true)
	return ""

## 黑市恢复只接受三件碎片、两次兑换和两档体力的锁定项目。
func _validate_market(value: Dictionary, content: RefCounted) -> String:
	if value.size() != 1 or not value.get("actions") is Array or value.actions.size() != 7: return "黑市商品存档不完整。"
	var ids: Array = []
	var counts: Dictionary = {MarketKind.Fragment: 0, MarketKind.Exchange: 0, MarketKind.Stamina: 0}
	for action: Variant in value.actions:
		if not action is Dictionary or action.size() != 12: return "黑市商品格式损坏。"
		if not action.get("id") is String or action.id in ids or not action.get("kind") in MarketKind.values() or not action.get("purchased") is bool: return "黑市商品身份损坏。"
		ids.append(action.id)
		counts[action.kind] += 1
		for field in ["amount", "gold_price", "stone_price", "cost_currency", "cost_amount", "reward_currency", "reward_amount"]:
			if not action.get(field) is int: return "黑市商品数值损坏。"
		if not action.get("content_id") is String or not action.get("reward_id") is String: return "黑市商品内容身份损坏。"
		if action.kind == MarketKind.Fragment:
			var sources: Array = content.data.shop_offers.filter(func(offer): return offer.reward_id == action.reward_id and offer.fragment_item_id == action.content_id and offer.shop_tab in [C.ShopTab.Hero, C.ShopTab.Minion, C.ShopTab.Item])
			if sources.size() != 1 or content.get_record("items", action.content_id).is_empty() or action.amount <= 0 or action.gold_price <= 0 or action.stone_price <= 0: return "黑市碎片商品无效。"
		if action.kind == MarketKind.Exchange and (not action.cost_currency in [C.Currency.Gold, C.Currency.StarStone] or not action.reward_currency in [C.Currency.Gold, C.Currency.StarStone] or action.cost_currency == action.reward_currency or action.cost_amount <= 0 or action.reward_amount <= 0): return "黑市兑换项目无效。"
		if action.kind == MarketKind.Stamina and (action.amount <= 0 or action.gold_price <= 0 or action.stone_price <= 0): return "黑市体力商品无效。"
	return "" if counts == {MarketKind.Fragment: 3, MarketKind.Exchange: 2, MarketKind.Stamina: 2} else "黑市商品分类数量错误。"

## 奇遇恢复核对类别、范围和引用，允许卡牌或骰子代价锁定为空目标。
func _validate_encounter(value: Dictionary, content: RefCounted) -> String:
	if value.size() != 3 or not value.get("reward") is Dictionary or not value.get("cost") is Dictionary or not value.get("refreshes") is int: return "奇遇组合格式损坏。"
	if value.refreshes < 0 or value.refreshes > content.data.adventure_encounter_rules[0].refresh_count: return "奇遇刷新次数越界。"
	var reward: Dictionary = value.reward
	var cost: Dictionary = value.cost
	if reward.size() != 3 or not reward.get("kind") in C.EncounterReward.values() or not reward.get("amount") is int or reward.amount <= 0 or not reward.get("content_id") is String: return "奇遇收获损坏。"
	if reward.kind == C.EncounterReward.Relic and content.get_record("relics", reward.content_id).is_empty(): return "奇遇遗物引用无效。"
	if reward.kind == C.EncounterReward.Card and content.get_record("cards", reward.content_id).get("card_kind") not in [CardTypes.Kind.Minion, CardTypes.Kind.ItemCard]: return "奇遇卡牌引用无效。"
	if reward.kind in [C.EncounterReward.Dice, C.EncounterReward.StarStone] and not reward.content_id.is_empty(): return "奇遇数值奖励夹带内容。"
	if cost.size() != 4 or not cost.get("kind") in C.EncounterCost.values() or not cost.get("amount") is int or cost.amount <= 0 or not cost.get("stat") is String or not cost.get("target_id") is String: return "奇遇代价损坏。"
	if cost.kind == C.EncounterCost.TeamDebuff and not cost.stat in ["physical_damage", "witchcraft_damage", "burn_damage", "poison_damage"]: return "奇遇减益属性无效。"
	if cost.kind != C.EncounterCost.TeamDebuff and not cost.stat.is_empty(): return "奇遇非减益代价夹带属性。"
	return ""
