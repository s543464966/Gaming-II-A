extends SceneTree
## 验证三关完整解、新玩法边界、逐次回收与页面中断后的状态一致性。

var _failures: Array[String] = []


## 等待引擎初始化后进入确定性的规则与场景验证。
func _initialize() -> void:
	_run.call_deferred()


## 一次执行全部相关场景，汇总失败而不逐项修改期望。
func _run() -> void:
	_check_content_and_solutions()
	_check_early_level_space()
	_check_group_and_reveal()
	_check_waiting_and_chain()
	_check_mechanisms_and_stock()
	_check_event_boundaries()
	_check_turnover_and_single()
	_check_tools_and_victory()
	_check_reward_tiers()
	await _check_ui_lifecycle()
	await _check_pointer_input()
	await _check_early_level_drags()
	await _check_portrait_layout()
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: donut; F-01..F-08, mechanisms, rewards, undo and UI lifecycle")
	quit(0)


## 记录可定位断言，独立场景仍继续执行。
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## 创建明确指定口味与隐藏索引的最小盒子定义。
func _box(flavors: Array, hidden: Array = [], kind: String = "normal", lid: int = 0) -> Dictionary:
	var items: Array = []
	for index: int in flavors.size():
		items.append({"flavor": int(flavors[index]), "revealed": not index in hidden})
	return {"kind": kind, "lid": lid, "items": items}


## 局部规则用明确的可操作空盒夹具，不充当正式关卡配置。
func _definition(boxes: Array = []) -> Dictionary:
	var slots: Array = []
	for index: int in 14:
		slots.append({"kind": "regular", "unlock_after": 0, "box": boxes[index] if index < boxes.size() else _box([])})
	slots.append({"kind": "turnover", "unlock_after": -1, "box": null})
	slots.append({"kind": "turnover", "unlock_after": -1, "box": null})
	return {"title": "规则夹具", "slots": slots,
		"demands": [{"sequence": [0], "unlock_after": 0}, {"sequence": [1], "unlock_after": 0},
			{"sequence": [2], "unlock_after": 0}, {"sequence": [3], "unlock_after": 0}],
		"stock": [], "tools": {"undo": 3, "add_box": 2, "top": 3},
		"combo_rewards": [{"count": 2, "coins": 5, "diamonds": 0}, {"count": 3, "coins": 10, "diamonds": 1}, {"count": 4, "coins": 20, "diamonds": 2}]}


## 正式三关逐步验证完整解、每盒容量、数量守恒及无需道具可解。
func _check_content_and_solutions() -> void:
	var levels: Array = DonutLevel.catalog()
	_expect(levels.size() == 3, "Expected three playable content levels")
	for index: int in levels.size():
		var definition: Dictionary = DonutLevel.load_definition(levels[index].path)
		_expect(DonutLevel.validate(definition).is_empty(), "Content validation failed")
		var session := DonutSession.new(definition)
		session.begin()
		var fixture_path: String = get_script().resource_path.get_base_dir().path_join("../../fixtures/donut_sort/level_%02d_solution.json" % (index + 1))
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
		_expect(session.slots.size() == 16 and session.demands.size() == 4 and session.next_turnover() == 14, "Initial slot/demand structure")
		for step: Array in fixture.steps:
			_expect(session.move(int(step[0]), int(step[1])), "Level %d invalid move %s at %d" % [index + 1, step, session.moves])
			_expect(session.remaining_donuts() + session.completed * 4 == session.total_donuts(), "Food conservation failed")
			for slot_index: int in session.slots.size():
				var slot: Dictionary = session.slots[slot_index]
				_expect(slot.box == null or slot.box.items.size() <= session.capacity(slot_index), "Capacity exceeded")
		_expect(session.is_won() and session.moves == int(fixture.moves), "Full solution failed level %d" % (index + 1))
		_expect(session.tools == {"undo": 3, "add_box": 2, "top": 3}, "Full solution spent tools")
		_expect(not session.move(0, 1) and not session.add_box(), "Won session accepts new actions")
		print("PASS: level %d, %d moves, %d orders, %d donuts conserved" % [index + 1, session.moves, session.completed, session.total_donuts()])
		if index == 2:
			_expect(definition.stock.size() + 14 == 25, "Long level must contain 25 preset boxes")
			_expect(session.best_combo >= 3 and session.coins > 0 and session.diamonds > 0, "Mixed demand level must exercise automatic combos and rewards")
	var invalid: Dictionary = DonutLevel.load_definition(levels[0].path).duplicate(true)
	invalid.slots[0].box.items[0].flavor = 99
	_expect(not DonutLevel.validate(invalid).is_empty(), "Invalid flavor escaped content validator")
	invalid = DonutLevel.load_definition(levels[0].path).duplicate(true)
	invalid.demands[0].sequence.pop_back()
	_expect(not DonutLevel.validate(invalid).is_empty(), "Unbalanced flavor totals escaped validator")


