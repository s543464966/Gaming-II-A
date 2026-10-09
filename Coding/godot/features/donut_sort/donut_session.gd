class_name DonutSession
extends RefCounted
## 拥有盒位、逐盒备货与需求状态，原子结算搬运、回收、机关和本关奖励。

signal changed(events: Array)

var slots: Array = []
var demands: Array = []
var completed: int = 0
var moves: int = 0
var tools: Dictionary = {}
var tool_claimed: Dictionary = {} # 每次尝试各道具只领取一次，不随撤回恢复。
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
var active_seconds: float = 0.0 # 只累计可操作时间；撤回不退还炸弹时间。
var failed: bool = false
var attempt: int = 0 # 重开或切关后递增，用于拒绝旧广告奖励。
var pending_reward: Dictionary = {}
var _reward_serial: int = 0


## 正常启动读取内容目录；验证可显式注入独立定义而不修改运行配置。
func _init(definition: Dictionary = {}) -> void:
	if definition.is_empty():
		_definition = DonutLevel.load_definition(DonutLevel.catalog()[0].path)
	else:
		_definition = definition.duplicate(true)
	_prepare()


## 切换内容目录中的关卡，清除上一关事务与奖励后重新入场。
func load_level(index: int) -> bool:
	if not pending_reward.is_empty():
		return false
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
	if not pending_reward.is_empty():
		return
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
	active_seconds = 0.0
	failed = false
	attempt += 1
	pending_reward = {}
	_history.clear()
	if _definition.is_empty():
		return
	title = _definition.get("title", "甜甜圈小铺")
	tools = _definition.tools.duplicate(true)
	tool_claimed = {}
	for key: String in tools:
		tools[key] = clampi(int(tools[key]), 0, 1)
		tool_claimed[key] = tools[key] > 0
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
		items.append({"flavor": int(item.flavor), "revealed": not bool(item.get("hidden", hidden_layers))})
	var kind: String = definition.get("kind", "normal")
	return {"id": _next_box_id, "kind": kind, "lid": int(definition.get("lid", 0)),
		"frozen": kind in ["frozen", "number_frozen"], "items": items,
		"grouped": items.size() == 4 and items.all(func(item: Dictionary) -> bool: return item.flavor == items[0].flavor),
		"fixed_flavor": int(definition.get("fixed_flavor", -1)),
		"bomb_deadline": active_seconds + float(definition.get("bomb_seconds", 0)) if kind == "bomb" else -1.0}


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


## 全部需求与食物处理完且没有未解除炸弹后才允许通关，单纯搬空炸弹不算解除。
func is_won() -> bool:
	return started and not failed and completed == total_orders() and remaining_stock() == 0 and remaining_donuts() == 0 and not slots.any(
		func(slot: Dictionary) -> bool: return slot.box != null and slot.box.kind == "bomb")


## 单颗暂存容量为一，其余盒子容量为四。
func capacity(index: int) -> int:
	return DonutMoveRules.capacity(slots, index)


## 判断实际容器存在且限制已解除，空盒位与锁定盒均不允许取放。
func can_handle(index: int) -> bool:
	return DonutMoveRules.can_handle(slots, index)


## 仅允许从可操作餐盒的明牌顶层开始拿取。
func can_pick_top(source: int) -> bool:
	return DonutMoveRules.can_pick_top(slots, started, is_won() or failed or not pending_reward.is_empty(), source)


## 返回操作开始时可一起拿起的连续同味明牌数量。
func pick_count(source: int) -> int:
	return DonutMoveRules.pick_count(slots, started, is_won() or failed or not pending_reward.is_empty(), source)


## 返回连续同味组中目标容量允许接收的实际数量。
func move_count(source: int, target: int) -> int:
	return DonutMoveRules.move_count(slots, started, is_won() or failed or not pending_reward.is_empty(), source, target)


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
	if slots[source].box.kind == "cycle" and slots[source].box.items.size() > 1:
		slots[source].box.items.push_front(slots[source].box.items.pop_back())
		_event(events, "cycle", {"index": source})
	if _reveal_top(source):
		_event(events, "reveal", {"index": source})
	_first_group(target, events)
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
	if not started or is_won() or failed or not pending_reward.is_empty() or index < 0 or int(tools.add_box) <= 0:
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
	if not started or is_won() or failed or not pending_reward.is_empty() or not can_handle(index) or slots[index].box.kind == "in_only" or int(tools.top) <= 0:
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
	if not started or failed or is_won() or not pending_reward.is_empty() or index < 0 or index >= demands.size() or demands[index].open:
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


