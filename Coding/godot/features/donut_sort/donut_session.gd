class_name DonutSession
extends RefCounted
## 拥有盒位、逐盒备货与需求状态，原子结算搬运、回收、机关和本关奖励。

signal changed(events: Array)

var slots: Array = []
var demands: Array = []
var completed: int = 0
var moves: int = 0
var tools: Dictionary = {}
var coins: int = 0
var diamonds: int = 0
var last_combo: int = 0
var best_combo: int = 0
var started: bool = false
var level_index: int = 0
var title: String = ""
var _definition: Dictionary = {}
var _stock_cursor: int = 0
var _next_box_id: int = 0
var _history: DonutUndoHistory = DonutUndoHistory.new()


## 正常启动读取内容目录；验证可显式注入独立定义而不修改运行配置。
func _init(definition: Dictionary = {}) -> void:
	if definition.is_empty():
		_definition = DonutLevel.load_definition(DonutLevel.catalog()[0].path)
	else:
		_definition = definition.duplicate(true)
	_prepare()


## 切换内容目录中的关卡，清除上一关事务与奖励后重新入场。
func load_level(index: int) -> bool:
	var levels: Array = DonutLevel.catalog()
	if index < 0 or index >= levels.size():
		return false
	var next: Dictionary = DonutLevel.load_definition(levels[index].path)
	if next.is_empty():
		return false
	_definition = next
	level_index = index
	restart()
	return true


## 首次进入页面时开始营业，开局自动匹配同样使用正式回收流程。
func begin() -> void:
	if started or _definition.is_empty():
		return
	started = true
	var events: Array = []
	_event(events, "begin")
	_settle(events)
	_award_combo(completed, events)
	changed.emit(events)


## 重开完整关卡，不保留可刷取的奖励或上次隐藏信息。
func restart() -> void:
	_prepare()
	begin()


## 将关卡静态定义转换为本会话独立的盒子与需求实例。
func _prepare() -> void:
	slots = []
	demands = []
	completed = 0
	moves = 0
	coins = 0
	diamonds = 0
	last_combo = 0
	best_combo = 0
	_stock_cursor = 0
	_next_box_id = 0
	started = false
	_history.clear()
	if _definition.is_empty():
		return
	title = _definition.get("title", "甜甜圈小铺")
	tools = _definition.tools.duplicate(true)
	for key: String in tools:
		tools[key] = int(tools[key])
	for entry: Dictionary in _definition.slots:
		var threshold: int = int(entry.get("unlock_after", 0))
		slots.append({"kind": entry.kind, "unlock_after": threshold, "open": threshold == 0,
			"box": _make_box(entry.box) if entry.get("box") != null else null})
	demands = DonutOrderRules.create_positions(_definition.demands)
	for index: int in slots.size():
		_reveal_top(index)


## 按单盒配置初始化明暗，新盒不继承同一盒位旧盒的隐藏层或机关效果。
func _make_box(definition: Dictionary) -> Dictionary:
	_next_box_id += 1
	var hidden_layers: bool = definition.get("hidden_layers", false)
	var items: Array = []
	for item: Dictionary in definition.items:
		items.append({"flavor": int(item.flavor), "revealed": not hidden_layers})
	return {"id": _next_box_id, "kind": definition.get("kind", "normal"),
		"lid": int(definition.get("lid", 0)), "frozen": definition.get("kind", "normal") == "frozen", "items": items}


## 返回本关全部需求数，包含锁定位置及各位置的后续需求。
func total_orders() -> int:
	return DonutOrderRules.total_orders(demands)


## 返回尚未入场的整盒数，界面明确使用“盒”为单位。
func remaining_stock() -> int:
	return _definition.get("stock", []).size() - _stock_cursor


## 返回本关食物数量，供关卡验收与数量守恒检查使用。
func total_donuts() -> int:
	var total: int = 0
	for slot: Dictionary in _definition.slots:
		if slot.get("box") != null:
			total += slot.box.items.size()
	for box: Dictionary in _definition.stock:
		total += box.items.size()
	return total


## 统计在场和备货中的剩余食物，锁定位置也不能被遗漏。
func remaining_donuts() -> int:
	var total: int = 0
	for slot: Dictionary in slots:
		if slot.box != null:
			total += slot.box.items.size()
	for index: int in range(_stock_cursor, _definition.stock.size()):
		total += _definition.stock[index].items.size()
	return total


## 全部需求完成且备货和场上食物都已处理后才允许通关。
func is_won() -> bool:
	return started and completed == total_orders() and remaining_stock() == 0 and remaining_donuts() == 0


## 单颗暂存容量为一，其余盒子容量为四。
func capacity(index: int) -> int:
	return DonutMoveRules.capacity(slots, index)


## 判断实际容器存在且限制已解除，空盒位与锁定盒均不允许取放。
func can_handle(index: int) -> bool:
	return DonutMoveRules.can_handle(slots, index)