## 新手关必须提供无需道具的普通空盒和多个落点，不能只证明有一条固定解。
func _check_early_level_space() -> void:
	for index: int in 2:
		var definition: Dictionary = DonutLevel.load_definition(DonutLevel.catalog()[index].path)
		var session := DonutSession.new(definition)
		session.begin()
		var empty_boxes: int = 0
		var capacity: int = 0
		var food: int = 0
		var legal_moves: int = 0
		var empty_indices: Array[int] = []
		for source: int in 14:
			capacity += session.capacity(source)
			food += session.slots[source].box.items.size()
			if session.slots[source].kind == "regular" and session.slots[source].box.items.is_empty():
				empty_boxes += 1
				empty_indices.append(source)
			if session.top_group_size(source) == 0:
				continue
			var targets: int = 0
			for target: int in 14:
				if session.slots[target].kind == "regular" and session.can_move(source, target):
					targets += 1
			legal_moves += targets
			_expect(targets >= 2, "Level %d source %d lacks alternative ordinary targets" % [index + 1, source])
		_expect(empty_boxes >= [4, 3][index], "Level %d lacks visible ordinary empty boxes" % (index + 1))
		_expect(float(food) / capacity <= [0.55, 0.65][index], "Level %d opening is overcrowded" % (index + 1))
		_expect(session.completed == 0 and session.remaining_stock() == definition.stock.size(), "Opening auto-settlement concealed initial density")
		for demand: Dictionary in session.demands:
			_expect(demand.open, "Early level unexpectedly locks a demand")
		for slot: Dictionary in session.slots:
			_expect(slot.box == null or (not slot.box.frozen and slot.box.lid == 0), "Early level stacks blocking mechanisms")
		var fixture_path: String = get_script().resource_path.get_base_dir().path_join("../../fixtures/donut_sort/level_%02d_solution.json" % (index + 1))
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
		var first: Array = fixture.steps[0]
		for empty_index: int in empty_indices:
			var alternate := DonutSession.new(definition)
			alternate.begin()
			var initial_tools: Dictionary = alternate.tools.duplicate()
			_expect(alternate.move(int(first[0]), empty_index), "Ordinary empty box rejected opening group")
			_expect(alternate.move(empty_index, int(first[1])), "Opening detour could not continue sorting")
			for step: Array in fixture.steps.slice(1):
				_expect(alternate.move(int(step[0]), int(step[1])), "Alternative empty-box opening broke continuation")
			_expect(alternate.is_won(), "Level %d empty box %d opening cannot finish" % [index + 1, empty_index])
			_expect(alternate.tools == initial_tools, "Alternative opening spent a tool")
		print("PASS: level %d opening, %d ordinary empty boxes, %d/%d filled, %d ordinary drag routes" % [index + 1, empty_boxes, food, capacity, legal_moves])


