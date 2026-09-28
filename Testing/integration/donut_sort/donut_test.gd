extends SceneTree
## 验证全部关卡完整解、玩法边界、逐次回收与页面中断后的状态一致性。

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
	_check_reward_tiers()
	await _check_currency_and_settings()
	await _check_level_navigation()
	await _check_ui_lifecycle()
	await _check_group_flight()
	await _check_drag_follow_flight()
	await _check_pointer_input()
	await _check_hit_area_and_no_hints()
	await _check_early_level_drags()
	await _check_portrait_layout()
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
	return {"title": "规则夹具", "slots": slots,
		"demands": [{"sequence": [0], "initially_open": true}, {"sequence": [1], "initially_open": true},
			{"sequence": [2], "initially_open": true}, {"sequence": [3], "initially_open": true}],
		"stock": [], "tools": {"undo": 3, "add_box": 2, "top": 3},
		"combo_rewards": [{"count": 2, "coins": 5, "diamonds": 0}, {"count": 3, "coins": 10, "diamonds": 1}, {"count": 4, "coins": 20, "diamonds": 2}]}


## 正式十关逐步验证完整解、每盒容量、数量守恒及无需道具可解。
func _check_content_and_solutions() -> void:
	var levels: Array = DonutLevel.catalog()
	_expect(levels.size() == 10, "Expected ten playable content levels")
	var definitions: Dictionary = {}
	_expect(DonutArt.FOOD.size() == DonutLevel.FLAVOR_COUNT, "Supported flavor count and artwork mapping differ")
	var artwork: Dictionary = {}
	for texture: Texture2D in DonutArt.FOOD:
		artwork[texture.resource_path] = true
		_expect(texture.get_width() > 0 and texture.get_height() > 0, "Flavor artwork is empty")
	_expect(artwork.size() >= 7, "Expected at least seven distinct flavor textures")
	for index: int in levels.size():
		var definition: Dictionary = DonutLevel.load_definition(levels[index].path)
		_expect(DonutLevel.validate(definition).is_empty(), "Content validation failed")
		_expect(int(definition.id) == index + 1 and definition.title == levels[index].title, "Catalog and level identity differ")
		var layout_key: String = JSON.stringify(definition.slots)
		_expect(not definitions.has(layout_key), "Level %d repeats another opening layout" % (index + 1))
		definitions[layout_key] = true
		var initial_boxes: Array = []
		for slot: Dictionary in definition.slots:
			if slot.box != null:
				initial_boxes.append(slot.box)
		_check_layer_variety(initial_boxes, "level %d opening" % (index + 1))
		_check_layer_variety(definition.stock, "level %d stock" % (index + 1))
		var session := DonutSession.new(definition)
		session.begin()
		_expect_exposed_tops_revealed(session, "level %d opening" % (index + 1))
		var opening_flavors: Dictionary = {}
		for slot_index: int in session.slots.size():
			if session.can_pick_top(slot_index):
				opening_flavors[session.slots[slot_index].box.items[0].flavor] = true
		_expect(opening_flavors.size() >= 7, "Level %d must expose at least seven flavors at opening" % (index + 1))
		var hidden_boxes: int = 0
		for slot: Dictionary in session.slots:
			if slot.box != null and slot.box.items.any(func(item: Dictionary) -> bool: return not item.revealed):
				hidden_boxes += 1
		_expect(hidden_boxes == 1, "Level %d should start with exactly one hidden-layer box" % (index + 1))
		var fixture_path: String = get_script().resource_path.get_base_dir().path_join("../../fixtures/donut_sort/level_%02d_solution.json" % (index + 1))
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
		_expect(session.slots.size() == 17 and session.demands.size() == 4 and session.next_turnover() == 16, "Initial slot/demand structure")
		_expect(session.demands[0].open and session.demands[1].open and not session.demands[2].open and not session.demands[3].open,
			"Level %d must begin with only the left two order slots open" % (index + 1))
		for step: Array in fixture.steps:
			_expect(session.move(int(step[0]), int(step[1])), "Level %d invalid move %s at %d" % [index + 1, step, session.moves])
			_expect_exposed_tops_revealed(session, "level %d move %d" % [index + 1, session.moves])
			_expect(session.remaining_donuts() + session.completed * 4 == session.total_donuts(), "Food conservation failed")
			for slot_index: int in session.slots.size():
				var slot: Dictionary = session.slots[slot_index]
				_expect(slot.box == null or slot.box.items.size() <= session.capacity(slot_index), "Capacity exceeded")
		_expect(session.is_won() and session.moves == int(fixture.moves), "Full solution failed level %d" % (index + 1))
		_expect(not session.demands[2].open and not session.demands[3].open, "Completing orders automatically unlocked a reserved order slot")
		_expect(session.slots.filter(func(slot: Dictionary) -> bool: return slot.box != null).size() == (3 if index < 6 else 2),
			"Level %d victory did not retain its two/three base boxes" % (index + 1))
		_expect(session.tools == {"undo": 1, "add_box": 1, "top": 1}, "Full solution spent tools")
		_expect(not session.move(0, 1) and not session.add_box(), "Won session accepts new actions")
		print("PASS: level %d, %d opening flavors, %d moves, %d orders, %d donuts conserved" % [index + 1, opening_flavors.size(), session.moves, session.completed, session.total_donuts()])
		if index == 2:
			_expect(definition.stock.size() + initial_boxes.size() == 27, "Long level must contain 27 preset boxes")
			_expect(session.best_combo >= 3 and session.coins > 0 and session.diamonds > 0, "Mixed demand level must exercise automatic combos and rewards")
	var invalid: Dictionary = DonutLevel.load_definition(levels[0].path).duplicate(true)
	invalid.slots[0].box.items[0].flavor = 99
	_expect(not DonutLevel.validate(invalid).is_empty(), "Invalid flavor escaped content validator")
	invalid = DonutLevel.load_definition(levels[0].path).duplicate(true)
	invalid.demands[0].sequence.pop_back()
	_expect(not DonutLevel.validate(invalid).is_empty(), "Unbalanced flavor totals escaped validator")
	invalid = DonutLevel.load_definition(levels[0].path).duplicate(true)
	invalid.slots[0].box.hidden_layers = "true"
	_expect(not DonutLevel.validate(invalid).is_empty(), "String hidden_layers escaped content validator")
	invalid = DonutLevel.load_definition(levels[0].path).duplicate(true)
	for slot: Dictionary in invalid.slots:
		if slot.box != null:
			for item: Dictionary in slot.box.items:
				item.flavor = int(item.flavor) % 6
	for box: Dictionary in invalid.stock:
		for item: Dictionary in box.items:
			item.flavor = int(item.flavor) % 6
	for demand: Dictionary in invalid.demands:
		demand.sequence = demand.sequence.map(func(flavor: Variant) -> int: return int(flavor) % 6)
	_expect(DonutLevel.validate(invalid).has("level must contain at least 7 flavors"), "Balanced six-flavor level escaped minimum variety validation")


