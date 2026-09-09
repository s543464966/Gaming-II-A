class_name AdventureProgression
extends RefCounted
## 冒险用例编排：进度、体力、构筑和账号生命镜像在同一事务内提交。

const T = preload("res://features/mechanics/contracts/combat_types.gd")
const C = preload("res://game_content/runtime/content_types.gd")
const Generator = preload("res://features/game_modes_pve_adventure/domain/route_generator.gd")
const Route = preload("res://features/game_modes_pve_adventure/domain/route_state.gd")
const Placement = preload("res://features/game_modes_pve_adventure/domain/deployment_placement.gd")
enum BattlePhase { Idle, Deployment, Computing, Ready, Settled, StartRejected, Interrupted }
var session: PlayerSessionState
var persist: Callable
var clock: Callable
var battle_phase: BattlePhase:
	get: return _battle_phase
var _battle_phase: BattlePhase = BattlePhase.Idle
var battle_result: Dictionary:
	get: return _simulation.result if battle_phase in [BattlePhase.Ready, BattlePhase.Settled] else {}
var _simulation: CombatSimulator
var _battle_chapter: String = ""
var _battle_index: int = -1
var _battle_cost: int = 0
## 准备阶段可计算同一场输入；正式开战前不提交遗物消耗或交付战报。
var _prepared: bool = false
var _preparation_error: String = ""
var _start_consumed: Array = []

## 注入当前会话和真实保存回调。
func _init(player: PlayerSessionState, save: Callable, time_source: Callable = Callable(), simulation: CombatSimulator = null) -> void:
	session = player
	persist = save
	clock = time_source
	_simulation = simulation if simulation != null else CombatSimulator.new()

## 冒险奖励可取得公共卡牌与遗物，但章节背景只准备当前章；下载前不生成路线或扣体力。
func required_resource_keys() -> Array[String]:
	var records: Array = []
	for table: String in ["cards", "relics", "items", "reward_dice", "aurora_rewards", "main_abilities", "innate_abilities", "talents", "synergies"]:
		records.append(session.content.data.get(table, []))
	records.append(session.content.get_record("chapters", session.selected_chapter))
	return session.content.resource_keys(records)

## 进入塔前只生成缺失路线，并持久保存完整敌方坐标。
func ensure_started(seed: int) -> String:
	return session.transact(func():
		var route: RouteState = session.current_route()
		if route == null: return "当前章节不存在。"
		if route.nodes.is_empty():
			var generator = Generator.new()
			var nodes = generator.generate(session.content, session.content.get_record("chapters", session.selected_chapter), seed)
			if not generator.error.is_empty(): return generator.error
			route.nodes = nodes
			route.seed = seed
		if not session.build.started:
			var hero: String = session.collection.selected_hero
			if session.collection.cards[hero].health_ratio <= 0: return "英雄生命为零，无法开始章节。"
			var growth: Dictionary = session.collection.growth_snapshot()
			var definition: Dictionary = session.collection.definition(hero)
			var error: String = session.build.start(definition, session.collection.current_health(hero), session.collection.hero_position, growth, session.talents.learned)
			if not error.is_empty(): return error
			return _starting_companion()
		return "", persist)

## 确认章节是显式动作，浏览不会改变实际挑战章节。
func select_chapter(id: String) -> String:
	if _has_active_battle(): return "请先结束当前战斗。"
	return session.transact(func():
		if not id in session.unlocked: return "章节尚未解锁。"
		if id != session.selected_chapter:
			session.selected_chapter = id
			session.build.clear()
		return "", persist)

## Home 确认换英雄时保留本章路线，但清空本次构筑和进度。
func change_hero(id: String) -> String:
	if _has_active_battle(): return "请先结束当前战斗。"
	if id == session.collection.selected_hero: return ""
	return session.transact(func():
		var error: String = session.collection.select(id, session.collection.hero_position)
		if not error.is_empty(): return error
		session.build.clear()
		session.current_route().restart_progress()
		return "", persist)

