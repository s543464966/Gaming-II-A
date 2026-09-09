class_name RouteState
extends RefCounted
## 路线进度只保存活动锚点；可选节点由拓扑实时派生。

const Generator = preload("res://features/game_modes_pve_adventure/domain/route_generator.gd")
const C = preload("res://game_content/runtime/content_types.gd")
const Formation = preload("res://features/game_modes_pve_adventure/domain/enemy_formation.gd")
enum Phase { NodeInProgress = 0, RouteSelection = 1, ChapterCompleted = 2 }
var nodes: Array = []
var current: int = -1
var phase: int = Phase.RouteSelection
var completed: bool = false
var seed: int = 0

## 当前合法候选只有起点或已完成锚点的直接后继。
func candidates() -> Array:
	if phase != Phase.RouteSelection or completed or nodes.is_empty(): return []
	var indices: Array = [0] if current < 0 else nodes[current].next
	return indices.filter(func(index): return nodes[index] != null and not nodes[index].completed)

## 进入只提交进度，体力和保存由外层事务同时提交。
func begin(index: int) -> String:
	if not index in candidates(): return "该节点不是当前合法入口。"
	if current >= 0:
		var road = road_slot(nodes[current], nodes[index], nodes.size())
		nodes[current].selected_roads = [0, 0, 0]
		nodes[current].selected_roads[road] = 1
	current = index
	nodes[current].unlocked = true
	phase = Phase.NodeInProgress
	return ""

## 放弃节点不推进、不发奖，恢复上一已完成锚点。
func abandon() -> String:
	if phase != Phase.NodeInProgress or current < 0 or nodes[current].completed: return "没有可释放的进行中节点。"
	var previous: Array = nodes[current].before.filter(func(index): return nodes[index].completed)
	current = -1 if previous.is_empty() else int(previous[0])
	if current >= 0: nodes[current].selected_roads = nodes[current].roads.duplicate()
	phase = Phase.RouteSelection
	return ""

## 节点胜利或事件成功只允许结算一次。
func resolve(victory: bool) -> String:
	if phase != Phase.NodeInProgress or current < 0 or nodes[current].completed: return "无效或重复节点结算。"
	if not victory: return abandon()
	nodes[current].completed = true
	nodes[current].selected_roads = nodes[current].roads.duplicate()
	completed = nodes[current].next.is_empty()
	phase = Phase.ChapterCompleted if completed else Phase.RouteSelection
	for index in nodes[current].next: nodes[index].unlocked = true
	return ""

## 更换英雄只重置本章进度，保持路线与固定阵型不变。
func restart_progress() -> void:
	current = -1
	phase = Phase.RouteSelection
	completed = false
	for node in nodes:
		if node == null: continue
		node.completed = false
		node.unlocked = node.index == 0
		node.stars = 0
		node.selected_roads = [0, 0, 0]

## 以紧凑稳定引用保存全部拓扑和固定阵型。
func capture() -> Dictionary:
	return {"nodes": nodes.duplicate(true), "current": current, "phase": phase, "completed": completed, "seed": seed}

## 候选完全合法后替换状态；中断战斗在会话恢复层显式放弃。
func restore(state: Dictionary, content: RefCounted) -> String:
	var error = validate(state, content)
	if not error.is_empty(): return error
	nodes = state.nodes.duplicate(true)
	current = state.current
	phase = state.phase
	completed = state.completed
	seed = state.seed
	return ""

