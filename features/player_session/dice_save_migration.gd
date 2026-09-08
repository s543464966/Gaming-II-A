class_name DiceSaveMigration
extends RefCounted
## 迁移已发布骰子存档：旧市场资产转换与退役治疗骰清理，不改动原文件。

const Dice = preload("res://features/game_modes_pve_adventure/domain/reward_dice.gd")
const Ids = preload("res://features/player_session/content_id_migration.gd")
const C = preload("res://game_content/runtime/content_types.gd")
## 仅用于十五／十六版的迁移身份；不回填到当前运行时枚举。
const RETIRED_HEAL_DIE = 4
const RETIRED_HEAL_REWARD = 3
var error: String = ""

## 只转换副本；完整恢复与保存成功前不会修改用户原文件。
func convert(saved: Dictionary, catalog: RefCounted) -> Dictionary:
	error = ""
	var state = saved.duplicate(true)
	if state.get("schema") != 14 or not state.get("build") is Dictionary or not state.get("collection") is Dictionary or not state.collection.get("dices") is Dictionary or not state.get("chapters") is Dictionary: return _fail("旧骰子存档结构损坏。")
	if state.collection.dices.has("DI001"):
		if state.collection.dices.has("DI002"): return _fail("旧骰子收藏身份冲突。")
		state.collection.dices.DI002 = state.collection.dices.DI001
		state.collection.dices.erase("DI001")
	for route in state.chapters.values():
		if not route is Dictionary or not route.get("nodes") is Array: return _fail("旧章节路线损坏。")
		for node in route.nodes:
			if node == null: continue
			if not node is Dictionary or not node.get("type") is int or not node.get("completed") is bool: return _fail("旧章节节点损坏。")
			if not node.completed: node.reward_dice = catalog.dice_count(node.type)
	var build: Dictionary = state.build
	if build.get("started") == true:
		if not state.get("assets") is Dictionary or not state.assets.get("gold") is int or state.assets.gold < 0: return _fail("旧账号金币余额损坏。")
		if not build.get("gold") is int or build.gold < 0 or not build.get("gear") is Array or not build.get("market") is Dictionary: return _fail("旧章节资产或附着损坏。")
		var market: Dictionary = build.market
		for key in ["dice", "seed", "roll"]:
			if not market.get(key) is int or (key != "seed" and market[key] < 0): return _fail("旧骰子计数损坏。")
		if not market.get("slots") is Array: return _fail("旧市场槽位损坏。")
		if not market.slots.is_empty():
			if not market.get("round_rules") is Dictionary or market.round_rules.get("slot_count") != market.slots.size(): return _fail("旧市场轮次不完整。")
		var count: int = market.dice
		for index in range(market.slots.size()):
			var slot: Variant = market.slots[index]
			if not slot is Dictionary or slot.get("index") != index or not slot.get("face") is int or slot.face < 1 or slot.face > 6 or not slot.get("purchased") is bool or not slot.get("locked") is bool: return _fail("旧市场槽位状态损坏。")
			if not slot.get("offer_id") is String or not slot.offer_id in Ids.MARKET_OFFERS.values() or (slot.purchased and slot.locked): return _fail("旧市场奖励身份或领取状态损坏。")
			for field in ["price", "amount"]:
				if slot.has(field) and (not slot[field] is int or slot[field] < 0): return _fail("旧市场报价数值损坏。")
			if not slot.purchased: count += 1
		var rewards = Dice.new()
		rewards.grant(count, 0, (market.seed ^ market.roll) & 0xffffffff)
		build.rewards = rewards.capture()
		build.reward_cards = []
		build.attachments = []
		for gear in build.gear:
			if not gear is Dictionary or not gear.get("gear_id") is String or not gear.get("target") is String: return _fail("旧附着关系损坏。")
			build.attachments.append({"kind": 0, "content_id": gear.gear_id, "target": gear.target})
		state.assets.gold += build.gold
		build.migration_receipt = {"merged_account_gold": build.gold, "converted_dice": count}
		for field in ["gold", "market", "gear"]: build.erase(field)
	state.schema = 15
	return state

## 十六版治疗骰均已即时消费，只清理历史身份，不回滚既往生命或另发奖励。
func remove_healing(saved: Dictionary) -> Dictionary:
	error = ""
	var state = saved.duplicate(true)
	if state.get("schema") != 16 or not state.get("build") is Dictionary or not state.get("collection") is Dictionary or not state.collection.get("dices") is Dictionary: return _fail("旧治疗骰子存档结构损坏。")
	if state.collection.dices.has("DI006"):
		var owned: Variant = state.collection.dices.DI006
		if not owned is Dictionary or not owned.get("quantity") is int or owned.quantity < 0 or not owned.get("equipped") is bool: return _fail("旧治疗骰子收藏损坏。")
		state.collection.dices.erase("DI006")
	if state.build.get("started") == true:
		var rewards: Variant = state.build.get("rewards")
		if not rewards is Dictionary or not rewards.get("dice") is Array or not rewards.get("next_id") is int or not rewards.get("choice") is Dictionary: return _fail("旧治疗骰子集合损坏。")
		var kept: Array = []
		var seen: Array = []
		for die in rewards.dice:
			if not die is Dictionary or not die.get("id") is int or die.id < 0 or die.id >= rewards.next_id or die.id in seen: return _fail("旧骰子身份损坏或重复。")
			seen.append(die.id)
			if die.get("kind") != RETIRED_HEAL_DIE:
				kept.append(die)
				continue
			if not die.kind is int or not die.get("status") is int or not die.get("guaranteed") is bool or not die.get("face") is int: return _fail("旧治疗骰子状态类型损坏。")
			if die.size() != 6 or die.get("status") != Dice.Status.Used or die.get("guaranteed") != false or die.get("face") != 0: return _fail("旧治疗骰子不是已消费结果。")
			var reward: Variant = die.get("reward")
			if not reward is Dictionary or reward.size() != 4 or not reward.get("kind") is int or reward.kind != RETIRED_HEAL_REWARD or reward.get("content_id") != "" or reward.get("pool_id") != "DP004" or not reward.get("amount") is int or reward.amount <= 0 or reward.amount > 100: return _fail("旧治疗骰子奖励损坏。")
			if rewards.choice.get("die_id") == die.id: return _fail("已消费的治疗骰子不能保留活动选择。")
		rewards.dice = kept
	state.schema = 17
	return state

## 失败不输出可能覆盖用户进度的部分候选。
func _fail(message: String) -> Dictionary:
	error = message
	return {}