## 限制成对满盒比例，要求多数满盒混入三四种口味并保留不同重复层位。
func _check_layer_variety(boxes: Array, context: String) -> void:
	var full_boxes: int = 0
	var paired_boxes: int = 0
	var mixed_boxes: int = 0
	var patterns: Dictionary = {}
	for box: Dictionary in boxes:
		if box.items.size() != 4:
			continue
		full_boxes += 1
		var flavors: Dictionary = {}
		var pattern: String = ""
		for item: Dictionary in box.items:
			var flavor: int = int(item.flavor)
			if not flavors.has(flavor):
				flavors[flavor] = flavors.size()
			pattern += "ABCD"[flavors[flavor]]
		patterns[pattern] = true
		if pattern == "AABB":
			paired_boxes += 1
		if flavors.size() >= 3:
			mixed_boxes += 1
	if full_boxes == 0:
		return
	_expect(paired_boxes * 4 <= full_boxes, "%s has too many AABB boxes: %d/%d" % [context, paired_boxes, full_boxes])
	_expect(mixed_boxes * 4 >= full_boxes * 3, "%s lacks three/four-flavor boxes: %d/%d" % [context, mixed_boxes, full_boxes])
	if full_boxes >= 4:
		_expect(patterns.size() >= 3 and patterns.has("ABCD"), "%s lacks varied layer patterns and four-flavor boxes" % context)
	print("PASS: %s layer variety, %d/%d three/four-flavor boxes, %d AABB, patterns %s" % [context, mixed_boxes, full_boxes, paired_boxes, patterns.keys()])


