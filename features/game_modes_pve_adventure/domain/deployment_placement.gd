extends RefCounted
## 冒险部署占位候选：入场避让和双卡交换均先检查完整空间，不改写输入。

## 交换双方锚点，必须完整容纳且不重叠双方、其他玩家或固定怪物。
static func swap_positions(players: Array, enemies: Array, first_id: String, second_id: String) -> Dictionary:
	var first: Dictionary = {}
	var second: Dictionary = {}
	for card in players:
		if card.id == first_id: first = card
		if card.id == second_id: second = card
	if first_id == second_id or first.is_empty() or second.is_empty():
		return {"error": "请选择两张不同的己方卡牌。", "positions": {}}
	var first_mask := BattleGrid.footprint_mask(second.position, first.width, first.height)
	var second_mask := BattleGrid.footprint_mask(first.position, second.width, second.height)
	if first_mask == 0 or second_mask == 0 or first_mask & second_mask:
		return {"error": "双方占位区域不足，无法对调。", "positions": {}}
	for card in players + enemies:
		if card in [first, second]: continue
		var mask := BattleGrid.footprint_mask(card.position, card.width, card.height)
		if mask == 0 or mask & (first_mask | second_mask):
			return {"error": "对调区域被其他卡牌占用。", "positions": {}}
	return {"error": "", "positions": {first_id: second.position, second_id: first.position}}

## 先生成完整候选，不改写输入；放不下时不返回部分迁移。
static func resolve(players: Array, enemies: Array) -> Dictionary:
	var occupied: int = 0
	for enemy in enemies:
		var mask := BattleGrid.footprint_mask(enemy.position, enemy.width, enemy.height)
		if mask == 0 or occupied & mask: return {"error": "怪物占位无效。", "positions": {}}
		occupied |= mask
	var moving: Array = []
	var enemy_mask: int = occupied
	var player_mask: int = 0
	var required: int = 0
	for card in players:
		var mask := BattleGrid.footprint_mask(card.position, card.width, card.height)
		if mask == 0: return {"error": "玩家卡牌占位越界。", "positions": {}}
		if mask & player_mask: return {"error": "玩家卡牌占位重叠。", "positions": {}}
		player_mask |= mask
		if mask & enemy_mask:
			moving.append(card)
			required += card.width * card.height
		else: occupied |= mask
	var available: int = 0
	for slot in range(BattleGrid.SLOTS):
		if not occupied & (1 << slot): available += 1
	if required > available: return {"error": "棋盘没有足够的空位，无法避让重叠卡牌。", "positions": {}}
	var candidates: Array = []
	for card in moving:
		var choices: Array = []
		for slot in range(BattleGrid.SLOTS):
			var mask := BattleGrid.footprint_mask(slot, card.width, card.height)
			if mask != 0 and not mask & occupied: choices.append({"position": slot, "mask": mask})
		choices.sort_custom(func(a, b): return _distance(a.position, card.position) < _distance(b.position, card.position))
		candidates.append(choices)
	var positions: Dictionary = {}
	if not _search(0, occupied, moving, candidates, positions, {}):
		return {"error": "棋盘没有足够的完整空位，无法避让重叠卡牌。", "positions": {}}
	return {"error": "", "positions": positions}

## 逐圈优先，圈内先正交距离再行列顺序，确保重试结果一致且不会边缘绕行。
static func _distance(position: int, origin: int) -> int:
	var dx := absi(position % BattleGrid.COLUMNS - origin % BattleGrid.COLUMNS)
	var dy := absi(position / BattleGrid.COLUMNS - origin / BattleGrid.COLUMNS)
	return maxi(dx, dy) * 1000 + (dx + dy) * 100 + position

## 按稳定卡牌顺序回溯完整占位，避免先移动的小卡堵住后续多格卡。
static func _search(depth: int, occupied: int, moving: Array, candidates: Array, positions: Dictionary, failed: Dictionary) -> bool:
	if depth == moving.size(): return true
	var key: int = (occupied << 6) | depth
	if failed.has(key): return false
	for choice in candidates[depth]:
		if occupied & choice.mask: continue
		positions[moving[depth].id] = choice.position
		if _search(depth + 1, occupied | choice.mask, moving, candidates, positions, failed): return true
	positions.erase(moving[depth].id)
	failed[key] = true
	return false
