extends RefCounted
## 将旧即时非战斗节点升级为可恢复事件，并把星能候选收敛为逐轮三选一。

const C = preload("res://game_content/runtime/content_types.gd")
var error: String = ""

## 迁移只补充新状态与节点效果身份，不重抽奖励、商品或历史路线。
func convert(saved: Dictionary) -> Dictionary:
	error = ""
	var result: Dictionary = saved.duplicate(true)
	if not result.get("build") is Dictionary or not result.get("chapters") is Dictionary: return _fail("事件迁移缺少章节构筑或路线。")
	var build: Dictionary = result.build
	if not build.get("aurora_rewards") is Dictionary: return _fail("事件迁移缺少星能奖励。")
	var aurora: Dictionary = build.aurora_rewards
	if aurora.size() != 3 or not aurora.get("offers") is Array or not aurora.get("selected") is Array: return _fail("旧星能奖励格式损坏。")
	aurora.choice_seed = int(build.get("reward_seed", 0))
	aurora.active_offer_ids = []
	if not aurora.offers.is_empty() and aurora.selected.size() < int(aurora.get("trigger_count", 0)):
		for offer in aurora.offers:
			if not offer is Dictionary or not offer.get("id") is String: return _fail("旧星能候选格式损坏。")
			if not offer.id in aurora.selected and aurora.active_offer_ids.size() < 3: aurora.active_offer_ids.append(offer.id)
	build.events = {"node_index": -1, "node_type": -1, "seed": 0, "market": {}, "encounter": {}}
	build.event_debuffs = {}
	for chapter_id in result.chapters:
		var route: Variant = result.chapters[chapter_id]
		if not route is Dictionary or not route.get("nodes") is Array: return _fail("事件迁移遇到损坏路线。")
		for node in route.nodes:
			if node == null: continue
			if not node is Dictionary or not node.get("type") is int or not node.get("event_terms") is Dictionary: return _fail("事件迁移遇到损坏节点。")
			if node.type == C.NodeType.BlackMarket: _replace_terms(node.event_terms, C.NodeEffect.BlackMarket)
			elif node.type == C.NodeType.Adventure: _replace_terms(node.event_terms, C.NodeEffect.Encounter)
	result.schema = 26
	return result

## 新事件的随机内容另存于构筑，路线条款只保留稳定效果身份。
func _replace_terms(terms: Dictionary, effect: int) -> void:
	terms.clear()
	terms.merge({"effect_type": effect, "cost_currency": C.Currency.Gold, "cost_amount": 0, "reward_currency": C.Currency.Gold, "reward_amount": 0})

## 损坏候选不发布为新版本，源存档由仓储层原样保留。
func _fail(message: String) -> Dictionary:
	error = message
	return {}