## 进入战斗正式扣体力并提交进行中节点；尚不执行模拟。
func begin_battle(index: int, now: int) -> String:
	if _has_active_battle(): return "当前战斗尚未结束。"
	var error: String = session.transact(func():
		if session.build.pending_reward: return "必须先完成战后构筑。"
		var route: RouteState = session.current_route()
		if not index in route.candidates() or not Generator.is_battle(route.nodes[index].type): return "目标不是可进入的战斗节点。"
		var placement_error: String = _relocate_overlaps(route.nodes[index])
		if not placement_error.is_empty(): return placement_error
		if not session.user.spend(route.nodes[index].stamina, now): return "体力不足。"
		return route.begin(index), persist)
	if error.is_empty():
		_clear_preparation()
		_battle_chapter = session.selected_chapter
		_battle_index = index
		_battle_cost = session.current_route().nodes[index].stamina
		_battle_phase = BattlePhase.Deployment
	return error

## 迁移与进入、扣体力共用事务；所有候选成功后一次写入，失败恢复原站位。
func _relocate_overlaps(node: Dictionary) -> String:
	var error: String = session.build.validate_board()
	if not error.is_empty(): return error
	var result: Dictionary = Placement.resolve(session.build.cards, _enemy_footprints(node))
	if not result.error.is_empty(): return result.error
	for card in session.build.cards:
		if result.positions.has(card.id): card.position = result.positions[card.id]
	if result.positions.has(session.build.core().id): session.collection.hero_position = session.build.core().position
	return ""

## 固定怪物尺寸只读内容记录，入场避让和停留校验无需装配整套能力。
func _enemy_footprints(node: Dictionary) -> Array:
	var enemies: Array = []
	for enemy in AdventureBattleRequest.enemies_for(node):
		var record: Dictionary = session.content.get_record("cards", enemy.card_id)
		enemies.append({"position": enemy.position, "width": record.footprint_width, "height": record.footprint_height})
	return enemies

## 用准备阶段的空闲帧计算同一个内核，结果在正式开战前保持私有。
func prepare_battle(budget_usec: int = 4000) -> void:
	if battle_phase != BattlePhase.Deployment or not _matches_battle(): return
	if not _prepare_input().is_empty(): return
	if _simulation.running: _simulation.advance(budget_usec)

## 输入只装配一次；每次合法站位变更会撤销本次预计算。
func _prepare_input() -> String:
	if _prepared: return _preparation_error
	_prepared = true
	var factory = AdventureBattleRequest.new()
	var route: RouteState = session.current_route()
	var request: Dictionary = factory.create(session.build, AdventureBattleRequest.enemies_for(route.nodes[_battle_index]), session.adventure,
		AdventureBattleRequest.seed_for(_battle_chapter, _battle_index), session.content.get_record("chapters", _battle_chapter))
	_preparation_error = factory.error
	if not request.is_empty(): _preparation_error = "\n".join(_simulation.begin(request))
	if request.is_empty() and _preparation_error.is_empty(): _preparation_error = "战斗输入为空。"
	if _preparation_error.is_empty(): _start_consumed = _simulation.consumed_source_ids().duplicate()
	return _preparation_error

## 正式开战复用已算结果；一次性遗物仍仅在这个入口成功保存后消耗。
func start_battle() -> String:
	if battle_phase != BattlePhase.Deployment or not _matches_battle(): return "当前不处于战斗部署阶段。"
	var error: String = _prepare_input()
	if not error.is_empty():
		_battle_phase = BattlePhase.StartRejected
		return error
	# 当前一次性遗物在开战时触发，正式开始前持久提交，失败或中断不返还。
	if not _start_consumed.is_empty():
		error = session.transact(func(): return RelicMechanic.consume(session.build.relics, _start_consumed), persist)
		if not error.is_empty():
			_simulation.cancel()
			_battle_phase = BattlePhase.StartRejected
			return error
	_battle_phase = BattlePhase.Computing if _simulation.running else BattlePhase.Ready
	return ""

