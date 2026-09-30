extends SceneTree
## 验证全部关卡完整解、玩法边界、逐次回收与页面中断后的状态一致性。

# 数值表“关卡总表”第 6–15 行：盒位、非空盒、空盒、备货、订单、口味、隐藏颗数。
const LEVEL_TARGETS: Array = [
	[8, 4, 2, 0, 3, 2, 0], [6, 3, 1, 0, 3, 2, 0], [7, 4, 1, 0, 4, 3, 0],
	[7, 4, 1, 0, 4, 3, 0], [8, 5, 1, 0, 5, 3, 0], [8, 5, 1, 0, 4, 3, 1],
	[8, 5, 1, 0, 5, 4, 1], [8, 5, 1, 0, 5, 4, 2], [9, 6, 1, 1, 6, 4, 0],
	[7, 4, 1, 2, 6, 4, 0],
]
var _failures: Array[String] = []


## 等待引擎初始化后进入确定性的规则与场景验证。
func _initialize() -> void:
	_run.call_deferred()


## 一次执行全部相关场景，汇总失败而不逐项修改期望。
func _run() -> void:
	_check_content_and_solutions()
	_check_order_slot_unlock()
	_check_early_level_space()
	_check_spare_box_return()
	_check_hidden_box_scope()
	_check_group_move_and_reveal()
	_check_waiting_and_chain()
	_check_mechanisms_and_stock()
	_check_event_boundaries()
	_check_turnover_and_single()
	_check_tools_and_victory()
	_check_failure_rules()
	_check_reward_tiers()
	await _check_currency_and_settings()
	await _check_level_navigation()
	await _check_failure_panel()
	await _check_ui_lifecycle()
	await _check_inline_actions()
	await _check_group_flight()
	await _check_drag_follow_flight()
	await _check_pointer_input()
	await _check_hit_area_and_no_hints()
	await _check_early_level_drags()
	await _check_configured_layouts()
	await _check_portrait_layout()
	await _check_side_refill()
	await _check_order_card_layout()
	await _check_host_safe_area()
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


## 默认创建明牌盒，隐藏层用例显式启用单盒配置。
func _box(flavors: Array, kind: String = "normal", lid: int = 0, hidden_layers: bool = false) -> Dictionary:
	var items: Array = []
	for index: int in flavors.size():
		items.append({"flavor": int(flavors[index])})
	var box: Dictionary = {"kind": kind, "lid": lid, "items": items}
	if hidden_layers:
		box.hidden_layers = true
	return box


## 可操作盒的顶层必须揭示，下层允许保留之前露顶的明牌状态。
func _expect_exposed_tops_revealed(session: DonutSession, context: String) -> void:
	for slot_index: int in session.slots.size():
		var slot: Dictionary = session.slots[slot_index]
		if not session.can_handle(slot_index) or slot.box.items.is_empty():
			continue
		_expect(slot.box.items[0].revealed, "Unrevealed top in %s at box %d" % [context, slot_index])


## 局部规则用明确的可操作空盒夹具，不充当正式关卡配置。
func _definition(boxes: Array = []) -> Dictionary:
	var slots: Array = []
	for index: int in 14:
		slots.append({"kind": "regular", "unlock_after": 0, "box": boxes[index] if index < boxes.size() else _box([])})
	slots.append({"kind": "turnover", "unlock_after": -1, "box": null})
	slots.append({"kind": "turnover", "unlock_after": -1, "box": null})
	slots.append({"kind": "regular", "unlock_after": 0, "box": null})
	return {"title": "规则夹具", "layout_id": "staggered_17", "slots": slots,
		"demands": [{"sequence": [0], "initially_open": true}, {"sequence": [1], "initially_open": true},
			{"sequence": [2], "initially_open": true}, {"sequence": [3], "initially_open": true}],
		"stock": [], "tools": {"undo": 3, "add_box": 2, "top": 3},
		"combo_rewards": [{"count": 2, "coins": 5, "diamonds": 0}, {"count": 3, "coins": 10, "diamonds": 1}, {"count": 4, "coins": 20, "diamonds": 2}]}


## 对照策划表验证十关数量，并在正式会话中重放完整解，锁定周转盒且不使用道具。
func _check_content_and_solutions() -> void:
	var levels: Array = DonutLevel.catalog()
	_expect(levels.size() == 100, "Expected 100 playable content levels")
	_expect(DonutArt.FOOD.size() == DonutLevel.FLAVOR_COUNT, "Supported flavor count and artwork mapping differ")
	var openings: Dictionary = {}
	for index: int in mini(10, levels.size()):
		var expected: Array = LEVEL_TARGETS[index]
		var definition: Dictionary = DonutLevel.load_definition(levels[index].path)
		_expect(DonutLevel.validate(definition).is_empty(), "Content validation failed")
		_expect(int(definition.id) == index + 1 and definition.title == levels[index].title, "Catalog and level identity differ")
		var key: String = JSON.stringify(definition.slots)
		_expect(not openings.has(key), "Repeated opening")
		openings[key] = true
		var session := DonutSession.new(definition)
		session.begin()
		var flavors: Dictionary = {}
		var hidden: int = 0
		var filled: int = 0
		var empty: int = 0
		for slot: Dictionary in session.slots:
			if slot.box == null:
				continue
			filled += 1 if not slot.box.items.is_empty() else 0
			empty += 1 if slot.box.items.is_empty() else 0
			_expect(slot.box.kind == "normal", "Mechanism introduced before its planned teaching level")
			for item: Dictionary in slot.box.items:
				flavors[item.flavor] = true
				hidden += 0 if item.revealed else 1
		for stock: Dictionary in definition.stock:
			for item: Dictionary in stock.items:
				flavors[int(item.flavor)] = true
				hidden += 1 if bool(item.get("hidden", stock.get("hidden_layers", false))) else 0
		_expect(session.slots.size() == expected[0] and filled == expected[1] and empty == expected[2], "Initial box counts differ from planning sheet at level %d" % (index + 1))
		_expect(definition.stock.size() == expected[3] and session.total_orders() == expected[4] and session.total_donuts() == expected[4] * 4, "Stock/order/food counts differ from planning sheet")
		_expect(flavors.size() == expected[5] and hidden == expected[6], "Flavor or concealed count differs from planning sheet")
		_expect(session.slots.filter(func(slot: Dictionary) -> bool: return slot.kind == "turnover" and not slot.open).size() == 2, "Expected two locked turnover positions")
		_expect(session.demands[0].open and session.demands[1].open and not session.demands[2].open and not session.demands[3].open, "Initial demand availability")
		var fixture_path: String = get_script().resource_path.get_base_dir().path_join("../../fixtures/donut_sort/level_%02d_solution.json" % (index + 1))
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
		for step: Array in fixture.steps:
			_expect(session.move(int(step[0]), int(step[1])), "Level %d invalid move %s at %d" % [index + 1, step, session.moves])
			_expect_exposed_tops_revealed(session, "level %d move %d" % [index + 1, session.moves])
			_expect(session.remaining_donuts() + session.completed * 4 == session.total_donuts(), "Food conservation failed")
			for slot_index: int in session.slots.size():
				var slot: Dictionary = session.slots[slot_index]
				_expect(slot.box == null or slot.box.items.size() <= session.capacity(slot_index), "Capacity exceeded")
		_expect(session.is_won() and session.moves == int(fixture.moves), "Full solution failed level %d" % (index + 1))
		_expect(session.slots.filter(func(slot: Dictionary) -> bool: return slot.box != null).size() == expected[1] + expected[2] + expected[3] - expected[4], "Victory container budget")
		_expect(session.tools == {"undo": 1, "add_box": 1, "top": 1}, "Full solution spent tools")
		_expect(not session.move(0, 1) and not session.add_box(), "Won session accepts actions")
		print("PASS: level %d, %d slots, %d moves, %d orders, %d donuts conserved" % [index + 1, session.slots.size(), session.moves, session.completed, session.total_donuts()])
	var valid: Dictionary = DonutLevel.load_definition(levels[0].path)
	var invalid: Dictionary = valid.duplicate(true)
	invalid.slots[0].box.items[0].flavor = 99
	_expect(not DonutLevel.validate(invalid).is_empty(), "Invalid flavor escaped validator")
	invalid = valid.duplicate(true)
	invalid.demands[0].sequence.pop_back()
	_expect(not DonutLevel.validate(invalid).is_empty(), "Unbalanced food escaped validator")
	invalid = valid.duplicate(true)
	invalid.slots[0].box.hidden_layers = "true"
	_expect(not DonutLevel.validate(invalid).is_empty(), "String hidden_layers escaped validator")
	invalid = valid.duplicate(true)
	invalid.slots.pop_back()
	_expect(not DonutLevel.validate(invalid).is_empty(), "Missing second turnover escaped validator")
	invalid = valid.duplicate(true)
	while invalid.slots.size() < 25:
		invalid.slots.append({"kind": "regular", "unlock_after": 0, "box": _box([])})
	_expect(DonutLevel.validate(invalid).is_empty(), "Variable slot count up to 25 rejected")
	invalid.slots.append({"kind": "regular", "unlock_after": 0, "box": _box([])})
	_expect(not DonutLevel.validate(invalid).is_empty(), "26 slots escaped limit")


## 开局普通空盒按逐关表配置，可直接搬入并撤回；不再规定统一的剩余容器数。
func _check_early_level_space() -> void:
	for index: int in mini(10, DonutLevel.catalog().size()):
		var definition: Dictionary = DonutLevel.load_definition(DonutLevel.catalog()[index].path)
		var session := DonutSession.new(definition)
		session.begin()
		var empty_index: int = -1
		for slot_index: int in session.slots.size():
			if session.can_handle(slot_index) and session.slots[slot_index].box.items.is_empty():
				empty_index = slot_index
				break
		_expect(empty_index >= 0 and session.completed == 0, "Opening is blocked or clears itself")
		var before: Dictionary = session.snapshot()
		_expect(session.move(0, empty_index) and session.tools.add_box == 1, "Initial empty box cannot accept food")
		_expect(session.undo() and session.slots == before.slots, "Undo failed to restore opening")


## 使用周转盒中转完整同味组，验证通关归还、数量守恒、撤回和重做。
func _check_spare_box_return() -> void:
	for level_index: int in mini(10, DonutLevel.catalog().size()):
		var definition: Dictionary = DonutLevel.load_definition(DonutLevel.catalog()[level_index].path)
		var path: String = get_script().resource_path.get_base_dir().path_join("../../fixtures/donut_sort/level_%02d_solution.json" % (level_index + 1))
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		definition.tools.undo = 1 # 回滚机制的隔离用例。
		var session := DonutSession.new(definition)
		session.begin()
		var extra_index: int = session.next_turnover()
		_expect(session.resolve_turnover(session.request_turnover(extra_index), true), "Cannot activate turnover at level %d" % (level_index + 1))
		# 部分容量搬运不能简单拆成两步，否则中转盒会拿走原本应留在来源盒的食物。
		var probe := DonutSession.new(definition)
		probe.begin()
		var steps: Array = fixture.steps.duplicate(true)
		var routed: bool = false
		for index: int in steps.size():
			var step: Array = steps[index]
			if probe.move_count(int(step[0]), int(step[1])) == probe.pick_count(int(step[0])):
				steps[index] = [step[0], extra_index]
				steps.insert(index + 1, [extra_index, step[1]])
				routed = true
				break
			probe.move(int(step[0]), int(step[1]))
		_expect(routed, "No complete group available for turnover test")
		var events: Array = []
		session.changed.connect(func(batch: Array) -> void: events.append_array(batch))
		for step: Array in steps.slice(0, -1):
			_expect(session.move(int(step[0]), int(step[1])), "Turnover path failed at level %d" % (level_index + 1))
		_expect(events.all(func(event: Dictionary) -> bool: return event.kind != "spare_return"), "Spare container returned before victory")
		var before: Dictionary = session.snapshot()
		var final_step: Array = steps.back()
		events.clear()
		_expect(session.move(int(final_step[0]), int(final_step[1])) and session.is_won(), "Turnover path did not win level %d" % (level_index + 1))
		var after: Dictionary = session.snapshot()
		var expected: Array = LEVEL_TARGETS[level_index]
		_expect(session.slots.filter(func(slot: Dictionary) -> bool: return slot.box != null).size() == expected[1] + expected[2] + expected[3] - expected[4], "Victory container budget with turnover")
		_expect(events.filter(func(event: Dictionary) -> bool: return event.kind == "spare_return").size() == 1, "Victory did not return exactly one added container")
		_expect(session.completed == session.total_orders() and session.remaining_donuts() == 0, "Spare return affected orders")
		_expect(session.undo() and session.slots == before.slots and session.completed == before.completed and not session.is_won(), "Undo did not restore final move and spare container")
		_expect(session.move(int(final_step[0]), int(final_step[1])) and session.slots == after.slots and session.coins == after.coins and session.diamonds == after.diamonds, "Replaying victory duplicated returns or rewards")
	print("PASS: ten-level turnover use, container conservation, undo and replay")


