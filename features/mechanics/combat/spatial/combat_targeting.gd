class_name CombatTargeting
extends RefCounted
## 模式所选矩形棋盘上的寻敌和相邻关系。

const T = preload("res://features/mechanics/contracts/combat_types.gd")

## 取双方最近占用格的直线距离平方，整数排序可覆盖任意合法矩形棋盘。
static func distance_squared(owner: CombatUnit, target: CombatUnit) -> int:
	var rows = maxi(0, maxi(target.row - (owner.row + owner.definition.height - 1), owner.row - (target.row + target.definition.height - 1)))
	var columns = maxi(0, maxi(target.column - (owner.column + owner.definition.width - 1), owner.column - (target.column + target.definition.width - 1)))
	return rows * rows + columns * columns

## 判断双方矩形是否共享一条边，不把角接触算作相邻。
static func adjacent(left: CombatUnit, right: CombatUnit) -> bool:
	var lb = left.row + left.definition.height - 1
	var le = left.column + left.definition.width - 1
	var rb = right.row + right.definition.height - 1
	var re = right.column + right.definition.width - 1
	return ((lb + 1 == right.row or rb + 1 == left.row) and left.column <= re and right.column <= le) or ((le + 1 == right.column or re + 1 == left.column) and left.row <= rb and right.row <= lb)

## 先筛选合法目标；最近敌人并列按稳定 ID 顺序交给本场随机源。
static func select(cards: Array, random: DeterministicRandom, context: Dictionary, selector: int, source: CombatUnit, target: CombatUnit, tag_query: Dictionary = {}, max_targets: int = 0) -> Array:
	# 先筛选再寻敌，最近的不匹配卡不会挡住更远的合法目标。
	cards = cards.filter(func(card): return CardTagQuery.matches(card.definition.get("card_tag_ids", []), tag_query))
	var owner: CombatUnit = context.get("unit")
	var allies = cards.filter(func(card): return card.alive() and card.team_id == context.team_id)
	var enemies = cards.filter(func(card): return card.alive() and card.team_id != context.team_id)
	allies.sort_custom(func(a, b): return a.id < b.id)
	enemies.sort_custom(func(a, b): return a.id < b.id)
	match selector:
		T.Target.Self: return [owner] if owner != null and CardTagQuery.matches(owner.definition.get("card_tag_ids", []), tag_query) else []
		T.Target.EventSource: return [source] if source != null and CardTagQuery.matches(source.definition.get("card_tag_ids", []), tag_query) else []
		T.Target.EventTarget: return [target] if target != null and CardTagQuery.matches(target.definition.get("card_tag_ids", []), tag_query) else []
		T.Target.AllAllies: return allies
		T.Target.AllUnits:
			var all_units = cards.filter(func(card): return card.alive())
			all_units.sort_custom(func(a, b): return a.id < b.id)
			return _limited(all_units, owner, random, max_targets)
		T.Target.AllEnemies: return _limited(enemies, owner, random, max_targets)
		T.Target.MarkedEnemy:
			return enemies.filter(func(card): return card.mechanics.marked(context.team_id)).slice(0, 1)
		T.Target.LinkedAlly:
			return allies.filter(func(card): return owner != null and owner.mechanics.links.has(card.id))
		T.Target.NearestAlly, T.Target.AlliedMinion:
			if owner == null: return []
			var eligible: Array = allies.filter(func(card): return card != owner and (selector != T.Target.AlliedMinion or card.kind == CardTypes.Kind.Minion))
			eligible.sort_custom(func(a, b): return a.id < b.id if distance_squared(owner, a) == distance_squared(owner, b) else distance_squared(owner, a) < distance_squared(owner, b))
			return eligible.slice(0, 1)
		T.Target.AdjacentAllies:
			if owner == null: return []
			return allies.filter(func(card): return card != owner and adjacent(owner, card))
		T.Target.LowestHealthAlly:
			allies.sort_custom(func(a, b):
				var ratio_a = DeterministicMath.f32(a.health / a.maximum_health)
				var ratio_b = DeterministicMath.f32(b.health / b.maximum_health)
				return a.id < b.id if ratio_a == ratio_b else ratio_a < ratio_b)
			return allies.slice(0, 1)
		T.Target.FarthestEnemy:
			if owner == null: return []
			enemies.sort_custom(func(a, b):
				var da = distance_squared(owner, a)
				var db = distance_squared(owner, b)
				return a.id < b.id if da == db else da > db)
			return enemies.slice(0, 1)
		T.Target.NearestEnemy:
			if owner == null: return []
			if enemies.is_empty(): return []
			var nearest = enemies.map(func(card): return distance_squared(owner, card)).min()
			var candidates = enemies.filter(func(card): return distance_squared(owner, card) == nearest)
			return [candidates[0] if candidates.size() == 1 else candidates[random.next_int(candidates.size())]]
		T.Target.RandomEnemy:
			return [] if enemies.is_empty() else [enemies[random.next_int(enemies.size())]]
	return []

## 群攻先取最近的不同目标，同距使用本场随机源；无卡牌宿主的遗物在合法候选中随机抽取。
static func _limited(candidates: Array, owner: CombatUnit, random: DeterministicRandom, limit: int) -> Array:
	if limit <= 0: return candidates
	var remaining: Array = candidates.duplicate()
	var result: Array = []
	while result.size() < limit and not remaining.is_empty():
		var nearest: int = int(remaining.map(func(card): return distance_squared(owner, card)).min()) if owner != null else 0
		var tied: Array = remaining.filter(func(card): return owner == null or distance_squared(owner, card) == nearest)
		var chosen: CombatUnit = tied[0] if tied.size() == 1 else tied[random.next_int(tied.size())]
		result.append(chosen)
		remaining.erase(chosen)
	return result
