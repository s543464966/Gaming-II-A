class_name AuroraRewards
extends RefCounted
## 本章星能触发次数与锁定的八项奖励；账号入账和强化由冒险事务执行。

const C = preload("res://game_content/runtime/content_types.gd")
var trigger_count: int = 0
var offers: Array = []
var selected: Array = []

## 当前触发可选数量随本章次数递增，已领取选项不重复消费。
func remaining() -> int:
	return 0 if offers.is_empty() else trigger_count - selected.size()

## 到达章节上限后不再生成奖励，不消耗随机数或修改已有候选。
func begin(seed: int, catalog: AdventureCatalog, build: MechanicBuild) -> String:
	if remaining() > 0: return "请先领取本次星能奖励。"
	if trigger_count >= catalog.content.data.aurora_reward_rules[0].max_triggers: return ""
	var random := DeterministicRandom.new(seed)
	var candidates: Array = []
	for row: Dictionary in catalog.content.data.aurora_rewards:
		var offer: Dictionary = {"id": row.id, "amount": row.amount_min + random.next_int(row.amount_max - row.amount_min + 1), "content_ids": []}
		var pool: Array = fragment_ids(row.aurora_reward_kind, catalog.content)
		if row.distinct_count > 0:
			if pool.size() < row.distinct_count: return "星能碎片候选不足。"
			for index: int in range(row.distinct_count):
				var chosen: int = random.next_int(pool.size())
				offer.content_ids.append(pool[chosen])
				pool.remove_at(chosen)
		elif row.aurora_reward_kind == C.AuroraReward.Relic:
			var relics: Array = catalog.content.data.relics
			if relics.is_empty(): return "星能缺少章节遗物。"
			offer.content_ids = [relics[random.next_int(relics.size())].id]
		candidates.append(offer)
	if candidates.size() != C.AuroraReward.size(): return "星能奖励必须完整提供八项。"
	trigger_count += 1
	offers = candidates
	selected.clear()
	return ""

## 返回尚可领取的锁定选项，拒绝候选外身份和同次重复选择。
func available(id: String) -> Dictionary:
	if remaining() <= 0 or id in selected: return {}
	for offer: Dictionary in offers:
		if offer.id == id: return offer
	return {}

## 所有副作用成功后才记录领取；外层保存失败会恢复整个检查点。
func claim(id: String) -> String:
	if available(id).is_empty(): return "该星能奖励不可领取。"
	selected.append(id)
	return ""

## 本轮完成只清理候选，章节累计次数继续保留。
func complete() -> void:
	offers.clear()
	selected.clear()

## 结束章节时清除本次奖励与触发次数，不撤回已入账的永久资产。
func clear() -> void:
	trigger_count = 0
	complete()

## 存档锁定实际金额、碎片和遗物，不保存第二份静态规则。
func capture() -> Dictionary:
	return {"trigger_count": trigger_count, "offers": offers.duplicate(true), "selected": selected.duplicate()}

## 完整验证次数、类别、去重与来源后才替换状态。
func restore(state: Variant, content: RefCounted) -> String:
	if not state is Dictionary or state.size() != 3 or not state.get("trigger_count") is int or not state.get("offers") is Array or not state.get("selected") is Array: return "星能奖励存档格式损坏。"
	if state.trigger_count < 0 or state.trigger_count > content.data.aurora_reward_rules[0].max_triggers: return "星能触发次数越界。"
	if not state.offers.size() in [0, C.AuroraReward.size()]: return "星能八项候选不完整。"
	if (state.offers.is_empty() and not state.selected.is_empty()) or (not state.offers.is_empty() and state.trigger_count == 0): return "星能候选与触发状态不一致。"
	var ids: Array = []
	for offer: Variant in state.offers:
		if not offer is Dictionary or offer.size() != 3 or not offer.get("id") is String or not offer.get("amount") is int or not offer.get("content_ids") is Array: return "星能选项格式损坏。"
		var row: Dictionary = content.get_record("aurora_rewards", offer.id)
		if row.is_empty() or offer.id in ids: return "星能选项缺失或重复。"
		ids.append(offer.id)
		if offer.amount < row.amount_min or offer.amount > row.amount_max: return "星能奖励数量越界。"
		var expected: int = 1 if row.aurora_reward_kind == C.AuroraReward.Relic else row.distinct_count
		if offer.content_ids.size() != expected: return "星能奖励内容数量错误。"
		var seen: Array = []
		var fragments: Array = fragment_ids(row.aurora_reward_kind, content)
		for id: Variant in offer.content_ids:
			if not id is String or id in seen: return "星能奖励内容重复或无效。"
			seen.append(id)
			if row.aurora_reward_kind == C.AuroraReward.Relic:
				if content.get_record("relics", id).is_empty(): return "星能遗物引用无效。"
			elif not id in fragments: return "星能碎片分类或引用无效。"
	var chosen: Array = []
	for id: Variant in state.selected:
		if not id is String or not id in ids or id in chosen: return "星能已领取选项损坏。"
		chosen.append(id)
	if chosen.size() > state.trigger_count: return "星能领取数量超出本次额度。"
	trigger_count = state.trigger_count
	offers = state.offers.duplicate(true)
	selected = chosen
	return ""

## 专属碎片仅由商城的内容关系分类，不根据名称或 FR 编号推断。
static func fragment_ids(kind: int, content: RefCounted) -> Array:
	var tab: int = {C.AuroraReward.MinionFragments: C.ShopTab.Minion, C.AuroraReward.RelicFragments: C.ShopTab.Relic, C.AuroraReward.HeroFragment: C.ShopTab.Hero}.get(kind, -1)
	var result: Array = []
	if tab < 0: return result
	for offer: Dictionary in content.data.shop_offers:
		if offer.shop_tab == tab and not offer.fragment_item_id.is_empty() and not offer.fragment_item_id in result: result.append(offer.fragment_item_id)
	result.sort()
	return result
