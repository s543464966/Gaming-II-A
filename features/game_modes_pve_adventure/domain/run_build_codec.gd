class_name RunBuildCodec
extends RefCounted
## 通用构筑恢复完成后，校验章节阶段、事件、减益、分类骰子、遗物及部署约束。

const C = preload("res://game_content/runtime/content_types.gd")
const Build = preload("res://features/game_modes_pve_adventure/domain/run_build.gd")
const DiceCodec = preload("res://features/game_modes_pve_adventure/domain/reward_dice_codec.gd")
var error: String = ""

## 返回独立候选；损坏存档不会部分修改当前会话。
func restore(state: Dictionary, catalog: RefCounted) -> RefCounted:
	error = ""
	var result = Build.new()
	if state.is_empty(): return result
	if state.has("attachments") or state.has("reward_cards"): return _fail("旧装备必须先迁移为遗物。")
	if state.has("talent_points"): return _fail("退役章节天赋点必须先迁移。")
	if state.has("aurora_counts") or state.has("pending_auroras"): return _fail("退役星能能力必须先迁移。")
	var aurora_error: String = result.aurora_rewards.restore(state.get("aurora_rewards"), catalog.content)
	if not aurora_error.is_empty(): return _fail(aurora_error)
	var event_error: String = result.events.restore(state.get("events"), catalog.content)
	if not event_error.is_empty(): return _fail(event_error)
	if not state.get("event_debuffs") is Dictionary: return _fail("奇遇全队减益格式损坏。")
	for stat in state.event_debuffs:
		if stat not in ["physical_damage", "witchcraft_damage", "burn_damage", "poison_damage"] or not state.event_debuffs[stat] is int or state.event_debuffs[stat] <= 0: return _fail("奇遇全队减益数值损坏。")
	if state.has("faction"): return _fail("当前构筑不能包含退役阵营字段。")
	if state.get("started") == false:
		if not state.get("cards") is Array or not state.cards.is_empty() or state.get("pending_reward") != false: return _fail("未开始章节夹带构筑或奖励。")
		for key in ["relics", "talents"]:
			if not state.get(key, []) is Array or not state.get(key, []).is_empty(): return _fail("未开始章节夹带遗物或天赋。")
		if result.aurora_rewards.trigger_count != 0: return _fail("未开始章节包含星能奖励。")
		if result.events.is_active() or not state.event_debuffs.is_empty(): return _fail("未开始章节包含事件或全队减益。")
		return result
	if state.get("started") != true: return _fail("构筑开始状态无效。")
	for key in ["pollution", "reward_seed"]:
		if not state.get(key) is int: return _fail("章节计数不是整数。")
	if state.pollution < 0 or state.pollution > 100: return _fail("章节计数越界。")
	if not state.get("pending_reward") is bool or not state.get("rewards") is Dictionary or not state.get("migration_receipt") is Dictionary: return _fail("构筑奖励状态损坏。")
	var core_id = ""
	if state.get("cards") is Array:
		for card in state.cards:
			if card is Dictionary and card.get("kind") == CardTypes.Kind.CoreHero: core_id = str(card.get("id", ""))
	var codec = BuildRestorer.new()
	var restored = codec.restore(state, catalog.content, AdventureBattleRules.assembly_options(core_id), BattleGrid.SLOTS)
	if restored == null: return _fail(codec.error)
	for key in ["next_sequence", "cards", "relics", "talents", "permanent_growth"]: result.set(key, restored.get(key))
	if result.cards.any(func(card): return card.kind == CardTypes.Kind.Monster): return _fail("章节玩家构筑不允许怪物载体。")
	if result.core().is_empty(): return _fail("章节缺少英雄。")
	if not state.pending_reward and (not result.aurora_rewards.offers.is_empty() or state.reward_seed != 0): return _fail("非奖励阶段保存了待处理候选。")
	if state.pending_reward and result.events.is_active(): return _fail("奖励阶段不能同时保留活动事件。")
	result.started = true
	result.pollution = state.pollution
	result.pending_reward = state.pending_reward
	result.reward_seed = state.reward_seed
	result.event_debuffs = state.event_debuffs.duplicate()
	var dice_codec = DiceCodec.new()
	result.rewards = dice_codec.restore(state.rewards, catalog)
	if result.rewards == null: return _fail(dice_codec.error)
	result.rewards.rerolls = mini(result.rewards.rerolls, 1) if result.pending_reward else 0
	if not state.pending_reward and not result.rewards.choice.is_empty(): return _fail("非奖励阶段不能保存活动三选一。")
	for relic in result.relics:
		var suffix: String = relic.id.trim_prefix("relic:")
		if not relic.id.begins_with("relic:") or not suffix.is_valid_int() or int(suffix) < 0 or int(suffix) >= result.next_sequence: return _fail("章节遗物序号损坏。")
	if not state.migration_receipt.is_empty() and state.migration_receipt.size() != 2: return _fail("旧章节资产迁移凭据不完整。")
	for key in state.migration_receipt:
		if not key in ["merged_account_gold", "converted_dice"] or not state.migration_receipt[key] is int or state.migration_receipt[key] < 0: return _fail("旧章节资产迁移凭据损坏。")
	result.migration_receipt = state.migration_receipt.duplicate(true)
	error = _restore_deployment(result, catalog)
	return result if error.is_empty() else null

## 旧存档未部署卡就近填入合法空位，容量不足保留源存档并明确失败，不删卡。
func _restore_deployment(build: RefCounted, catalog: RefCounted) -> String:
	var message: String = build.validate_board(true)
	if not message.is_empty(): return message
	for card in build.cards:
		if card.position >= 0: continue
		card.position = build.reward_position(catalog.assembly.base_definition(card.definition_id))
		if card.position < 0: return "旧章节卡牌超过当前开放席位或棋盘容量，原存档已保留，未移除卡牌。"
		if card.health <= 0:
			var definition: Dictionary = catalog.assembly.definition(build, card, 0, AdventureBattleRules.assembly_options(build.core().id))
			if definition.is_empty(): return catalog.assembly.error
			card.health = CombatAttributes.max_health(definition)
	return build.validate_board()

## 保存明确错误且不产生可被误用的部分构筑。
func _fail(message: String) -> RefCounted:
	error = message
	return null