## 隐藏只作用于指定盒的初始食物，普通盒及补到原位的新盒保留自己的明暗配置。
func _check_hidden_box_scope() -> void:
	var definition: Dictionary = _definition([_box([0, 1, 2], "normal", 0, true), _box([0, 1, 2]), _box([1, 2, 3])])
	definition.slots[2].box.hidden_layers = false
	var session := DonutSession.new(definition)
	session.begin()
	_expect(session.slots[0].box.items[0].revealed and not session.slots[0].box.items[1].revealed and
		not session.slots[0].box.items[2].revealed, "Configured hidden box did not conceal only its lower layers")
	for index: int in [1, 2]:
		_expect(session.slots[index].box.items.all(func(item: Dictionary) -> bool: return item.revealed),
			"Unmarked or explicitly ordinary box hid its lower layers")
	_expect(session.move(1, 0) and session.slots[0].box.items[0].revealed and session.slots[0].box.items[1].revealed and
		not session.slots[0].box.items[2].revealed, "Hidden box concealed a known incoming donut or exposed an untouched layer")
	definition = _definition([_box([0, 0, 0], "normal", 0, true), _box([0])])
	definition.stock = [_box([1, 2, 3])]
	session = DonutSession.new(definition)
	session.begin()
	var before: Dictionary = session.snapshot()
	_expect(session.move(1, 0) and session.completed == 1 and session.remaining_stock() == 0, "Hidden box did not recycle and refill")
	_expect(session.slots[0].box.items.all(func(item: Dictionary) -> bool: return item.revealed),
		"Ordinary stock inherited the old box's hidden layers")
	_expect(session.undo() and session.slots == before.slots, "Undo did not restore original hidden box after refill")
	print("PASS: per-box hidden layers, ordinary boxes, incoming known donuts and refill isolation")


## 连续同味明牌按容量整组搬运，灰色边界、新备货及不同口味均不追加到本次操作。
func _check_group_move_and_reveal() -> void:
	var session := DonutSession.new(_definition([_box([0, 0, 1]), _box([0])]))
	session.begin()
	var before: Dictionary = session.snapshot()
	var events: Array = []
	session.changed.connect(func(batch: Array) -> void: events.append_array(batch))
	_expect(session.pick_count(0) == 2 and session.move_count(0, 1) == 2 and session.move(0, 1), "Contiguous known group did not move")
	_expect(session.slots[0].box.items.size() == 1 and session.slots[1].box.items.size() == 3 and session.moves == 1,
		"Group movement was not one transaction")
	_expect(events.size() == 1 and events[0].count == 2 and events[0].items.size() == 2, "Group event lost its moved items")
	_expect(session.undo() and session.slots == before.slots and session.moves == 0 and session.tools.undo == 2,
		"Undo did not restore the entire group in one operation")
	for occupied: int in range(1, 4):
		var target: Array = []
		target.resize(occupied)
		target.fill(0)
		session = DonutSession.new(_definition([_box([0, 0, 0]), _box(target)]))
		session.begin()
		_expect(session.move_count(0, 1) == 4 - occupied and session.move(0, 1), "Group size ignored target capacity")
		_expect(session.slots[0].box.items.size() == occupied - 1 and session.completed == 1 and session.slots[1].box == null,
			"Capacity-limited group exceeded the target or recycled twice")
	before = session.snapshot()
	_expect(not session.move(0, 1) and not session.move(-1, 0) and not session.move(0, 0), "Empty slot or invalid index accepted")
	_expect(session.snapshot() == before, "Invalid operation mutated state")
	session = DonutSession.new(_definition([_box([0, 1, 0]), _box([0])]))
	session.begin()
	_expect(session.move_count(0, 1) == 1 and session.move(0, 1) and session.slots[0].box.items.size() == 2,
		"Move skipped a different flavor to pick a deeper match")
	var definition: Dictionary = _definition([_box([0, 0, 0], "normal", 0, true), _box([0])])
	definition.demands[0].sequence = [1] # 保留满盒，以独立检查明牌被再次覆盖后的状态。
	session = DonutSession.new(definition)
	session.begin()
	before = session.snapshot()
	_expect(session.pick_count(0) == 1 and session.move(0, 1), "Top donut did not stop at hidden boundary")
	_expect(session.slots[0].box.items.size() == 2 and session.slots[0].box.items[0].revealed, "Exposed layer not revealed")
	_expect(session.slots[1].box.items.size() == 2 and not session.slots[0].box.items[1].revealed,
		"Newly exposed or deeper hidden donut joined the same action")
	var after_reveal: Dictionary = session.snapshot()
	_expect(session.move(1, 0) and session.pick_count(0) == 3 and session.slots[0].box.items[2].revealed
		and not session.slots[0].box.items[3].revealed, "Re-covering a known donut erased knowledge or leaked hidden flavor")
	_expect(session.move(0, 2) and session.slots[2].box.items.size() == 3 and session.slots[0].box.items.size() == 1
		and session.slots[0].box.items[0].revealed, "Known prefix failed to stop before the concealed fourth donut")
	_expect(session.undo() and session.undo() and session.slots == after_reveal.slots, "Undo erased prior revealed knowledge")
	_expect(session.undo() and session.slots == before.slots, "Undo did not restore hidden knowledge")
	_expect_exposed_tops_revealed(session, "group move undo")
	var emptying := DonutSession.new(_definition([_box([1, 1]), _box([])]))
	emptying.begin()
	_expect(emptying.move(0, 1) and emptying.slots[0].box != null and emptying.slots[0].box.items.is_empty()
		and emptying.slots[1].box.items.size() == 2, "Moving a whole group removed its empty container")
	definition = _definition([_box([0, 0, 0]), _box([0, 0, 0])])
	definition.stock = [_box([0])]
	session = DonutSession.new(definition)
	session.begin()
	_expect(session.move(0, 1) and session.slots[0].box.items.size() == 2 and session.slots[1].box.items.size() == 1
		and session.moves == 1 and session.completed == 1, "Group continued into freshly refilled stock")
	print("PASS: contiguous groups, capacity clipping, hidden boundaries, preserved knowledge and atomic undo")


## 已凑齐等待不锁取放，固定需求位置可自动连续回收三盒且只更新自己。
func _check_waiting_and_chain() -> void:
	var definition: Dictionary = _definition([_box([0, 0, 0]), _box([0]), _box([3, 3, 3, 3]), _box([2, 2, 2, 2])])
	definition.demands = [{"sequence": [0, 3, 2], "initially_open": true}, {"sequence": [1], "initially_open": true},
		{"sequence": [], "initially_open": true}, {"sequence": [], "initially_open": true}]
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
	definition.demands[3].initially_open = false
	session = DonutSession.new(definition)
	session.begin()
	_expect(session.demand_flavor(3) == -1 and session.completed == 0, "Locked demand participated in matching")
	session.move(1, 0)
	_expect(not session.demands[3].open and session.completed == 1 and session.is_waiting(2), "Completing orders unlocked a reserved slot")
	_expect(session.unlock_order_slot(3) and session.completed == 2, "Explicit unlock did not settle a matching waiting box")


## 默认只开左侧两位，显式解锁幂等且与后续回收一起撤回，重开恢复配置。
func _check_order_slot_unlock() -> void:
	var definition: Dictionary = _definition([_box([2, 2, 2, 2])])
	for position: Dictionary in definition.demands:
		position.erase("initially_open")
	var session := DonutSession.new(definition)
	_expect(not session.unlock_order_slot(2), "Order slot unlocked before the session began")
	session.begin()
	_expect(session.demands[0].open and session.demands[1].open and not session.demands[2].open and not session.demands[3].open,
		"Missing initial state must default to two open slots")
	_expect(session.completed == 0 and session.is_waiting(0) and session.demand_flavor(2) == -1,
		"Locked slot matched or exposed a pending order")
	var before: Dictionary = session.snapshot()
	var events: Array = []
	session.changed.connect(func(batch: Array) -> void: events.append_array(batch))
	_expect(not session.unlock_order_slot(-1) and not session.unlock_order_slot(4) and not session.unlock_order_slot(0)
		and session.snapshot() == before and events.is_empty() and not session.can_undo(), "Invalid unlock changed session or undo history")
	_expect(session.unlock_order_slot(2) and session.completed == 1 and session.demands[2].open
		and not session.demands[3].open and session.total_orders() == 4, "Explicit unlock did not settle only its own pending order")
	_expect(events[0].kind == "demand_unlock" and events[0].index == 2 and session.tools == before.tools,
		"Unlock hook lost its event or introduced an unspecified cost")
	var after: Dictionary = session.snapshot()
	events.clear()
	_expect(not session.unlock_order_slot(2) and session.snapshot() == after and events.is_empty(), "Repeated unlock produced duplicate effects")
	_expect(session.undo() and session.demands == before.demands and session.slots == before.slots and session.completed == 0,
		"Undo did not restore the locked slot and dispatched box together")
	_expect(session.unlock_order_slot(2), "Unlock could not be repeated after undo")
	session.restart()
	_expect(not session.demands[2].open and not session.demands[3].open and session.completed == 0, "Restart kept a temporary unlock")
	var invalid: Dictionary = DonutLevel.load_definition(DonutLevel.catalog()[0].path)
	invalid.demands[2].initially_open = "false"
	_expect(not DonutLevel.validate(invalid).is_empty(), "Invalid initial order slot state escaped validation")
	invalid.demands[2].initially_open = false
	invalid.demands[2].unlock_after = 1
	_expect(not DonutLevel.validate(invalid).is_empty(), "Obsolete automatic order unlock escaped validation")
	print("PASS: two default order slots, explicit unlock, idempotency, undo and restart")


## 机关只作用于事件发生时在场的旧盒，每次原位补入一盒而非填充任意空盒。
func _check_mechanisms_and_stock() -> void:
	var definition: Dictionary = _definition([_box([0, 0, 0]), _box([0]), _box([1], "lid", 2),
		_box([2], "lid", 3), _box([3], "frozen"), _box([2], "frozen")])
	definition.stock = [_box([1, 2], "lid", 3), _box([3, 0], "frozen")]
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
	_expect(session.slots[2].box.lid == 1 and session.slots[3].box.lid == 3, "Only first numbered target should decrement")
	_expect(not session.slots[4].box.frozen and session.slots[5].box.frozen, "Expected one lowest-index frozen box thawed")
	_expect(session.move(4, 6) and session.remaining_stock() == 1 and session.completed == 1, "Moving empty source triggered refill/mechanisms")
	_expect(session.undo() and session.undo() and session.slots[2].box.lid == 2 and session.slots[4].box.frozen, "Undo failed to restore mechanisms")
	definition = _definition([_box([0, 0, 0]), _box([0]), _box([1, 1, 1, 1], "lid", 1)])
	session = DonutSession.new(definition)
	session.begin()
	session.move(1, 0)
	_expect(session.completed == 2 and session.slots[2].box == null, "Newly opened matching box did not recycle once")


## 验证同口味需求优先级、新入场冰冻保护以及跨操作不累计连单。
func _check_event_boundaries() -> void:
	var definition: Dictionary = _definition([_box([0, 0, 0]), _box([0]), _box([1, 1, 1]), _box([1])])
	definition.demands[1].sequence = [0, 1]
	definition.stock = [_box([2, 3], "frozen")]
	definition.slots[4].box = _box([2, 3], "frozen")
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
	definition.demands = [{"sequence": [1, 0], "initially_open": true}, {"sequence": [], "initially_open": true},
		{"sequence": [], "initially_open": true}, {"sequence": [], "initially_open": true}]
	definition.stock = [_box([2, 3]), _box([1, 2])]
	session = DonutSession.new(definition)
	session.begin()
	_expect(session.add_box() and session.slots[14].open and session.slots[14].box.items.is_empty(), "Turnover unlock failed")
	_expect(session.remaining_stock() == 2 and session.slots.size() == 17, "Unlock consumed stock or grew board")
	_expect(session.move_count(0, 14) == 4 and session.move(0, 14), "Turnover rejected a four-donut group")
	var turnover_id: int = session.slots[14].box.id
	_expect(session.is_waiting(14), "Full turnover should wait for matching demand")
	session.move(2, 1)
	_expect(session.completed == 2 and session.remaining_stock() == 0 and session.slots[14].box.id != turnover_id, "Turnover recycle did not refill in place")
	_expect(session.slots[0].box != null and session.slots[0].box.items.is_empty(), "Source empty box was consumed")
	_expect(session.add_box() and not session.add_box() and session.slots.size() == 17, "Turnover tool exceeded two locked positions")


