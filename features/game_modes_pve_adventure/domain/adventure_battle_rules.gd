class_name AdventureBattleRules
extends RefCounted
## 冒险明确选择单英雄、当前四随从席位与英雄保护目标。

const MECHANISMS = ["innate_abilities", "relics", "talents", "synergies", "growth"]

## 单英雄规则属于冒险，通用战斗不按敌我推断载体类别。
static func create(core_id: String) -> Dictionary:
	var rules = BattleRules.create([0, 1])
	rules.maximum_duration = 60.0
	rules.health_judgment = {"warning_seconds": 10.0, "tie_winner_team": 1}
	rules.constraints["0"] = {"min_heroes": 1, "max_heroes": 1, "max_minions": 4}
	rules.protected_units["0"] = [core_id]
	return rules

## 冒险只选择参战能力与生命继承，星能奖励不进入战斗装配。
static func assembly_options(core_id: String, cards: Array = []) -> Dictionary:
	var carried: Array = [core_id]
	for card in cards:
		if card.kind == CardTypes.Kind.Minion: carried.append(card.id)
	return {"mechanisms": MECHANISMS.duplicate(), "instance_prefix": "", "carry_health_ids": carried}
