extends RefCounted
## Schema 27→28 兼容旧档多格怪物占位；只移动未完成、非进行中节点的冲突站位。

const Route = preload("res://features/game_modes_pve_adventure/domain/route_state.gd")
const Formation = preload("res://features/game_modes_pve_adventure/domain/enemy_formation.gd")
const SEARCH_LIMIT = 200000
var error: String = ""
var _budget: int = 0

## 在副本中转换并完整校验路线；正式会话仍负责其余业务状态的原子恢复。
func convert(saved: Dictionary, content: RefCounted) -> Dictionary:
	error = ""
	var result: Dictionary = saved.duplicate(true)
	if result.get("schema") != 27 or not result.get("chapters") is Dictionary:
		return _fail("怪物站位迁移缺少旧版章节。")
	for chapter: Variant in result.chapters:
		if not result.chapters[chapter] is Dictionary:
			return _fail("怪物站位迁移遇到损坏章节。")
		var route: Dictionary = result.chapters[chapter]
		error = _convert_route(route, content)
		if not error.is_empty(): return {}
		error = Route.validate(route, content)
		if not error.is_empty(): return {}
	result.schema = 28
	return result

## 单格锚点原本必须合法；只为完整占位冲突提供一次性转换，不重新随机路线。
func _convert_route(route: Dictionary, content: RefCounted) -> String:
	if not route.get("nodes") is Array or not route.get("current") is int or not route.get("phase") in Route.Phase.values():
		return "怪物站位迁移遇到损坏路线。"
	for index in range(route.nodes.size()):
		var node: Variant = route.nodes[index]
		if node == null: continue
		if not node is Dictionary or not node.get("monsters") is Array or not node.get("enemy_positions") is Array or not node.get("completed") is bool:
			return "怪物站位迁移遇到损坏节点。"
		var footprints: Array = []
		var anchors: Array = []
		for id: Variant in node.monsters:
			if not id is String: return "怪物站位迁移遇到无效怪物引用。"
			var card: Dictionary = content.get_record("cards", id)
			if card.is_empty() or card.card_kind != CardTypes.Kind.Monster:
				return "怪物站位迁移遇到无效怪物引用。"
			footprints.append(Vector2i(card.footprint_width, card.footprint_height))
			anchors.append(Vector2i.ONE)
		var formation_error: String = Formation.validate(footprints, node.enemy_positions)
		if formation_error.is_empty(): continue
		if node.completed or (route.phase == Route.Phase.NodeInProgress and route.current == index):
			return "已完成或进行中的怪物阵型不合法，不能自动调整历史。"
		if not Formation.validate(anchors, node.enemy_positions).is_empty(): return formation_error
		var positions: Array = _relocate(footprints, node.enemy_positions)
		if positions.is_empty(): return "无法在搜索限额内完整迁移怪物站位，原存档保持不变。"
		node.enemy_positions = positions
	return ""

## 优先最少移动数量，再按原顺序就近尝试；固定预算使异常阵容可控地失败。
func _relocate(footprints: Array, original: Array) -> Array:
	var candidates: Array = []
	for i in range(footprints.size()):
		var slots: Array = []
		for slot in range(BattleGrid.SLOTS):
			if BattleGrid.footprint_mask(slot, footprints[i].x, footprints[i].y) != 0: slots.append(slot)
		var anchor: int = original[i]
		slots.sort_custom(func(a: int, b: int) -> bool:
			var left: int = _distance(a, anchor)
			var right: int = _distance(b, anchor)
			return a < b if left == right else left < right)
		candidates.append(slots)
	var positions: Array = original.duplicate()
	_budget = SEARCH_LIMIT
	for moves in range(1, footprints.size() + 1):
		if _search(0, 0, moves, footprints, original, candidates, positions): return positions
		if _budget <= 0: break
	return []

## 回溯只输出完整解，不改变怪物身份、数量或奖励；不使用随机源。
func _search(index: int, blocked: int, moves: int, footprints: Array, original: Array, candidates: Array, positions: Array) -> bool:
	if index == footprints.size(): return true
	for slot: int in candidates[index]:
		_budget -= 1
		if _budget < 0: return false
		var cost: int = 0 if slot == original[index] else 1
		if cost > moves: continue
		var mask: int = BattleGrid.footprint_mask(slot, footprints[index].x, footprints[index].y)
		if mask & blocked: continue
		positions[index] = slot
		if _search(index + 1, blocked | Formation.expand(mask), moves - cost, footprints, original, candidates, positions): return true
	return false

## 行列曼哈顿距离保持同一旧档的候选顺序稳定。
@warning_ignore("integer_division")
func _distance(a: int, b: int) -> int:
	return absi(a / BattleGrid.COLUMNS - b / BattleGrid.COLUMNS) + absi(a % BattleGrid.COLUMNS - b % BattleGrid.COLUMNS)

## 失败不发布部分候选，也不写入源文件。
func _fail(message: String) -> Dictionary:
	error = message
	return {}