## 灰色层可盲选置顶，撤回恢复完整状态，通关不能遗漏需求或备货。
func _check_tools_and_victory() -> void:
	var session := DonutSession.new(_definition([_box([0, 1, 2], "normal", 0, true)]))
	session.begin()
	var before: Dictionary = session.snapshot()
	_expect(not session.bring_to_top(0, 0) and not session.bring_to_top(0, 3) and session.snapshot() == before,
		"Invalid top selection spent a tool")
	_expect(session.can_bring_to_top(0, 1) and session.can_bring_to_top(0, 2), "Gray lower layers cannot be selected")
	_expect(session.bring_to_top(0, 1) and session.slots[0].box.items[0].flavor == 1 and
		session.slots[0].box.items[0].revealed and session.slots[0].box.items[1].revealed and
		not session.slots[0].box.items[2].revealed,
		"Topping did not preserve known flavors and conceal untouched layers")
	_expect_exposed_tops_revealed(session, "blind top")
	_expect(session.undo() and session.slots == before.slots and session.tools.top == 3 and session.tools.undo == 2, "Top undo incorrect")
	_expect_exposed_tops_revealed(session, "top undo")
	_expect(session.bring_to_top(0, 2) and session.slots[0].box.items[0].flavor == 2, "Deeper gray layer could not be topped")
	_expect_exposed_tops_revealed(session, "deep blind top")
	session.add_box()
	session.undo()
	_expect(not session.slots[14].open and session.slots[14].box == null and session.tools.undo == 1, "Turnover undo restored incorrect container or credits")
	var same_flavor := DonutSession.new(_definition([_box([0, 0], "normal", 0, true)]))
	same_flavor.begin()
	_expect(same_flavor.bring_to_top(0, 1), "Same-flavor gray layer could not be revealed by topping")
	var known_before: Dictionary = same_flavor.snapshot()
	_expect(not same_flavor.bring_to_top(0, 1) and same_flavor.snapshot() == known_before,
		"Reordering identical known donuts spent a tool")
	var definition: Dictionary = _definition()
	session = DonutSession.new(definition)
	session.begin()
	_expect(not session.is_won(), "Empty board ignored unfinished demand")
	definition.demands = [{"sequence": [], "initially_open": true}, {"sequence": [], "initially_open": true},
		{"sequence": [], "initially_open": true}, {"sequence": [], "initially_open": true}]
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
	var initial: Dictionary = session.snapshot()
	_expect(session.tools == {"undo": 1, "add_box": 1, "top": 1}, "Level must provide one use of each tool")
	var turnover: int = session.next_turnover()
	_expect(session.add_box() and session.slots[turnover].open and session.tools.add_box == 0, "Add-box tool did not open a turnover box")
	_expect(not session.add_box(), "Exhausted add-box tool can be spent twice")
	_expect(session.undo() and session.slots == initial.slots and session.tools.add_box == 1 and session.tools.undo == 0, "Undo did not restore the add-box transaction")
	_expect(not session.undo(), "Exhausted undo can be spent twice")
	var top_source: int = -1
	var top_item: int = -1
	for source: int in session.slots.size():
		if not session.can_handle(source):
			continue
		for item: int in range(1, session.slots[source].box.items.size()):
			if DonutTopRules.can_reorder(session.slots[source].box.items, item):
				top_source = source
				top_item = item
				break
		if top_source >= 0:
			break
	_expect(top_source >= 0 and session.bring_to_top(top_source, top_item) and session.tools.top == 0, "Top tool did not reorder a real level")
	_expect(not session.bring_to_top(top_source, 1), "Exhausted top tool can be spent twice")
	session.restart()
	_expect(session.completed == 0 and session.moves == 0 and session.coins == 0
		and session.tools == {"undo": 1, "add_box": 1, "top": 1}, "Restart did not restore tool uses")


## 用一次真实搬运形成堵塞，避免直接改写会话的结束标记。
func _failure_definition() -> Dictionary:
	var boxes: Array = [_box([0, 1, 1, 1]), _box([0, 2, 2])]
	for index: int in 12:
		boxes.append(_box([2, 3, 4, 5]))
	var definition: Dictionary = _definition(boxes)
	definition.tools = {"undo": 0, "add_box": 0, "top": 0}
	return definition


## 无合法操作才判负，三种补救道具必须按实际可用性保留机会。
func _check_failure_rules() -> void:
	var definition: Dictionary = _failure_definition()
	var session := DonutSession.new(definition)
	_expect(not session.is_failed(), "Unstarted level was marked failed")
	session.begin()
	_expect(not session.is_failed() and session.move(0, 1), "Failure fixture has no opening move")
	_expect(session.is_blocked() and not session.is_failed() and not session.is_won(), "Stall must not fail")
	session.restart()
	_expect(not session.is_failed() and session.moves == 0, "Restart retained failure")
	for tool: String in ["undo", "add_box", "top"]:
		definition = _failure_definition()
		definition.tools[tool] = 1
		session = DonutSession.new(definition)
		session.begin()
		session.move(0, 1)
		_expect(session.is_blocked() and not session.is_failed(), "Usable %s tool did not prevent failure" % tool)
		if tool == "undo":
			_expect(session.undo() and not session.is_blocked(), "Undo did not recover from blockage")
		elif tool == "add_box":
			_expect(session.add_box() and not session.is_blocked(), "Additional box did not recover from blockage")
		else:
			_expect(session.bring_to_top(2, 1) and not session.is_failed(), "Stall after tools must not fail")
	definition = _failure_definition()
	definition.tools = {"undo": 1, "add_box": 1, "top": 1}
	for slot: Dictionary in definition.slots:
		slot.box = _box([6, 6, 6, 6])
		slot.kind = "regular"
		slot.unlock_after = 0
	session = DonutSession.new(definition)
	session.begin()
	_expect(not session.is_failed(), "Stall without usable tools must not fail")
	print("PASS: failure only after no moves and no usable recovery tools")


## 验证真实失败触发、遮罩、窄屏布局、取消恢复及主页接口和重试。
func _check_failure_panel() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	var bomb_definition: Dictionary = _failure_definition()
	bomb_definition.slots[2].box.kind = "bomb"
	bomb_definition.slots[2].box.bomb_seconds = 1.0
	page.initialize(DonutSession.new(bomb_definition))
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	page.session.move(0, 1)
	page.session.advance_clock(1.0)
	_expect(not page.failure_panel.visible, "Failure opened before the last move finished presenting")
	page.event_player._animation.custom_step(30.0)
	await process_frame
	var panel: DonutFailurePanel = page.failure_panel
	var home_requests: Array = []
	page.home_requested.connect(func() -> void: home_requests.append(true))
	_expect(panel.visible and not page.completion_view.visible and not page._board_input_enabled(), "Failure did not lock underlying board input")
	var failed_state: Dictionary = page.session.snapshot()
	for dimensions: Vector2i in [Vector2i(320, 568), Vector2i(360, 640), Vector2i(393, 852), Vector2i(440, 956), Vector2i(1024, 1536)]:
		viewport.size = dimensions
		await process_frame
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		var card: Rect2 = panel.get_node("Card").get_global_rect()
		_expect(bounds.encloses(card) and card.get_center().distance_to(bounds.get_center()) < 1.0,
			"Failure card clipped or not centered at %s" % dimensions)
		_expect(card.size.x <= bounds.size.x * 0.80 + 0.01 and card.size.y <= bounds.size.y * 0.58 + 0.01,
			"Failure card obscures too much of the board at %s" % dimensions)
		for path: String in ["Home", "TryAgain"]:
			var button: Rect2 = panel.get_node("Card/" + path).get_global_rect()
			_expect(card.encloses(button) and button.size.y >= 44, "Failure button too small or clipped: " + path)
		_expect(not panel.get_node("Card/Home").get_global_rect().intersects(panel.get_node("Card/TryAgain").get_global_rect()),
			"Failure buttons overlap")
		_check_art_aspect(panel)
	await _mouse_button(viewport, Vector2(8, 8), true)
	await _mouse_button(viewport, Vector2(8, 8), false)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	page._unhandled_input(cancel)
	page._on_box_pressed(0)
	page._on_add_box_pressed()
	_expect(panel.visible and page.session.snapshot() == failed_state, "Backdrop, back key or board input bypassed failure")
	var retry: TextureButton = panel.get_node("Card/TryAgain")
	var point: Vector2 = retry.get_global_rect().get_center()
	await _touch(viewport, point, true, 0)
	await _touch(viewport, point, false, 0, true)
	await process_frame
	_expect(panel.visible and page.session.snapshot() == failed_state and retry.self_modulate == Color.WHITE,
		"Canceled retry touch restarted or left pressed feedback")
	page.hide()
	page.show()
	paused = true
	paused = false
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	_expect(panel.visible and page.session.snapshot() == failed_state, "Hide/pause/focus interruption lost failure")
	await _mouse_button(viewport, panel.get_node("Card/Home").get_global_rect().get_center(), true)
	await _mouse_button(viewport, panel.get_node("Card/Home").get_global_rect().get_center(), false)
	await process_frame
	_expect(panel.visible and not page.settings_panel.visible and home_requests.size() == 1
		and page.session.snapshot() == failed_state and not retry.disabled, "Home did not preserve failure and forward the reserved navigation signal")
	await _touch(viewport, point, true, 0)
	await _touch(viewport, point, false, 0)
	await process_frame
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	_expect(not panel.visible and page.session.moves == 0 and not page.session.is_failed()
		and page.session.coins == 0 and page.session.tools == {"undo": 0, "add_box": 0, "top": 0}, "Retry did not restore the current level")
	page.session.move(0, 1)
	page.session.advance_clock(1.0)
	page.hide()
	page.show()
	await process_frame
	_expect(panel.visible, "Interrupting the losing animation skipped failure")
	page.session.load_level(1)
	await process_frame
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	_expect(page.session.level_index == 1 and not panel.visible and not page.settings_panel.visible
		and page._board_input_enabled(), "Loading a fresh level did not clear failure and restore input")
	viewport.queue_free()
	await process_frame
	print("PASS: failure panel layout, cancellation, lifecycle, reserved Home signal and Try Again")


## 验证二连、三连、四连及以上只结算对应最高奖励档位。
func _check_reward_tiers() -> void:
	for count: int in [2, 3, 4, 5]:
		var boxes: Array = [_box([0, 0, 0]), _box([0])]
		var sequence: Array = [0]
		for index: int in count - 1:
			boxes.append(_box([3, 3, 3, 3]))
			sequence.append(3)
		var definition: Dictionary = _definition(boxes)
		definition.demands = [{"sequence": sequence, "initially_open": true}, {"sequence": [], "initially_open": true},
			{"sequence": [], "initially_open": true}, {"sequence": [], "initially_open": true}]
		var session := DonutSession.new(definition)
		session.begin()
		session.move(1, 0)
		_expect(session.last_combo == count and session.completed == count, "Combo length incorrect")
		_expect(session.coins == (5 if count == 2 else (10 if count == 3 else 20)), "Coin reward tier incorrect")
		_expect(session.diamonds == (0 if count == 2 else (1 if count == 3 else 2)), "Diamond reward tier incorrect")


## 金币显示暂时隐藏，奖励与撤回仍可正确结算且设置保持可操作。
func _check_currency_and_settings() -> void:
	var definition: Dictionary = _definition([_box([0, 0, 0]), _box([0]), _box([3, 3, 3, 3]), _box([2, 2, 2, 2])])
	definition.demands = [{"sequence": [0, 3, 2], "initially_open": true}, {"sequence": [1], "initially_open": true},
		{"sequence": [], "initially_open": true}, {"sequence": [], "initially_open": true}]
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	page.initialize(DonutSession.new(definition))
	root.add_child(page)
	await process_frame
	await process_frame
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var coin_balance: DonutCoinBalance = page.get_node("Stage/CoinBalance")
	_expect(not coin_balance.visible and coin_balance.get_node("Amount").text == "0", "Opening coin balance was not hidden")
	coin_balance.present(1280)
	_expect(coin_balance.get_node("Amount").text == "1,280", "Coin balance thousands separator is incorrect")
	page._render()
	_expect(coin_balance.get_node("Amount").text == "0", "Coin balance ignored the session snapshot")
	var displayed_feedback: Array[String] = []
	var toast: Control = page.get_node("Stage/Toast")
	toast.visibility_changed.connect(func() -> void:
		if toast.visible:
			displayed_feedback.append(toast.get_node("Message").text))
	_expect(page.session.move(1, 0) and page.session.coins == 10, "Reward fixture did not produce coins")
	page.event_player._animation.custom_step(30.0)
	_expect(page.get_node("Stage/Toast/Message").text == "3 连单！" and not coin_balance.visible,
		"Combo feedback exposed hidden currency rewards")
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(coin_balance.get_node("Amount").text == "10", "Coin balance did not follow combo reward")
	page.get_node("Stage/Settings").pressed.emit()
	var panel: DonutSettingsPanel = page.get_node("Stage/SettingsPanel")
	_expect(panel.visible and panel.get_node("Card/Heading").text == "游戏设置", "Gear did not open settings")
	_expect(not panel.get_node("Card/Detail").text.contains("金币") and not panel.get_node("Card/Detail").text.contains("钻石"),
		"Settings exposed hidden currency balances")
	_expect(panel.get_node("Card/Choices").get_child_count() == 10, "Settings cannot select all ten levels")
	panel.get_node("Card/Resume").pressed.emit()
	_expect(not panel.visible, "Settings return did not close the panel")
	_expect(page.session.undo() and page.session.coins == 0, "Reward fixture undo failed")
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(coin_balance.get_node("Amount").text == "0", "Undo did not restore coin balance")
	_expect(page.session.move(1, 0) and page.session.coins == 10, "Reward fixture could not replay before restart")
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	page.get_node("Stage/Settings").pressed.emit()
	panel.get_node("Card/Restart").pressed.emit()
	page.lesson_dialog._answer(true)
	await process_frame
	await process_frame
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(page.session.moves == 0 and page.session.coins == 0 and coin_balance.get_node("Amount").text == "0" and not coin_balance.visible,
		"Settings restart did not reset the level and coin balance")
	page.queue_free()
	await process_frame