## 先结清在场连续回收，再按回收顺序补货，重复到局面稳定。
func _settle(events: Array) -> void:
	while true:
		var refill: Array[int] = []
		var current_match: Vector2i = DonutDispatchRules.next_match(slots, demands)
		while current_match.x >= 0:
			var parcel: Dictionary = slots[current_match.x].box.duplicate(true)
			slots[current_match.x].box = null
			demands[current_match.y].cursor += 1
			completed += 1
			refill.append(current_match.x)
			_event(events, "dispatch", {"index": current_match.x, "box": parcel, "demand": current_match.y})
			_apply_mechanisms(events)
			_unlock_positions(events)
			current_match = DonutDispatchRules.next_match(slots, demands)
		if refill.is_empty() or remaining_stock() == 0:
			_return_spare_boxes(events)
			return
		for index: int in refill:
			if remaining_stock() == 0:
				break
			slots[index].box = _make_box(_definition.stock[_stock_cursor])
			_stock_cursor += 1
			_reveal_top(index)
			_event(events, "refill", {"index": index})


## 通关后归还道具增添的空盒，不增加订单、机关或奖励，撤回随完整事务恢复。
func _return_spare_boxes(events: Array) -> void:
	if not is_won():
		return
	for index: int in DonutAddBoxRules.returnable_empty_boxes(slots):
		slots[index].box = null
		_event(events, "spare_return", {"index": index})


## 一次真实回收仅解冻当前在场的第一只无数字冰冻盒。
func _apply_mechanisms(events: Array) -> void:
	for index: int in slots.size():
		var slot: Dictionary = slots[index]
		if not slot.open or slot.box == null:
			continue
		if slot.box.kind == "frozen" and slot.box.frozen:
			slot.box.frozen = false
			_reveal_top(index)
			_event(events, "mechanism", {"index": index})
			return


## 返回按固定盒位顺序排列的数字机关，成组时只推进首个目标。
func number_targets() -> Array[int]:
	var result: Array[int] = []
	for index: int in slots.size():
		if slots[index].open and slots[index].box != null and int(slots[index].box.lid) > 0:
			result.append(index)
	return result


## 目标首次四同味解除炸弹并产生归纳，一次只减一个数字，不必等待需求回收。
func _first_group(index: int, events: Array) -> void:
	var box: Dictionary = slots[index].box
	if box.grouped or not DonutDispatchRules.packable(slots, index):
		return
	box.grouped = true
	if box.kind == "bomb":
		box.kind = "normal"
		box.bomb_deadline = -1.0
	_event(events, "group", {"index": index})
	var targets: Array[int] = number_targets()
	if targets.is_empty():
		return
	var target: int = targets[0]
	slots[target].box.lid -= 1
	if int(slots[target].box.lid) == 0:
		slots[target].box.frozen = false
		_reveal_top(target)
	_event(events, "mechanism", {"index": target})


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
	return {"layout_id": _definition.get("layout_id", ""), "waiting": waiting, "slots": slots.duplicate(true), "demands": demands.duplicate(true), "completed": completed,
		"moves": moves, "tools": tools.duplicate(), "tool_claimed": tool_claimed.duplicate(), "coins": coins, "diamonds": diamonds,
		"last_combo": last_combo, "best_combo": best_combo, "stock_cursor": _stock_cursor,
		"next_box_id": _next_box_id, "started": started, "won": is_won(), "remaining_stock": remaining_stock(),
		"active_seconds": active_seconds, "failed": failed, "number_targets": number_targets()}


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
	return not failed and pending_reward.is_empty() and _history.has_entry() and int(tools.undo) > 0


## 恢复上一步棋盘与奖励，所有道具的领取和消耗均不回退。
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


## 停滞不自动判负；仅未归纳解除的炸弹到时失败。
func is_failed() -> bool:
	return failed


## 页面只在可计时时调用；已归纳解除的盒子不再计时或触发爆炸。
func advance_clock(seconds: float) -> bool:
	if not started or is_won() or failed or not pending_reward.is_empty() or not is_finite(seconds) or seconds <= 0:
		return false
	if not slots.any(func(slot: Dictionary) -> bool: return slot.open and slot.box != null and slot.box.kind == "bomb"):
		return false
	active_seconds += seconds
	for slot: Dictionary in slots:
		if slot.open and slot.box != null and slot.box.kind == "bomb" and active_seconds >= float(slot.box.bomb_deadline):
			failed = true
	return true