## 所有关卡开局提供二至三盒整理余量，普通空盒可直接搬入且通关预算一致。
func _check_early_level_space() -> void:
	for index: int in DonutLevel.catalog().size():
		var definition: Dictionary = DonutLevel.load_definition(DonutLevel.catalog()[index].path)
		var session := DonutSession.new(definition)
		session.begin()
		var containers: int = 0
		var empty_boxes: int = 0
		var capacity: int = 0
		var food: int = 0
		var legal_moves: int = 0
		for source: int in session.slots.size():
			var slot: Dictionary = session.slots[source]
			if slot.box == null:
				continue
			containers += 1
			capacity += session.capacity(source)
			food += slot.box.items.size()
			if slot.box.items.is_empty():
				empty_boxes += 1
			for target: int in session.slots.size():
				if session.can_move(source, target):
					legal_moves += 1
		var spare_count: int = 3 if index < 6 else 2
		_expect(empty_boxes >= 2 and empty_boxes <= 3 and capacity - food == spare_count * 4,
			"Level %d does not provide its two/three boxes of opening buffer capacity" % (index + 1))
		_expect(containers + definition.stock.size() - session.total_orders() == spare_count, "Level %d has an incorrect base container budget" % (index + 1))
		_expect(legal_moves > 0 and session.completed == 0, "Dense opening is blocked or automatically clears itself")
		var before: Dictionary = session.snapshot()
		var source: int = 0
		while source < session.slots.size() and not session.can_pick_top(source):
			source += 1
		_expect(session.can_handle(15) and session.move(source, 15) and session.tools.add_box == 1,
			"Additional opening buffer is not usable without spending add box")
		_expect(session.undo() and session.slots == before.slots, "Undo failed to restore the additional opening buffer")
		print("PASS: level %d box budget, %d + %d - %d = %d; opening %d/%d filled, %d empty, %d legal routes" %
			[index + 1, containers, definition.stock.size(), session.total_orders(), spare_count, food, capacity, empty_boxes, legal_moves])
	var two_spares: Dictionary = DonutLevel.load_definition(DonutLevel.catalog()[0].path)
	two_spares.slots[15] = {"kind": "turnover", "unlock_after": -1, "box": null}
	_expect(DonutLevel.validate(two_spares).is_empty(), "Two spare containers should remain a valid level budget")
	two_spares.slots[12].box = null
	_expect(DonutLevel.validate(two_spares).has("level must finish with two or three base containers, got 1"),
		"One-buffer level escaped the new minimum budget")
	var invalid: Dictionary = DonutLevel.load_definition(DonutLevel.catalog()[0].path)
	invalid.stock.append(_box([]))
	_expect(DonutLevel.validate(invalid).has("level must finish with two or three base containers, got 4"),
		"Excess containers escaped validation despite balanced food totals")


