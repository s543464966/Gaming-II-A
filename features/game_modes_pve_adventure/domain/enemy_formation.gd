class_name EnemyFormation
extends RefCounted
## 固定怪物阵型：允许斜角相邻，禁止重叠及上下左右相邻。

const RandomSource = preload("res://features/mechanics/foundation/deterministic_random.gd")
const SEARCH_LIMIT = 200000
var error: String = ""
var _budget: int

## 只返回完整阵型，失败不会产生部分部署或减少怪物。
func generate(footprints: Array, seed: int) -> Array:
	error = ""
	if footprints.size() > BattleGrid.SLOTS:
		error = "怪物阵型数量超过棋盘容量。"
		return []
	var random = RandomSource.new(seed)
	var candidates: Array = []
	for footprint in footprints:
		var available: Array = []
		for slot in range(BattleGrid.SLOTS):
			if BattleGrid.footprint_mask(slot, footprint.x, footprint.y) != 0: available.append(slot)
		for i in range(available.size() - 1, 0, -1):
			var swap = random.next_int(i + 1)
			var value = available[i]
			available[i] = available[swap]
			available[swap] = value
		candidates.append(available)
	var order = range(footprints.size())
	order.sort_custom(func(a, b): return a < b if candidates[a].size() == candidates[b].size() else candidates[a].size() < candidates[b].size())
	var result: Array = []
	result.resize(footprints.size())
	_budget = SEARCH_LIMIT
	if not _search(0, 0, order, footprints, candidates, result):
		error = "五列六行棋盘无法在搜索限额内生成完整、不相邻的怪物阵型。"
		return []
	return result

## 大占位优先回溯，显式预算防止非法配置阻塞游戏。
func _search(depth: int, blocked: int, order: Array, footprints: Array, candidates: Array, result: Array) -> bool:
	if depth == order.size(): return true
	var index: int = order[depth]
	for slot in candidates[index]:
		_budget -= 1
		if _budget < 0: return false
		var mask = BattleGrid.footprint_mask(slot, footprints[index].x, footprints[index].y)
		if mask & blocked: continue
		result[index] = slot
		if _search(depth + 1, blocked | expand(mask), order, footprints, candidates, result): return true
	return false

## 严格读取已有坐标，不因为玩家重叠而重新随机。
static func validate(footprints: Array, positions: Array) -> String:
	if footprints.size() != positions.size(): return "怪物与固定坐标数量不一致。"
	var blocked: int = 0
	for i in range(footprints.size()):
		if not positions[i] is int: return "固定怪物坐标必须为整数。"
		var mask = BattleGrid.footprint_mask(positions[i], footprints[i].x, footprints[i].y)
		if mask == 0 or mask & blocked: return "怪物固定坐标越界、重叠或正交相邻。"
		blocked |= expand(mask)
	return ""

## 扩展正交邻格，禁止左右边缘绕行。
static func expand(mask: int) -> int:
	var result = mask
	for i in range(BattleGrid.SLOTS):
		if not mask & (1 << i): continue
		if i >= BattleGrid.COLUMNS: result |= 1 << (i - BattleGrid.COLUMNS)
		if i < BattleGrid.SLOTS - BattleGrid.COLUMNS: result |= 1 << (i + BattleGrid.COLUMNS)
		if i % BattleGrid.COLUMNS > 0: result |= 1 << (i - 1)
		if i % BattleGrid.COLUMNS < BattleGrid.COLUMNS - 1: result |= 1 << (i + 1)
	return result