## 站位变化或离场释放唯一模拟任务，旧结果不能用于新的部署。
func _clear_preparation() -> void:
	_simulation.cancel()
	_prepared = false
	_preparation_error = ""
	_start_consumed = []

## 渲染帧只提供计算预算；推进的固定战斗时间不由帧率决定。
func advance_battle(budget_usec: int = 4000) -> bool:
	if battle_phase != BattlePhase.Computing: return _battle_phase == BattlePhase.Ready
	if not _matches_battle():
		interrupt_battle()
		return false
	if _simulation.advance(budget_usec): _battle_phase = BattlePhase.Ready
	return _battle_phase == BattlePhase.Ready

## 离场取消只释放瞬态计算，不伪造存档成功；持久中断仍由恢复入口处理。
func interrupt_battle() -> void:
	_clear_preparation()
	if _has_active_battle(): _battle_phase = BattlePhase.Interrupted

## 仅本次正式进入的同章同节点能继续部署、计算或结算。
func _matches_battle() -> bool:
	var route: RouteState = session.current_route()
	return session.selected_chapter == _battle_chapter and route != null and route.current == _battle_index and route.phase == Route.Phase.NodeInProgress

## 进行中存档与瞬态阶段共同防止切章、换英雄或重复创建计算。
func _has_active_battle() -> bool:
	var route: RouteState = session.current_route()
	return route != null and route.phase == Route.Phase.NodeInProgress

## 合法站位在保存后成为权威落点；怪物冲突由部署阶段暂停提示。
func place_card(id: String, position: int) -> String:
	if battle_phase != BattlePhase.Deployment or not _matches_battle(): return "只有战斗部署阶段可以调整站位。"
	var result: String = session.transact(func():
		var error: String = session.build.place(id, position)
		if error.is_empty() and session.build.core().id == id: session.collection.hero_position = position
		return error, persist)
	if result.is_empty(): _clear_preparation()
	return result

## 停留反馈只查询当前合法性，不移动卡牌或写盘。
func can_swap_cards(first_id: String, second_id: String) -> bool:
	return _swap_candidate(first_id, second_id).error.is_empty()

## 两张卡同时落位并只保存一次；失败由会话恢复全部站位和英雄镜像。
func swap_cards(first_id: String, second_id: String) -> String:
	var candidate: Dictionary = _swap_candidate(first_id, second_id)
	if not candidate.error.is_empty(): return candidate.error
	var result: String = session.transact(func():
		for card in session.build.cards:
			if candidate.positions.has(card.id): card.position = candidate.positions[card.id]
		var error: String = session.build.validate_board()
		if error.is_empty(): session.collection.hero_position = session.build.core().position
		return error, persist)
	if result.is_empty(): _clear_preparation()
	return result

## 松手与预览共用同一模式校验，拒绝敌方身份和战斗后的迟到交换。
func _swap_candidate(first_id: String, second_id: String) -> Dictionary:
	if battle_phase != BattlePhase.Deployment or not _matches_battle():
		return {"error": "只有战斗部署阶段可以对调卡牌。", "positions": {}}
	return Placement.swap_positions(session.build.cards, _enemy_footprints(session.current_route().nodes[_battle_index]), first_id, second_id)

## 主动放弃释放节点并让全队回满，不退体力、不推进路线或发奖。
func abandon() -> String:
	var result: String = session.transact(func():
		var error: String = session.current_route().abandon()
		if not error.is_empty(): return error
		error = session.build.restore_full_health(session.adventure)
		if error.is_empty(): _sync_hero()
		return error, persist)
	if result.is_empty():
		_clear_preparation()
		_battle_phase = BattlePhase.Idle
	return result

