class_name RunBuild
extends "res://features/mechanics/gameplay/build_state.gd"
## 单次章节构筑的权威状态；不包含账号收藏，也不依赖界面节点。

const T = preload("res://features/mechanics/contracts/combat_types.gd")
const C = preload("res://game_content/runtime/content_types.gd")
const Dice = preload("res://features/game_modes_pve_adventure/domain/reward_dice.gd")
const Events = preload("res://features/game_modes_pve_adventure/domain/adventure_events.gd")
const MINION_CAPACITY: int = 8
const OPEN_MINION_SLOTS: int = AdventureBattleRules.OPEN_MINION_SLOTS
var started: bool = false
var pollution: int = 0
var pending_reward: bool = false
var reward_seed: int = 0
var aurora_rewards: AuroraRewards = AuroraRewards.new()
var rewards: RewardDice = Dice.new()
var events: AdventureEvents = Events.new()
## 奇遇全队减益按输出属性累计，统一在冒险装配投影时应用。
var event_debuffs: Dictionary = {}
## 记录旧余额并入账号的结果，凭据本身不是第二套货币。
var migration_receipt: Dictionary = {}

## 读取唯一核心，不缓存第二份英雄状态。
func core() -> Dictionary:
	for card in cards:
		if card.kind == CardTypes.Kind.CoreHero: return card
	return {}

## 使用合法的英雄静态定义建立新构筑。
func start(definition: Dictionary, health: float, position: int, growth: Dictionary = {}, permanent_talents: Array = []) -> String:
	if definition.is_empty() or definition.kind != CardTypes.Kind.CoreHero: return "必须选择有效英雄。"
	if BattleGrid.footprint_mask(position, definition.width, definition.height) == 0: return "英雄起始占位越界。"
	clear()
	permanent_growth = growth.duplicate(true)
	talents = permanent_talents.duplicate()
	var card = create_card(definition.id, definition.kind, CombatAttributes.max_health(definition), position, definition.width, definition.height)
	card.health = clampf(health, 1.0, card.max_health)
	cards.append(card)
	started = true
	return ""

## 清空当前章节，不触及账号状态。
func clear() -> void:
	started = false
	pollution = 0
	cards.clear()
	relics.clear()
	talents.clear()
	permanent_growth.clear()
	pending_reward = false
	reward_seed = 0
	aurora_rewards.clear()
	events.clear()
	event_debuffs.clear()
	next_sequence = 0
	rewards.clear()
	migration_receipt.clear()

## 开始奖励阶段，星能选项由独立奖励状态在同一事务中锁定。
func begin_reward(seed: int) -> String:
	if pending_reward: return "已有尚未完成的战后构筑。"
	reward_seed = seed
	pending_reward = true
	return ""

## 选择本章卡牌直接提升一级并保留级内进度；生命按原比例变化。
func upgrade_card(id: String, catalog: AdventureCatalog) -> String:
	var card: Dictionary = find_card(id)
	if card.is_empty() or card.kind == CardTypes.Kind.Monster: return "请选择本章卡牌。"
	var added: int = DuplicateGrowth.required_next(card.copies)
	if card.copies > DuplicateGrowth.MAX_COPIES - added: return "卡牌强化超出存储范围。"
	var options: Dictionary = AdventureBattleRules.assembly_options(core().id)
	var before: Dictionary = catalog.assembly.definition(self, card, 0, options)
	if before.is_empty(): return catalog.assembly.error
	card.copies += added
	var after: Dictionary = catalog.assembly.definition(self, card, 0, options)
	if after.is_empty():
		card.copies -= added
		return catalog.assembly.error
	card.health = CombatAttributes.points(card.health * CombatAttributes.max_health(after) / CombatAttributes.max_health(before))
	return ""

## Home 点亮天赋后更新章节输入；生命保持原比例，不复活或额外治疗。
func update_talents(selected: Array, catalog: AdventureCatalog) -> String:
	if not started: return ""
	var ratios: Array = []
	for card: Dictionary in cards:
		var definition: Dictionary = catalog.assembly.definition(self, card, 0, AdventureBattleRules.assembly_options(core().id))
		if definition.is_empty(): return catalog.assembly.error
		ratios.append(card.health / CombatAttributes.max_health(definition))
	talents = selected.duplicate()
	for index: int in range(cards.size()):
		var card: Dictionary = cards[index]
		var definition: Dictionary = catalog.assembly.definition(self, card, 0, AdventureBattleRules.assembly_options(core().id))
		if definition.is_empty(): return catalog.assembly.error
		card.health = CombatAttributes.points(ratios[index] * CombatAttributes.max_health(definition))
	return ""