## 验证十关菜单完整可见、真实点击选关，以及第三、九、十关的结算导航边界。
func _check_level_navigation() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 640)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var panel: DonutSettingsPanel = page.settings_panel
	var choices: GridContainer = panel.get_node("Card/Choices")
	for dimensions: Vector2i in [Vector2i(360, 640), Vector2i(720, 1280), Vector2i(1024, 1536)]:
		viewport.size = dimensions
		await process_frame
		page._show_level_menu()
		await process_frame
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		var card: Rect2 = panel.get_node("Card").get_global_rect()
		var footer: Rect2 = panel.get_node("Card/Resume").get_global_rect()
		_expect(bounds.encloses(card), "Ten-level menu leaves viewport at %s" % dimensions)
		_expect(absf(card.get_center().y - bounds.get_center().y) < 1.0, "Expanded menu is not vertically centered")
		for button: Button in choices.get_children():
			var area: Rect2 = button.get_global_rect()
			_expect(card.encloses(area) and area.end.y < footer.position.y and area.size.y >= 44,
				"Level button is clipped, overlaps footer or is too small: %s at %s" % [button.text, dimensions])
			for other: Button in choices.get_children():
				_expect(button == other or not area.intersects(other.get_global_rect()), "Level buttons overlap")
		panel.close()
	viewport.size = Vector2i(360, 640)
	await process_frame
	for index: int in DonutLevel.catalog().size():
		page._show_level_menu()
		await process_frame
		panel.page_index = index / 10
		panel._show_page()
		await process_frame
		var point: Vector2 = choices.get_child(index % 10).get_global_rect().get_center()
		await _mouse_button(viewport, point, true)
		await _mouse_button(viewport, point, false)
		page.lesson_dialog._answer(true)
		await process_frame
		page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_expect(page.session.level_index == index and not panel.visible and page.session.moves == 0,
			"Menu click did not load level %d" % (index + 1))
		_expect(page.get_node("Stage/Title").text == "第 %d 关" % (index + 1), "Header shows wrong level number")
		_expect(page.session.tools == {"undo": 1, "add_box": 1, "top": 1}, "Level selection did not reset tool uses")
	for index: int in [2, 8, 9, 99]:
		_expect(page.session.load_level(index), "Cannot load navigation boundary level")
		page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		var path: String = get_script().resource_path.get_base_dir().path_join("../../fixtures/donut_sort/level_%02d_solution.json" % (index + 1))
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for step: Array in fixture.steps:
			_expect(page.session.move(int(step[0]), int(step[1])), "Navigation solution failed")
			if page.session.is_won():
				page.event_player._animation.custom_step(30.0)
			else:
				page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		var next: Button = page.get_node("Stage/Completion/Continue")
		_expect(page.completion_view.visible and page.session.is_won() and not page.settings_panel.visible and not page.failure_panel.visible, "Completion did not stay inline on the table")
		_expect(page.get_node_or_null("Stage/Modal") == null, "Normal gameplay modal returned")
		_expect(next.visible == (index == 99) and next.text == "再玩一遍", "Only the final level should offer replay")
		var completed: Dictionary = page.session.snapshot()
		page.hide()
		page.show()
		page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_expect(page.completion_view.visible and page.session.snapshot() == completed and page.get_node("AdvanceTimer").is_stopped(), "Inactive page lost completion or retained automatic navigation")
		page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		await process_frame
		await process_frame
		if index < 99:
			_expect(not page.get_node("AdvanceTimer").is_stopped(), "Returning to completed level did not resume feedback")
			page.settings_button.pressed.emit()
			_expect(page.settings_panel.visible and page.get_node("AdvanceTimer").is_stopped(), "Settings did not suspend automatic advancement")
			page.get_node("AdvanceTimer").timeout.emit()
			await process_frame
			_expect(page.session.snapshot() == completed, "Settings allowed a background level change")
			page.settings_panel.close()
			_expect(not page.get_node("AdvanceTimer").is_stopped(), "Closing settings did not resume feedback")
			paused = true
			_expect(page.get_node("AdvanceTimer").is_stopped(), "Pause retained automatic navigation")
			paused = false
			await process_frame
			page.get_node("AdvanceTimer").timeout.emit()
			page.hide()
			await process_frame
			_expect(page.session.snapshot() == completed, "Queued navigation ran after hiding the page")
			page.show()
			page.get_node("AdvanceTimer").timeout.emit()
			page.get_node("AdvanceTimer").timeout.emit()
		else:
			_expect(page.get_node("AdvanceTimer").is_stopped(), "Last level automatically restarted")
			var point: Vector2 = next.get_global_rect().get_center()
			await _mouse_button(viewport, point, true)
			await _mouse_button(viewport, point, false)
		await process_frame
		page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_expect(page.session.level_index == mini(index + 1, 99) and page.session.moves == 0 and not page.session.is_won(),
			"Next/replay navigation did not load the correct fresh level")
	viewport.queue_free()
	await process_frame
	print("PASS: ten-level menu, automatic level 3/9 advance, interrupted feedback and explicit level 10 replay")


## 底部选择不遮挡餐台，支持切盒、取消、设置与生命周期中断且不误扣道具。
func _check_inline_actions() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 640)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	page.initialize(DonutSession.new(_definition([_box([0, 1, 2, 3]), _box([1]), _box([2]), _box([3]), _box([0, 1, 2, 3], "normal", 0, true)])))
	page._cancel_interaction()
	var before: Dictionary = page.session.snapshot()
	for dimensions: Vector2i in [Vector2i(360, 640), Vector2i(720, 1600), Vector2i(1024, 1536)]:
		viewport.size = dimensions
		await process_frame
		page._cancel_interaction()
		page.tools_view.get_node("Top").pressed.emit()
		await _mouse_button(viewport, _box_point(page, 0), true)
		await _mouse_button(viewport, _box_point(page, 0), false)
		await process_frame
		_expect(page.top_choices.visible and not page.tools_view.visible and page._board_input_enabled(), "Inline choice blocked the board or overlapped tools")
		_expect(not page.settings_panel.visible and not page.failure_panel.visible and page.get_node_or_null("Stage/Modal") == null, "Top tool opened a gameplay popup")
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		var row: HBoxContainer = page.top_choices.get_node("Row")
		for choice: Button in row.get_children():
			_expect(bounds.encloses(choice.get_global_rect()) and choice.get_global_rect().size.y >= 44, "Inline top choice clipped or too small")
			for box: DonutBox in page.board.boxes:
				_expect(not choice.get_global_rect().intersects(box.get_global_rect()), "Inline choices cover a table box")
		await _mouse_button(viewport, _box_point(page, 4), true)
		await _mouse_button(viewport, _box_point(page, 4), false)
		await process_frame
		_expect(page.selected_box == 4 and row.get_child(2).icon == DonutArt.HIDDEN, "Inline picker cannot switch to another box")
		var cancel: Vector2 = row.get_node("Cancel").get_global_rect().get_center()
		await _touch(viewport, cancel, true, 0)
		await _touch(viewport, cancel, false, 0, true)
		await process_frame
		_expect(page.top_choices.visible and page.session.snapshot() == before, "Canceled touch dismissed picker or consumed a tool")
		await _mouse_button(viewport, cancel, true)
		await _mouse_button(viewport, cancel, false)
		await process_frame
		_expect(not page.top_choices.visible and page.tools_view.visible and page.session.snapshot() == before, "Cancel failed to restore tools without changing rules")
	for interruption: String in ["hide", "pause", "focus", "settings", "back"]:
		page.tools_view.get_node("Top").pressed.emit()
		page._on_box_pressed(4)
		match interruption:
			"hide":
				page.hide()
				page.show()
			"pause":
				paused = true
				paused = false
			"focus":
				page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"settings":
				page.settings_button.pressed.emit()
				_expect(page.settings_panel.visible, "Gear no longer opens its settings popup")
				page.settings_panel.close()
			"back":
				var cancel := InputEventAction.new()
				cancel.action = "ui_cancel"
				cancel.pressed = true
				page._unhandled_input(cancel)
		_expect(not page.top_choices.visible and page.tools_view.visible and page.session.snapshot() == before, "Inline selection survived interruption: " + interruption)
	viewport.queue_free()
	await process_frame
	print("PASS: inline top choices, responsive bounds, box switching, cancel and lifecycle")


## 通过场景交互验证开局、取消、隐藏、外部暂停、切关和完整界面操作。
func _check_ui_lifecycle() -> void:
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	root.add_child(page)
	await process_frame
	await process_frame
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(page.session.started and not page._busy and page.get_node("Stage/Orders/Panel/Order3") != null, "Initial animation/four demand scene failed")
	for button: String in ["Undo", "AddBox", "Top"]:
		_expect(page.get_node("Stage/Tools/%s/Count" % button).visible and page.get_node("Stage/Tools/%s/Badge" % button).visible, "Available tool is missing its charge: " + button)
	for index: int in page.orders.cards.size():
		var card: DonutOrderCard = page.orders.cards[index]
		_expect(card.food.visible == (index < 2) and card.lock_icon.visible == (index >= 2), "Initial order card shows the wrong open/locked state")
		_expect(not card.count_label.visible, "Initial order card shows a completion mark or redundant quantity")
	var visible_flavor_art: Dictionary = {}
	for index: int in page.board.boxes.size():
		if page.session.can_pick_top(index):
			var food: TextureRect = page.board.boxes[index].food_stack.food_at(0)
			var flavor: int = page.session.slots[index].box.items[0].flavor
			_expect(food.visible and food.texture == DonutArt.FOOD[flavor], "Opening top artwork differs from flavor at box %d" % index)
			visible_flavor_art[food.texture] = true
	_expect(visible_flavor_art.size() == 2, "Teaching level did not display its two planned flavors")
	for index: int in page.session.slots.size():
		var slot: Dictionary = page.session.slots[index]
		if slot.box != null:
			for item_index: int in slot.box.items.size():
				_expect(page.board.boxes[index].food_stack.food_at(item_index).texture == DonutArt.FOOD[int(slot.box.items[item_index].flavor)], "Teaching level concealed a visible flavor")
	page.get_node("Stage/Boxes/Box0").pressed.emit()
	_expect(page.selected_box == 0, "Source selection not wired")
	page.hide()
	page.show()
	_expect(page.selected_box == -1, "Hide retained selection")
	page.session.tools = {"undo": 1, "add_box": 1, "top": 1}
	page._render()
	page.get_node("Stage/Tools/Top").pressed.emit()
	page.get_node("Stage/Boxes/Box0").pressed.emit()
	_expect(page.top_choices.visible, "Top choices missing")
	page.get_node("Stage/TopChoices/Row/Cancel").pressed.emit()
	await process_frame
	_expect(page.session.tools.top == 1, "Cancel spent a top charge")
	page.get_node("Stage/Boxes/Box0").pressed.emit()
	page.get_node("Stage/Boxes/Box4").pressed.emit()
	var state: Dictionary = page.session.snapshot()
	page.hide()
	page.show()
	_expect(not page._busy and page.session.snapshot() == state, "Animation interruption changed committed transaction")
	page.get_node("Stage/Tools/Undo").pressed.emit()
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(page.session.moves == 0 and page.session.completed == 0, "Undo did not restore UI session")
	page.get_node("Stage/Boxes/Box0").pressed.emit()
	paused = true
	_expect(page.selected_box == -1, "Pause kept transient selection")
	paused = false
	_expect(page.get_node_or_null("Stage/Pause") == null, "Pause button remains on the level")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	page._unhandled_input(cancel)
	_expect(not page.top_choices.visible, "Idle cancel still opens a pause menu")
	var title_release := InputEventMouseButton.new()
	title_release.button_index = MOUSE_BUTTON_LEFT
	page.get_node("Stage/Title").gui_input.emit(title_release)
	_expect(page.get_node("Stage/SettingsPanel/Card/Choices").get_child_count() == 10, "Level selection missing")
	page.get_node("Stage/SettingsPanel/Card/Choices").get_child(1).pressed.emit()
	page.lesson_dialog._answer(true)
	await process_frame
	await process_frame
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(page.session.level_index == 1 and not page.session.demands[3].open, "Level selection not connected to the revised second level")
	_expect(page.session.tools == {"undo": 1, "add_box": 1, "top": 1}, "Changing level did not reset tool uses")
	# 隐藏层交互使用独立机制夹具，基础第二关不提前引入灰层。
	page.initialize(DonutSession.new(_definition([_box([0, 1]), _box([1]), _box([2, 1, 3], "normal", 0, true)])))
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	page.session.tools.top = 1
	page._render()
	page.get_node("Stage/Tools/Top").pressed.emit()
	page.get_node("Stage/Boxes/Box2").pressed.emit()
	var hidden_choice: Button = page.get_node("Stage/TopChoices/Row").get_child(2)
	_expect(not hidden_choice.disabled and hidden_choice.icon == DonutArt.HIDDEN, "Inline top choices did not offer a concealed layer")
	hidden_choice.pressed.emit()
	await process_frame
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(page.session.slots[2].box.items[0].flavor == 3 and page.session.slots[2].box.items[0].revealed and
		page.session.tools.top == 0, "Inline top choices did not reveal selected gray layer")
	var revealed_box: DonutBox = page.board.boxes[2]
	_expect(revealed_box.food_stack.food_at(0).texture == DonutArt.FOOD[3] and
		revealed_box.food_stack.food_at(1).texture == DonutArt.FOOD[2] and
		revealed_box.food_stack.food_at(2).texture == DonutArt.HIDDEN,
		"Board did not preserve a covered known flavor")
	page.get_node("Stage/Tools/Top").pressed.emit()
	page.get_node("Stage/Boxes/Box2").pressed.emit()
	_expect(not page.top_choices.visible and page.get_node("Stage/Tools/Top/Count").text == "0",
		"Exhausted top tool opened its picker or retained a stale badge")
	_expect_exposed_tops_revealed(page.session, "UI blind top")
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