## 系统启动失败才退还本次体力；回退写盘失败保留原进行中状态供重试。
func reject_battle_start() -> String:
	if battle_phase != BattlePhase.StartRejected or not _matches_battle(): return "启动回退请求已失效。"
	var error: String = _refund_failed_start()
	if error.is_empty():
		_clear_preparation()
		_battle_phase = BattlePhase.Idle
	return error

## 回退额度来自本次已支付入口，不接受调用方传入金额或节点。
func _refund_failed_start() -> String:
	return session.transact(func():
		var route: RouteState = session.current_route()
		if not _matches_battle(): return "启动回退请求已失效。"
		var error: String = route.abandon()
		if error.is_empty(): session.user.stamina = mini(session.user.STAMINA_MAX, session.user.stamina + _battle_cost)
		return error, persist)

## 骰子、账号入账与强化消费在同一保存事务内完成。
func reward_command(action: String, index: int = -1, id: String = "", target: String = "") -> String:
	if not action in ["reroll", "open", "refresh", "highlight", "choose", "timeout", "aurora", "complete"]: return "当前页面不支持此构筑操作。"
	return session.transact(func():
		var build: RunBuild = session.build
		if not build.pending_reward: return "当前没有待处理战后构筑。"
		if is_aurora_node() and not action in ["aurora", "complete"]: return "星辉遗迹只提供星能选择。"
		var payouts: Array = []
		var now = current_time()
		var error = ""
		if build.rewards.expired(now):
			error = _settle_timeout(now, payouts)
		else:
			match action:
				"reroll": error = build.rewards.reroll(session.adventure, build, session.collection, payouts)
				"open": error = build.rewards.open(index, now, session.adventure, build, session.collection)
				"refresh": error = build.rewards.refresh(index, now, session.adventure, build, session.collection)
				"highlight": error = build.rewards.highlight(index, now)
				"choose": error = build.rewards.claim(index, now, payouts)
				"timeout": return "选择时间尚未结束。"
				"aurora": error = _receive_aurora(id, target)
				"complete": error = build.complete_reward()
				_: return "未知构筑操作。"
		if not error.is_empty(): return error
		for reward in payouts:
			error = _receive(reward)
			if not error.is_empty(): return error
		return _roll_new_dice() if build.pending_reward and not is_aurora_node() else "", persist)

## 由当前路线推导遗迹奖励形态，不另存一份页面状态。
func is_aurora_node() -> bool:
	var route: RouteState = session.current_route()
	return route != null and route.current >= 0 and route.nodes[route.current].type == C.NodeType.Relic

## 恢复旧奖励时只投尚未出结果的骰子，已有结果和活动选择保持不变。
func prepare_rewards() -> String:
	if not session.build.pending_reward: return "当前没有待处理战后构筑。"
	if is_aurora_node(): return ""
	if not session.build.rewards.choice.is_empty() or not session.build.rewards.dice.any(func(die): return die.status == RewardDice.Status.Unrolled): return ""
	return session.transact(_roll_new_dice, persist)

## 自动投掷与直接奖励共用外层事务，失败时一起恢复骰子和账号余额。
func _roll_new_dice() -> String:
	var build: RunBuild = session.build
	if not build.rewards.choice.is_empty() or not build.rewards.dice.any(func(die): return die.status == RewardDice.Status.Unrolled): return ""
	var payouts: Array = []
	var error: String = build.rewards.roll(session.adventure, build, session.collection, payouts)
	if not error.is_empty(): return error
	for reward in payouts:
		error = _receive(reward)
		if not error.is_empty(): return error
	return ""

## 界面和事务使用同一个可注入时钟，重进页面不会得到新的十五秒。
func current_time() -> float:
	return float(clock.call()) if clock.is_valid() else Time.get_unix_time_from_system()