## 必选星能尚未处理时不允许离开构筑。
func complete_reward() -> String:
	if not pending_reward: return "当前没有待完成构筑。"
	if aurora_rewards.remaining() > 0: return "请先领取本次星能奖励。"
	if not rewards.choice.is_empty(): return "请先完成当前骰子的三选一。"
	pending_reward = false
	reward_seed = 0
	aurora_rewards.complete()
	rewards.rerolls = 0
	return ""

## 先尝试占位，校验失败时恢复原来的权威位置。
func place(id: String, position: int) -> String:
	var card = find_card(id)
	if card.is_empty(): return "章节卡牌不存在。"
	if card.kind == CardTypes.Kind.Minion and card.health <= 0 and position >= 0: return "倒下的随从不能继续出战。"
	if position < 0: return "卡牌必须留在战场，不能撤回。"
	var previous = card.position
	card.position = position
	var error = validate_board()
	if not error.is_empty(): card.position = previous
	return error

## 全队必须上场；当前开放五个随从席位，占位不能重叠。
func validate_board(allow_legacy_unplaced: bool = false) -> String:
	var heroes = cards.filter(func(card): return card.kind == CardTypes.Kind.CoreHero)
	if not started or heroes.size() != 1 or heroes[0].position < 0: return "构筑必须存在且部署唯一英雄。"
	if cards.filter(func(card): return card.kind == CardTypes.Kind.Minion and card.position >= 0).size() > OPEN_MINION_SLOTS: return "当前最多容纳 %d 名随从。" % OPEN_MINION_SLOTS
	var occupied: int = 0
	for card in cards:
		if card.position < 0:
			if allow_legacy_unplaced: continue
			return "章节卡牌必须全部上场。"
		if card.kind == CardTypes.Kind.Minion and card.health <= 0: return "倒下的随从不能部署。"
		var mask = BattleGrid.footprint_mask(card.position, card.width, card.height)
		if mask == 0: return "卡牌占位越过五列六行棋盘。"
		if occupied & mask: return "玩家卡牌占位重叠。"
		occupied |= mask
	return ""

## 领取前再次核对资格，章节实例与账号解锁不相互替代。
func can_receive(reward: Dictionary, catalog: AdventureCatalog, collection: CollectionState, allow_unowned: bool = false) -> String:
	var error: String = catalog.validate_reward(reward)
	if not error.is_empty(): return error
	if reward.kind == C.DiceReward.Relic:
		return ""
	if reward.kind == C.DiceReward.HeroGrowth and reward.content_id != core().get("definition_id", ""): return "只能强化本章当前英雄。"
	if reward.kind in [C.DiceReward.Minion, C.DiceReward.ItemCard, C.DiceReward.HeroGrowth]:
		var row: Dictionary = catalog.reward_record(reward)
		if reward.kind == C.DiceReward.Minion and not allow_unowned and not collection.owns(row.id): return "随从尚未解锁。"
		if not can_add_card(catalog.assembly.base_definition(row.id)): return "战场没有可容纳这张新卡的位置，请选择其他奖励。"
		for card in cards:
			if card.definition_id == reward.content_id and card.copies == DuplicateGrowth.MAX_COPIES: return "卡牌累计份数超出存储范围。"
	return ""