## 仅允许从可操作餐盒的明牌顶层开始拿取。
func can_pick_top(source: int) -> bool:
	return DonutMoveRules.can_pick_top(slots, started, is_won(), source)


## 返回操作开始时可一起拿起的连续同味明牌数量。
func pick_count(source: int) -> int:
	return DonutMoveRules.pick_count(slots, started, is_won(), source)


## 返回连续同味组中目标容量允许接收的实际数量。
func move_count(source: int, target: int) -> int:
	return DonutMoveRules.move_count(slots, started, is_won(), source, target)


## 为界面提供与正式执行完全一致的目标合法性判断。
func can_move(source: int, target: int) -> bool:
	return move_count(source, target) > 0


## 整组搬运只记一步和一次撤回，移完才揭示露顶食物并结算回收。
func move(source: int, target: int) -> bool:
	var count: int = move_count(source, target)
	if count == 0:
		return false
	_remember()
	var before: int = completed
	var moving: Array = slots[source].box.items.slice(0, count)
	slots[source].box.items = slots[source].box.items.slice(count)
	slots[target].box.items = moving + slots[target].box.items
	moves += 1
	last_combo = 0
	var events: Array = []
	_event(events, "move", {"source": source, "target": target, "items": moving, "count": count})
	if _reveal_top(source):
		_event(events, "reveal", {"index": source})
	_settle(events)
	_award_combo(completed - before, events)
	changed.emit(events)
	return true


## 返回下一个可由加餐盒道具启用的周转盒位。
func next_turnover() -> int:
	return DonutAddBoxRules.next_turnover(slots)


## 道具只解锁固定棋盘内的周转盒，并创建一个空盒，不消耗备货。
func add_box() -> bool:
	var index: int = next_turnover()
	if not started or is_won() or index < 0 or int(tools.add_box) <= 0:
		return false
	_remember()
	tools.add_box -= 1
	slots[index].open = true
	slots[index].box = _make_box({"items": []})
	last_combo = 0
	var events: Array = []
	_event(events, "unlock", {"index": index})
	changed.emit(events)
	return true


## 置顶可选已知下层或盲选未揭示下层，不提前显示未知口味。
func can_bring_to_top(index: int, item_index: int) -> bool:
	if not started or is_won() or not can_handle(index) or int(tools.top) <= 0:
		return false
	return DonutTopRules.can_reorder(slots[index].box.items, item_index)


## 置顶与后续回收形成同一可撤回事务，仅在选中层露顶后揭示。
func bring_to_top(index: int, item_index: int) -> bool:
	if not can_bring_to_top(index, item_index):
		return false
	_remember()
	var before: int = completed
	DonutTopRules.bring_to_top(slots[index].box.items, item_index)
	_reveal_top(index)
	tools.top -= 1
	last_combo = 0
	var events: Array = []
	_event(events, "top", {"index": index})
	_settle(events)
	_award_combo(completed - before, events)
	changed.emit(events)
	return true


## 返回某需求位置当前口味；锁定或耗尽均返回负一，防止隐藏需求泄露。
func demand_flavor(index: int) -> int:
	return DonutOrderRules.demand_flavor(demands, index)


## 预留显式解锁入口；资格由未来调用方判定，开放及后续回收作为一次可撤回事务。
func unlock_order_slot(index: int) -> bool:
	if not started or is_won() or index < 0 or index >= demands.size() or demands[index].open:
		return false
	_remember()
	DonutOrderRules.unlock_position(demands, index)
	var before: int = completed
	last_combo = 0
	var events: Array = []
	_event(events, "demand_unlock", {"index": index})
	_settle(events)
	_award_combo(completed - before, events)
	changed.emit(events)
	return true


## 判断凑齐但无需求的等待状态，不据此额外限制取放。
func is_waiting(index: int) -> bool:
	if not DonutDispatchRules.packable(slots, index):
		return false
	return DonutOrderRules.matching_demand(demands, int(slots[index].box.items[0].flavor)) < 0


## 在确定的盒位顺序中逐次回收，每次都先影响旧盒，再原位补入一个新盒。
func _settle(events: Array) -> void:
	while true:
		var match: Vector2i = DonutDispatchRules.next_match(slots, demands)
		if match.x < 0:
			_return_spare_boxes(events)
			return
		var match_index: int = match.x
		var demand_index: int = match.y
		var parcel: Dictionary = slots[match_index].box.duplicate(true)
		slots[match_index].box = null
		demands[demand_index].cursor += 1
		completed += 1
		_event(events, "dispatch", {"index": match_index, "box": parcel, "demand": demand_index})
		_apply_mechanisms(events)
		_unlock_positions(events)
		if slots[match_index].kind != "single" and remaining_stock() > 0:
			slots[match_index].box = _make_box(_definition.stock[_stock_cursor])
			_stock_cursor += 1
			_reveal_top(match_index)
			_event(events, "refill", {"index": match_index})