## 手动推进同一条动效时间线，验证逐颗错峰、飞行重叠、落点层序与中断后的整组一致性。
func _check_group_flight() -> void:
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	root.add_child(page)
	await process_frame
	page.initialize(DonutSession.new(_definition([_box([0, 0, 1]), _box([0])])))
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	_expect(page.session.move(0, 1), "Animation fixture failed to move")
	var effects: DonutEventPlayer = page.get_node("Stage/Effects")
	var timeline: Tween = effects._animation
	timeline.pause()
	var sprites: Array = effects.get_children().filter(func(node: Node) -> bool: return node is TextureRect and node.texture == DonutArt.FOOD[0])
	_expect(sprites.size() == 2, "Group flight did not create one sprite per moved donut")
	if sprites.size() == 2:
		var first_start: Vector2 = sprites[0].position
		var second_start: Vector2 = sprites[1].position
		timeline.custom_step(0.065)
		_expect(sprites[0].visible and sprites[0].position != first_start and not sprites[1].visible
			and sprites[1].position == second_start, "Group started simultaneously instead of staggered")
		_expect(not page.board.boxes[0].food_stack.food_at(0).visible and page.board.boxes[0].food_stack.food_at(1).visible,
			"Click flight hid a following donut before departure")
		timeline.custom_step(0.085)
		var first_mid: Vector2 = sprites[0].position
		_expect(sprites[1].visible and sprites[1].position != second_start, "Following donut waited until leader landed")
		timeline.custom_step(0.025)
		_expect(sprites[0].position != first_mid, "Leader was already stationary when follower started")
		timeline.custom_step(0.26)
		var target_box: DonutBox = page.board.boxes[1]
		var expected_bottom: Vector2 = page.board.origin(1) + target_box.food_position(1, false, 3) * target_box.scale
		var expected_top: Vector2 = page.board.origin(1) + target_box.food_position(0, false, 3) * target_box.scale
		_expect(sprites[0].position.is_equal_approx(expected_bottom) and sprites[1].position.is_equal_approx(expected_top),
			"Sequential arrivals did not build the target stack from bottom to top")
		_expect(sprites[1].z_index > sprites[0].z_index, "Later arriving top donut is drawn beneath its predecessor")
	await process_frame
	_expect(page.session.moves == 1 and page.session.slots[1].box.items.size() == 3 and effects.get_child_count() == 0,
		"Flight completion duplicated the transaction or retained temporary sprites")
	# 下一组在飞行途中失焦，已提交事务保持一次，画面收敛到最终状态。
	page.session.undo()
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	page.session.move(0, 1)
	effects._animation.pause()
	effects._animation.custom_step(0.075)
	effects._animation.play()
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	_expect(page.session.moves == 1 and page.session.slots[0].box.items.size() == 1 and effects.get_child_count() == 0
		and page.board.boxes[1].food_stack.food_at(2).visible, "Interrupted flight lost or duplicated group items")
	page.queue_free()
	await process_frame
	print("PASS: staggered overlapping donut flights, arrival stacking and interruption consistency")


## 覆盖鼠标与触摸两颗、四颗连移，后续甜甜圈必须留在原盒并在松手后从原盒逐颗出发。
func _check_drag_follow_flight() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	for touch: bool in [false, true]:
		for count: int in [2, 4]:
			var food: Array = []
			food.resize(count)
			food.fill(0)
			var definition: Dictionary = _definition([_box(food), _box([])])
			definition.demands[0].sequence = [1] # 满盒留场，独立检查各颗的飞行来源与落点。
			page.initialize(DonutSession.new(definition))
			page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			await process_frame
			var source: Vector2 = _box_point(page, 0)
			var target: Vector2 = _box_point(page, 1)
			if touch:
				await _touch(viewport, source, true, 0)
				await _touch_motion(viewport, target, 0)
			else:
				await _mouse_button(viewport, source, true)
				await _mouse_motion(viewport, target)
			_expect(page._drag_preview.size.is_equal_approx(DonutArt.FOOD_SIZE) and page.session.moves == 0,
				"Dragging carried multiple donuts or committed early")
			for index: int in range(1, count):
				_expect(page.board.boxes[0].food_stack.food_at(index).visible, "Follower vanished during drag")
			var leader_start: Vector2 = page._drag_preview.position
			# 在业务提交的同一帧暂停展示，避免等待帧率左右时序断言。
			page.session.changed.connect(func(_events: Array) -> void: page.event_player._animation.pause(), CONNECT_ONE_SHOT)
			if touch:
				await _touch(viewport, target, false, 0)
			else:
				await _mouse_button(viewport, target, false)
			var timeline: Tween = page.event_player._animation
			var sprites: Array = page.event_player.get_children().filter(func(node: Node) -> bool: return node is TextureRect)
			_expect(sprites.size() == count and page.session.moves == 1, "Drag release did not commit exactly one group")
			if sprites.size() != count:
				continue
			_expect(sprites[0].visible and sprites[0].position.is_equal_approx(leader_start), "Leader jumped away from the released pointer")
			for index: int in range(1, count):
				var origin: Vector2 = page.board.origin(0) + page.board.boxes[0].food_position(index, false, count) * page.board.boxes[0].scale
				_expect(not sprites[index].visible and sprites[index].position.is_equal_approx(origin)
					and page.board.boxes[0].food_stack.food_at(index).visible, "Follower started at the pointer instead of remaining in source")
			timeline.custom_step(0.065)
			_expect(not sprites[1].visible and page.board.boxes[0].food_stack.food_at(1).visible, "Follower started too soon to distinguish the leader")
			timeline.custom_step(0.085)
			var leader_mid: Vector2 = sprites[0].position
			var follower_mid: Vector2 = sprites[1].position
			_expect(sprites[1].visible and not page.board.boxes[0].food_stack.food_at(1).visible, "Follower never left source after leader")
			if count == 4:
				_expect(not sprites[2].visible and page.board.boxes[0].food_stack.food_at(2).visible, "Third donut departed with the second")
			timeline.custom_step(0.035)
			_expect(sprites[0].position != leader_mid and sprites[1].position != follower_mid, "Leader and follower did not overlap in flight")
			timeline.custom_step(0.5)
			await process_frame
			_expect(page.event_player.get_child_count() == 0 and page.session.slots[1].box.items.size() == count
				and page.session.slots[0].box.items.is_empty(), "Drag flight ended with missing or duplicated donuts")
	viewport.queue_free()
	await process_frame
	print("PASS: mouse/touch single leader drag and source-origin followers for two/four donuts")


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
	var title_center: Vector2 = page.get_node("Stage/Title").get_global_rect().get_center()
	await _mouse_button(viewport, title_center, true)
	await _mouse_button(viewport, title_center, false)
	_expect(page.get_node("Stage/SettingsPanel").visible, "Tapping the level title did not open level selection")
	page.get_node("Stage/SettingsPanel/Card/Resume").pressed.emit()
	await _touch(viewport, title_center, true, 0)
	await _touch(viewport, title_center, false, 0)
	_expect(page.get_node("Stage/SettingsPanel").visible, "Touching the level title did not open level selection")
	page.get_node("Stage/SettingsPanel/Card/Resume").pressed.emit()
	var settings_center: Vector2 = page.get_node("Stage/Settings").get_global_rect().get_center()
	await _mouse_button(viewport, settings_center, true)
	await _mouse_button(viewport, settings_center, false)
	_expect(page.get_node("Stage/SettingsPanel").visible, "Tapping the gear did not open settings")
	page.get_node("Stage/SettingsPanel/Card/Resume").pressed.emit()
	var undo_center: Vector2 = page.get_node("Stage/Tools/Undo").get_global_rect().get_center()
	await _mouse_button(viewport, undo_center, true)
	await _mouse_button(viewport, undo_center, false)
	_expect(page.get_node("Stage/Toast").visible, "Scaled tool button lost its pointer hit area")
	page._hide_toast()
	var effects_layer: CanvasItem = page.get_node("Stage/Effects")
	var highest_static_z: int = 0
	for layer: Node in page.get_node("Stage").get_children():
		if layer is CanvasItem and layer != effects_layer and layer != page.get_node("Stage/Toast") and layer != page.get_node("Stage/IdleHint") and layer != page.get_node("Stage/SettingsPanel") and layer != page.failure_panel and layer != page.lesson_dialog:
			highest_static_z = maxi(highest_static_z, _highest_z(layer as CanvasItem))
	_expect(effects_layer.z_index > highest_static_z, "Moving donuts can be covered by a tray or other static art")
	_expect(page.get_node("Stage/Toast").z_index > effects_layer.z_index
		and page.get_node("Stage/SettingsPanel").z_index > page.get_node("Stage/Toast").z_index,
		"Board, effects, feedback and modal layers are out of order")
	_expect(page.failure_panel.z_index > effects_layer.z_index, "Failure panel does not cover game effects")
	var source: Vector2 = _box_point(page, 0)
	var target: Vector2 = _box_point(page, 1)
	var before: Dictionary = page.session.snapshot()
	await _mouse_button(viewport, source, true)
	await _mouse_motion(viewport, target)
	_expect(page.session.snapshot() == before, "Dragging committed before release")
	_expect(page._drag_preview is TextureRect and page._drag_preview.size.is_equal_approx(DonutArt.FOOD_SIZE),
		"Drag must carry only the leader donut, not the whole group")
	_expect(not page.get_node("Stage/Boxes/Box0").food_stack.food_at(0).visible
		and page.get_node("Stage/Boxes/Box0").food_stack.food_at(1).visible
		and page.get_node("Stage/Boxes/Box0").food_stack.food_at(2).visible,
		"Drag removed followers from the source before release")
	_check_art_aspect(page.get_node("Stage/Effects"))
	await _mouse_button(viewport, target, false)
	_expect(page.session.moves == 1 and page.session.slots[1].box.items.size() == 3, "Mouse drag failed to move the contiguous group")
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
	page.initialize(DonutSession.new(_definition([_box([0, 0, 0]), _box([0, 0, 0])])))
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _mouse_button(viewport, _box_point(page, 0), true)
	await _mouse_motion(viewport, _box_point(page, 3))
	_expect(page._drag_preview.size.is_equal_approx(DonutArt.FOOD_SIZE)
		and page.board.boxes[0].food_stack.food_at(1).visible and page.board.boxes[0].food_stack.food_at(2).visible,
		"Empty target must keep a single leader preview and preserve followers")
	await _mouse_motion(viewport, _box_point(page, 1))
	_expect(page._drag_preview.size.is_equal_approx(DonutArt.FOOD_SIZE)
		and page.board.boxes[0].food_stack.food_at(1).visible, "Capacity change removed the follower before release")
	await _mouse_button(viewport, _box_point(page, 1), false)
	_expect(page.session.moves == 1 and page.session.completed == 1 and page.session.slots[0].box.items.size() == 2,
		"Capacity-limited group drag did not fill target and recycle once")
	# 顶层上缘可直接拿起，触摸预览避开指尖，邻近空隙松手可容错。
	await _reset_pointer_page(page)
	var source_box: DonutBox = page.get_node("Stage/Boxes/Box0")
	source_box.size = Vector2(200, 157) # 复现紧凑盒里食物露出上缘的原始缺陷。
	source_box.present(page.session.slots[0])
	var edge: Vector2 = source_box.get_global_transform_with_canvas() * (source_box.food_position(0) + Vector2(65, 10))
	await _touch(viewport, edge, true, 0)
	await _touch_motion(viewport, target, 0)
	_expect(page._drag_preview != null, "Visible donut upper edge cannot start a drag")
	var preview_bounds: Rect2 = page._drag_preview.get_global_rect()
	_expect(preview_bounds.end.y < target.y, "Touch preview is hidden under the fingertip")
	await _touch(viewport, target, false, 0)
	# 不等待上次动画完成，直接把同一盒下一组移到另一同味盒。
	await _mouse_drag(viewport, _box_point(page, 0), _box_point(page, 2))
	_expect(page.session.moves == 2 and page.session.slots[2].box.items.size() == 3,
		"Fast consecutive gestures were swallowed by presentation animation")
	page._fit_stage()
	await _reset_pointer_page(page)
	var target_box: DonutBox = page.get_node("Stage/Boxes/Box1")
	var target_rect: Rect2 = target_box.get_global_rect()
	var near_edge := Vector2(target_rect.end.x + 3, target_rect.get_center().y)
	await _mouse_drag(viewport, _box_point(page, 0), near_edge)
	_expect(page.session.moves == 1, "Near-edge drop was rejected instead of using the legal neighbouring tray")
	await _reset_pointer_page(page)
	await _mouse_button(viewport, source, true)
	await _mouse_motion(viewport, target)
	page.queue_free()
	await process_frame
	await _mouse_button(viewport, target, false)
	viewport.queue_free()
	await process_frame
	print("PASS: grouped mouse/touch drag, exposed edges, finger clearance, drop tolerance, rapid input and cancellation")