## 遗物按份直接加入章节；新卡上场，重复卡升级原实例且保留站位。
func receive(reward: Dictionary, catalog: AdventureCatalog, collection: CollectionState, allow_unowned: bool = false) -> String:
	var error = can_receive(reward, catalog, collection, allow_unowned)
	if not error.is_empty(): return error
	if reward.kind == C.DiceReward.Relic:
		relics.append({"id": "relic:%d" % next_sequence, "content_id": reward.content_id, "consumed": false})
		next_sequence += 1
	elif reward.kind in [C.DiceReward.Minion, C.DiceReward.ItemCard, C.DiceReward.HeroGrowth]:
		for card in cards:
			if card.definition_id == reward.content_id:
				var before: Dictionary = catalog.assembly.definition(self, card, 0, AdventureBattleRules.assembly_options(core().id))
				if before.is_empty(): return catalog.assembly.error
				card.copies += 1
				var after: Dictionary = catalog.assembly.definition(self, card, 0, AdventureBattleRules.assembly_options(core().id))
				if after.is_empty():
					card.copies -= 1
					return catalog.assembly.error
				card.health = CombatAttributes.points(card.health * CombatAttributes.max_health(after) / CombatAttributes.max_health(before))
				return ""
		var definition: Dictionary = catalog.assembly.base_definition(reward.content_id)
		var card = create_card(definition.id, definition.kind, definition.max_health, reward_position(definition), definition.width, definition.height)
		cards.append(card)
		var effective: Dictionary = catalog.assembly.definition(self, card, 0, AdventureBattleRules.assembly_options(core().id))
		if effective.is_empty():
			cards.pop_back()
			next_sequence -= 1
			return catalog.assembly.error
		card.health = CombatAttributes.max_health(effective)
	return ""

## 奇遇卡牌可来自全部正式内容，仍服从重复份数、开放席位与棋盘容量。
func receive_event_card(content_id: String, catalog: AdventureCatalog, collection: CollectionState) -> String:
	var row: Dictionary = catalog.content.get_record("cards", content_id)
	if row.get("card_kind") not in [CardTypes.Kind.Minion, CardTypes.Kind.ItemCard]: return "奇遇卡牌类别无效。"
	var kind: int = C.DiceReward.Minion if row.card_kind == CardTypes.Kind.Minion else C.DiceReward.ItemCard
	var pools: Array = catalog.content.data.dice_reward_pools.filter(func(pool): return pool.reward_kind == kind)
	if pools.is_empty(): return "奇遇卡牌缺少正式奖励来源。"
	return receive({"pool_id": pools[0].id, "kind": kind, "content_id": content_id, "amount": 1}, catalog, collection, true)

## 奇遇只减少锁定的非英雄章节卡牌份数，最后一份移除实例且绝不改动英雄。
func remove_event_card(instance_id: String, catalog: AdventureCatalog) -> String:
	if instance_id.is_empty(): return ""
	for index: int in range(cards.size()):
		var card: Dictionary = cards[index]
		if card.id != instance_id: continue
		if card.kind not in [CardTypes.Kind.Minion, CardTypes.Kind.ItemCard]: return "奇遇不能移除英雄。"
		if card.copies <= 1:
			cards.remove_at(index)
			return ""
		var options: Dictionary = AdventureBattleRules.assembly_options(core().id)
		var before: Dictionary = catalog.assembly.definition(self, card, 0, options)
		if before.is_empty(): return catalog.assembly.error
		card.copies -= 1
		var after: Dictionary = catalog.assembly.definition(self, card, 0, options)
		if after.is_empty():
			card.copies += 1
			return catalog.assembly.error
		card.health = CombatAttributes.points(card.health * CombatAttributes.max_health(after) / CombatAttributes.max_health(before))
		return ""
	return "奇遇锁定的卡牌不存在。"

## 章节减益使用正数惩罚累计，最终数值由战斗属性边界截断到零。
func add_event_debuff(stat: String, amount: int) -> String:
	if stat not in ["physical_damage", "witchcraft_damage", "burn_damage", "poison_damage"] or amount <= 0: return "奇遇全队减益无效。"
	event_debuffs[stat] = int(event_debuffs.get(stat, 0)) + amount
	return ""