## 容量决定成组或拆分，隐藏露顶不能继续加入同一次搬运。
func _check_group_and_reveal() -> void:
	var session := DonutSession.new(_definition([_box([0, 0, 1]), _box([0])]))
	session.begin()
	_expect(session.move_count(0, 1) == 2 and session.move(0, 1), "Visible group did not move together")
	_expect(session.slots[0].box.items.size() == 1 and session.slots[1].box.items.size() == 3, "Group transfer incorrect")
	session = DonutSession.new(_definition([_box([0, 0]), _box([0, 0, 0])]))
	session.begin()
	_expect(session.move_count(0, 1) == 1 and session.move(0, 1), "One-slot target must split one donut")
	_expect(session.slots[0].box.items.size() == 1 and session.slots[1].box == null and session.completed == 1, "Split/recycle result incorrect")
	var before: Dictionary = session.snapshot()
	_expect(not session.move(0, 1) and not session.move(-1, 0) and not session.move(0, 0), "Empty slot or invalid index accepted")
	_expect(session.snapshot() == before, "Invalid operation mutated state")
	session = DonutSession.new(_definition([_box([0, 0, 0], [1]), _box([0])]))
	session.begin()
	before = session.snapshot()
	_expect(session.move_count(0, 1) == 1 and session.move(0, 1), "Group crossed hidden boundary")
	_expect(session.slots[0].box.items.size() == 2 and session.slots[0].box.items[0].revealed, "Exposed layer not revealed")
	_expect(session.slots[1].box.items.size() == 2 and session.completed == 0, "Newly revealed donut moved again")
	_expect(session.undo() and session.slots == before.slots, "Undo did not restore hidden knowledge")
	var emptying := DonutSession.new(_definition([_box([1, 1]), _box([])]))
	emptying.begin()
	_expect(emptying.move(0, 1) and emptying.slots[0].box != null and emptying.slots[0].box.items.is_empty(), "Moving out last donut removed container")
	session = DonutSession.new(_definition([_box([0, 0, 0]), _box([0, 0])]))
	session.begin()
	_expect(session.move_count(0, 1) == 2 and session.move(0, 1) and session.slots[0].box.items.size() == 1, "Multi-slot capacity split moved incorrect count")


## 已凑齐等待不锁取放，固定需求位置可自动连续回收三盒且只更新自己。
func _check_waiting_and_chain() -> void:
	var definition: Dictionary = _definition([_box([0, 0, 0]), _box([0]), _box([3, 3, 3, 3]), _box([2, 2, 2, 2])])
	definition.demands = [{"sequence": [0, 3, 2], "unlock_after": 0}, {"sequence": [1], "unlock_after": 0},
		{"sequence": [], "unlock_after": 0}, {"sequence": [], "unlock_after": 0}]
	var session := DonutSession.new(definition)
	var events: Array = []
	session.changed.connect(func(batch: Array) -> void: events.append_array(batch))
	session.begin()
	_expect(session.is_waiting(2) and session.is_waiting(3) and session.completed == 0, "Waiting boxes dispatched early")
	_expect(session.can_move(2, 4), "Waiting state incorrectly locked taking donuts")
	events.clear()
	_expect(session.move(1, 0), "Chain trigger failed")
	var dispatches: Array = events.filter(func(event: Dictionary) -> bool: return event.kind == "dispatch")
	_expect(dispatches.size() == 3 and session.completed == 3 and session.last_combo == 3, "Chain did not count three unique recycles")
	_expect(session.demands[0].cursor == 3 and session.demands[1].cursor == 0 and session.demand_flavor(1) == 1, "Chain modified another demand position")
	_expect(session.coins == 10 and session.diamonds == 1, "Three-chain reward incorrect")
	_expect(session.undo() and session.completed == 0 and session.coins == 0 and session.diamonds == 0, "Undo failed to refund chain/rewards")
	_expect(session.move(1, 0) and session.coins == 10 and session.diamonds == 1, "Replaying undo duplicated rewards")
	definition = _definition([_box([0, 0, 0]), _box([0]), _box([3, 3, 3, 3])])
	definition.demands[3].unlock_after = 1
	session = DonutSession.new(definition)
	session.begin()
	_expect(session.demand_flavor(3) == -1 and session.completed == 0, "Locked demand participated in matching")
	session.move(1, 0)
	_expect(session.demands[3].open and session.completed == 2, "Threshold unlock did not cascade")


