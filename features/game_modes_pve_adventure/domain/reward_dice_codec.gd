class_name RewardDiceCodec
extends RefCounted
## 验证骰子存档的身份、领取状态与活动选择，拒绝重复发奖或静默重抽。

const Dice = preload("res://features/game_modes_pve_adventure/domain/reward_dice.gd")
const C = preload("res://game_content/runtime/content_types.gd")
var error: String = ""

## 仅返回完整候选对象，调用方决定何时替换当前章节。
func restore(state: Dictionary, catalog: RefCounted) -> RefCounted:
	error = ""
	for key in ["rerolls", "seed", "roll_index", "next_id"]:
		if not state.get(key) is int or state[key] < 0: return _fail("骰子计数损坏。")
	if not state.get("dice") is Array or not state.get("choice") is Dictionary: return _fail("骰子集合或选择状态损坏。")
	var result = Dice.new()
	var seen: Array = []
	for die in state.dice:
		if not die is Dictionary or die.size() != 6: return _fail("骰子记录格式损坏。")
		if not die.get("id") is int or die.id < 0 or die.id >= state.next_id or die.id in seen: return _fail("骰子实例身份重复或越界。")
		seen.append(die.id)
		if not die.get("status") is int or not die.status in Dice.Status.values() or not die.get("kind") is int or not die.get("guaranteed") is bool or not die.get("face") is int or die.face < 0 or not die.get("reward") is Dictionary: return _fail("骰子状态字段损坏。")
		if die.guaranteed and die.kind != C.DiceKind.Treasure: return _fail("精英保底宝物身份损坏。")
		if not die.guaranteed and die.kind == C.DiceKind.Treasure: return _fail("普通骰子不能变成保底宝物。")
		if die.status == Dice.Status.Unrolled:
			if die.kind != (C.DiceKind.Treasure if die.guaranteed else -1) or die.face != 0 or not die.reward.is_empty(): return _fail("未投骰子夹带了结果。")
		else:
			if not die.kind in C.DiceKind.values(): return _fail("骰子类型损坏。")
			if die.kind == C.DiceKind.StarStone:
				if die.status != Dice.Status.Used or die.face < 1: return _fail("星石骰子必须已经直接领取。")
			elif die.face != 0: return _fail("非星石骰子不能保存数值点数。")
			if die.status == Dice.Status.Used:
				var message: String = catalog.validate_reward(die.reward, die.kind)
				if not message.is_empty(): return _fail(message)
			elif not die.reward.is_empty(): return _fail("未使用骰子不能夹带已领取奖励。")
		result.dice.append(die.duplicate(true))
	for key in ["rerolls", "seed", "roll_index", "next_id"]: result.set(key, state[key])
	# 旧档没有结算范围，只接续尚未使用的骰子，不把无法归属的历史领取冒充本场奖励。
	var settlement: Variant = state.get("settlement_ids", result.dice.filter(func(die): return die.status != Dice.Status.Used).map(func(die): return die.id))
	if not settlement is Array: return _fail("骰子结算范围损坏。")
	for id: Variant in settlement:
		if not id is int or not id in seen or id in result.settlement_ids: return _fail("骰子结算身份重复或无效。")
		result.settlement_ids.append(id)
	if not state.choice.is_empty():
		var value: Dictionary = state.choice
		if value.size() != 6 or not value.get("die_id") is int or not value.get("candidates") is Array or not value.get("refreshes") is Array or not value.get("refresh_limit") is int or value.refresh_limit != 1 or not value.get("highlight") is int: return _fail("活动选择字段损坏。")
		if not (value.get("deadline") is int or value.get("deadline") is float) or not is_finite(float(value.deadline)) or value.deadline <= 0: return _fail("选择截止时间损坏。")
		var die = result.find_die(value.die_id)
		if die.is_empty() or die.status != Dice.Status.Ready or die.kind == C.DiceKind.StarStone: return _fail("活动选择没有对应的待用骰子。")
		if value.candidates.size() != 3 or value.refreshes.size() != value.candidates.size() or value.highlight < -1 or value.highlight >= value.candidates.size(): return _fail("三选一数量或高亮位置损坏。")
		for index in range(value.candidates.size()):
			var message: String = catalog.validate_reward(value.candidates[index], die.kind)
			if not message.is_empty(): return _fail(message)
			if not value.refreshes[index] is int or value.refreshes[index] < 0 or value.refreshes[index] > value.refresh_limit: return _fail("候选刷新次数损坏。")
		result.choice = value.duplicate(true)
		result.choice.deadline = float(value.deadline)
	return result

## 失败不返回可被当作新章节保存的空状态。
func _fail(message: String) -> RefCounted:
	error = message
	return null
