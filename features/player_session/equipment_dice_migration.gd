class_name EquipmentDiceMigration
extends RefCounted
## 玩家十五版一次性退出独立技能／属性骰子强化，不触及其他能力来源。

const C = preload("res://game_content/runtime/content_types.gd")
const Dice = preload("res://features/game_modes_pve_adventure/domain/reward_dice.gd")
const DiceMigration = preload("res://features/player_session/dice_save_migration.gd")
## 仅用于识别十五版已退役身份；当前内容目录不保留这些定义。
const RETIRED_ATTRIBUTES = ["AB001", "AB002", "AB003", "AB004", "AB005", "AB006", "AB007", "AB008"]
var error: String = ""

## 转换独立副本，完整恢复及正常保存成功前不改写原存档。
func convert(saved: Dictionary, catalog: RefCounted) -> Dictionary:
	error = ""
	var state = saved.duplicate(true)
	if state.get("schema") != 15 or not state.get("build") is Dictionary: return _fail("旧装备骰子存档结构损坏。")
	var build: Dictionary = state.build
	if build.get("started") == true:
		if not build.get("attachments") is Array or not build.get("reward_cards") is Array or not build.get("rewards") is Dictionary or not build.get("cards") is Array: return _fail("旧强化集合损坏。")
		var attachments: Array = []
		for entry in build.attachments:
			if not entry is Dictionary or entry.size() != 3 or not entry.get("kind") is int or not entry.get("content_id") is String or not entry.get("target") is String: return _fail("旧附着关系损坏。")
			if entry.kind in [1, 2]:
				if not _retired_content(entry.kind, entry.content_id, catalog) or not build.cards.any(func(card): return card is Dictionary and card.get("id") == entry.target): return _fail("旧强化引用或目标损坏。")
			else: attachments.append(entry)
		build.attachments = attachments
		var hands: Array = []
		var seen: Array = []
		for hand in build.reward_cards:
			if not hand is Dictionary or hand.size() != 2 or not hand.get("id") is String or hand.id in seen or not hand.id.begins_with("reward:") or not hand.get("reward") is Dictionary: return _fail("旧强化手牌损坏。")
			var suffix: String = hand.id.trim_prefix("reward:")
			if not suffix.is_valid_int() or int(suffix) < 0 or not build.get("next_sequence") is int or int(suffix) >= build.next_sequence: return _fail("旧强化手牌序号损坏。")
			seen.append(hand.id)
			if hand.reward.get("kind") in [1, 2]:
				if not _retired_reward(hand.reward, catalog): return _fail("旧强化手牌内容损坏。")
			else: hands.append(hand)
		build.reward_cards = hands
		var rewards: Dictionary = build.rewards
		if not rewards.get("dice") is Array or not rewards.get("choice") is Dictionary: return _fail("旧骰子结果损坏。")
		var dice: Array = []
		seen.clear()
		for die in rewards.dice:
			if not die is Dictionary or die.size() != 6 or not die.get("reward") is Dictionary or not die.get("id") is int or die.id in seen or die.id < 0 or not rewards.get("next_id") is int or die.id >= rewards.next_id: return _fail("旧骰子身份损坏。")
			seen.append(die.id)
			if die.reward.get("kind") in [1, 2]:
				if die.get("status") != Dice.Status.Used or die.get("kind") != C.DiceKind.Relic or die.get("guaranteed") != false or die.get("face") != 0 or not _retired_reward(die.reward, catalog): return _fail("旧强化领取历史损坏。")
				continue
			if die.reward.get("kind") == DiceMigration.RETIRED_HEAL_REWARD:
				if die.get("status") != Dice.Status.Used or die.get("kind") != C.DiceKind.Relic or die.get("guaranteed") != false or die.get("face") != 0 or not _old_heal(die.reward): return _fail("旧治疗领取历史损坏。")
				die.kind = DiceMigration.RETIRED_HEAL_DIE
			dice.append(die)
		rewards.dice = dice
		if not rewards.choice.is_empty():
			var choice: Dictionary = rewards.choice
			if not choice.get("candidates") is Array: return _fail("旧选择候选损坏。")
			var matches = dice.filter(func(die): return die.id == choice.get("die_id"))
			if matches.size() != 1: return _fail("旧选择缺少骰子。")
			if matches[0].get("kind") == C.DiceKind.Relic:
				var codec = BuildRestorer.new()
				var core_id = ""
				for card in build.cards:
					if card is Dictionary and card.get("kind") == CardTypes.Kind.CoreHero: core_id = str(card.get("id", ""))
				var growth = preload("res://features/player_session/growth_save_migration.gd").new()
				var candidate_state = growth.project_build(build)
				if not growth.error.is_empty(): return _fail(growth.error)
				var outputs = preload("res://features/player_session/output_save_migration.gd").new()
				candidate_state = outputs.convert({"build": candidate_state}, catalog.content).get("build", {})
				if not outputs.error.is_empty(): return _fail(outputs.error)
				var talent_error: String = preload("res://features/player_session/talent_save_migration.gd").validate_retired(candidate_state)
				if not talent_error.is_empty(): return _fail(talent_error)
				candidate_state.erase("talent_points")
				candidate_state.talents = []
				var aurora_error: String = preload("res://features/player_session/aurora_save_migration.gd").validate_retired(candidate_state)
				if not aurora_error.is_empty(): return _fail(aurora_error)
				candidate_state.erase("aurora_counts")
				candidate_state.erase("pending_auroras")
				var relics = preload("res://features/player_session/relic_save_migration.gd").new()
				candidate_state = relics.project_build(candidate_state, catalog)
				if not relics.error.is_empty(): return _fail(relics.error)
				var candidate = codec.restore(candidate_state, catalog.content, AdventureBattleRules.assembly_options(core_id))
				if candidate == null: return _fail(codec.error)
				if not rewards.get("seed") is int: return _fail("旧骰子随机种子损坏。")
				var random = DeterministicRandom.new((rewards.seed ^ matches[0].id) & 0xffffffff)
				var excluded: Array = []
				for reward in choice.candidates:
					if reward is Dictionary and reward.get("kind") == C.DiceReward.Relic:
						if not catalog.validate_reward(reward, C.DiceKind.Relic).is_empty(): return _fail("旧装备候选引用损坏。")
						excluded.append(AdventureCatalog.reward_key(reward))
				for index in range(choice.candidates.size()):
					var reward: Variant = choice.candidates[index]
					if not reward is Dictionary: return _fail("旧强化候选损坏。")
					if reward.get("kind") == C.DiceReward.Relic: continue
					if not _retired_reward(reward, catalog) and not _old_heal(reward): return _fail("旧强化候选引用损坏。")
					var equipment: Dictionary = catalog.pick_reward(C.DiceKind.Relic, candidate, null, random, excluded)
					if equipment.is_empty(): return _fail("旧选择无法转换为合法装备候选。")
					choice.candidates[index] = equipment
					excluded.append(AdventureCatalog.reward_key(equipment))
	state.schema = 16
	return state

## 退役奖励必须来自旧固定池；损坏记录不得借清理流程静默消失。
func _retired_reward(reward: Dictionary, catalog: RefCounted) -> bool:
	return reward.size() == 4 and reward.get("kind") is int and reward.kind in [1, 2] and reward.get("amount") == 1 and reward.get("pool_id") == ("DP002" if reward.kind == 1 else "DP003") and reward.get("content_id") is String and _retired_content(reward.kind, reward.content_id, catalog)

## 只识别已发布的属性 ID；技能引用仍由唯一技能表校验。
func _retired_content(kind: int, id: String, catalog: RefCounted) -> bool:
	return not catalog.content.get_record("main_abilities", id).is_empty() if kind == 1 else id in RETIRED_ATTRIBUTES

## 旧治疗已经执行过，不再次治疗，也不把历史百分比改为新抽取结果。
func _old_heal(reward: Dictionary) -> bool:
	return reward == {"kind": DiceMigration.RETIRED_HEAL_REWARD, "content_id": "", "pool_id": "DP004", "amount": 30}

## 出错不提供可覆盖原进度的部分候选。
func _fail(message: String) -> Dictionary:
	error = message
	return {}
