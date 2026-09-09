class_name RewardDice
extends RefCounted
## 章节骰子、重摇与限时选择的权威状态；账号发奖由外层事务提交。

const C = preload("res://game_content/runtime/content_types.gd")
const RandomSource = preload("res://features/mechanics/foundation/deterministic_random.gd")
enum Status { Unrolled, Ready, Used }
var dice: Array = []
var rerolls: int = 0
var seed: int = 0
var roll_index: int = 0
var next_id: int = 0
## 本次胜利参与投掷的骰子身份，包含带入旧骰；领取内容仍以骰子记录为准。
var settlement_ids: Array[int] = []
## 只有一个活动选择；截止时间为 UTC 秒，离开界面不会重置。
var choice: Dictionary = {}

## 胜利发放时让未用骰与新骰一起待投，精英保底计入总数。
func grant(total: int, treasure: int, new_seed: int) -> void:
	seed = (seed ^ new_seed) & 0xffffffff
	settlement_ids.clear()
	for die: Dictionary in dice:
		if die.status == Status.Used: continue
		settlement_ids.append(die.id)
		die.status = Status.Unrolled
		die.face = 0
		die.reward = {}
	for index in range(total):
		var guaranteed = index < treasure
		dice.append({"id": next_id, "kind": C.DiceKind.Treasure if guaranteed else -1, "guaranteed": guaranteed,
			"status": Status.Unrolled, "face": 0, "reward": {}})
		settlement_ids.append(next_id)
		next_id += 1

## 奇遇新增一颗普通待投骰并只把它计入本轮结算。
func grant_extra(new_seed: int) -> void:
	seed = (seed ^ new_seed) & 0xffffffff
	var id: int = next_id
	dice.append({"id": id, "kind": -1, "guaranteed": false, "status": Status.Unrolled, "face": 0, "reward": {}})
	settlement_ids = [id]
	next_id += 1

## 奇遇代价只列出尚未消费的骰子，已领取历史不能再次失去。
func unused_ids() -> Array:
	return dice.filter(func(die): return die.status != Status.Used).map(func(die): return die.id)

## 锁定目标为空时不扣其他骰子；存在目标只移除一次且不触发奖励。
func remove_unused(id: int) -> String:
	if id < 0: return ""
	if not choice.is_empty(): return "当前有正在选择的骰子。"
	for index: int in range(dice.size()):
		if dice[index].id != id: continue
		if dice[index].status == Status.Used: return "奇遇锁定的骰子已经使用。"
		dice.remove_at(index)
		settlement_ids.erase(id)
		return ""
	return "奇遇锁定的骰子不存在。"

## 待投的新旧骰一次投出，星石立即进入本次事务的发奖清单。
func roll(catalog: RefCounted, build: RefCounted, collection: RefCounted, payouts: Array) -> String:
	if not choice.is_empty(): return "请先完成当前骰子的选择。"
	var targets = dice.filter(func(die): return die.status == Status.Unrolled)
	if targets.is_empty(): return "没有尚未投掷的骰子。"
	return _roll(targets, catalog, build, collection, payouts)

## 一次机会重摇所有剩余骰子，已领取的骰子与保底宝物身份不变。
func reroll(catalog: RefCounted, build: RefCounted, collection: RefCounted, payouts: Array) -> String:
	if not choice.is_empty(): return "请先完成当前骰子的选择，不能重置倒计时。"
	if rerolls <= 0: return "没有剩余重摇机会。"
	var targets = dice.filter(func(die): return die.status != Status.Used)
	if targets.is_empty(): return "没有可重摇的骰子。"
	var error = _roll(targets, catalog, build, collection, payouts)
	if error.is_empty(): rerolls -= 1
	return error

## 展开候选时才开始计时，尚未展开的其他骰子不受此计时影响。
func open(id: int, now: float, catalog: RefCounted, build: RefCounted, collection: RefCounted) -> String:
	if not choice.is_empty(): return "已有正在选择的骰子。"
	var die = find_die(id)
	if die.is_empty() or die.status != Status.Ready: return "该骰子尚未投出或已经使用。"
	var rule: Dictionary = catalog.content.data.dice_reward_rules[0]
	var random = _random()
	var candidates: Array = []
	var excluded: Array = []
	for _index in range(rule.choice_count):
		var reward: Dictionary = catalog.pick_reward(die.kind, build, collection, random, excluded)
		if reward.is_empty(): return "当前没有符合条件的奖励，可以保留骰子或重摇。"
		candidates.append(reward)
		excluded.append(AdventureCatalog.reward_key(reward))
	var refreshes: Array = []
	refreshes.resize(candidates.size())
	refreshes.fill(0)
	choice = {"die_id": id, "candidates": candidates, "refreshes": refreshes, "refresh_limit": rule.refreshes_per_choice,
		"highlight": -1, "deadline": now + rule.choice_seconds}
	return ""