## 机关只作用于事件发生时在场的旧盒，每次原位补入一盒而非填充任意空盒。
func _check_mechanisms_and_stock() -> void:
	var definition: Dictionary = _definition([_box([0, 0, 0]), _box([0]), _box([1], [], "lid", 2),
		_box([2], [], "lid", 3), _box([3], [], "frozen"), _box([2], [], "frozen")])
	definition.stock = [_box([1, 2], [], "lid", 3), _box([3, 0], [], "frozen")]
	var session := DonutSession.new(definition)
	session.begin()
	_expect(not session.can_move(2, 6) and not session.can_move(6, 4) and not session.can_bring_to_top(2, 1), "Restricted box allowed interaction")
	var old_id: int = session.slots[0].box.id
	var other_boxes: Array = session.slots.slice(6, 14).duplicate(true)
	_expect(session.move(1, 0), "Mechanism trigger move failed")
	_expect(session.completed == 1 and session.remaining_stock() == 1, "Recycle did not consume exactly one stock box")
	_expect(session.slots[0].box.id != old_id and session.slots[0].box.lid == 3, "Fresh stock inherited past lid decrement")
	_expect(session.slots[1].box != null and session.slots[1].box.items.is_empty(), "Emptied source refilled or removed")
	_expect(session.slots.slice(6, 14) == other_boxes, "Refill moved unrelated boxes")
	_expect(session.slots[2].box.lid == 1 and session.slots[3].box.lid == 2, "Not all old lids decremented once")
	_expect(not session.slots[4].box.frozen and session.slots[5].box.frozen, "Expected one lowest-index frozen box thawed")
	_expect(session.move(4, 6) and session.remaining_stock() == 1 and session.completed == 1, "Moving empty source triggered refill/mechanisms")
	_expect(session.undo() and session.undo() and session.slots[2].box.lid == 2 and session.slots[4].box.frozen, "Undo failed to restore mechanisms")
	definition = _definition([_box([0, 0, 0]), _box([0]), _box([1, 1, 1, 1], [], "lid", 1)])
	session = DonutSession.new(definition)
	session.begin()
	session.move(1, 0)
	_expect(session.completed == 2 and session.slots[2].box == null, "Newly opened matching box did not recycle once")


## 验证同口味需求优先级、新入场冰冻保护以及跨操作不累计连单。
func _check_event_boundaries() -> void:
	var definition: Dictionary = _definition([_box([0, 0, 0]), _box([0]), _box([1, 1, 1]), _box([1])])
	definition.demands[1].sequence = [0, 1]
	definition.stock = [_box([2, 3], [], "frozen")]
	definition.slots[4].box = _box([2, 3], [], "frozen")
	definition.slots[4].unlock_after = 1
	var session := DonutSession.new(definition)
	session.begin()
	session.move(1, 0)
	_expect(session.demands[0].cursor == 1 and session.demands[1].cursor == 0, "Duplicate demand should prefer leftmost open position")
	_expect(session.slots[0].box.frozen and session.slots[4].open and session.slots[4].box.frozen, "Newly refilled/unlocked frozen box received prior thaw")
	var before: Dictionary = session.snapshot()
	_expect(not session.move(2, 0) and not session.bring_to_top(0, 1) and session.snapshot() == before, "Frozen box accepted take, put or top")
	definition = _definition([_box([0, 0, 0]), _box([0]), _box([1, 1, 1]), _box([1])])
	session = DonutSession.new(definition)
	session.begin()
	session.move(1, 0)
	session.move(3, 2)
	_expect(session.completed == 2 and session.last_combo == 1 and session.coins == 0, "Two separate recycles incorrectly earned a combo")
	definition = _definition([_box([0, 0, 0, 0]), _box([0, 0, 0, 0])])
	definition.demands[0].sequence = [0, 0]
	var order: Array = []
	session = DonutSession.new(definition)
	session.changed.connect(func(events: Array) -> void:
		for event: Dictionary in events:
			if event.kind == "dispatch":
				order.append(event.index))
	session.begin()
	_expect(order == [0, 1] and session.completed == 2, "Simultaneous matching boxes were duplicated or reordered")


## 暂存只接收一颗且不回收，周转搬空保留、真正回收才按常规补位。
func _check_turnover_and_single() -> void:
	var definition: Dictionary = _definition([_box([0, 0]), _box([])])
	definition.slots[1].kind = "single"
	definition.stock = [_box([2, 3])]
	var session := DonutSession.new(definition)
	session.begin()
	_expect(session.move_count(0, 1) == 1 and session.move(0, 1), "Single storage accepted incorrect count")
	_expect(session.slots[1].box.items.size() == 1 and session.completed == 0 and session.remaining_stock() == 1, "Single storage packed/refilled")
	_expect(not session.move(0, 1), "Single storage exceeded capacity")
	definition = _definition([_box([0, 0, 0, 0]), _box([1, 1, 1]), _box([1])])
	definition.demands = [{"sequence": [1, 0], "unlock_after": 0}, {"sequence": [], "unlock_after": 0},
		{"sequence": [], "unlock_after": 0}, {"sequence": [], "unlock_after": 0}]
	definition.stock = [_box([2, 3]), _box([1, 2])]
	session = DonutSession.new(definition)
	session.begin()
	_expect(session.add_box() and session.slots[14].open and session.slots[14].box.items.is_empty(), "Turnover unlock failed")
	_expect(session.remaining_stock() == 2 and session.slots.size() == 16, "Unlock consumed stock or grew board")
	session.move(0, 14)
	var turnover_id: int = session.slots[14].box.id
	_expect(session.is_waiting(14), "Full turnover should wait for matching demand")
	session.move(2, 1)
	_expect(session.completed == 2 and session.remaining_stock() == 0 and session.slots[14].box.id != turnover_id, "Turnover recycle did not refill in place")
	_expect(session.slots[0].box != null and session.slots[0].box.items.is_empty(), "Source empty box was consumed")
	_expect(session.add_box() and not session.add_box() and session.slots.size() == 16, "Turnover tool exceeded two locked positions")