## 超时优先确认有效高亮项，失效时选择第一项仍合法的候选。
func _settle_timeout(now: float, payouts: Array) -> String:
	var choice: Dictionary = session.build.rewards.choice
	var selected: int = choice.highlight
	if selected < 0 or not session.build.can_receive(choice.candidates[selected], session.adventure, session.collection).is_empty():
		selected = -1
		for index in range(choice.candidates.size()):
			if session.build.can_receive(choice.candidates[index], session.adventure, session.collection).is_empty():
				selected = index
				break
	if selected < 0: return "当前候选均已失效，奖励未消费，请检查内容配置。"
	return session.build.rewards.claim(selected, now, payouts, true)

## 永久奖励只交给账号资产，章节奖励只交给本次构筑。
func _receive(reward: Dictionary) -> String:
	var error: String = session.build.can_receive(reward, session.adventure, session.collection)
	if not error.is_empty(): return error
	match reward.kind:
		C.DiceReward.StarStone:
			return "" if session.assets.grant(C.Currency.StarStone, reward.amount) else "星石入账失败。"
		C.DiceReward.Fragment:
			return "" if session.assets.add_item(reward.content_id, reward.amount) else "专属碎片入账失败。"
	return session.build.receive(reward, session.adventure, session.collection)

## 星能领取与账号资产、指定卡牌强化或章节遗物在同一会话事务中提交。
func _receive_aurora(id: String, target: String) -> String:
	var rewards: AuroraRewards = session.build.aurora_rewards
	var offer: Dictionary = rewards.available(id)
	if offer.is_empty(): return "该星能奖励不可领取。"
	var row: Dictionary = session.content.get_record("aurora_rewards", id)
	var error: String = ""
	match row.aurora_reward_kind:
		C.AuroraReward.StarStone, C.AuroraReward.Gold:
			var currency: int = C.Currency.StarStone if row.aurora_reward_kind == C.AuroraReward.StarStone else C.Currency.Gold
			if not session.assets.grant(currency, offer.amount): return "星能货币奖励入账失败。"
		C.AuroraReward.MinionFragments, C.AuroraReward.RelicFragments, C.AuroraReward.HeroFragment:
			for item_id: String in offer.content_ids:
				if not session.assets.add_item(item_id, offer.amount): return "星能碎片奖励入账失败。"
		C.AuroraReward.Stamina:
			if not session.user.grant_stamina(offer.amount, int(current_time())): return "星能体力奖励入账失败。"
		C.AuroraReward.CardUpgrade:
			error = session.build.upgrade_card(target, session.adventure)
		C.AuroraReward.Relic:
			error = session.build.receive({"kind": C.DiceReward.Relic, "content_id": offer.content_ids[0], "pool_id": id, "amount": 1}, session.adventure, session.collection)
		_: return "星能奖励类别未实现。"
	if not error.is_empty(): return error
	return rewards.claim(id)

## 胜利原子结算生命、污染、骰子和强制星能候选；失败仅释放节点。
func resolve_battle() -> String:
	if battle_phase != BattlePhase.Ready or not _matches_battle(): return "当前没有已完成且待结算的战斗。"
	var error: String = _apply_battle_result(_simulation.result)
	if error.is_empty(): _battle_phase = BattlePhase.Settled
	return error

## 结算事务与表现无关；单元测试可独立覆盖保存失败、奖励及生命映射。
func _apply_battle_result(result: Dictionary) -> String:
	if result.get("reason") not in [T.Completion.Victory, T.Completion.Defeat, T.Completion.Timeout, T.Completion.Draw]: return "战斗结果不可结算。"
	return session.transact(func():
		var route: RouteState = session.current_route()
		if route.phase != Route.Phase.NodeInProgress: return "当前没有待结算战斗。"
		if result.get("reason") != T.Completion.Victory:
			_sync_hero()
			return route.resolve(false)
		var node: Dictionary = route.nodes[route.current]
		var error: String = session.build.apply_victory(result, session.adventure)
		if not error.is_empty(): return error
		var reward_seed: int = (int(result.seed) * 31 + session.build.rewards.roll_index + 1) & 0xffffffff
		var dice_rules: Dictionary = session.content.data.dice_reward_rules[0]
		var treasure: int = dice_rules.elite_treasure_dice_count if node.type == Generator.Type.EliteBattle else 0
		if node.reward_dice < treasure: return "节点骰子总数小于精英保底数量。"
		session.build.rewards.grant(node.reward_dice, treasure, reward_seed)
		error = session.build.begin_reward(reward_seed)
		if not error.is_empty(): return error
		if node.type == Generator.Type.EliteBattle:
			error = session.build.aurora_rewards.begin(reward_seed ^ 0x51F15E, session.adventure, session.build)
			if not error.is_empty(): return error
		error = _roll_new_dice()
		if not error.is_empty(): return error
		_sync_hero()
		error = route.resolve(true)
		if error.is_empty():
			session.build.rewards.rerolls = session.content.data.dice_reward_rules[0].rerolls_per_node
			error = _unlock_next()
		return error, persist)