## 通关后归还道具增添的空盒，不增加订单、机关或奖励，撤回随完整事务恢复。
func _return_spare_boxes(events: Array) -> void:
	if not is_won():
		return
	for index: int in DonutAddBoxRules.returnable_empty_boxes(slots):
		slots[index].box = null
		_event(events, "spare_return", {"index": index})


## 一次真实回收使已在场数字盖各减一，并按盒位顺序解冻一盒。
func _apply_mechanisms(events: Array) -> void:
	var thawed: bool = false
	for index: int in slots.size():
		var slot: Dictionary = slots[index]
		if not slot.open or slot.box == null:
			continue
		var modified: bool = false
		if int(slot.box.lid) > 0:
			slot.box.lid -= 1
			modified = true
		if slot.box.frozen and not thawed:
			slot.box.frozen = false
			thawed = true
			modified = true
		if modified:
			_reveal_top(index)
			_event(events, "mechanism", {"index": index})


## 消除达到配置阈值时只开放常规盒位，订单位等待显式解锁。
func _unlock_positions(events: Array) -> void:
	for index: int in slots.size():
		if not slots[index].open and slots[index].kind != "turnover" and completed >= int(slots[index].unlock_after):
			slots[index].open = true
			_reveal_top(index)
			_event(events, "unlock", {"index": index})


## 首次露顶时记住真实口味，后续堆叠不会抹去揭示状态。
func _reveal_top(index: int) -> bool:
	if not can_handle(index) or slots[index].box.items.is_empty() or slots[index].box.items[0].revealed:
		return false
	slots[index].box.items[0].revealed = true
	return true


## 按一次操作内的真实回收数结算最高匹配奖励档位，金币钻石均可随事务撤回。
func _award_combo(count: int, events: Array) -> void:
	last_combo = count
	best_combo = maxi(best_combo, count)
	var reward: Dictionary = {"coins": 0, "diamonds": 0}
	for tier: Dictionary in _definition.combo_rewards:
		if count >= int(tier.count):
			reward = tier
	coins += int(reward.coins)
	diamonds += int(reward.diamonds)
	if count >= 2:
		_event(events, "combo", {"count": count, "coins": int(reward.coins), "diamonds": int(reward.diamonds)})


## 输出不可回写的显示快照，动效可逐步表现已提交事务而不拥有第二套规则状态。
func snapshot() -> Dictionary:
	var waiting: Array[bool] = []
	for index: int in slots.size():
		waiting.append(is_waiting(index))
	return {"waiting": waiting, "slots": slots.duplicate(true), "demands": demands.duplicate(true), "completed": completed,
		"moves": moves, "tools": tools.duplicate(), "coins": coins, "diamonds": diamonds,
		"last_combo": last_combo, "best_combo": best_combo, "stock_cursor": _stock_cursor,
		"next_box_id": _next_box_id, "started": started, "won": is_won(), "remaining_stock": remaining_stock()}


## 记录一次事件之后的画面快照，避免动画完成时再次执行回收或发奖。
func _event(events: Array, kind: String, data: Dictionary = {}) -> void:
	var event: Dictionary = data.duplicate(true)
	event.kind = kind
	event.state = snapshot()
	events.append(event)


## 保存用户操作之前的完整状态，包括隐藏层、机关、备货、需求与奖励。
func _remember() -> void:
	_history.remember(snapshot())


## 检查是否可撤回；撤回次数本身不会被旧快照补回。
func can_undo() -> bool:
	return _history.has_entry() and int(tools.undo) > 0


## 原子恢复上一步全部结果并保留本次撤回消耗，不重播或重复结算历史事件。
func undo() -> bool:
	if not can_undo():
		return false
	var remaining: int = int(tools.undo) - 1
	var state: Dictionary = _history.take()
	slots = state.slots
	demands = state.demands
	completed = state.completed
	moves = state.moves
	coins = state.coins
	diamonds = state.diamonds
	last_combo = state.last_combo
	best_combo = state.best_combo
	_stock_cursor = state.stock_cursor
	_next_box_id = state.next_box_id
	started = state.started
	tools = state.tools
	tools.undo = remaining
	var events: Array = []
	_event(events, "undo")
	changed.emit(events)
	return true


## 判断是否没有普通搬运路线，仍可使用道具的堵塞不等于失败。
func is_blocked() -> bool:
	if not started or is_won():
		return false
	for source: int in slots.size():
		for target: int in slots.size():
			if can_move(source, target):
				return false
	return true


## 无搬运路线且没有实际可用的补救道具时判负，不保存第二份结束状态。
func is_failed() -> bool:
	if not is_blocked() or can_undo():
		return false
	if int(tools.add_box) > 0 and next_turnover() >= 0:
		return false
	if int(tools.top) > 0:
		for index: int in slots.size():
			if not can_handle(index):
				continue
			for item_index: int in slots[index].box.items.size():
				if can_bring_to_top(index, item_index):
					return false
	return true