## 校验端点、三槽层结构、相邻层双向边和所有节点可达性。
static func validate(state: Dictionary, content: RefCounted) -> String:
	if not state.get("nodes") is Array or not state.get("current") is int or not state.get("phase") in Phase.values() or not state.get("completed") is bool or not state.get("seed") is int: return "路线格式损坏。"
	var values: Array = state.nodes
	if values.is_empty():
		return "" if state.current == -1 and state.phase == Phase.RouteSelection and not state.completed else "空路线有活动节点。"
	if values.size() < 2 or (values.size() - 2) % 3 != 0: return "路线不符合三槽结构。"
	if not values[0] is Dictionary or not values.back() is Dictionary or values[0].get("type") != Generator.Type.Start or values.back().get("type") != Generator.Type.BossBattle: return "路线起点或首领无效。"
	var real_nodes: int = 0
	for i in range(values.size()):
		var node: Variant = values[i]
		if node == null: continue
		real_nodes += 1
		if not node is Dictionary or node.get("index") != i or not node.get("type") in Generator.Type.values(): return "路线节点标识无效。"
		var expected_layer: int = 0 if i == 0 else (values.size() - 2) / 3 + 1 if i == values.size() - 1 else (i - 1) / 3 + 1
		var expected_lane: int = 1 if i == 0 or i == values.size() - 1 else (i - 1) % 3
		if node.get("layer") != expected_layer or node.get("lane") != expected_lane: return "节点层级或槽位与索引不符。"
		for field in ["monsters", "enemy_positions", "next", "before", "roads", "selected_roads"]:
			if not node.get(field) is Array: return "节点缺少拓扑或阵型数组。"
		for field in ["completed", "unlocked"]:
			if not node.get(field) is bool: return "节点进度格式损坏。"
		for field in ["stamina", "reward_dice", "monster_count", "stars"]:
			if not node.get(field) is int or node[field] < 0: return "节点数值无效。"
		if node.roads.size() != 3 or node.selected_roads.size() != 3: return "节点路线槽数量错误。"
		if Generator.is_battle(node.type) and node.monsters.is_empty(): return "战斗节点缺少怪物。"
		if not Generator.is_battle(node.type) and not node.monsters.is_empty(): return "非战斗节点包含怪物。"
		var terms_error = validate_terms(node.get("event_terms"), node.type)
		if not terms_error.is_empty(): return terms_error
		var footprints: Array = []
		for id in node.monsters:
			var card: Dictionary = content.get_record("cards", id)
			if card.is_empty() or not card.card_kind == CardTypes.Kind.Monster: return "节点引用无效怪物。"
			footprints.append(Vector2i(card.footprint_width, card.footprint_height))
		var formation_error = Formation.validate(footprints, node.enemy_positions)
		if not formation_error.is_empty(): return formation_error
		var expected_roads = [0, 0, 0]
		for pair in [["next", "before", 1], ["before", "next", -1]]:
			var seen: Array = []
			for index in node[pair[0]]:
				if not index is int or index < 0 or index >= values.size() or index in seen or not values[index] is Dictionary: return "节点连接越界或重复。"
				seen.append(index)
				var target: Dictionary = values[index]
				if target.get("layer") != node.layer + pair[2] or not target.get(pair[1]) is Array or not i in target[pair[1]]: return "路线连接非相邻层或未对称。"
				if pair[0] == "next":
					var slot = road_slot(node, target, values.size())
					if slot < 0 or slot > 2: return "路线跨越了合法相邻槽。"
					expected_roads[slot] = 1
		if node.roads != expected_roads: return "路线显示槽与拓扑不一致。"
		for road in range(3):
			if not node.selected_roads[road] in [0, 1] or node.selected_roads[road] > node.roads[road]: return "选择了不存在的路线。"
		if i != values.size() - 1 and node.next.is_empty(): return "中间节点没有后继。"
	var reachable: Array = [0]
	var cursor: int = 0
	while cursor < reachable.size():
		for index in values[reachable[cursor]].next:
			if not index in reachable: reachable.append(index)
		cursor += 1
	if reachable.size() != real_nodes: return "路线存在不可达节点。"
	if state.current < -1 or state.current >= values.size() or (state.current >= 0 and values[state.current] == null): return "活动路线锚点无效。"
	if state.phase == Phase.NodeInProgress and (state.current < 0 or values[state.current].completed): return "进行中节点不合法。"
	if state.phase == Phase.RouteSelection and state.current >= 0 and not values[state.current].completed: return "路线选择锚点尚未完成。"
	if state.completed != (state.phase == Phase.ChapterCompleted) or (state.completed and (state.current != values.size() - 1 or not values.back().completed)): return "章节完成标记不一致。"
	return ""

## 起点和首领居中，其余三槽按相对方向映射。
static func road_slot(source: Dictionary, target: Dictionary, count: int) -> int:
	if source.index == 0: return int(target.lane)
	if target.index == count - 1: return 2 - int(source.lane)
	return int(target.lane) - int(source.lane) + 1

## 校验历史节点条款的类型和范围，不用新报价覆盖旧奖励。
static func validate_terms(value: Variant, type: int) -> String:
	if not value is Dictionary: return "节点缺少已生成奖励条款。"
	if Generator.is_battle(type): return "" if value.is_empty() else "战斗节点夹带事件奖励。"
	for key in ["effect_type", "cost_currency", "cost_amount", "reward_currency", "reward_amount"]:
		if not value.get(key) is int: return "节点奖励参数损坏。"
	var effects = {C.NodeType.Relic: C.NodeEffect.AuroraChoice, C.NodeType.BlackMarket: C.NodeEffect.BlackMarket, C.NodeType.Adventure: C.NodeEffect.Encounter}
	if value.size() != 5 or value.effect_type != effects.get(type) or not value.cost_currency in [C.Currency.Gold, C.Currency.StarStone] or not value.reward_currency in [C.Currency.Gold, C.Currency.StarStone]: return "节点奖励枚举损坏。"
	if value.cost_amount < 0 or value.reward_amount < 0: return "节点奖励数量无效。"
	if value.cost_amount != 0 or value.reward_amount != 0 or value.cost_currency != C.Currency.Gold or value.reward_currency != C.Currency.Gold: return "事件节点不能夹带旧货币条款。"
	return ""