## 遗迹直接进入奖励；黑市与奇遇保存活动事件，等待页面逐项操作或离开。
func execute_node(index: int) -> String:
	return session.transact(func():
		var route: RouteState = session.current_route()
		if session.build.pending_reward or not index in route.candidates(): return "当前节点不可执行。"
		var node: Dictionary = route.nodes[index]
		if Generator.is_battle(node.type): return "战斗节点不能作为事件执行。"
		var rule: Dictionary = session.content.node_definition(node)
		if rule.is_empty(): return "节点缺少静态效果规则。"
		var error: String = route.begin(index)
		if not error.is_empty(): return error
		match int(rule.effect_type):
			C.NodeEffect.AuroraChoice:
				var reward_seed: int = (route.seed * 31 + index + 1) & 0xffffffff
				error = session.build.begin_reward(reward_seed)
				if not error.is_empty(): return error
				error = session.build.aurora_rewards.begin(reward_seed ^ 0x51F15E, session.adventure, session.build)
				if not error.is_empty(): return error
			C.NodeEffect.BlackMarket, C.NodeEffect.Encounter:
				var event_seed: int = (route.seed * 31 + index * 131 + session.build.rewards.roll_index + 1) & 0xffffffff
				error = session.build.events.begin(index, node.type, event_seed, session.adventure, session.build)
				return error
			_: return "节点效果未实现。"
		error = route.resolve(true)
		if error.is_empty():
			error = _unlock_next()
		return error, persist)

## 恢复页面前核对活动事件与当前进行中节点完全一致。
func has_active_event() -> bool:
	var route: RouteState = session.current_route()
	return route != null and route.phase == Route.Phase.NodeInProgress and session.build.events.is_active() and route.current == session.build.events.node_index and route.nodes[route.current].type == session.build.events.node_type

## 黑市项目各自只结算一次；碎片和体力可任选金币或星石支付。
func market_purchase(id: String, payment: int = -1) -> String:
	return session.transact(func():
		if not has_active_event() or session.build.events.node_type != C.NodeType.BlackMarket: return "当前不在流动黑市。"
		var action: Dictionary = session.build.events.available_market_action(id)
		if action.is_empty(): return "该项目已经完成或不存在。"
		var error: String = ""
		match int(action.kind):
			AdventureEvents.MarketKind.Fragment, AdventureEvents.MarketKind.Stamina:
				if payment not in [C.Currency.Gold, C.Currency.StarStone]: return "请选择金币或星石支付。"
				var price: int = action.gold_price if payment == C.Currency.Gold else action.stone_price
				if not session.assets.spend(payment, price): return "账号货币不足。"
				if action.kind == AdventureEvents.MarketKind.Fragment:
					if not session.assets.add_item(action.content_id, action.amount): return "碎片商品交付失败。"
				elif not session.user.grant_stamina(action.amount, int(current_time())): return "体力商品交付失败。"
			AdventureEvents.MarketKind.Exchange:
				if not session.assets.spend(action.cost_currency, action.cost_amount): return "账号货币不足。"
				if not session.assets.grant(action.reward_currency, action.reward_amount): return "货币兑换交付失败。"
			_: return "黑市项目类别无效。"
		error = session.build.events.mark_purchased(id)
		return error, persist)