## 每个位置独立消耗刷新次数，原截止时间保持不变。
func refresh(index: int, now: float, catalog: RefCounted, build: RefCounted, collection: RefCounted) -> String:
	var error = _choice_error(index, now)
	if not error.is_empty(): return error
	if choice.refreshes[index] >= choice.refresh_limit: return "这个选项已经刷新过。"
	var excluded = choice.candidates.map(func(reward): return AdventureCatalog.reward_key(reward))
	var reward: Dictionary = catalog.pick_reward(find_die(choice.die_id).kind, build, collection, _random(), excluded)
	if reward.is_empty(): return "当前没有可替换的合法奖励。"
	choice.candidates[index] = reward
	choice.refreshes[index] += 1
	return ""

## 记录玩家主动高亮项，超时结算使用同一已保存选择。
func highlight(index: int, now: float) -> String:
	var error = _choice_error(index, now)
	if not error.is_empty(): return error
	choice.highlight = index
	return ""

## 领取只消费一次；超时采用高亮项，没有高亮时采用第一项。
func claim(index: int, now: float, payouts: Array, timeout: bool = false) -> String:
	if choice.is_empty(): return "当前没有待选择奖励。"
	if timeout:
		if now < choice.deadline: return "选择时间尚未结束。"
		if index < 0: index = choice.highlight if choice.highlight >= 0 else 0
		if index >= choice.candidates.size(): return "奖励选项不存在。"
	else:
		var error = _choice_error(index, now)
		if not error.is_empty(): return error
	var die = find_die(choice.die_id)
	if die.is_empty() or die.status != Status.Ready: return "骰子状态已失效。"
	die.reward = choice.candidates[index].duplicate(true)
	die.status = Status.Used
	payouts.append(die.reward.duplicate(true))
	choice.clear()
	return ""

## 查询实例而不是把界面顺序当成长期身份。
func find_die(id: int) -> Dictionary:
	for die in dice:
		if die.id == id: return die
	return {}

## 界面显示剩余未使用数量，已领取历史只用于核对结果。
func remaining() -> int:
	return dice.filter(func(die): return die.status != Status.Used).size()

## 只投影本次已经领取的结果，候选、未用骰和上场奖励不计入回执。
func settled_rewards() -> Array:
	return dice.filter(func(die): return die.id in settlement_ids and die.status == Status.Used).map(func(die): return die.reward.duplicate(true))

## 是否到期由传入时钟决定，测试不依赖真实等待。
func expired(now: float) -> bool:
	return not choice.is_empty() and now >= choice.deadline

## 新章节清除临时骰子与本轮重摇机会，不触及账号奖励。
func clear() -> void:
	dice.clear()
	choice.clear()
	rerolls = 0
	seed = 0
	roll_index = 0
	next_id = 0
	settlement_ids.clear()

## 已投结果与选择状态均保存，重登不能重新抽取或重复领钱。
func capture() -> Dictionary:
	return {"dice": dice.duplicate(true), "rerolls": rerolls, "seed": seed, "roll_index": roll_index,
		"next_id": next_id, "choice": choice.duplicate(true), "settlement_ids": settlement_ids.duplicate()}

## 所有骰子先得出结果，外层统一处理发奖与写盘回滚。
func _roll(targets: Array, catalog: RefCounted, build: RefCounted, collection: RefCounted, payouts: Array) -> String:
	var random = _random()
	var pool: Array = catalog.content.data.reward_dice.filter(func(row): return row.selection_weight > 0)
	for die in targets:
		die.kind = C.DiceKind.Treasure if die.guaranteed else AdventureCatalog.weighted(pool, random).dice_kind
		die.face = 0
		die.status = Status.Ready
		if die.kind != C.DiceKind.StarStone: continue
		var reward: Dictionary = catalog.pick_reward(die.kind, build, collection, random)
		if reward.is_empty(): return "星石骰子的奖励配置缺失。"
		var terms: Dictionary = catalog.content.get_record("dice_reward_pools", reward.pool_id)
		die.face = 1 + (reward.amount - terms.amount_min) / terms.amount_step
		die.reward = reward
		die.status = Status.Used
		payouts.append(reward.duplicate(true))
	return ""

## 每次随机操作消耗唯一序列，失败时由章节事务恢复检查点。
func _random() -> RefCounted:
	roll_index += 1
	return RandomSource.new((seed ^ (roll_index * 486187739)) & 0xffffffff)

## 刷新、选中与手动领取共享截止时间及位置校验。
func _choice_error(index: int, now: float) -> String:
	if choice.is_empty(): return "当前没有待选择奖励。"
	if index < 0 or index >= choice.candidates.size(): return "奖励选项不存在。"
	if now >= choice.deadline: return "选择时间已经结束，请结算默认奖励。"
	return ""
