class_name BattleRules
extends RefCounted
## 模式提供的有限战斗规则：队伍、部署约束、保护目标及时间目标。

## 创建对称队伍规则，不推断英雄数量或怪物身份。
static func create(team_ids: Array, columns: int = 5, rows: int = 6) -> Dictionary:
	return {"team_ids": team_ids.duplicate(), "columns": columns, "rows": rows, "constraints": {},
		"protected_units": {}, "defeat_order": team_ids.duplicate(), "maximum_duration": 120.0,
		"step": 0.1, "survival_team": null, "health_judgment": {}, "view_team": team_ids[0] if not team_ids.is_empty() else 0}

## 开局锁定每张卡的生命权重，死亡或临时生命修正都不能改变分母。
static func initial_health(cards: Array) -> Dictionary:
	var result: Dictionary = {}
	for card: CombatUnit in cards:
		result[card.id] = {"team_id": card.team_id, "maximum": card.maximum_health}
	return result

## 每张卡最多贡献开局生命上限；护盾、弹药与临时召唤均不增加裁决分数。
static func health_standings(cards: Array, initial: Dictionary, teams: Array) -> Array:
	var result: Array = []
	var current: Dictionary = {}
	for card: CombatUnit in cards: current[card.id] = card
	for team: int in teams:
		var remaining: float = 0.0
		var maximum: float = 0.0
		for id: String in initial:
			var entry: Dictionary = initial[id]
			if entry.team_id != team: continue
			maximum += entry.maximum
			if current.has(id) and current[id].alive(): remaining += minf(current[id].health, entry.maximum)
		result.append({"team_id": team, "remaining": remaining, "maximum": maximum,
			"ratio": remaining / maximum if maximum > 0 else 0.0})
	return result

## 双方比较真实生命比例，完全相同时采用模式明确指定的守方胜利。
static func judge_health(standings: Array, rules: Dictionary) -> Dictionary:
	var left: Dictionary = standings[0]
	var right: Dictionary = standings[1]
	var left_weight: float = left.remaining * right.maximum
	var right_weight: float = right.remaining * left.maximum
	var tied: bool = left_weight == right_weight
	var winner: int = rules.health_judgment.tie_winner_team if tied else left.team_id if left_weight > right_weight else right.team_id
	return {"finished": true, "winner_team": winner,
		"defeated_teams": rules.team_ids.filter(func(team: int): return team != winner), "tied": tied}

## 保护目标死亡或全队倒下算作该队失败，按模式声明顺序处理同时失败。
static func outcome(cards: Array, rules: Dictionary) -> Dictionary:
	var defeated: Array = []
	for team in rules.defeat_order:
		var alive = cards.filter(func(card): return card.team_id == team and card.alive())
		var protected_ids: Array = rules.protected_units.get(str(team), [])
		if alive.is_empty() or protected_ids.any(func(id): return not alive.any(func(card): return card.id == id)): defeated.append(team)
	var survivors: Array = rules.team_ids.filter(func(team): return not team in defeated)
	if survivors.size() == 1: return {"finished": true, "winner_team": survivors[0], "defeated_teams": defeated}
	if survivors.is_empty():
		return {"finished": true, "winner_team": null, "defeated_teams": defeated}
	return {"finished": false, "winner_team": null, "defeated_teams": defeated}