## 页面离开前可据此提示尚有未购买项目，但不强迫玩家消费。
func market_has_unpurchased() -> bool:
	if not has_active_event() or session.build.events.node_type != C.NodeType.BlackMarket: return false
	return session.build.events.market.actions.any(func(action): return not action.purchased)

## 奇遇刷新只替换一次锁定组合，不结算被放弃的收获或代价。
func refresh_encounter() -> String:
	return session.transact(func():
		if not has_active_event() or session.build.events.node_type != C.NodeType.Adventure: return "当前不在旅途奇遇。"
		return session.build.events.refresh_encounter(session.adventure, session.build), persist)

## 需要腾出位置时列出可替换的非英雄实例，并预先计入锁定卡牌代价可能释放的位置。
func encounter_replacement_candidates() -> Array:
	if not has_active_event() or session.build.events.node_type != C.NodeType.Adventure: return []
	var pair: Dictionary = session.build.events.encounter
	if pair.reward.kind != C.EncounterReward.Card: return []
	var definition: Dictionary = session.adventure.assembly.base_definition(pair.reward.content_id)
	if session.build.can_add_card(definition): return []
	var cost_target: String = pair.cost.target_id if pair.cost.kind == C.EncounterCost.Card else ""
	var locked: Dictionary = session.build.find_card(cost_target)
	var projected_removals: Array = [cost_target] if not locked.is_empty() and locked.copies == 1 else []
	if session.build.can_add_after_removing(definition, projected_removals): return []
	return session.build.cards.filter(func(card): return card.kind in [CardTypes.Kind.Minion, CardTypes.Kind.ItemCard] and session.build.can_add_after_removing(definition, projected_removals + [card.id]))

## 接受时先结算锁定代价，再发放收获；体力不足时保持原组合供刷新或离开。
func accept_encounter(replacement_id: String = "") -> String:
	return session.transact(func():
		if not has_active_event() or session.build.events.node_type != C.NodeType.Adventure: return "当前不在旅途奇遇。"
		var pair: Dictionary = session.build.events.encounter
		var candidates: Array = encounter_replacement_candidates()
		if not candidates.is_empty() and (replacement_id.is_empty() or not candidates.any(func(card): return card.id == replacement_id)): return "请选择一张非英雄卡牌替换。"
		var error: String = _apply_encounter_cost(pair.cost)
		if not error.is_empty(): return error
		if pair.reward.kind == C.EncounterReward.Card:
			var definition: Dictionary = session.adventure.assembly.base_definition(pair.reward.content_id)
			if not session.build.can_add_card(definition):
				error = session.build.replace_event_card(replacement_id)
				if not error.is_empty(): return error
		error = _apply_encounter_reward(pair.reward)
		if not error.is_empty(): return error
		session.build.events.clear()
		error = session.current_route().resolve(true)
		if error.is_empty(): error = _unlock_next()
		return error, persist)

## 代价目标为空代表无操作，不能改扣英雄、其他卡牌或其他骰子。
func _apply_encounter_cost(cost: Dictionary) -> String:
	match int(cost.kind):
		C.EncounterCost.Stamina:
			return "" if session.user.spend(cost.amount, int(current_time())) else "体力不足，无法接受这次奇遇。"
		C.EncounterCost.TeamDebuff:
			return session.build.add_event_debuff(cost.stat, cost.amount)
		C.EncounterCost.Card:
			return session.build.remove_event_card(cost.target_id, session.adventure)
		C.EncounterCost.Dice:
			return session.build.rewards.remove_unused(int(cost.target_id) if cost.target_id.is_valid_int() else -1)
	return "奇遇代价类别无效。"

