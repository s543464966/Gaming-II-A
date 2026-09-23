class_name DonutSession
extends RefCounted
## 拥有盒位、逐盒备货与需求状态，原子结算搬运、回收、机关和本关奖励。

signal changed(events: Array)

const BOX_COUNT: int = 16
const CAPACITY: int = 4

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
var _history: Array[Dictionary] = []


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
	for entry: Dictionary in _definition.demands:
		var threshold: int = int(entry.get("unlock_after", 0))
		demands.append({"sequence": entry.sequence.map(func(value: Variant) -> int: return int(value)),
			"cursor": 0, "unlock_after": threshold, "open": threshold == 0})
	for index: int in slots.size():
		_reveal_top(index)


## 创建带独立编号的餐盒，确保同一盒位的新盒不继承旧盒机关效果。
func _make_box(definition: Dictionary) -> Dictionary:
	_next_box_id += 1
	var items: Array = []
	for item: Dictionary in definition.items:
		items.append({"flavor": int(item.flavor), "revealed": bool(item.revealed)})
	return {"id": _next_box_id, "kind": definition.get("kind", "normal"),
		"lid": int(definition.get("lid", 0)), "frozen": definition.get("kind", "normal") == "frozen", "items": items}


## 返回本关全部需求数，包含锁定位置及各位置的后续需求。
func total_orders() -> int:
	var total: int = 0
	for position: Dictionary in demands:
		total += position.sequence.size()
	return total


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
	return 1 if slots[index].kind == "single" else CAPACITY


## 判断实际容器存在且限制已解除，空盒位与锁定盒均不允许取放。
func can_handle(index: int) -> bool:
	if index < 0 or index >= slots.size():
		return false
	var slot: Dictionary = slots[index]
	return slot.open and slot.box != null and int(slot.box.lid) == 0 and not slot.box.frozen


## 查询来源盒可拿起的连续明牌组，拖拽预览与实际搬运共用此边界。
func top_group_size(source: int) -> int:
	if not started or is_won() or not can_handle(source):
		return 0
	var items: Array = slots[source].box.items
	if items.is_empty() or not items[0].revealed:
		return 0
	var flavor: int = int(items[0].flavor)
	var count: int = 0
	for item: Dictionary in items:
		if not item.revealed or int(item.flavor) != flavor:
			break
		count += 1
	return count


## 计算目标实际可容纳的搬运数量，保留同味匹配与特殊盒限制。
func move_count(source: int, target: int) -> int:
	var count: int = top_group_size(source)
	if count == 0 or source == target or not can_handle(target):
		return 0
	var destination: Array = slots[target].box.items
	var space: int = capacity(target) - destination.size()
	if space <= 0:
		return 0
	if not destination.is_empty() and (not destination[0].revealed or destination[0].flavor != slots[source].box.items[0].flavor):
		return 0
	return mini(count, space)


## 为界面提供与正式执行完全一致的目标合法性判断。
func can_move(source: int, target: int) -> bool:
	return move_count(source, target) > 0


## 原子提交整组或拆分搬运，再揭示露顶食物并结算所有真实回收。
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
	for index: int in slots.size():
		if slots[index].kind == "turnover" and not slots[index].open:
			return index
	return -1


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


## 置顶只能选择可操作盒中已揭示且确实改变顺序的食物。
func can_bring_to_top(index: int, item_index: int) -> bool:
	if not started or is_won() or not can_handle(index) or int(tools.top) <= 0:
		return false
	var items: Array = slots[index].box.items
	if item_index <= 0 or item_index >= items.size() or not items[item_index].revealed:
		return false
	var next: Array = items.duplicate(true)
	var item: Dictionary = next.pop_at(item_index)
	next.push_front(item)
	return next != items


## 置顶与后续回收形成同一可撤回事务，不揭露不可选的隐藏口味。
func bring_to_top(index: int, item_index: int) -> bool:
	if not can_bring_to_top(index, item_index):
		return false
	_remember()
	var before: int = completed
	var item: Dictionary = slots[index].box.items.pop_at(item_index)
	slots[index].box.items.push_front(item)
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
	var position: Dictionary = demands[index]
	if not position.open or position.cursor >= position.sequence.size():
		return -1
	return int(position.sequence[position.cursor])


## 判断凑齐但无需求的等待状态，不据此额外限制取放。
func is_waiting(index: int) -> bool:
	if not _packable(index):
		return false
	return _matching_demand(int(slots[index].box.items[0].flavor)) < 0


## 在确定的盒位顺序中逐次回收，每次都先影响旧盒，再原位补入一个新盒。
func _settle(events: Array) -> void:
	while true:
		var match_index: int = -1
		var demand_index: int = -1
		for index: int in slots.size():
			if _packable(index):
				demand_index = _matching_demand(int(slots[index].box.items[0].flavor))
				if demand_index >= 0:
					match_index = index
					break
		if match_index < 0:
			return
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


## 仅普通容量且限制解除的同味整盒可打包，暂存盒不参加回收。
func _packable(index: int) -> bool:
	if not can_handle(index) or slots[index].kind == "single":
		return false
	var items: Array = slots[index].box.items
	return items.size() == CAPACITY and items.all(func(item: Dictionary) -> bool: return item.flavor == items[0].flavor)


## 同口味需求并存时优先匹配靠左的开放位置。
func _matching_demand(flavor: int) -> int:
	for index: int in demands.size():
		if demand_flavor(index) == flavor:
			return index
	return -1


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


## 消除达到配置阈值时开放需求与常规盒位，刚入场盒不承接本次旧盒机关效果。
func _unlock_positions(events: Array) -> void:
	for index: int in demands.size():
		if not demands[index].open and completed >= int(demands[index].unlock_after):
			demands[index].open = true
			_event(events, "demand_unlock", {"index": index})
	for index: int in slots.size():
		if not slots[index].open and slots[index].kind != "turnover" and completed >= int(slots[index].unlock_after):
			slots[index].open = true
			_reveal_top(index)
			_event(events, "unlock", {"index": index})


## 只揭示当前露顶的一颗，调用方不会把它追加到已确定的搬运组。
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
		"next_box_id": _next_box_id, "started": started, "remaining_stock": remaining_stock(),
		"stock_preview": _definition.stock.slice(_stock_cursor, _stock_cursor + 2).duplicate(true)}


## 记录一次事件之后的画面快照，避免动画完成时再次执行回收或发奖。
func _event(events: Array, kind: String, data: Dictionary = {}) -> void:
	var event: Dictionary = data.duplicate(true)
	event.kind = kind
	event.state = snapshot()
	events.append(event)


## 保存用户操作之前的完整状态，包括隐藏层、机关、备货、需求与奖励。
func _remember() -> void:
	_history.append(snapshot())


## 检查是否可撤回；撤回次数本身不会被旧快照补回。
func can_undo() -> bool:
	return not _history.is_empty() and int(tools.undo) > 0


## 原子恢复上一步全部结果并保留本次撤回消耗，不重播或重复结算历史事件。
func undo() -> bool:
	if not can_undo():
		return false
	var remaining: int = int(tools.undo) - 1
	var state: Dictionary = _history.pop_back()
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


## 无普通搬运时提示玩家使用仍可用的道具或重开，不强制判负。
func is_blocked() -> bool:
	if not started or is_won():
		return false
	for source: int in slots.size():
		for target: int in slots.size():
			if can_move(source, target):
				return false
	return true