## 新卡使用完整空位；开章伙伴可优先贴近英雄，其余奖励保持稳定空位顺序。
func reward_position(definition: Dictionary, near: int = -1) -> int:
	if definition.kind == CardTypes.Kind.Minion and cards.filter(func(card): return card.kind == CardTypes.Kind.Minion and card.position >= 0).size() >= OPEN_MINION_SLOTS: return -1
	var occupied: int = 0
	for card in cards:
		if card.position >= 0: occupied |= BattleGrid.footprint_mask(card.position, card.width, card.height)
	var positions: Array = range(BattleGrid.COLUMNS * BattleGrid.ROWS)
	if near >= 0:
		positions.sort_custom(func(a, b):
			var da = absi(a % BattleGrid.COLUMNS - near % BattleGrid.COLUMNS) + absf(floorf(float(a) / BattleGrid.COLUMNS) - floorf(float(near) / BattleGrid.COLUMNS))
			var db = absi(b % BattleGrid.COLUMNS - near % BattleGrid.COLUMNS) + absf(floorf(float(b) / BattleGrid.COLUMNS) - floorf(float(near) / BattleGrid.COLUMNS))
			return a < b if da == db else da < db)
	for position in positions:
		var mask = BattleGrid.footprint_mask(position, definition.width, definition.height)
		if mask != 0 and (occupied & mask) == 0: return position
	return -1

## 重复内容不增加占位，新增卡牌必须能够立即完整放上棋盘。
func can_add_card(definition: Dictionary) -> bool:
	return cards.any(func(card): return card.definition_id == definition.id) or reward_position(definition) >= 0

## 替换预览按将被移除的实例重新计算席位和占位，不修改真实构筑。
func can_add_after_removing(definition: Dictionary, removed_ids: Array) -> bool:
	var remaining_cards: Array = cards.filter(func(card): return not card.id in removed_ids)
	if remaining_cards.any(func(card): return card.definition_id == definition.id): return true
	if definition.kind == CardTypes.Kind.Minion and remaining_cards.filter(func(card): return card.kind == CardTypes.Kind.Minion and card.position >= 0).size() >= OPEN_MINION_SLOTS: return false
	var occupied: int = 0
	for card: Dictionary in remaining_cards:
		if card.position >= 0: occupied |= BattleGrid.footprint_mask(card.position, card.width, card.height)
	for position in range(BattleGrid.COLUMNS * BattleGrid.ROWS):
		var mask: int = BattleGrid.footprint_mask(position, definition.width, definition.height)
		if mask != 0 and (occupied & mask) == 0: return true
	return false

## 卡牌奖励替换会移除所选非英雄实例的全部章节份数，从而确定释放一个席位。
func replace_event_card(instance_id: String) -> String:
	for index: int in range(cards.size()):
		if cards[index].id != instance_id: continue
		if cards[index].kind not in [CardTypes.Kind.Minion, CardTypes.Kind.ItemCard]: return "奇遇不能替换英雄。"
		cards.remove_at(index)
		return ""
	return "奇遇替换的卡牌不存在。"


## 胜利后全队按当前构筑回满，污染仍按模式比例继承。
func apply_victory(result: Dictionary, catalog: AdventureCatalog, carry: float = 0.5) -> String:
	if result.get("reason") != T.Completion.Victory: return "只有胜利可以结算章节奖励。"
	var hero = core()
	var outcomes: Array = result.cards.filter(func(card): return card.id == hero.get("id", ""))
	if hero.is_empty() or outcomes.is_empty() or outcomes[0].defeated: return "胜利缺少存活英雄。"
	var error = restore_full_health(catalog)
	if not error.is_empty(): return error
	pollution = PollutionMechanic.carry(pollution, result.pollution, carry)
	return ""

## 战后重置全部章节载体，包含本场倒下随从；不触发战斗治疗事件。
func restore_full_health(catalog: AdventureCatalog) -> String:
	if not started or core().is_empty(): return "尚无可恢复的章节队伍。"
	var maximums: Array = []
	for card in cards:
		var definition: Dictionary = catalog.assembly.definition(self, card, 0, AdventureBattleRules.assembly_options(core().id))
		if definition.is_empty(): return catalog.assembly.error
		maximums.append(CombatAttributes.max_health(definition))
	for index in range(cards.size()): cards[index].health = maximums[index]
	return ""

## 保存章节事实与遗物使用记录，不复制静态数值。
func capture() -> Dictionary:
	var state = super.capture()
	state.merge({"started": started, "pollution": pollution, "pending_reward": pending_reward,
		"reward_seed": reward_seed, "aurora_rewards": aurora_rewards.capture(), "rewards": rewards.capture(),
		"events": events.capture(), "event_debuffs": event_debuffs.duplicate(), "migration_receipt": migration_receipt.duplicate(true)})
	return state