## 无效置顶不扣次数，撤回恢复完整状态，通关不能遗漏后续需求或备货。
func _check_tools_and_victory() -> void:
	var session := DonutSession.new(_definition([_box([0, 1, 2], [1])]))
	session.begin()
	var before: Dictionary = session.snapshot()
	_expect(not session.bring_to_top(0, 1) and not session.bring_to_top(0, 0) and session.snapshot() == before, "Hidden/no-op top spent tool or revealed flavor")
	_expect(session.bring_to_top(0, 2) and session.slots[0].box.items[0].flavor == 2, "Visible top tool failed")
	_expect(session.undo() and session.slots == before.slots and session.tools.top == 3 and session.tools.undo == 2, "Top undo incorrect")
	session.add_box()
	session.undo()
	_expect(not session.slots[14].open and session.slots[14].box == null and session.tools.undo == 1, "Turnover undo restored incorrect container or credits")
	var definition: Dictionary = _definition()
	session = DonutSession.new(definition)
	session.begin()
	_expect(not session.is_won(), "Empty board ignored unfinished demand")
	definition.demands = [{"sequence": [], "unlock_after": 0}, {"sequence": [], "unlock_after": 0},
		{"sequence": [], "unlock_after": 0}, {"sequence": [], "unlock_after": 0}]
	definition.stock = [_box([0])]
	session = DonutSession.new(definition)
	session.begin()
	_expect(not session.is_won(), "Empty board ignored stock")
	definition.stock = []
	session = DonutSession.new(definition)
	session.begin()
	_expect(session.is_won(), "Empty containers should not block completed level")
	session = DonutSession.new()
	session.begin()
	session.move(0, 12)
	session.restart()
	_expect(session.completed == 0 and session.moves == 0 and session.coins == 0 and session.tools.undo == 3, "Restart did not reset level ledger")


## 验证二连、三连、四连及以上只结算对应最高奖励档位。
func _check_reward_tiers() -> void:
	for count: int in [2, 3, 4, 5]:
		var boxes: Array = [_box([0, 0, 0]), _box([0])]
		var sequence: Array = [0]
		for index: int in count - 1:
			boxes.append(_box([3, 3, 3, 3]))
			sequence.append(3)
		var definition: Dictionary = _definition(boxes)
		definition.demands = [{"sequence": sequence, "unlock_after": 0}, {"sequence": [], "unlock_after": 0},
			{"sequence": [], "unlock_after": 0}, {"sequence": [], "unlock_after": 0}]
		var session := DonutSession.new(definition)
		session.begin()
		session.move(1, 0)
		_expect(session.last_combo == count and session.completed == count, "Combo length incorrect")
		_expect(session.coins == (5 if count == 2 else (10 if count == 3 else 20)), "Coin reward tier incorrect")
		_expect(session.diamonds == (0 if count == 2 else (1 if count == 3 else 2)), "Diamond reward tier incorrect")