## 请求指定周转位奖励，使用本次尝试与唯一序号隔离延迟或重复回调。
func request_turnover(index: int) -> String:
	if not started or failed or is_won() or not pending_reward.is_empty() or index < 0 or index >= slots.size():
		return ""
	if slots[index].kind != "turnover" or slots[index].open:
		return ""
	_reward_serial += 1
	var token: String = "%d:%d:%d" % [attempt, _reward_serial, index]
	pending_reward = {"kind": "turnover", "token": token, "index": index, "attempt": attempt}
	return token


## 只有匹配的奖励确认才开放所选盒，不扣道具且不可被撤回重复领取。
func resolve_turnover(token: String, rewarded: bool) -> bool:
	if pending_reward.get("kind") != "turnover" or token != pending_reward.token or int(pending_reward.attempt) != attempt:
		return false
	var index: int = int(pending_reward.index)
	pending_reward = {}
	if not rewarded or slots[index].open:
		return false
	slots[index].open = true
	slots[index].box = _make_box({"items": []})
	_history.clear()
	var events: Array = []
	_event(events, "unlock", {"index": index})
	changed.emit(events)
	return true


## 未领取的道具才可请求广告奖励，等待期间冻结操作与炸弹计时。
func request_tool_reward(tool: String) -> String:
	if not started or failed or is_won() or not pending_reward.is_empty() or not tools.has(tool) or tool_claimed[tool]:
		return ""
	_reward_serial += 1
	var token: String = "%d:%d:%s" % [attempt, _reward_serial, tool]
	pending_reward = {"kind": "tool", "token": token, "tool": tool, "attempt": attempt}
	return token


## 广告完成只授予一次使用点，不执行道具；取消、重复或过期回调不发奖。
func resolve_tool_reward(token: String, rewarded: bool) -> bool:
	if pending_reward.get("kind") != "tool" or token != pending_reward.token or int(pending_reward.attempt) != attempt:
		return false
	var tool: String = pending_reward.tool
	pending_reward = {}
	if rewarded and not tool_claimed[tool]:
		tool_claimed[tool] = true
		tools[tool] = 1
		changed.emit([])
		return true
	changed.emit([])
	return false


## 页面退出或替换时撤销道具请求，迟到的完成回调不能再发奖。
func cancel_tool_reward() -> void:
	if pending_reward.get("kind") == "tool":
		resolve_tool_reward(pending_reward.token, false)


## 存档绑定当前关卡内容摘要，关卡更新后不套用过时局面。
func export_run() -> Dictionary:
	return {"level_index": level_index, "content_hash": JSON.stringify(_definition).sha256_text(),
		"state": snapshot(), "undo": _history.export_latest()}


## 只恢复同版本定义下数量守恒的完整局面，不恢复未收到确认的广告请求。
func restore_run(data: Dictionary) -> bool:
	var index: int = int(data.get("level_index", -1))
	if index < 0 or index >= DonutLevel.catalog().size() or not data.get("state") is Dictionary:
		return false
	var definition: Dictionary = DonutLevel.load_definition(DonutLevel.catalog()[index].path)
	if str(data.get("content_hash", "")) != JSON.stringify(definition).sha256_text():
		return false
	if not _valid_saved_state(data.state, definition):
		return false
	var history: Dictionary = data.get("undo", {}) if data.get("undo") is Dictionary else {}
	if not history.is_empty() and not _valid_saved_state(history, definition):
		return false
	_definition = definition
	level_index = index
	_prepare()
	var state: Dictionary = data.state
	slots = state.slots.duplicate(true)
	_normalize_grouped_bombs(slots)
	demands = state.demands.duplicate(true)
	completed = int(state.completed)
	moves = int(state.moves)
	coins = int(state.coins)
	diamonds = int(state.diamonds)
	last_combo = int(state.last_combo)
	best_combo = int(state.best_combo)
	_stock_cursor = int(state.stock_cursor)
	_next_box_id = int(state.next_box_id)
	active_seconds = float(state.active_seconds)
	failed = bool(state.failed)
	started = bool(state.started)
	tools = state.tools.duplicate()
	tool_claimed = state.tool_claimed.duplicate()
	for key: String in tools:
		tools[key] = int(tools[key])
	if not history.is_empty():
		history = history.duplicate(true)
		_normalize_grouped_bombs(history.slots)
	_history.restore_latest(history)
	return true