## 道具盒实际参与搬运后，通关等量归还额外空盒；撤回恢复，重做不重复收盒或发奖。
func _check_spare_box_return() -> void:
	for level_index: int in DonutLevel.catalog().size():
		var definition: Dictionary = DonutLevel.load_definition(DonutLevel.catalog()[level_index].path)
		var path: String = get_script().resource_path.get_base_dir().path_join("../../fixtures/donut_sort/level_%02d_solution.json" % (level_index + 1))
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for use_as_main_buffer: bool in ([false, true] if level_index < 2 else [false]):
			var session := DonutSession.new(definition)
			session.begin()
			var extra_index: int = session.next_turnover()
			_expect(session.add_box(), "Spare box fixture cannot activate its one extra container")
			var steps: Array = fixture.steps.duplicate(true)
			if use_as_main_buffer:
				for step: Array in steps:
					for side: int in 2:
						if int(step[side]) == 12:
							step[side] = extra_index
			else:
				var first: Array = steps.pop_front()
				steps.push_front([extra_index, first[1]])
				steps.push_front([first[0], extra_index])
			var events: Array = []
			session.changed.connect(func(batch: Array) -> void: events.append_array(batch))
			for step: Array in steps.slice(0, -1):
				_expect(session.move(int(step[0]), int(step[1])), "Spare-box path failed before final move at level %d" % (level_index + 1))
			_expect(events.all(func(event: Dictionary) -> bool: return event.kind != "spare_return"), "Spare container returned before victory")
			var before: Dictionary = session.snapshot()
			var final_step: Array = steps.back()
			events.clear()
			_expect(session.move(int(final_step[0]), int(final_step[1])) and session.is_won(), "Spare-box path did not win")
			var after: Dictionary = session.snapshot()
			_expect(session.slots.filter(func(slot: Dictionary) -> bool: return slot.box != null).size() == (3 if level_index < 6 else 2),
				"Victory did not retain the base box budget after returning the added box")
			_expect(events.filter(func(event: Dictionary) -> bool: return event.kind == "spare_return").size() == 1,
				"Victory did not return exactly one added container")
			_expect(session.completed == session.total_orders() and session.remaining_donuts() == 0, "Spare return affected actual order completion")
			_expect(session.undo() and session.slots == before.slots and session.completed == before.completed and not session.is_won(),
				"Undo did not restore the final move and returned spare container")
			events.clear()
			_expect(session.move(int(final_step[0]), int(final_step[1])) and session.slots == after.slots
				and session.coins == after.coins and session.diamonds == after.diamonds, "Replaying victory duplicated returns or rewards")
	print("PASS: ten-level add-box use, dispatched turnover, two/three-box victory, undo and replay")


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
	_expect(session.slots[2].box.lid == 1 and session.slots[3].box.lid == 2, "Not all old lids decremented once")
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
	_expect(session.tools == {"undo": 1, "add_box": 1, "top": 1}, "Default tools must each have one charge")
	_expect(session.add_box() and session.tools.add_box == 0 and not session.add_box(), "Add box exceeded its single charge")
	_expect(session.bring_to_top(4, 1) and session.tools.top == 0 and not session.bring_to_top(4, 2), "Top exceeded its single charge")
	_expect(session.undo() and session.tools.undo == 0 and not session.undo(), "Undo exceeded its single charge")
	_expect(session.tools.top == 1 and session.tools.add_box == 0, "Undo did not refund only the reversed tool action")
	session.restart()
	_expect(session.completed == 0 and session.moves == 0 and session.coins == 0
		and session.tools == {"undo": 1, "add_box": 1, "top": 1}, "Restart did not reset level ledger and single tool charges")


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