## 整叠上缘和近边缘均可拿取放入，点击与悬停不得通过描边、暗色或文字泄露落点。
func _check_hit_area_and_no_hints() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	var definition: Dictionary = _definition([_box([0, 0, 1]), _box([0, 0, 2]), _box([1, 1, 2])])
	for dimensions: Vector2i in [Vector2i(360, 800), Vector2i(720, 1280), Vector2i(1024, 1536)]:
		viewport.size = dimensions
		await process_frame
		await process_frame
		for touch: bool in [false, true]:
			for above: float in [0.0, 8.0]:
				page.initialize(DonutSession.new(definition))
				page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
				await process_frame
				var source_box: DonutBox = page.board.boxes[0]
				var target_box: DonutBox = page.board.boxes[1]
				var source: Vector2 = source_box.get_global_transform_with_canvas() * (source_box.food_position(0) + Vector2(71, 8))
				var target: Vector2 = target_box.get_global_transform_with_canvas() * (target_box.food_position(0) + Vector2(71, 8 if above == 0.0 else 0))
				target.y -= above * page.board_input.logical_pixel
				_expect(not target_box.get_global_rect().has_point(target), "Hit-area regression accidentally targeted only the bottom tray")
				var before: Dictionary = page.session.snapshot()
				if touch:
					await _touch(viewport, source, true, 0)
					await _touch_motion(viewport, target_box.get_global_rect().get_center(), 0)
					_expect_no_move_hints(page)
					await _touch_motion(viewport, target, 0)
				else:
					await _mouse_button(viewport, source, true)
					await _mouse_motion(viewport, target_box.get_global_rect().get_center())
					_expect_no_move_hints(page)
					await _mouse_motion(viewport, target)
				_expect(page._drag_preview != null and page.session.snapshot() == before, "Upper stack cannot start a drag or committed before release")
				_expect_no_move_hints(page)
				if touch:
					await _touch(viewport, target, false, 0)
				else:
					await _mouse_button(viewport, target, false)
				_expect(page.session.moves == 1 and page.session.slots[1].box.items.size() == 4
					and page.session.slots[0].box.items.size() == 2, "Dropping onto the upper stack or its padded edge missed the target")
		page.initialize(DonutSession.new(definition))
		page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await process_frame
		var source: Vector2 = _box_point(page, 0)
		await _mouse_button(viewport, source, true)
		await _mouse_button(viewport, source, false)
		_expect_no_move_hints(page)
		# 两盒间隙按距离命中，无效的近邻不能被自动绕过到更远的同味盒。
		var left: Rect2 = page.board.boxes[1].get_global_rect()
		var right: Rect2 = page.board.boxes[2].get_global_rect()
		var gap := Vector2((left.end.x + right.position.x) * 0.5 + 1, right.get_center().y)
		_expect(page.board_input.box_at(gap) == 2, "Gap targeting skipped the nearest incompatible box")
		var before: Dictionary = page.session.snapshot()
		await _mouse_button(viewport, source, true)
		await _mouse_motion(viewport, _box_point(page, 2))
		_expect_no_move_hints(page)
		await _mouse_motion(viewport, gap)
		await _mouse_button(viewport, gap, false)
		_expect(page.session.snapshot() == before and not page.get_node("Stage/Toast").visible,
			"Invalid drop auto-corrected to a legal neighbour or displayed movement coaching")
		page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		# 满盒的顶层仍属于该盒，不能穿透到其他盒位。
		page.initialize(DonutSession.new(_definition([_box([0]), _box([0, 1, 2, 3])])))
		page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		before = page.session.snapshot()
		await _mouse_drag(viewport, _box_point(page, 0), _box_point(page, 1))
		_expect(page.session.snapshot() == before, "Expanded target accepted a full tray")
	viewport.queue_free()
	await process_frame
	print("PASS: whole-stack pickup/drop and edge tolerance across viewports, no coaching or legality-based snapping")


## 检查玩家可见的提示效果，不以是否计算了合法落点作为通过条件。
func _expect_no_move_hints(page: Control) -> void:
	for box: DonutBox in page.board.boxes:
		_expect(box.modulate == Color.WHITE, "Selection dimmed an incompatible box or its donuts")
		var outline: CanvasItem = box.get_node_or_null("Selection")
		_expect(outline == null or not outline.visible, "Selection or dragging revealed target outlines")
	if page._drag_preview != null:
		for label: Node in page._drag_preview.find_children("*", "Label", true, false):
			_expect(not label.visible or label.text.is_empty(), "Drag preview displayed movement coaching text")


## 正式前两关用鼠标拖拽完成全解，验证结算画面保留各关真实的容器余量。
func _check_early_level_drags() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	root.add_child(viewport)
	var app: Node = load("res://bootstrap/app.tscn").instantiate()
	viewport.add_child(app)
	var page: Control = app.get_node("SceneContainer/HomeScreen")
	page.lessons_enabled = false
	await process_frame
	await process_frame
	for index: int in 2:
		page.session.load_level(index)
		page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		var fixture_path: String = get_script().resource_path.get_base_dir().path_join("../../fixtures/donut_sort/level_%02d_solution.json" % (index + 1))
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
		for step: Array in fixture.steps:
			var previous_moves: int = page.session.moves
			await _mouse_drag(viewport, _box_point(page, int(step[0])), _box_point(page, int(step[1])))
			_expect(page.session.moves == previous_moves + 1, "Level %d drag %s did not commit" % [index + 1, step])
			page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_expect(page.session.is_won() and page.session.tools == {"undo": 1, "add_box": 1, "top": 1}, "Early-level drag solution did not finish without tools")
		_expect(page.board.boxes.filter(func(box: DonutBox) -> bool: return box.visible and box.back.visible).size() == LEVEL_TARGETS[index][1] + LEVEL_TARGETS[index][2] - LEVEL_TARGETS[index][4], "Victory board container budget differs from planning sheet")
	viewport.queue_free()
	await process_frame
	print("PASS: early-level mouse drag solutions and visible container conservation")



## 验证全部布局在不同画布上保留四层食物空间，预览样例不修改现有关卡。
func _check_configured_layouts() -> void:
	var board: DonutBoardView = load("res://features/donut_sort/board/ui/donut_board_view.tscn").instantiate()
	root.add_child(board)
	await process_frame
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DonutBoardView.LAYOUT_PATH))
	for key: String in catalog.templates:
		_expect(board.configure_layout(key), "Layout cannot be loaded: " + key)
		_expect(board.boxes.size() == catalog.templates[key].slots.size(), "Layout lost a box: " + key)
		if key in catalog.levels:
			var row_counts: Dictionary = {}
			for slot: Dictionary in catalog.templates[key].slots:
				row_counts[int(slot.layer)] = int(row_counts.get(int(slot.layer), 0)) + 1
			_expect(row_counts.size() == ceili(board.boxes.size() / 5.0), "Level does not prefer five boxes per row: " + key)
			var counts: Array = row_counts.values()
			_expect(int(counts.max()) <= 5 and int(counts.max()) - int(counts.min()) <= 1,
				"Level rows are sparse or exceed five boxes: " + key)
		for dimensions: Vector2 in [Vector2(976, 1150), Vector2(640, 760), Vector2(976, 1600)]:
			board.fit(Rect2(Vector2(24, 400), dimensions))
			for index: int in board.boxes.size():
				var state: Dictionary = _box([0, 1, 2, 3])
				state.frozen = false
				for item: Dictionary in state.items:
					item.revealed = true
				board.boxes[index].present({"kind": "regular", "open": true, "box": state}, true)
			_check_layout_geometry(board)
			var frozen: DonutBox = board.boxes[0]
			var state: Dictionary = _box([0, 1, 2, 3])
			state.frozen = true
			for item: Dictionary in state.items:
				item.revealed = true
			frozen.present({"kind": "regular", "open": true, "box": state})
			var ice: Control = frozen.food_stack.food_at(0).get_child(0)
			_expect(ice.visible and ice.size == DonutArt.FOOD_SIZE, "Per-donut frost missing")
			state.frozen = false
			state.lid = 3
			state.kind = "lid"
			frozen.present({"kind": "regular", "open": true, "box": state})
			_expect(frozen.closed.visible and is_equal_approx(frozen.closed.size.x, frozen.size.x)
				and is_equal_approx(frozen.closed.position.y + frozen.closed.size.y, frozen.size.y),
				"Numbered lid is undersized or no longer rests at the tray baseline")
			_check_layout_geometry(board)
			var stable_positions: Array = []
			for box: DonutBox in board.boxes:
				stable_positions.append(box.position)
				box.present({"kind": "regular", "open": true, "box": null})
			board.fit(Rect2(board.position, board.size))
			for index: int in board.boxes.size():
				_expect(board.boxes[index].position.distance_to(stable_positions[index]) < 0.001,
					"Empty slots reflowed the layout: %s/%s/%d" % [key, dimensions, index])
	var valid: Array = catalog.templates.staggered_17.slots
	var duplicate: Array = valid.duplicate(true)
	duplicate[1].id = duplicate[0].id
	_expect(not DonutBoardView.validate_layout(duplicate).is_empty(), "Duplicate layout identity accepted")
	var reversed: Array = valid.duplicate(true)
	reversed.reverse()
	_expect(not DonutBoardView.validate_layout(reversed).is_empty(), "Reversed processing order accepted")
	var overlap: Array = valid.duplicate(true)
	overlap[1].x = overlap[0].x + 10
	_expect(not DonutBoardView.validate_layout(overlap).is_empty(), "Overlapping stacks accepted")
	var previous: String = board.layout_id
	_expect(not board.configure_layout("missing") and board.layout_id == previous, "Invalid layout overwrote the current board")
	for index: int in DonutLevel.catalog().size():
		var definition: Dictionary = DonutLevel.load_definition(DonutLevel.catalog()[index].path)
		board.configure_level(index, definition.slots.size())
		_expect(board.layout_id == catalog.levels[index] and board.boxes.size() == definition.slots.size(),
			"Level layout changed its slot count or assignment")
	board.queue_free()
	await process_frame
	print("PASS: 8/12/17/25-slot layouts, stable order, full-stack bounds, ice coverage and invalid-layout rejection")


## 统一检查预留空间与真实食物边界，避免构图正确但命中区或选中食物相互覆盖。
func _check_layout_geometry(board: DonutBoardView) -> void:
	var bounds := Rect2(Vector2.ZERO, board.size).grow(0.01)
	for index: int in board.boxes.size():
		var box: DonutBox = board.boxes[index]
		var reserved := Rect2(box.position - Vector2(0, DonutStackView.MAX_TOP_OVERHANG * box.scale.y),
			Vector2(box.size.x, box.size.y + DonutStackView.MAX_TOP_OVERHANG + (20.0 if box.get_node("Mechanic").visible else 0.0)) * box.scale)
		_expect(bounds.encloses(reserved), "Four-layer reserved space left its board: " + board.layout_id)
		_expect(box.box_index == index and int(board.layout_slots[index].order) == index, "Visual layout changed business index")
		_expect(reserved.grow(0.01).encloses(box.get_transform() * box.interaction_rect()), "Visible food left its reserved space")
		for prior: int in index:
			var previous: DonutBox = board.boxes[prior]
			var previous_bounds := Rect2(previous.position - Vector2(0, DonutStackView.MAX_TOP_OVERHANG * previous.scale.y),
				Vector2(previous.size.x, previous.size.y + DonutStackView.MAX_TOP_OVERHANG) * previous.scale)
			_expect(not reserved.intersects(previous_bounds), "Four-layer stacks overlap: " + board.layout_id)