## 兼容同一项目旧存档：已经归纳的炸弹按新规则解除，未归纳的原倒计时保留。
func _normalize_grouped_bombs(box_slots: Array) -> void:
	for slot: Dictionary in box_slots:
		if slot.box != null and slot.box.kind == "bomb" and slot.box.grouped:
			slot.box.kind = "normal"
			slot.box.bomb_deadline = -1.0


## 拒绝损坏存档的容器、游标、机关与逐口味数量，避免加载后才在交互中崩溃。
func _valid_saved_state(state: Dictionary, definition: Dictionary) -> bool:
	for key: String in ["slots", "demands"]:
		if not state.get(key) is Array or state[key].size() != definition[key].size():
			return false
	for key: String in ["completed", "moves", "coins", "diamonds", "last_combo", "best_combo", "stock_cursor", "next_box_id", "active_seconds"]:
		if not (state.get(key) is int or state.get(key) is float) or not is_finite(float(state[key])) or float(state[key]) < 0:
			return false
	if not state.get("started") is bool or not state.get("failed") is bool or not state.get("tools") is Dictionary or not state.get("tool_claimed") is Dictionary:
		return false
	for key: String in ["undo", "add_box", "top"]:
		if not (state.tools.get(key) is int or state.tools.get(key) is float) or not float(state.tools[key]) in [0.0, 1.0] or not state.tool_claimed.get(key) is bool:
			return false
		if state.tools[key] == 1 and not state.tool_claimed[key]:
			return false
	if int(state.stock_cursor) > definition.stock.size():
		return false
	var supply: Array[int] = []
	var required: Array[int] = []
	supply.resize(DonutLevel.FLAVOR_COUNT)
	required.resize(DonutLevel.FLAVOR_COUNT)
	var seen_ids: Dictionary = {}
	for index: int in state.slots.size():
		var slot: Variant = state.slots[index]
		if not slot is Dictionary or not slot.has_all(["kind", "box", "open", "unlock_after"]) or slot.kind != definition.slots[index].kind or not slot.open is bool:
			return false
		if slot.box == null:
			continue
		var box: Variant = slot.box
		if not box is Dictionary or not box.has_all(["id", "kind", "lid", "frozen", "items", "grouped", "fixed_flavor", "bomb_deadline"]):
			return false
		if not box.items is Array or box.items.size() > (1 if slot.kind == "single" else 4) or int(box.lid) < 0 or not box.frozen is bool or not box.grouped is bool:
			return false
		if seen_ids.has(int(box.id)) or int(box.id) < 1 or int(box.id) > int(state.next_box_id):
			return false
		seen_ids[int(box.id)] = true
		if not box.kind in ["normal", "lid", "frozen", "number_frozen", "fixed", "in_only", "cycle", "bomb"] or not is_finite(float(box.bomb_deadline)):
			return false
		if box.kind == "fixed" and (int(box.fixed_flavor) < 0 or int(box.fixed_flavor) >= DonutLevel.FLAVOR_COUNT):
			return false
		for item: Variant in box.items:
			if not item is Dictionary or not item.has_all(["flavor", "revealed"]) or not item.revealed is bool or int(item.flavor) < 0 or int(item.flavor) >= DonutLevel.FLAVOR_COUNT:
				return false
			supply[int(item.flavor)] += 1
	for stock_index: int in range(int(state.stock_cursor), definition.stock.size()):
		for item: Dictionary in definition.stock[stock_index].items:
			supply[int(item.flavor)] += 1
	var dispatched: int = 0
	for index: int in state.demands.size():
		var demand: Variant = state.demands[index]
		if not demand is Dictionary or not demand.has_all(["sequence", "cursor", "open"]) or not demand.sequence is Array or not demand.open is bool:
			return false
		if JSON.stringify(demand.sequence) != JSON.stringify(definition.demands[index].sequence) or int(demand.cursor) < 0 or int(demand.cursor) > demand.sequence.size():
			return false
		dispatched += int(demand.cursor)
		for cursor: int in range(int(demand.cursor), demand.sequence.size()):
			required[int(demand.sequence[cursor])] += 4
	return supply == required and dispatched == int(state.completed)