## 通过场景按钮验证开局、取消、隐藏、暂停、离树以及完整界面操作。
func _check_ui_lifecycle() -> void:
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	root.add_child(page)
	await process_frame
	await process_frame
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(page.session.started and not page._busy and page.get_node("Stage/Order3") != null, "Initial animation/four demand scene failed")
	page.get_node("Stage/Boxes/Box0").pressed.emit()
	_expect(page.selected_box == 0, "Source selection not wired")
	page.hide()
	page.show()
	_expect(page.selected_box == -1, "Hide retained selection")
	page.get_node("Stage/Top").pressed.emit()
	page.get_node("Stage/Boxes/Box0").pressed.emit()
	_expect(page.get_node("Stage/Modal").visible, "Top choices missing")
	page.get_node("Stage/Modal/Card/Resume").pressed.emit()
	_expect(page.session.tools.top == 3, "Cancel spent a top charge")
	page.get_node("Stage/Boxes/Box0").pressed.emit()
	page.get_node("Stage/Boxes/Box12").pressed.emit()
	var state: Dictionary = page.session.snapshot()
	page.hide()
	page.show()
	_expect(not page._busy and page.session.snapshot() == state, "Animation interruption changed committed transaction")
	page.get_node("Stage/Undo").pressed.emit()
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(page.session.moves == 0 and page.session.completed == 0, "Undo did not restore UI session")
	page.get_node("Stage/Boxes/Box0").pressed.emit()
	paused = true
	_expect(page.selected_box == -1, "Pause kept transient selection")
	paused = false
	page.get_node("Stage/Pause").pressed.emit()
	_expect(page.get_node("Stage/Modal/Card/Choices").get_child_count() == 3, "Level selection missing")
	page.get_node("Stage/Modal/Card/Choices").get_child(1).pressed.emit()
	await process_frame
	await process_frame
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(page.session.level_index == 1 and page.session.demands[3].open, "Level selection not connected to the revised second level")
	page.get_node("Stage/Top").pressed.emit()
	page.get_node("Stage/Boxes/Box2").pressed.emit()
	var hidden_choice: Button = page.get_node("Stage/Modal/Card/Choices").get_child(1)
	_expect(hidden_choice.disabled and hidden_choice.icon == DonutBox.HIDDEN, "Top modal leaked hidden flavor")
	page.get_node("Stage/Modal/Card/Resume").pressed.emit()
	page._toast("上关反馈")
	page.session.load_level(0)
	_expect(not page.get_node("Stage/Toast").visible, "Starting another level retained previous feedback")
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var fixture_path: String = get_script().resource_path.get_base_dir().path_join("../../fixtures/donut_sort/level_01_solution.json")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	for step: Array in fixture.steps:
		page.get_node("Stage/Boxes/Box%d" % int(step[0])).pressed.emit()
		page.get_node("Stage/Boxes/Box%d" % int(step[1])).pressed.emit()
		page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(page.session.is_won(), "UI actions failed to finish level")
	page.queue_free()
	await process_frame


