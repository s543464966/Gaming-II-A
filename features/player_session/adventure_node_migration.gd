extends RefCounted
## Schema 18→19 退役营地和治疗条款，保留旧路线拓扑、进度及固定阵型。

const C = preload("res://game_content/runtime/content_types.gd")
const Route = preload("res://features/game_modes_pve_adventure/domain/route_state.gd")
const RETIRED_REST = 4
const RETIRED_HEAL = 1
var error: String = ""

## 只修改已验证的历史事件条款，已完成节点不补发奖励。
func convert(saved: Dictionary, content: RefCounted) -> Dictionary:
	error = ""
	var result = saved.duplicate(true)
	if not result.get("chapters") is Dictionary: return _fail("节点迁移缺少章节。")
	for route in result.chapters.values():
		if not route is Dictionary or not route.get("nodes") is Array: return _fail("节点迁移路线损坏。")
		for node in route.nodes:
			if node == null: continue
			if not node is Dictionary or not node.get("type") is int: return _fail("节点迁移标识损坏。")
			var type: int = node.type
			if type in [C.NodeType.Start, C.NodeType.NormalBattle, C.NodeType.EliteBattle, C.NodeType.BossBattle]: continue
			var failure = _validate_legacy_terms(node.get("event_terms"), type)
			if not failure.is_empty(): return _fail(failure)
			if type in [RETIRED_REST, C.NodeType.Relic]:
				node.type = C.NodeType.Relic
				node.event_terms = content.node_terms(C.NodeType.Relic)
			else: node.event_terms.erase("heal_percent")
		var failure = Route.validate(route, content)
		if not failure.is_empty(): return _fail(failure)
	result.schema = 19
	return result

## 无条款的 Schema 1–12 导入只在此补齐原协议，后续统一经过退役迁移。
static func legacy_terms(type: int, content: RefCounted) -> Dictionary:
	if type == RETIRED_REST:
		return {"effect_type": RETIRED_HEAL, "heal_percent": 30, "cost_currency": C.Currency.Gold, "cost_amount": 0, "reward_currency": C.Currency.Gold, "reward_amount": 0}
	if type == C.NodeType.Relic:
		return {"effect_type": C.NodeEffect.GrantCurrency, "heal_percent": null, "cost_currency": C.Currency.Gold, "cost_amount": 0, "reward_currency": C.Currency.StarStone, "reward_amount": 5}
	var terms: Dictionary = content.node_terms(type)
	if not terms.is_empty(): terms.heal_percent = null
	return terms

## 先拒绝损坏的旧字段，不能借迁移把无效奖励清成有效节点。
static func _validate_legacy_terms(value: Variant, type: int) -> String:
	if not value is Dictionary or value.size() != 6 or not value.has("heal_percent"): return "旧节点条款格式损坏。"
	for key in ["effect_type", "cost_currency", "cost_amount", "reward_currency", "reward_amount"]:
		if not value.get(key) is int: return "旧节点奖励参数损坏。"
	var effects = {RETIRED_REST: RETIRED_HEAL, C.NodeType.Relic: C.NodeEffect.GrantCurrency, C.NodeType.BlackMarket: C.NodeEffect.ExchangeCurrency, C.NodeType.Adventure: C.NodeEffect.GrantCurrency}
	if value.effect_type != effects.get(type) or not value.cost_currency in [C.Currency.Gold, C.Currency.StarStone] or not value.reward_currency in [C.Currency.Gold, C.Currency.StarStone]: return "旧节点枚举损坏。"
	if value.cost_amount < 0 or value.reward_amount < 0: return "旧节点数量无效。"
	if type == RETIRED_REST:
		if not (value.heal_percent is int or value.heal_percent is float) or not is_finite(float(value.heal_percent)) or value.heal_percent <= 0 or value.heal_percent > 100: return "旧节点恢复比例损坏。"
		if value.cost_amount != 0 or value.reward_amount != 0: return "旧恢复节点夹带交易。"
	else:
		if value.heal_percent != null or value.reward_amount <= 0: return "旧节点奖励损坏。"
		if (type == C.NodeType.BlackMarket and value.cost_amount <= 0) or (type != C.NodeType.BlackMarket and value.cost_amount != 0): return "旧节点花费无效。"
	return ""

## 失败不返回可被保存的部分候选。
func _fail(message: String) -> Dictionary:
	error = message
	return {}