## 连续切换竖屏尺寸，验证点击区域互不重叠、底部可达且缩放会取消旧拖拽。
func _check_portrait_layout() -> void:
	# 比较等比适配后的实际绘制宽度，旧版灰圈的偏高比例会让同一容器里明显变窄。
	var hidden_width: float = minf(DonutArt.FOOD_SIZE.x, DonutArt.FOOD_SIZE.y * DonutArt.HIDDEN.get_width() / DonutArt.HIDDEN.get_height())
	for texture: Texture2D in DonutArt.FOOD:
		var food_width: float = minf(DonutArt.FOOD_SIZE.x, DonutArt.FOOD_SIZE.y * texture.get_width() / texture.get_height())
		_expect(absf(hidden_width - food_width) <= DonutArt.FOOD_SIZE.x * 0.06, "Hidden donut has a different visible scale from normal flavors")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 1536)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await _reset_pointer_page(page)
	for dimensions: Vector2i in [Vector2i(360, 640), Vector2i(720, 1280), Vector2i(720, 1600), Vector2i(1024, 1536)]:
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
		var boxes: Array[DonutBox] = page.board.boxes
		_check_layout_geometry(page.board)
		var background: DonutBackground = page.get_node("Backdrop")
		var tabletop: TextureRect = background.get_node("TableClip/Tabletop")
		var table_clip: Control = background.get_node("TableClip")
		var floor_art: TextureRect = background.get_node("Floor")
		var shop: TextureRect = background.get_node("ShopClip/Shop")
		_expect(shop.get_global_rect().grow(0.01).encloses(background.get_node("ShopClip").get_global_rect()), "Wall crop exposes a gap above the counter")
		_expect(background.get_global_rect().is_equal_approx(bounds), "Background does not fill portrait viewport")
		_expect(tabletop.get_global_rect().grow(0.01).encloses(table_clip.get_global_rect()), "Counter crop exposes an empty margin")
		_expect(is_equal_approx(tabletop.get_global_rect().end.y, table_clip.get_global_rect().end.y), "Cabinet bottom frame is cropped by the floor")
		_expect(absf(floor_art.get_global_rect().end.y - bounds.end.y) < 1.0 and
			floor_art.get_global_rect().position.y <= table_clip.get_global_rect().end.y,
			"Counter and floor leave a seam or an uncovered bottom edge")
		_expect(tabletop.texture.resource_path.ends_with("background_middle.png") and
			shop.texture.resource_path.ends_with("background_top.png") and
			floor_art.texture.resource_path.ends_with("background_bottom.png"), "V8 background segments are not displayed")
		_expect(table_clip.z_index > page.orders.z_index and table_clip.z_index < page.board.z_index,
			"Counter does not sit between the orders and the playable board")
		_check_art_aspect(page)
		var coin_rect: Rect2 = page.get_node("Stage/CoinBalance").get_global_rect()
		var title_rect: Rect2 = page.get_node("Stage/Title").get_global_rect()
		var settings_rect: Rect2 = page.get_node("Stage/Settings").get_global_rect()
		var stage_rect: Rect2 = page.stage.get_global_rect()
		var left_inset: float = coin_rect.position.x - stage_rect.position.x
		var right_inset: float = stage_rect.end.x - settings_rect.end.x
		_expect(bounds.encloses(coin_rect) and bounds.encloses(settings_rect), "Coin balance or settings left portrait viewport")
		_expect(not coin_rect.intersects(title_rect) and not title_rect.intersects(settings_rect), "Header controls overlap")
		_expect(left_inset > 0 and left_inset < stage_rect.size.x * 0.04 and absf(left_inset - right_inset) < 1.0,
			"Coin balance and settings do not align to matching outer margins")
		_expect(absf(title_rect.get_center().x - stage_rect.get_center().x) < 1.0, "Level title is not centered on the page")
		_expect(page.get_node("Stage/CoinBalance/Amount").horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT,
			"Coin amount is not left aligned")
		_expect(absf(coin_rect.get_center().y - title_rect.get_center().y) < 3.0 and
			absf(settings_rect.get_center().y - title_rect.get_center().y) < 3.0, "Header controls do not share a center line")
		for box: DonutBox in boxes:
			_expect(box.size.is_equal_approx(DonutBox.BOX_SIZE), "Paper holder changed shape after resize")
			_expect(is_equal_approx(box.scale.x, box.scale.y), "Paper holder has non-uniform scale")
			_expect(box.back.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Paper holder art is stretched")
			_expect(box.back.texture.atlas.resource_path.ends_with("paper_holder_round.png") and
				box.get_node_or_null("Front") == null, "Round holder retained an unrelated front occluder")
			_expect(box.get_global_rect().end.y < floor_art.get_global_rect().position.y -
				DonutBackground.CABINET_HEIGHT * tabletop.get_global_rect().size.y / DonutBackground.MIDDLE_SIZE.y,
				"Playable paper holder overlaps cabinet decoration")
		_expect(page.get_node_or_null("Stage/Dispatch") == null, "Bottom dispatch decoration returned")
		var single_box: DonutBox = boxes[0]
		var single_box_state: Dictionary = _box([0]).merged({"frozen": false})
		single_box_state.items[0].revealed = true
		single_box.present({"kind": "single", "open": true, "box": single_box_state})
		var food_center: Vector2 = single_box.food_stack.food_at(0).get_rect().get_center()
		_expect(single_box.back.visible and not single_box.closed.visible and
			Rect2(Vector2.ZERO, single_box.size).has_point(food_center), "Single-donut food left its paper holder")
		_expect(single_box.food_position(0, false, 4).y < 0 and
			single_box.food_position(3, false, 4).y > -DonutArt.FOOD_SIZE.y * 0.1,
			"Four donuts do not rest against the paper holder opening")
		_expect(_highest_z(single_box.food_stack) > single_box.back.z_index,
			"Round holder incorrectly covers the donut stack")
		page._render()
		for index: int in boxes.size():
			var area: Rect2 = boxes[index].get_global_rect()
			_expect(bounds.encloses(area), "Box outside portrait viewport: %s/%d" % [dimensions, index])
			var stack_area: Rect2 = boxes[index].get_global_transform_with_canvas() * boxes[index].interaction_rect()
			_expect(bounds.encloses(stack_area), "Donut stack outside portrait viewport")
			for other: int in range(index + 1, boxes.size()):
				_expect(not area.intersects(boxes[other].get_global_rect()), "Box hit areas overlap after resize")
				var other_stack: Rect2 = boxes[other].get_global_transform_with_canvas() * boxes[other].interaction_rect()
				_expect(not stack_area.intersects(other_stack), "Configured donut stacks overlap")
		for name: String in ["Undo", "AddBox", "Top"]:
			var button: Control = page.get_node("Stage/Tools/" + name)
			_expect(bounds.encloses(button.get_global_rect()), "Tool outside portrait viewport: " + name)
		var undo_rect: Rect2 = page.get_node("Stage/Tools/Undo").get_global_rect()
		var top_rect: Rect2 = page.get_node("Stage/Tools/Top").get_global_rect()
		var add_center: Vector2 = page.get_node("Stage/Tools/AddBox").get_global_rect().get_center()
		_expect(absf(add_center.x - stage_rect.get_center().x) < 1.0 and
			absf(undo_rect.get_center().x + top_rect.get_center().x - add_center.x * 2.0) < 1.0,
			"Three tool buttons are not centered after removing the paper box")
		for index: int in [0, 4, 10, 14, 15, 16]:
			await _check_box_entry(page, index, bounds)
	viewport.queue_free()
	await process_frame
	print("PASS: paper holder proportions, donut stack layers, portrait bounds and resize cancellation")


## 从左右可见边界外等比水平飞入，途中不改变规则，终点与目标盒位完全一致。
func _check_box_entry(page: Control, index: int, bounds: Rect2) -> void:
	var before: Dictionary = page.session.snapshot()
	var effects: DonutEventPlayer = page.event_player
	effects._animation = effects.create_tween()
	effects._append_box_flight(before.slots[0], index, 1.0)
	var flying: DonutBox = effects.get_child(-1)
	var start: Rect2 = flying.get_global_rect()
	var target: Rect2 = page.board.boxes[index].get_global_rect()
	var from_left: bool = target.get_center().x < bounds.get_center().x
	_expect(start.end.x < bounds.position.x if from_left else start.position.x > bounds.end.x,
		"Incoming box must begin completely outside the nearest side")
	_expect(is_equal_approx(start.position.y, target.position.y), "Side entry must stay on the target row")
	_expect(start.size.is_equal_approx(target.size), "Incoming box changes proportions")
	effects._animation.custom_step(0.5)
	var midway: Rect2 = flying.get_global_rect()
	_expect(flying.visible and midway.position.distance_to(target.position) < start.position.distance_to(target.position), "Box did not travel toward its target")
	effects._animation.custom_step(0.5)
	_expect(flying.get_global_rect().is_equal_approx(target), "Incoming box missed exact target")
	_expect(page.session.snapshot() == before, "Entry animation changed committed rules")
	await process_frame
	_expect(effects.get_child_count() == 0, "Landed box left duplicate flight art")


## 真实左右两侧打包后原位补货，动画结束及缩放中断均保留唯一对应餐盒。
func _check_side_refill() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	for index: int in [0, 4]:
		var definition: Dictionary = _definition()
		definition.slots[index].box = _box([0, 0, 0])
		definition.slots[1].box = _box([0])
		definition.stock = [_box([1, 2, 3, 4])]
		page.initialize(DonutSession.new(definition))
		page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await process_frame
		_expect(page.session.move(1, index), "Side refill fixture could not dispatch")
		var after: Dictionary = page.session.snapshot()
		var arrivals: Array = page.event_player.get_children().filter(func(node: Node) -> bool: return node is DonutBox)
		_expect(arrivals.size() == 1 and arrivals[0].box_index == index, "Refill animation used the wrong box position")
		_expect(page.event_player.refill_pending and not page._board_input_enabled(), "Fresh board input can skip the pending refill")
		page._on_box_pressed(1)
		_expect(page.selected_box == -1 and page.event_player.is_playing(), "Repeated tap skipped the refill timeline")
		page.event_player._animation.custom_step(0.72)
		_expect(arrivals[0].visible and Rect2(Vector2.ZERO, Vector2(viewport.size)).intersects(arrivals[0].get_global_rect()),
			"Refill must have a visible in-flight frame before landing")
		_expect(page.session.completed == 1 and page.session.remaining_stock() == 0,
			"Side entry broke real dispatch or consumed extra stock")
		page.event_player._animation.custom_step(10.0)
		await process_frame
		_expect(page.board.boxes[index].visible and page.board.boxes[index].food_stack.food_at(0).texture == DonutArt.FOOD[1],
			"Refilled box did not render at its target after landing")
		_expect(page.event_player.get_child_count() == 0 and page.session.snapshot() == after, "Refill animation duplicated state or art")
		_expect(not page.event_player.refill_pending and page._board_input_enabled(), "Refill did not release board input after landing")
		page.session.restart()
		page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_expect(page.session.move(1, index), "Interrupted refill fixture could not dispatch")
		after = page.session.snapshot()
		viewport.size += Vector2i(10, 20)
		await process_frame
		await process_frame
		_expect(not page.event_player.is_playing() and page.event_player.get_child_count() == 0 and page.session.snapshot() == after,
			"Resize retained side-entry art or changed refill state")
		_expect(not page.event_player.refill_pending and page._board_input_enabled(), "Interrupted refill kept input locked")
		_expect(page.board.boxes[index].visible, "Resize interruption left the refilled box hidden")
	viewport.queue_free()
	await process_frame
	print("PASS: left/right entry, exact target, real dispatch/refill and resize cancellation")


## 验证独立订单盒的口味一致、锁定去色、完成反馈及台面遮挡范围。
func _check_order_card_layout() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	for dimensions: Vector2i in [Vector2i(360, 640), Vector2i(720, 1280), Vector2i(720, 1600), Vector2i(1024, 1536)]:
		viewport.size = dimensions
		await process_frame
		await process_frame
		page._cancel_interaction()
		for status: String in ["active", "locked", "complete"]:
			var demands: Array = []
			for flavor: int in [0, 4, 5, 6]:
				demands.append({"open": status != "locked", "cursor": 1 if status == "complete" else 0,
					"sequence": [flavor]})
			page.orders.present(demands)
			await process_frame
			var table_edge: float = page.backdrop.get_node("TableClip").get_global_rect().position.y
			for index: int in 4:
				var card: DonutOrderCard = page.orders.cards[index]
				var frame: Rect2 = card.get_global_rect()
				var context: String = "%s/%s/card%d" % [dimensions, status, index]
				var content: Control = card.food if status == "active" else (card.lock_icon if status == "locked" else card.count_label)
				var content_bounds: Rect2 = content.get_global_rect()
				_expect(content.visible and frame.encloses(content_bounds) and content_bounds.end.y < table_edge,
					"Order content is clipped by its box or counter: " + context)
				# 原图波浪贴纸约为 (342, 205)–(900, 619)，按裁切与等比留白换算视觉中心。
				var atlas: AtlasTexture = card.box_art.texture as AtlasTexture
				var art_scale: float = minf(card.box_art.size.x / atlas.get_width(), card.box_art.size.y / atlas.get_height())
				var art_inset: Vector2 = (card.box_art.size - atlas.get_size() * art_scale) * 0.5
				var label_center: Vector2 = card.box_art.get_global_transform_with_canvas() * (art_inset + (Vector2(621, 412) - atlas.region.position) * art_scale)
				_expect(content_bounds.get_center().distance_to(label_center) < 0.75 * card.get_global_transform_with_canvas().x.length(),
					"Order content drifts from background sticker center: " + context)
				_expect(frame.end.y > table_edge and frame.end.y - table_edge < frame.size.y * 0.15,
					"Counter occlusion is missing or excessive: " + context)
				if index > 0:
					_expect(not frame.intersects(page.orders.cards[index - 1].get_global_rect()), "Order boxes overlap: " + context)
				_expect(card.food.visible == (status == "active") and card.lock_icon.visible == (status == "locked")
					and card.count_label.visible == (status == "complete"), "Order state icons disagree: " + context)
				if status == "active":
					var flavor: int = demands[index].sequence[0]
					_expect(card.food.texture == DonutOrderCard.STICKER_ART[flavor] and card.box_art.texture == DonutOrderCard.BOX_ART[flavor],
						"Order art does not match the board flavor: " + context)
				elif status == "locked":
					_expect(card.box_art.material.get_shader_parameter("neutral_amount") == 1.0 and
						card.box_art.material.get_shader_parameter("neutral_tint") == Color.WHITE,
						"Locked order reveals a flavor color: " + context)
				else:
					_expect(card.count_label.size.y >= card.count_label.get_minimum_size().y, "Completion mark is cropped: " + context)
	viewport.queue_free()
	await process_frame
	print("PASS: independent order boxes, flavor identity, neutral locks, completion and counter occlusion at four viewport sizes")


## 同时覆盖无宿主网页和手机安全区，检查基础留白、长短屏与真实拖拽命中。
func _check_host_safe_area() -> void:
	var adapter: Script = load("res://platforms/minigame/host_viewport.gd")
	_expect(adapter.content_rect(Vector2(720, 1280), {}) == Rect2(0, 0, 720, 1280), "Desktop viewport fallback changed")
	var viewport := SubViewport.new()
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	var cases: Array = [
		{"width": 320, "height": 568},
		{"width": 360, "height": 640},
		{"width": 440, "height": 956},
		{"width": 440, "height": 956, "render_scale": 3},
		{"width": 375, "height": 667, "safeArea": {"top": 20, "bottom": 647},
			"menu": {"bottom": 64, "width": 80, "height": 32}},
		{"width": 440, "height": 956, "safeArea": {"top": 62, "bottom": 922},
			"menu": {"bottom": 104, "width": 80, "height": 32}},
		{"width": 440, "height": 956, "render_scale": 3, "safeArea": {"top": 62, "bottom": 922},
			"menu": {"bottom": 104, "width": 80, "height": 32}},
		{"width": 393, "height": 852, "safeArea": {"top": 59, "bottom": 818},
			"menu": {"bottom": 104, "width": 80, "height": 32}},
		{"width": 360, "height": 800, "statusBarHeight": 24,
			"menu": {"bottom": 64, "width": 80, "height": 32}},
		{"width": 360, "height": 960, "safeArea": {"top": 24, "bottom": 926},
			"menu": {"bottom": 64, "width": 80, "height": 32}},
		{"width": 360, "height": 640, "safeArea": {"top": 24, "bottom": 624},
			"menu": {"bottom": 56, "width": 80, "height": 32}},
		{"width": 768, "height": 1024, "safeArea": {"left": 12, "right": 756, "top": 24, "bottom": 1000}},
	]
	for metrics: Dictionary in cases:
		var render_scale: int = int(metrics.get("render_scale", 1))
		viewport.size = Vector2i(int(metrics.width), int(metrics.height)) * render_scale
		page.viewport_metrics = func() -> Dictionary: return metrics
		await _reset_pointer_page(page, true)
		page._fit_stage()
		var available: Rect2 = adapter.content_rect(page.size, metrics)
		var stage_bounds := Rect2(page.stage.position, page.stage.size * page.stage.scale)
		_expect(available.grow(0.001).encloses(stage_bounds), "Stage exceeds host safe area")
		_expect(is_equal_approx(page.stage.scale.x, page.stage.scale.y), "Safe-area fit distorted the whole stage")
		if metrics.has("menu"):
			_expect(available.position.y >= (float(metrics.menu.bottom) + 8) * render_scale, "Menu capsule is not excluded")
		for path: String in ["CoinBalance", "Title", "Settings", "Tools/Undo", "Tools/AddBox", "Tools/Top"]:
			var control: Control = page.get_node("Stage/" + path)
			_expect(available.encloses(control.get_global_rect()), "Interactive content overlaps unsafe region: " + path)
		_check_art_aspect(page)
		var title_rect: Rect2 = page.get_node("Stage/Title").get_global_rect()
		var orders_rect: Rect2 = page.orders.cards[0].get_global_rect()
		var tools_rect: Rect2 = page.get_node("Stage/Tools/Undo").get_global_rect()
		var floor_rect: Rect2 = page.backdrop.get_node("Floor").get_global_rect()
		_expect(page.backdrop.get_node("ShopClip/Shop").get_global_rect().grow(0.01).encloses(page.backdrop.get_node("ShopClip").get_global_rect()), "Safe-area wall crop exposes the clear color")
		var header_inset: float = (title_rect.position.y - available.position.y) / render_scale
		var footer_inset: float = (available.end.y - tools_rect.end.y) / render_scale
		_expect(header_inset >= 20.0 and header_inset <= 36.0, "Title has excessive top padding or leaves its safe area")
		_expect(footer_inset >= 23.0 and footer_inset <= 40.0, "Tools are flush with the safe edge or have excessive padding")
		_expect((stage_bounds.position.x - available.position.x) / render_scale >= 16.0,
			"Content is flush with the side of the safe area")
		_expect(is_equal_approx((orders_rect.position.y - title_rect.end.y) / page.stage.scale.y, 20.0),
			"Title/order gap differs from the 20-unit layout specification")
		_expect((stage_bounds.end.y - tools_rect.end.y) / render_scale <= 18.0 and
			(tools_rect.position.y - floor_rect.position.y) / render_scale <= 24.0,
			"Footer expands into a large empty floor or bottom padding")
		_check_layout_geometry(page.board)
		# 柜体与地板独立占位，改验实际纸托及触控容错面积，不沿用旧满屏木台的面积占比。
		for box: DonutBox in page.board.boxes:
			var target: Rect2 = (box.get_global_transform_with_canvas() * box.interaction_rect()).grow(
				DonutBoardInput.HIT_MARGIN * page.board_input.logical_pixel)
			_expect(box.get_global_rect().size.x / page.board_input.logical_pixel >= 44 and
				minf(target.size.x, target.size.y) / page.board_input.logical_pixel >= 44,
				"Paper holder or touch target is too small in the safe area")
		for name: String in ["Tools/Undo", "Tools/AddBox", "Tools/Top"]:
			var button: Control = page.get_node("Stage/" + name)
			_expect(button.get_global_rect().size.y / render_scale >= 44, "Touch target is shorter than 44 logical pixels: " + name)
		await _check_box_entry(page, 0, Rect2(Vector2.ZERO, Vector2(viewport.size)))
		await _check_box_entry(page, 4, Rect2(Vector2.ZERO, Vector2(viewport.size)))
		await _mouse_drag(viewport, _box_point(page, 0), _box_point(page, 1))
		_expect(page.session.moves == 1, "Safe-area offset broke drag hit testing")
		for level_index: int in DonutLevel.catalog().size():
			page.session.load_level(level_index)
			page._cancel_interaction()
			page._fit_stage()
			await process_frame
			_check_layout_geometry(page.board)
			_expect(page.board.boxes.size() == page.session.slots.size(), "Planned layout lost slots")
			_check_board_padding(page)
			for box: DonutBox in page.board.boxes:
				# 短屏允许等比缩小图案以保留留白；验真正的交互面积，仍须达到 44 逻辑像素。
				var target: Rect2 = (box.get_global_transform_with_canvas() * box.interaction_rect()).grow(
					DonutBoardInput.HIT_MARGIN * page.board_input.logical_pixel)
				_expect(box.get_global_rect().size.x / page.board_input.logical_pixel >= 36.0
					and minf(target.size.x, target.size.y) / page.board_input.logical_pixel >= 44.0,
					"Level %d artwork or touch target too small at %s" % [level_index + 1, metrics])
	viewport.queue_free()
	await process_frame
	print("PASS: browser and host padding, 320-440 phones, DPR 1/3, tablet safe areas and real drag coordinates")


## 按真实开局食物和纸托量上下留白，覆盖全部关卡而非只检查三行预留框。
func _check_board_padding(page: Control) -> void:
	var visible_bounds := Rect2()
	var rows: Dictionary = {}
	for box: DonutBox in page.board.boxes:
		var bounds: Rect2 = box.get_global_transform_with_canvas() * box.interaction_rect()
		visible_bounds = visible_bounds.merge(bounds) if visible_bounds.has_area() else bounds
		var layer: int = int(page.board.layout_slots[box.box_index].layer)
		rows[layer] = (rows[layer] as Rect2).merge(bounds) if rows.has(layer) else bounds
	var tabletop: Rect2 = page.backdrop.get_node("TableClip/Tabletop").get_global_rect()
	var table_top: float = page.backdrop.get_node("TableClip").get_global_rect().position.y
	var table_bottom: float = tabletop.end.y - DonutBackground.CABINET_HEIGHT * tabletop.size.x / DonutBackground.MIDDLE_SIZE.x
	var top_padding: float = visible_bounds.position.y - table_top
	var bottom_padding: float = table_bottom - visible_bounds.end.y
	var paper_width: float = page.board.boxes[0].get_global_rect().size.x
	_expect(absf(top_padding - bottom_padding) / page.board_input.logical_pixel < 1.0,
		"Initial visible top/bottom padding differs: " + page.board.layout_id)
	_expect(minf(top_padding, bottom_padding) + 0.01 >= paper_width * 0.4,
		"Board content is crowded against the tabletop edge: " + page.board.layout_id)
	var previous := Rect2()
	for row: Rect2 in rows.values():
		if previous.has_area():
			var gap: float = maxf(0.0, row.position.y - previous.end.y)
			_expect(minf(top_padding, bottom_padding) >= gap * 1.05,
				"Outer padding must exceed every visible row gap: %s (padding %.2f, gap %.2f)" % [page.board.layout_id, minf(top_padding, bottom_padding), gap])
		previous = row


## 计算静态界面树的相对绘制层级，防止新增盒子装饰意外盖住搬运动效。
func _highest_z(item: CanvasItem, parent_z: int = 0) -> int:
	var effective_z: int = parent_z + item.z_index if item.z_as_relative else item.z_index
	var highest: int = effective_z
	for child: Node in item.get_children():
		if child is CanvasItem:
			highest = maxi(highest, _highest_z(child as CanvasItem, effective_z))
	return highest


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
func _reset_pointer_page(page: Control, use_planned_layout: bool = false) -> void:
	var definition: Dictionary = _definition([_box([0, 0, 1, 1]), _box([0]), _box([1])])
	if use_planned_layout:
		# 手机触控检查采用正式首关的十盒构图；密集机制夹具仍独立验证十七盒。
		definition.slots = definition.slots.slice(0, 8) + definition.slots.slice(14, 16)
		definition.layout_id = "level_01"
	page.initialize(DonutSession.new(definition))
	await process_frame
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame


## 命中当前可拿取顶层中心，连续手势不依赖尚未播完的旧快照数量。
func _box_point(page: Control, index: int) -> Vector2:
	var box: DonutBox = page.board.boxes[index]
	var slot: Dictionary = page.session.slots[index]
	var count: int = slot.box.items.size() if slot.box != null else 0
	return box.get_global_transform_with_canvas() * (box.food_position(0, slot.kind == "single", count) + DonutArt.FOOD_SIZE * 0.5)


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