## 收获在同一事务发放；额外骰子立即进入无倒计时的正常奖励流程。
func _apply_encounter_reward(reward: Dictionary) -> String:
	match int(reward.kind):
		C.EncounterReward.Dice:
			var reward_seed: int = (session.build.events.seed ^ 0x34A71C) & 0xffffffff
			session.build.rewards.grant_extra(reward_seed)
			var error: String = session.build.begin_reward(reward_seed)
			return error if not error.is_empty() else _roll_new_dice()
		C.EncounterReward.StarStone:
			return "" if session.assets.grant(C.Currency.StarStone, reward.amount) else "奇遇星石入账失败。"
		C.EncounterReward.Relic:
			var pools: Array = session.content.data.dice_reward_pools.filter(func(pool): return pool.reward_kind == C.DiceReward.Relic)
			if pools.is_empty(): return "奇遇遗物缺少正式奖励来源。"
			return session.build.receive({"pool_id": pools[0].id, "kind": C.DiceReward.Relic, "content_id": reward.content_id, "amount": 1}, session.adventure, session.collection)
		C.EncounterReward.Card:
			return session.build.receive_event_card(reward.content_id, session.adventure, session.collection)
	return "奇遇收获类别无效。"

## 主动离开只放弃当前事件内容，已提交的黑市购买保持有效并推进路线。
func leave_event() -> String:
	return session.transact(func():
		if not has_active_event(): return "当前没有可离开的事件。"
		session.build.events.clear()
		var error: String = session.current_route().resolve(true)
		if error.is_empty(): error = _unlock_next()
		return error, persist)

## 只把生命比例映射回账号永久上限，章节加成不泄漏到收藏基础数值。
func _sync_hero() -> void:
	var core: Dictionary = session.build.core()
	if core.is_empty(): return
	var definition: Dictionary = session.adventure.assembly.definition(session.build, core, 0, AdventureBattleRules.assembly_options(core.id))
	if definition.is_empty(): return
	var maximum = CombatAttributes.max_health(definition)
	session.collection.cards[session.collection.selected_hero].health_ratio = clampf(core.health / maximum, 0, 1)

## 章节首通发一点永久天赋，同一胜利事务解锁下一章；末章也发奖。
func _unlock_next() -> String:
	if not session.current_route().completed: return ""
	var message: String = session.talents.award_chapter(session.selected_chapter)
	if not message.is_empty(): return message
	var chapters: Array = session.normal_chapters()
	for i in range(chapters.size() - 1):
		if chapters[i].id == session.selected_chapter and not chapters[i + 1].id in session.unlocked:
			session.unlocked.append(chapters[i + 1].id)
			break
	return ""

## 同基准英雄开章搭配一名已拥有的输出随从，队伍成长从首战开始。
func _starting_companion() -> String:
	var candidates: Array = session.content.data.cards.filter(func(row): return row.card_kind == CardTypes.Kind.Minion and row.output_type in [CombatTypes.Output.Physical, CombatTypes.Output.Witchcraft, CombatTypes.Output.Burn, CombatTypes.Output.Poison] and session.collection.owns(row.id))
	candidates.sort_custom(func(a, b): return a.output_type < b.output_type if a.output_type != b.output_type else a.sort_order < b.sort_order)
	if candidates.is_empty(): return "开章需要一名已解锁的输出随从。"
	var pools: Array = session.content.data.dice_reward_pools.filter(func(pool): return pool.reward_kind == C.DiceReward.Minion)
	if pools.is_empty(): return "开章随从缺少正式奖励来源。"
	var error: String = session.build.receive({"pool_id": pools[0].id, "kind": C.DiceReward.Minion, "content_id": candidates[0].id, "amount": 1}, session.adventure, session.collection)
	if not error.is_empty(): return error
	var companion: Dictionary = session.build.cards.back()
	companion.position = -1
	companion.position = session.build.reward_position(session.adventure.assembly.base_definition(companion.definition_id), session.build.core().position)
	return session.build.validate_board()