## 用真实会话奖励与撤回验证常驻金币栏，并检查齿轮面板可操作。
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
	_expect(coin_balance.visible and coin_balance.get_node("Amount").text == "0", "Opening coin balance is missing or not zero")
	coin_balance.present(1280)
	_expect(coin_balance.get_node("Amount").text == "1,280", "Coin balance thousands separator is incorrect")
	page._render()
	_expect(coin_balance.get_node("Amount").text == "0", "Coin balance ignored the session snapshot")
	_expect(page.session.move(1, 0) and page.session.coins == 10, "Reward fixture did not produce coins")
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(coin_balance.get_node("Amount").text == "10", "Coin balance did not follow combo reward")
	page.get_node("Stage/Settings").pressed.emit()
	var panel: DonutSettingsPanel = page.get_node("Stage/SettingsPanel")
	_expect(panel.visible and panel.get_node("Card/Heading").text == "游戏设置", "Gear did not open settings")
	_expect(panel.get_node("Card/Detail").text.contains("金币 10"), "Settings did not show the real balance")
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
	await process_frame
	await process_frame
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(page.session.moves == 0 and page.session.coins == 0 and coin_balance.get_node("Amount").text == "0",
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
		var point: Vector2 = choices.get_child(index).get_global_rect().get_center()
		await _mouse_button(viewport, point, true)
		await _mouse_button(viewport, point, false)
		await process_frame
		page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_expect(page.session.level_index == index and not panel.visible and page.session.moves == 0,
			"Menu click did not load level %d" % (index + 1))
		_expect(page.get_node("Stage/Title").text == "第 %d 关" % (index + 1), "Header shows wrong level number")
		_expect(page.session.tools == {"undo": 1, "add_box": 1, "top": 1}, "Level selection failed to reset tool charges")
	for index: int in [2, 8, 9]:
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
		var next: Button = page.get_node("Stage/Modal/Card/Restart")
		_expect(page.modal.visible and page.session.is_won(), "Victory modal did not open")
		_expect(next.text == ("下一关" if index < 9 else "再玩一遍"), "Last-level navigation label is incorrect")
		var point: Vector2 = next.get_global_rect().get_center()
		await _mouse_button(viewport, point, true)
		await _mouse_button(viewport, point, false)
		await process_frame
		page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_expect(page.session.level_index == mini(index + 1, 9) and page.session.moves == 0 and not page.session.is_won(),
			"Next/replay navigation did not load the correct fresh level")
	viewport.queue_free()
	await process_frame
	print("PASS: ten-level menu bounds, mouse selection, level 3/9 advance and level 10 replay")


## 通过场景交互验证开局、取消、隐藏、外部暂停、切关和完整界面操作。
func _check_ui_lifecycle() -> void:
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	root.add_child(page)
	await process_frame
	await process_frame
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(page.session.started and not page._busy and page.get_node("Stage/Orders/Panel/Order3") != null, "Initial animation/four demand scene failed")
	for button: String in ["Undo", "AddBox", "Top"]:
		_expect(page.get_node("Stage/Tools/%s/Count" % button).text == "1", "Opening tool badge is not one: " + button)
	for index: int in page.orders.cards.size():
		var card: DonutOrderCard = page.orders.cards[index]
		_expect(card.food.visible == (index < 2) and card.lock_icon.visible == (index >= 2), "Initial order card shows the wrong open/locked state")
		_expect(card.count_label.text == ("×4" if index < 2 else "锁定"), "Initial order card leaks quantity into a locked slot")
	var visible_flavor_art: Dictionary = {}
	for index: int in page.board.boxes.size():
		if page.session.can_pick_top(index):
			var food: TextureRect = page.board.boxes[index].food_stack.food_at(0)
			var flavor: int = page.session.slots[index].box.items[0].flavor
			_expect(food.visible and food.texture == DonutArt.FOOD[flavor], "Opening top artwork differs from flavor at box %d" % index)
			visible_flavor_art[food.texture] = true
	_expect(visible_flavor_art.size() >= 7, "Opening board did not display seven distinct flavor textures")
	var opening_box: DonutBox = page.board.boxes[0]
	_expect(opening_box.food_stack.food_at(0).texture == DonutArt.FOOD[0] and
		opening_box.food_stack.food_at(1).texture == DonutArt.FOOD[0],
		"Ordinary opening box did not show its lower flavor")
	var hidden_box: DonutBox = page.board.boxes[4]
	_expect(hidden_box.food_stack.food_at(0).texture == DonutArt.FOOD[0] and
		hidden_box.food_stack.food_at(1).texture == DonutArt.HIDDEN and
		hidden_box.food_stack.food_at(3).texture == DonutArt.HIDDEN,
		"Designated opening box did not show gray lower layers")
	page.get_node("Stage/Boxes/Box0").pressed.emit()
	_expect(page.selected_box == 0, "Source selection not wired")
	page.hide()
	page.show()
	_expect(page.selected_box == -1, "Hide retained selection")
	page.get_node("Stage/Tools/Top").pressed.emit()
	page.get_node("Stage/Boxes/Box0").pressed.emit()
	_expect(page.get_node("Stage/Modal").visible, "Top choices missing")
	page.get_node("Stage/Modal/Card/Resume").pressed.emit()
	_expect(page.session.tools.top == 1, "Cancel spent a top charge")
	page.get_node("Stage/Boxes/Box0").pressed.emit()
	page.get_node("Stage/Boxes/Box12").pressed.emit()
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
	_expect(not page.get_node("Stage/Modal").visible, "Idle cancel still opens a pause menu")
	var title_release := InputEventMouseButton.new()
	title_release.button_index = MOUSE_BUTTON_LEFT
	page.get_node("Stage/Title").gui_input.emit(title_release)
	_expect(page.get_node("Stage/SettingsPanel/Card/Choices").get_child_count() == 10, "Level selection missing")
	page.get_node("Stage/SettingsPanel/Card/Choices").get_child(1).pressed.emit()
	await process_frame
	await process_frame
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(page.session.level_index == 1 and not page.session.demands[3].open, "Level selection not connected to the revised second level")
	_expect(page.session.tools == {"undo": 1, "add_box": 1, "top": 1}, "Changing level did not restore one charge per tool")
	page.get_node("Stage/Tools/Top").pressed.emit()
	page.get_node("Stage/Boxes/Box2").pressed.emit()
	var hidden_choice: Button = page.get_node("Stage/Modal/Card/Choices").get_child(2)
	_expect(not hidden_choice.disabled and hidden_choice.icon == DonutArt.HIDDEN, "Top modal did not offer a concealed layer")
	hidden_choice.pressed.emit()
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(page.session.slots[2].box.items[0].flavor == 3 and page.session.slots[2].box.items[0].revealed and
		page.session.tools.top == 0, "Top modal did not reveal selected gray layer")
	var revealed_box: DonutBox = page.board.boxes[2]
	_expect(revealed_box.food_stack.food_at(0).texture == DonutArt.FOOD[3] and
		revealed_box.food_stack.food_at(1).texture == DonutArt.FOOD[2] and
		revealed_box.food_stack.food_at(2).texture == DonutArt.HIDDEN,
		"Board did not preserve a covered known flavor")
	page.get_node("Stage/Tools/Top").pressed.emit()
	page.get_node("Stage/Boxes/Box2").pressed.emit()
	_expect(not page.get_node("Stage/Modal").visible and page.get_node("Stage/Tools/Top/Count").text == "0",
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
		if layer is CanvasItem and layer != effects_layer and layer != page.get_node("Stage/Toast") and layer != page.get_node("Stage/Modal") and layer != page.get_node("Stage/SettingsPanel"):
			highest_static_z = maxi(highest_static_z, _highest_z(layer as CanvasItem))
	_expect(effects_layer.z_index > highest_static_z, "Moving donuts can be covered by a tray or other static art")
	_expect(page.get_node("Stage/Toast").z_index > effects_layer.z_index
		and page.get_node("Stage/Modal").z_index > page.get_node("Stage/Toast").z_index
		and page.get_node("Stage/SettingsPanel").z_index > page.get_node("Stage/Modal").z_index,
		"Board, effects, feedback and modal layers are out of order")
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


## 正式前两关使用新增普通空盒完成鼠标拖拽全解，验证结算画面留下三个盒体。
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
		for step: Array in fixture.steps:
			for side: int in 2:
				if int(step[side]) == 12:
					step[side] = 15
			var previous_moves: int = page.session.moves
			await _mouse_drag(viewport, _box_point(page, int(step[0])), _box_point(page, int(step[1])))
			_expect(page.session.moves == previous_moves + 1, "Level %d drag %s did not commit" % [index + 1, step])
			page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_expect(page.session.is_won() and page.session.tools == {"undo": 1, "add_box": 1, "top": 1}, "Early-level drag solution did not finish without tools")
		_expect(page.board.boxes.filter(func(box: DonutBox) -> bool: return box.visible and box.back.visible).size() == 3, "Victory board does not display exactly three base boxes")
	viewport.queue_free()
	await process_frame
	print("PASS: early levels use the new free buffer through mouse dragging and display three remaining boxes")


## 连续切换竖屏尺寸，验证点击区域互不重叠、底部可达且缩放会取消旧拖拽。
func _check_portrait_layout() -> void:
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
		var first_index: int = 0
		for row_count: int in [5, 5, 5, 2]:
			var first_box: Rect2 = boxes[first_index].get_global_rect()
			var last_box: Rect2 = boxes[first_index + row_count - 1].get_global_rect()
			_expect(absf((first_box.position.x + last_box.end.x) * 0.5 - page.board.get_global_rect().get_center().x) < 1,
				"Five-column board row is not centered")
			for index: int in range(first_index, first_index + row_count):
				_expect(is_equal_approx(boxes[index].get_global_rect().position.y, first_box.position.y), "Five-column row is not aligned")
			first_index += row_count
			if first_index < boxes.size():
				_expect(boxes[first_index].get_global_rect().position.y > first_box.end.y, "Five-column rows overlap")
		var background: DonutBackground = page.get_node("Backdrop")
		var tabletop: TextureRect = background.get_node("Tabletop")
		var shop: TextureRect = background.get_node("ShopClip/Shop")
		var shop_crop: AtlasTexture = shop.texture as AtlasTexture
		_expect(background.get_global_rect().is_equal_approx(bounds), "Background does not fill portrait viewport")
		_expect(tabletop.get_global_rect().encloses(bounds), "Tabletop leaves empty viewport margins")
		_expect(shop_crop != null and tabletop.texture.resource_path.ends_with("tabletop_light.png") and
			shop_crop.atlas.resource_path.ends_with("shop_background_unified.png"),
			"Approved shop and tabletop assets are not displayed")
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
			_expect(box.back.get_rect().is_equal_approx(box.front.get_rect()), "Paper holder front/back geometry diverged")
			_expect(box.back.texture.region == box.front.texture.region, "Paper holder front/back crop regions diverged")
			_expect(box.back.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and
				box.front.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Paper holder art is stretched")
			_expect(box.back.texture.atlas.resource_path.ends_with("paper_holder_empty.png") and
				box.front.texture.atlas.resource_path.ends_with("paper_holder_front.png"), "Approved paper holder assets are not displayed")
		var dispatch: Control = page.get_node("Stage/Dispatch")
		var paper_back: TextureRect = dispatch.get_node("Back")
		_expect(dispatch.get_child_count() == 2 and paper_back.get_rect().is_equal_approx(dispatch.get_node("Front").get_rect()),
			"Removed stock preview or labels returned, or paper box layers diverged")
		_expect(bounds.encloses(paper_back.get_global_rect()), "Paper box is outside portrait viewport")
		var single_box: DonutBox = boxes[0]
		var single_box_state: Dictionary = _box([0]).merged({"frozen": false})
		single_box_state.items[0].revealed = true
		single_box.present({"kind": "single", "open": true, "box": single_box_state})
		var food_center: Vector2 = single_box.food_stack.food_at(0).get_rect().get_center()
		_expect(single_box.back.visible and single_box.front.visible and not single_box.closed.visible and
			Rect2(Vector2.ZERO, single_box.size).has_point(food_center), "Single-donut food left its paper holder")
		_expect(single_box.food_position(0, false, 4).y < 0 and
			single_box.food_position(3, false, 4).y > -DonutArt.FOOD_SIZE.y * 0.1,
			"Four donuts do not rest against the paper holder opening")
		_expect(_highest_z(single_box.food_stack) < single_box.front.z_index,
			"Paper holder lip does not cover the lower donut edge")
		page._render()
		for index: int in boxes.size():
			var area: Rect2 = boxes[index].get_global_rect()
			_expect(bounds.encloses(area), "Box outside portrait viewport: %s/%d" % [dimensions, index])
			var stack_area: Rect2 = boxes[index].get_global_transform_with_canvas() * boxes[index].interaction_rect()
			_expect(bounds.encloses(stack_area), "Donut stack outside portrait viewport")
			for other: int in range(index + 1, boxes.size()):
				_expect(not area.intersects(boxes[other].get_global_rect()), "Box hit areas overlap after resize")
				var other_stack: Rect2 = boxes[other].get_global_transform_with_canvas() * boxes[other].interaction_rect()
				_expect(not stack_area.intersects(other_stack), "Five-column donut stacks overlap")
		for name: String in ["Undo", "AddBox", "Top"]:
			var button: Control = page.get_node("Stage/Tools/" + name)
			_expect(bounds.encloses(button.get_global_rect()), "Tool outside portrait viewport: " + name)
			var button_center_y: float = button.get_global_rect().get_center().y
			var paper_center_y: float = paper_back.get_global_rect().get_center().y
			_expect(paper_center_y < button_center_y and
				button_center_y - paper_center_y < button.get_global_rect().size.y * 0.25,
				"Paper box is not aligned just above the tool row: " + name)
			_expect(not button.get_global_rect().intersects(paper_back.get_global_rect()), "Tool overlaps paper box: " + name)
	page.event_player._animation = page.event_player.create_tween()
	page.event_player._append_box_flight(page.session.slots[0], 0, 0.2)
	var flying_box: DonutBox = page.get_node("Stage/Effects").get_child(-1)
	_expect((flying_box.position + flying_box.size * flying_box.scale * 0.5).is_equal_approx(page.dispatch.center_in_stage()),
		"Initial/refill box does not emerge from the paper box")
	page.event_player._animation.kill()
	flying_box.queue_free()
	viewport.queue_free()
	await process_frame
	print("PASS: paper holder proportions, donut stack layers, portrait bounds and resize cancellation")


## 对照底图卡槽像素边界，验证不同尺寸和状态下的图文居中与完整留白。
func _check_order_card_layout() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	# 这些边界来自原始底图，独立于内容控件的位置和尺寸。
	var artwork_slots: Array[Rect2] = [Rect2(150, 140, 438, 442), Rect2(629, 140, 438, 442),
		Rect2(1107, 140, 438, 442), Rect2(1585, 140, 438, 442)]
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
			page.orders.present(demands, 0, 8)
			await process_frame
			await process_frame
			var panel: TextureRect = page.orders.get_node("Panel")
			var panel_rect: Rect2 = panel.get_global_rect()
			var art_scale: Vector2 = panel_rect.size / panel.texture.get_size()
			for index: int in 4:
				var card: DonutOrderCard = page.orders.cards[index]
				var source: Rect2 = artwork_slots[index]
				var frame := Rect2(panel_rect.position + source.position * art_scale, source.size * art_scale)
				var context: String = "%s/%s/card%d" % [dimensions, status, index]
				var contents: Array[Control] = [card.count_label]
				if status == "active":
					contents.append(card.food)
				elif status == "locked":
					contents.append(card.lock_icon)
				for content: Control in contents:
					var bounds: Rect2 = content.get_global_rect()
					_expect(content.visible and frame.encloses(bounds), "Order content crosses artwork border: " + context)
					_expect(absf(bounds.get_center().x - frame.get_center().x) < 1.0,
						"Order content drifts from artwork center: " + context)
				_expect(card.count_label.size.y >= card.count_label.get_minimum_size().y,
					"Order label is smaller than its actual font height: " + context)
				_expect(not card.food.get_global_rect().intersects(card.count_label.get_global_rect()),
					"Order illustration overlaps quantity row: " + context)
	viewport.queue_free()
	await process_frame
	print("PASS: order artwork slot alignment, font bounds and active/locked/completed layouts at four viewport sizes")


## 用手机、长屏和平板宿主数据验证安全区、等比缩放及缩放后的真实拖拽命中。
func _check_host_safe_area() -> void:
	var adapter: Script = load("res://platforms/minigame/host_viewport.gd")
	_expect(adapter.content_rect(Vector2(720, 1280), {}) == Rect2(0, 0, 720, 1280), "Desktop viewport fallback changed")
	var viewport := SubViewport.new()
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	var cases: Array = [
		{"width": 393, "height": 852, "safeArea": {"top": 59, "bottom": 818},
			"menu": {"bottom": 104, "width": 80, "height": 32}},
		{"width": 360, "height": 800, "statusBarHeight": 24,
			"menu": {"bottom": 64, "width": 80, "height": 32}},
		{"width": 768, "height": 1024, "safeArea": {"left": 12, "right": 756, "top": 24, "bottom": 1000}},
	]
	for metrics: Dictionary in cases:
		viewport.size = Vector2i(int(metrics.width), int(metrics.height))
		page.viewport_metrics = func() -> Dictionary: return metrics
		await _reset_pointer_page(page)
		page._fit_stage()
		var available: Rect2 = adapter.content_rect(page.size, metrics)
		var stage_bounds := Rect2(page.stage.position, page.stage.size * page.stage.scale)
		_expect(available.grow(0.001).encloses(stage_bounds), "Stage exceeds host safe area")
		_expect(is_equal_approx(page.stage.scale.x, page.stage.scale.y), "Safe-area fit distorted the whole stage")
		if metrics.has("menu"):
			_expect(available.position.y >= float(metrics.menu.bottom) + 8, "Menu capsule is not excluded")
		for path: String in ["CoinBalance", "Title", "Settings", "Tools/Undo", "Tools/AddBox", "Tools/Top"]:
			var control: Control = page.get_node("Stage/" + path)
			_expect(available.encloses(control.get_global_rect()), "Interactive content overlaps unsafe region: " + path)
		_check_art_aspect(page)
		var board: Control = page.get_node("Stage/Boxes")
		_expect(board.get_global_rect().size.y / available.size.y >= 0.55, "Mobile board uses less than 55% of safe height")
		for name: String in ["Tools/Undo", "Tools/AddBox", "Tools/Top"]:
			var button: Control = page.get_node("Stage/" + name)
			_expect(button.get_global_rect().size.y >= 44, "Touch target is shorter than 44 logical pixels: " + name)
		_expect(page.get_node("Stage/Dispatch/Back").visible, "Paper box icon is hidden")
		await _mouse_drag(viewport, _box_point(page, 0), _box_point(page, 1))
		_expect(page.session.moves == 1, "Safe-area offset broke drag hit testing")
	viewport.queue_free()
	await process_frame
	print("PASS: phone/tablet safe areas, uniform scale and drag coordinates")


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
func _reset_pointer_page(page: Control) -> void:
	page.initialize(DonutSession.new(_definition([_box([0, 0, 1, 1]), _box([0]), _box([1])])))
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