## 用真实视口输入复现拖拽，验证鼠标、触摸、取消与点击共存。
func _check_pointer_input() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	await _reset_pointer_page(page)
	var source: Vector2 = _box_point(page, 0)
	var target: Vector2 = _box_point(page, 1)
	var before: Dictionary = page.session.snapshot()
	await _mouse_button(viewport, source, true)
	await _mouse_motion(viewport, target)
	_expect(page.session.snapshot() == before, "Dragging committed before release")
	_check_art_aspect(page.get_node("Stage/Effects"))
	await _mouse_button(viewport, target, false)
	_expect(page.session.moves == 1 and page.session.slots[1].box.items.size() == 3, "Mouse drag failed to move visible same-flavor group")
	_check_art_aspect(page.get_node("Stage/Effects"))
	await _reset_pointer_page(page)
	await _mouse_button(viewport, source, true)
	await _mouse_motion(viewport, source + Vector2(2, 2))
	await _mouse_button(viewport, source + Vector2(2, 2), false)
	await _mouse_button(viewport, target, true)
	await _mouse_button(viewport, target, false)
	_expect(page.session.moves == 1, "Small pointer jitter broke two-tap movement")
	for invalid_target: Vector2 in [Vector2(5, 5), _box_point(page, 2), source, _box_point(page, 14)]:
		await _reset_pointer_page(page)
		before = page.session.snapshot()
		await _mouse_drag(viewport, source, invalid_target)
		_expect(page.session.snapshot() == before, "Invalid drag changed food, tools or selection transaction")
	await _reset_pointer_page(page)
	before = page.session.snapshot()
	await _touch(viewport, source, true, 0)
	await _touch_motion(viewport, target, 0)
	await _touch(viewport, _box_point(page, 14), true, 1)
	await _touch(viewport, _box_point(page, 14), false, 1)
	_expect(page.session.snapshot() == before, "Second finger committed or activated a tool")
	await _touch(viewport, target, false, 0, true)
	_expect(page.session.snapshot() == before, "Canceled touch committed a transfer")
	await _touch(viewport, source, true, 0)
	await _mouse_button(viewport, source, true, InputEvent.DEVICE_ID_EMULATION)
	await _touch_motion(viewport, target, 0)
	await _touch(viewport, target, false, 0)
	await _mouse_button(viewport, target, false, InputEvent.DEVICE_ID_EMULATION)
	_expect(page.session.moves == 1 and page.session.slots[1].box.items.size() == 3, "Touch drag failed or generated a duplicate mouse action")
	for interruption: String in ["focus", "hide", "pause", "escape"]:
		await _reset_pointer_page(page)
		before = page.session.snapshot()
		await _mouse_button(viewport, source, true)
		await _mouse_motion(viewport, target)
		match interruption:
			"focus": page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"hide":
				page.hide()
				page.show()
			"pause":
				paused = true
				paused = false
			"escape":
				var cancel := InputEventAction.new()
				cancel.action = "ui_cancel"
				cancel.pressed = true
				viewport.push_input(cancel, true)
		await _mouse_button(viewport, target, false)
		_expect(page.session.snapshot() == before, "Interrupted drag committed on stale release: " + interruption)
		await _mouse_drag(viewport, source, target)
		_expect(page.session.moves == 1, "Input did not recover after drag interruption: " + interruption)
	await _reset_pointer_page(page)
	before = page.session.snapshot()
	await _mouse_drag(viewport, _box_point(page, 14), source)
	_expect(page.session.snapshot() == before, "Dragging locked turnover spent an add-box tool")
	page.initialize(DonutSession.new(_definition([_box([0, 0, 0]), _box([0, 0])])))
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _mouse_drag(viewport, source, target)
	_expect(page.session.moves == 1 and page.session.completed == 1 and page.session.slots[0].box.items.size() == 1, "Drag did not split to target capacity and recycle once")
	await _reset_pointer_page(page)
	await _mouse_button(viewport, source, true)
	await _mouse_motion(viewport, target)
	page.queue_free()
	await process_frame
	await _mouse_button(viewport, target, false)
	viewport.queue_free()
	await process_frame
	print("PASS: mouse/touch drag, capacity split, invalid drops, cancellation and input recovery")


## 正式前两关经鼠标拖拽通关，先借用普通空盒验证新手可见的周转路线。
func _check_early_level_drags() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	root.add_child(viewport)
	var app: Node = load("res://bootstrap/app.tscn").instantiate()
	viewport.add_child(app)
	var page: Control = app.get_node("SceneContainer/HomeScreen")
	await process_frame
	await process_frame
	for index: int in 2:
		page.session.load_level(index)
		page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		var fixture_path: String = get_script().resource_path.get_base_dir().path_join("../../fixtures/donut_sort/level_%02d_solution.json" % (index + 1))
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
		var first: Array = fixture.steps[0]
		var steps: Array = [[first[0], 10], [10, first[1]]] + fixture.steps.slice(1)
		for step: Array in steps:
			var previous_moves: int = page.session.moves
			await _mouse_drag(viewport, _box_point(page, int(step[0])), _box_point(page, int(step[1])))
			_expect(page.session.moves == previous_moves + 1, "Level %d drag %s did not commit" % [index + 1, step])
			page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_expect(page.session.is_won() and page.session.tools == {"undo": 3, "add_box": 2, "top": 3}, "Early-level drag solution did not finish without tools")
	viewport.queue_free()
	await process_frame
	print("PASS: early levels finish through mouse dragging and ordinary empty-box detours")


## 连续切换竖屏尺寸，验证点击区域互不重叠、底部可达且缩放会取消旧拖拽。
func _check_portrait_layout() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 1536)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await _reset_pointer_page(page)
	for dimensions: Vector2i in [Vector2i(720, 1280), Vector2i(720, 1600), Vector2i(1024, 1536)]:
		var before: Dictionary = page.session.snapshot()
		var source: Vector2 = _box_point(page, 0)
		await _mouse_button(viewport, source, true)
		await _mouse_motion(viewport, source + Vector2(30, 30))
		viewport.size = dimensions
		await process_frame
		await process_frame
		await _mouse_button(viewport, _box_point(page, 1), false)
		_expect(page.session.snapshot() == before and not page.board_input.is_active(), "Resize retained a drag or committed its stale release")
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		var boxes: Array[Node] = page.get_node("Stage/Boxes").get_children()
		_check_art_aspect(page)
		var preview: Control = page.get_node("Stage/Dispatch/Preview0")
		_expect(preview.back.get_rect().is_equal_approx(boxes[0].back.get_rect()), "Supply and board use different tray geometry")
		for box: Control in boxes + [preview, page.get_node("Stage/Dispatch/Preview1")]:
			_expect(box.back.get_rect().is_equal_approx(box.front.get_rect()), "Tray front/back geometry diverged")
			_expect(box.back.texture.region == box.front.texture.region, "Tray front/back crop regions diverged")
		for index: int in boxes.size():
			var area: Rect2 = boxes[index].get_global_rect()
			_expect(bounds.encloses(area), "Box outside portrait viewport: %s/%d" % [dimensions, index])
			for other: int in range(index + 1, boxes.size()):
				_expect(not area.intersects(boxes[other].get_global_rect()), "Box hit areas overlap after resize")
		for name: String in ["Undo", "AddBox", "Top"]:
			var button: Control = page.get_node("Stage/" + name)
			_expect(bounds.encloses(button.get_global_rect()), "Tool outside portrait viewport: " + name)
			_expect(not button.get_global_rect().intersects(page.get_node("Stage/Dispatch/NextPlate").get_global_rect()), "Tool overlaps supply panel: " + name)
	viewport.queue_free()
	await process_frame
	print("PASS: native art proportions, shared tray geometry, portrait bounds and resize cancellation")


## 检查真实节点的显示比例，避免容器尺寸正确却把内部素材拉伸；也用于动态食物。
func _check_art_aspect(node: Node) -> void:
	if node is TextureRect or node is TextureButton:
		var texture: Texture2D = node.texture if node is TextureRect else node.texture_normal
		if texture != null:
			var transform: Transform2D = node.get_global_transform()
			_expect(absf(transform.x.length() - transform.y.length()) < 0.001, "Non-uniform art transform: " + str(node.get_path()))
			if node.stretch_mode == 0:
				var source: Vector2 = texture.get_size()
				var scale_delta: float = absf(node.size.x / source.x - node.size.y / source.y)
				_expect(scale_delta < 0.001, "Stretched art: " + str(node.get_path()))
	for child: Node in node.get_children():
		_check_art_aspect(child)


## 每个手势用独立初始状态，保留真实场景与输入路由。
func _reset_pointer_page(page: Control) -> void:
	page.initialize(DonutSession.new(_definition([_box([0, 0, 1]), _box([0]), _box([2])])))
	await process_frame
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame


## 命中顶部甜甜圈中心，使用实际缩放后的视口坐标。
func _box_point(page: Control, index: int) -> Vector2:
	var box: Control = page.get_node("Stage/Boxes").get_child(index)
	return box.get_global_transform_with_canvas() * (box.food_position(0) + DonutBox.FOOD_SIZE * 0.5)


## 派发原生鼠标按下或抬起，不直接触发按钮业务信号。
func _mouse_button(viewport: SubViewport, point: Vector2, pressed: bool, device: int = 0) -> void:
	var event := InputEventMouseButton.new()
	event.device = device
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	viewport.push_input(event, true)
	await process_frame


## 派发按住鼠标后的移动，经过引擎输入分发。
func _mouse_motion(viewport: SubViewport, point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(event, true)
	await process_frame


## 执行一个按下、跨盒移动、抬起的鼠标手势。
func _mouse_drag(viewport: SubViewport, source: Vector2, target: Vector2) -> void:
	await _mouse_button(viewport, source, true)
	await _mouse_motion(viewport, target)
	await _mouse_button(viewport, target, false)


## 派发指定手指的触摸边界，支持系统取消事件。
func _touch(viewport: SubViewport, point: Vector2, pressed: bool, index: int, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	viewport.push_input(event, true)
	await process_frame


## 派发指定手指的触摸移动，不依赖鼠标模拟设置。
func _touch_motion(viewport: SubViewport, point: Vector2, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position = point
	event.index = index
	viewport.push_input(event, true)
	await process_frame
