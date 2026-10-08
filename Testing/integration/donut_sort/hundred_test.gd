extends SceneTree
## 用正式会话独立回放百关四种周转条件，检查数量、机制与时间边界。

var failures: Array[String] = []


## 推迟到引擎完成类注册后执行验证。
func _initialize() -> void:
	_run.call_deferred()


## 失败保留关号与步号，禁止仅凭进程退出宣称关卡有效。
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


## 同时检查策划数量与每一步容量守恒，再验证独立机制边界。
func _run() -> void:
	var plans: Array = JSON.parse_string(FileAccess.get_file_as_string("res://game_content/donuts/level_plan.json")).levels
	var levels: Array = DonutLevel.catalog()
	check(levels.size() == 100, "Catalog must contain 100 levels")
	var stock_levels: int = 0
	var short_bomb_levels: int = 0
	var long_bomb_levels: int = 0
	var mechanism_firsts: Dictionary = {}
	for index: int in levels.size():
		var definition: Dictionary = DonutLevel.load_definition(levels[index].path)
		if definition.is_empty():
			check(false, "Invalid definition %d" % (index + 1))
			continue
		var plan: Dictionary = plans[index]
		if index >= 30 and index <= 39:
			_check_wave_thirty_one(definition, index - 30)
		for key: String in ["undo", "add_box", "top"]:
			check(int(definition.tools.get(key, 0)) == 1, "Every level must enable the three tools")
		var has_bomb: bool = definition.slots.any(func(slot: Dictionary) -> bool: return slot.box != null and slot.box.kind == "bomb")
		if has_bomb:
			var timer: float = float(definition.design.bomb_timing.seconds)
			short_bomb_levels += 1 if timer < 100 else 0
			long_bomb_levels += 1 if timer >= 100 else 0
		var filled: int = 0
		var empty: int = 0
		var single: int = 0
		var flavors: Dictionary = {}
		for slot: Dictionary in definition.slots:
			if slot.kind == "single":
				single += 1
			elif slot.box != null:
				filled += 1 if not slot.box.items.is_empty() else 0
				empty += 1 if slot.box.items.is_empty() else 0
			if slot.box != null:
				var kind: String = "single" if slot.kind == "single" else str(slot.box.kind)
				if kind != "normal" and not mechanism_firsts.has(kind):
					mechanism_firsts[kind] = index + 1
				for item: Dictionary in slot.box.items:
					flavors[int(item.flavor)] = true
					if item.get("hidden", false) and not mechanism_firsts.has("hidden"):
						mechanism_firsts.hidden = index + 1
		for box: Dictionary in definition.stock:
			for item: Dictionary in box.items:
				flavors[int(item.flavor)] = true
		check(filled == int(plan.filled) and empty == int(plan.empty) and single == int(plan.single), "Plan box counts %d" % (index + 1))
		check(flavors.size() == int(plan.flavors) and definition.stock.size() == int(plan.stock), "Plan flavors/stock %d" % (index + 1))
		stock_levels += 1 if not definition.stock.is_empty() else 0
		var path: String = get_script().resource_path.get_base_dir().path_join("../../fixtures/donut_sort/level_%02d_solution.json" % (index + 1))
		var solution: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for mode: int in 4:
			var session := DonutSession.new(definition)
			var refills: Array = []
			session.changed.connect(func(events: Array) -> void:
				for event: Dictionary in events:
					if event.kind == "refill":
						refills.append(event)
			)
			session.begin()
			check(session.completed == 0, "Opening auto-clears %d" % (index + 1))
			var unlocked: Array[int] = []
			for offset: int in 2:
				if mode & (1 << offset):
					var slot_index: int = session.slots.size() - 2 + offset
					var token: String = session.request_turnover(slot_index)
					check(session.resolve_turnover(token, true), "Unlock specified A/B")
					check(not session.resolve_turnover(token, true), "Duplicate reward accepted")
					unlocked.append(slot_index)
			var steps: Array = solution.get("assist", {}).get(str(mode), solution.steps).duplicate(true)
			var interval_start: int = -1
			var interval_progress: int = 0
			var interval_has_group: bool = false
			var interval_split_group: bool = false
			var midgame_count: int = 0
			var first_group_step: int = -1
			var refill_steps: Array[int] = []
			var first_single_in: int = -1
			var first_single_out: int = -1
			for step_index: int in steps.size():
				var step: Array = steps[step_index]
				if mode == 0 and interval_start < 0:
					interval_start = step_index
					interval_progress = session.completed
					interval_has_group = _has_one_step_group(session)
					interval_split_group = false
				var source: int = int(step[0])
				var target: int = int(step[1])
				var grouping: bool = _is_new_group(session, source, target)
				var refills_before: int = refills.size()
				if mode == 0:
					interval_split_group = interval_split_group or session.slots[source].box.grouped
				# 三秒仅为自动回放的操作预算；真人拆弹耗时仍须试玩标定。
				session.advance_clock(3.0 if has_bomb else 1.0)
				if not session.move(int(step[0]), int(step[1])):
					check(false, "Level %d mode %d invalid move %s step %d" % [index + 1, mode, step, step_index])
					break
				if session.slots[target].kind == "single" and first_single_in < 0:
					first_single_in = step_index + 1
				if session.slots[source].kind == "single" and first_single_out < 0:
					first_single_out = step_index + 1
				if mode == 0 and grouping:
					if first_group_step < 0:
						first_group_step = step_index + 1
						if index == 17 or index == 18 or index == 20:
							check(session.completed > 0, "Ordinary ice practice must deliver its first group")
					var fraction: float = float(interval_progress) / session.total_orders()
					if fraction >= 0.3 and fraction <= 0.7 and step_index > interval_start and not interval_has_group and not interval_split_group:
						midgame_count += 1
					interval_start = -1
				if mode == 0 and refills.size() > refills_before:
					refill_steps.append(step_index + 1)
					# 补货教学的基线路线留有可操作余量，余量仍受顶层同味限制。
					if index == 8 or (index >= 13 and index <= 16) or (index >= 25 and index <= 27) or index in [33, 36, 37]:
						var usable_space: int = 0
						for slot_index: int in session.slots.size():
							if session.can_handle(slot_index):
								usable_space += session.capacity(slot_index) - session.slots[slot_index].box.items.size()
						check(usable_space >= 4, "Level %d refill leaves no planned working space" % (index + 1))
				check(session.remaining_donuts() + session.completed * 4 == session.total_donuts(), "Conservation %d/%d" % [index + 1, step_index])
				for slot_index: int in session.slots.size():
					check(session.slots[slot_index].box == null or session.slots[slot_index].box.items.size() <= session.capacity(slot_index), "Capacity exceeded")
			check(session.is_won() and not session.failed, "Level %d mode %d incomplete" % [index + 1, mode])
			if mode == 0:
				check(midgame_count >= int(plan.midgame_space_min) and midgame_count == int(solution.midgame_metrics.count),
					"R2 midgame %d actual %d target %d recorded %d" % [index + 1, midgame_count, plan.midgame_space_min, solution.midgame_metrics.count])
				if index >= 4 and index <= 39:
					check(first_group_step == int(solution.opening_metrics.first_group_moves), "Early wave opening prefix no longer reaches its target")
				if index == 9:
					check(refill_steps.size() == 2 and refill_steps[1] - refill_steps[0] >= 3, "Level ten stock must enter on separate operations")
				if index == 15 or index == 16 or index == 26 or index == 36:
					check(refill_steps.size() == 2 and refill_steps[1] - refill_steps[0] >= 5, "Wave stock must enter on separate operations")
				# 暂存练习必须实际取放；预放一颗的盒子先移出才能再次接收。
				if (index >= 23 and index <= 29) or index in [30, 33, 35, 36, 37, 38]:
					check(first_single_in > 0 and first_single_out > 0, "Single-box wave must exercise storage and removal")
					if index == 23 or index == 24:
						check(first_single_in <= first_group_step and first_single_out <= first_group_step + 6, "Single introduction must demonstrate an early storage cycle")
					if index in [25, 28, 35, 38]:
						check(first_single_out < first_single_in, "Preloaded single must empty before accepting another donut")
					if index == 25:
						check(not refill_steps.is_empty() and first_single_in <= refill_steps[0], "Level 26 must reuse its single before the stock arrives")
			check(not session.slots.any(func(slot: Dictionary) -> bool: return slot.box != null and slot.box.kind == "bomb"), "Win leaves bomb %d/%d" % [index + 1, mode])
			check(session.total_orders() == int(plan.orders), "Plan orders")
			check(refills.size() == definition.stock.size(), "Level %d mode %d refill count differs from real stock" % [index + 1, mode])
			for refill_index: int in refills.size():
				var event: Dictionary = refills[refill_index]
				check(int(event.state.stock_cursor) == refill_index + 1 and event.state.slots[event.index].box != null,
					"Refill skipped queue order or failed to enter a collected position")
			for key: String in session.tools:
				check(int(session.tools[key]) == int(definition.tools[key]), "Solution used tools")
		print("PASS: level %d; four turnover conditions; %d baseline moves" % [index + 1, solution.moves])
	check(stock_levels == 30, "Expected 30 stock levels")
	check(short_bomb_levels > 0 and long_bomb_levels > 0 and short_bomb_levels + long_bomb_levels == 10, "R2 requires ten bomb levels with operation-time budgets")
	# 用户参考关提前引入数字冰冻，其余机关仍沿用 R2。
	check(mechanism_firsts == {"hidden": 6, "lid": 12, "frozen": 18, "single": 24, "number_frozen": 2,
		"fixed": 41, "in_only": 51, "cycle": 61, "bomb": 81}, "R2 and confirmed reference-level introductions differ")
	_check_mechanics()
	_check_v13_data_boundaries()
	_check_restore_and_rewards()
	await _check_new_ui()
	await _check_v13_presentation()
	if not failures.is_empty():
		for message: String in failures:
			push_error(message)
		quit(1)
	else:
		print("PASS: hundred; 400 complete replays, planning counts and mechanism boundaries")
		quit(0)


## 锁定续接方案中的混合装量、预装暂存与隐藏边界，防止回退为统一双空盒。
func _check_wave_thirty_one(definition: Dictionary, offset: int) -> void:
	var amounts: Array = [[11,2,3,0,0], [13,1,0,1,1], [13,2,1,0,1], [13,1,0,1,1], [14,0,0,0,2],
		[11,3,1,0,1], [12,2,3,0,0], [12,2,1,0,1], [10,3,3,0,0], [12,4,0,0,1]]
	var single_fills: Array[int] = [0, -1, -1, 0, -1, 1, 0, 0, 1, -1]
	var hidden_totals: Array[int] = [0, 0, 3, 0, 3, 6, 0, 0, 6, 0]
	var numbered: Array = [[2,1], [1], [1,1], [1], [1,2], [], [1,1], [], [2], [1,1]]
	var actual_amounts: Array[int] = [0, 0, 0, 0, 0]
	var actual_single: Array[int] = []
	var actual_numbered: Array[int] = []
	var hidden: int = 0
	for slot: Dictionary in definition.slots:
		if slot.box == null:
			continue
		var item_count: int = slot.box.items.size()
		if slot.kind == "single":
			actual_single.append(item_count)
		elif slot.box.kind == "normal":
			actual_amounts[4 - item_count] += 1
		else:
			check(item_count == 4, "Wave mechanisms must start full")
		if int(slot.box.lid) > 0:
			actual_numbered.append(int(slot.box.lid))
		var hidden_indices: Array[int] = []
		for item_index: int in item_count:
			if slot.box.items[item_index].get("hidden", false):
				hidden_indices.append(item_index)
		if not hidden_indices.is_empty():
			check(slot.box.kind == "normal" and slot.kind == "regular" and hidden_indices == [1,2,3], "Hidden layers must belong to a normal full box")
			hidden += hidden_indices.size()
	check(actual_amounts == amounts[offset], "Wave ordinary fill distribution %d" % (offset + 31))
	check(actual_single == ([] if single_fills[offset] < 0 else [single_fills[offset]]), "Wave single preload")
	check(actual_numbered == numbered[offset] and hidden == hidden_totals[offset], "Wave numeric order or hidden amount")


## 用正式搬运判定枚举全部一步归纳，避免把某条刻意绕远的操作当成必须腾位。
func _has_one_step_group(session: DonutSession) -> bool:
	for source: int in session.slots.size():
		for target: int in session.slots.size():
			if _is_new_group(session, source, target):
				return true
	return false


## 首次归纳要求同一目标首次装满四颗同味，已归纳盒拆装和连锁回收不重复计数。
func _is_new_group(session: DonutSession, source: int, target: int) -> bool:
	var amount: int = session.move_count(source, target)
	if amount <= 0 or session.capacity(target) != 4:
		return false
	var box: Dictionary = session.slots[target].box
	if box.grouped or box.items.size() + amount != 4:
		return false
	var flavor: int = int(session.slots[source].box.items[0].flavor)
	return box.items.all(func(item: Dictionary) -> bool: return int(item.flavor) == flavor)


## 单独验证初始装量约束，运行中或备货盒不会误套初始三四颗限制。
func _check_v13_data_boundaries() -> void:
	for kind: String in ["lid", "frozen", "number_frozen", "cycle", "bomb", "fixed", "in_only"]:
		for count: int in 5:
			var items: Array = []
			items.resize(count)
			items.fill(0)
			var supply: Array[int] = []
			supply.resize(15)
			var errors: PackedStringArray = []
			DonutLevel._check_box(box(items, kind, 1 if kind in ["lid", "number_frozen"] else 0), 4, supply, errors, true)
			var valid: bool = count == 0 if kind == "fixed" else (count <= 1 if kind == "in_only" else count in [3, 4])
			check(errors.is_empty() == valid, "V1.3 opening amount %s/%d" % [kind, count])
	var definition: Dictionary = fixture([box([0,0,1])])
	definition.slots[0].box.items[1].hidden = true
	definition.stock = [box([1,2,3,0]), box([2,1,3,0]), box([0,1,2,3])]
	definition.stock[0].items[1].hidden = true
	var s := DonutSession.new(definition)
	s.begin()
	check(s.pick_count(0) == 1 and not s.slots[0].box.items[1].revealed and s.slots[0].box.items[2].revealed, "Per-item hidden boundary lost")
	check(not s.snapshot().has("stock_preview") and s.remaining_stock() == 3, "Hidden stock must stay queued without a preview")
	s = DonutSession.new(fixture([box([0], "in_only"), box([0,0,0])]))
	s.begin()
	check(not s.can_pick_top(0) and not s.move(0,1) and s.move(1,0), "Preloaded one-way food must remain extract-disabled")


## 检查备货隐藏、三个真实道具、数字顺序提示和可关闭的停滞提示，不暂停炸弹。
func _check_v13_presentation() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320,568)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	page._cancel_interaction()
	for name: String in ["Undo", "AddBox", "Top"]:
		check(page.tools_view.get_node(name+"/Badge").visible and page.tools_view.get_node(name+"/Count").text == "1", "Available tool must display one charge")
	var before: Dictionary = page.session.snapshot()
	var turnover: int = page.session.next_turnover()
	page.tools_view.get_node("AddBox").pressed.emit()
	page._cancel_interaction()
	check(page.session.slots[turnover].open and page.session.tools.add_box == 0, "Add-box button did not execute its tool")
	page.tools_view.get_node("Undo").pressed.emit()
	page._cancel_interaction()
	check(page.session.slots == before.slots and page.session.tools.undo == 0 and page.session.tools.add_box == 1, "Undo button did not restore the add-box transaction")
	page.tools_view.get_node("Top").pressed.emit()
	var top_source: int = -1
	var top_item: int = -1
	for source: int in page.session.slots.size():
		for item: int in range(1, 4):
			if page.session.can_bring_to_top(source, item):
				top_source = source
				top_item = item
				break
		if top_source >= 0:
			break
	page._on_box_pressed(top_source)
	page._choose_top(top_source, top_item)
	page._cancel_interaction()
	check(page.session.tools.top == 0 and page.session.slots[top_source].box.items[0].flavor == before.slots[top_source].box.items[top_item].flavor, "Top button did not reorder the selected donut")
	check(page.get_node_or_null("Stage/Stock") == null, "Removed stock area remains in the scene")
	page.session.load_level(9)
	page._cancel_interaction()
	check(page.session.remaining_stock() > 0 and not page.session.snapshot().has("stock_preview"), "Removing stock UI must retain the real refill queue")
	var definition: Dictionary = fixture([box([0,1,2],"lid",1),box([2,1,0],"number_frozen",2),box([0,1,2],"bomb"),box([]),box([]),box([])])
	definition.slots.append({"kind":"turnover","unlock_after":-1,"box":null})
	definition.slots.append({"kind":"turnover","unlock_after":-1,"box":null})
	definition.layout_id = "level_01"
	page.initialize(DonutSession.new(definition))
	page._cancel_interaction()
	check(page.board.boxes[0].get_node("NumberTarget").visible and not page.board.boxes[1].get_node("NumberTarget").visible, "Next numeric target must be first in fixed order")
	page.idle_hint_seconds = 0.1
	page._process(0.2)
	check(page.get_node("Stage/IdleHint").visible and page.session.active_seconds > 0, "Idle hint missing or pauses bomb")
	page.get_node("Stage/IdleHint/Row/Dismiss").pressed.emit()
	page._process(0.2)
	check(not page.get_node("Stage/IdleHint").visible, "Dismissed hint repeats without a valid move")
	page.hide()
	page.show()
	check(not page.get_node("Stage/IdleHint").visible, "Interrupted hint survives hidden page")
	definition = fixture([box([0,0,0],"bomb"),box([0]),box([]),box([]),box([]),box([])])
	definition.slots.append({"kind":"turnover","unlock_after":-1,"box":null})
	definition.slots.append({"kind":"turnover","unlock_after":-1,"box":null})
	definition.layout_id = "level_01"
	page.initialize(DonutSession.new(definition))
	page._cancel_interaction()
	check(page.board.boxes[0].get_node("Mechanic").visible and page.board.boxes[0].get_node("Countdown").visible, "Armed bomb must show icon and countdown")
	check(page.session.move(1,0) and page.session.completed == 0, "UI fixture did not leave a grouped waiting box")
	page._cancel_interaction()
	check(not page.board.boxes[0].get_node("Mechanic").visible and not page.board.boxes[0].get_node("Countdown").visible,
		"Grouped waiting bomb kept its icon or countdown")
	var legacy: Array = page.session.slots.duplicate(true)
	legacy[0].box.kind = "bomb"
	legacy[0].box.bomb_deadline = 3.0
	page.session._normalize_grouped_bombs(legacy)
	check(legacy[0].box.kind == "normal" and legacy[0].box.bomb_deadline < 0, "Previously grouped saved bomb did not adopt the new rule")
	viewport.queue_free()
	await process_frame


## 构造独立规则夹具，不作为正式关卡的内容来源。
func fixture(boxes: Array) -> Dictionary:
	var definition: Dictionary = DonutLevel.load_definition(DonutLevel.catalog()[0].path)
	definition.slots = []
	for box: Dictionary in boxes:
		definition.slots.append({"kind": "regular", "unlock_after": 0, "box": box})
	definition.demands = [{"sequence": [14, 0, 1, 2], "initially_open": true}, {"sequence": [], "initially_open": true}, {"sequence": [], "initially_open": false}, {"sequence": [], "initially_open": false}]
	definition.stock = []
	definition.tools = {"undo": 1, "add_box": 1, "top": 1} # 独立边界夹具显式启用。
	return definition


## 统一生成需要的初始内容和限制字段。
func box(items: Array, kind: String = "normal", number: int = 0) -> Dictionary:
	return {"kind": kind, "lid": number, "items": items.map(func(f: int) -> Dictionary: return {"flavor": f}), "fixed_flavor": 1 if kind == "fixed" else -1, "bomb_seconds": 3.0 if kind == "bomb" else 0}


## 覆盖首次归纳、单目标、冻结独立触发、固定口味、只进、置顶与炸弹。
func _check_mechanics() -> void:
	var s := DonutSession.new(fixture([box([0,0,0]),box([0]),box([1,2,1,2],"lid",2),box([2,1,2,1],"number_frozen",1),box([])]))
	s.begin()
	check(s.move(1,0) and s.slots[2].box.lid == 1 and s.slots[3].box.lid == 1, "Grouping must decrement only first target without demand")
	check(s.move(0,4) and s.slots[2].box.lid == 0, "Different entity may group same flavor")
	check(s.move(4,0) and s.slots[3].box.lid == 1, "Repeated entity must not claim grouping again")
	check(s.undo() and s.slots[3].box.lid == 1, "Undo grouping")
	s = DonutSession.new(fixture([box([0,0,0,0]),box([1,1,1,1],"lid",1),box([2],"frozen")]))
	s.begin()
	check(s.slots[1].box.lid == 1 and s.slots[2].box.frozen, "Opening full box must not trigger grouping or thaw without dispatch")
	s = DonutSession.new(fixture([box([0]),box([1]),box([],"fixed"),box([],"in_only")]))
	s.begin()
	check(not s.move(0,2) and s.move(1,2), "Fixed flavor rejects wrong flavor while empty")
	check(s.move(0,3) and not s.can_pick_top(3) and not s.can_bring_to_top(3,1), "In-only allows entry and forbids extraction")
	s = DonutSession.new(fixture([box([0,0,1,2],"cycle"),box([])]))
	s.begin()
	check(s.move(0,1) and s.slots[0].box.items[0].flavor == 2 and s.slots[0].box.items.size() == 2, "Cycle once after group removal")
	s = DonutSession.new(fixture([box([0],"bomb"),box([])]))
	s.begin()
	check(s.move(0,1), "Empty bomb fixture")
	s.advance_clock(3.0)
	check(s.failed and not s.move(1,0), "Empty bomb still explodes and blocks actions")
	s.restart()
	check(not s.failed and is_zero_approx(s.active_seconds), "Restart resets bomb")
	s.advance_clock(2.0)
	check(s.move(0,1) and s.undo() and is_equal_approx(s.active_seconds,2.0), "Undo must not refund time")
	var definition: Dictionary = fixture([box([0,0,0],"bomb"),box([0])])
	definition.demands[0].sequence = [0]
	s = DonutSession.new(definition)
	s.begin()
	s.advance_clock(2.99)
	check(s.move(1,0), "Accept last moment move")
	s.advance_clock(10)
	check(s.is_won() and not s.failed, "Accepted dispatch wins before animation timeout")
	definition = fixture([box([0],"bomb"),box([0,0,0])])
	definition.demands[0].sequence = [0]
	s = DonutSession.new(definition)
	s.begin()
	check(s.move(0,1) and s.remaining_donuts() == 0 and not s.is_won(), "Empty bomb cannot be bypassed by completing other orders")
	s.advance_clock(3.0)
	check(s.failed, "Uncollected empty bomb must still time out after all orders")
	s = DonutSession.new(fixture([box([0,0,0],"bomb"),box([0]),box([])]))
	s.begin()
	s.advance_clock(1.0)
	check(s.move(1,0) and s.completed == 0 and s.is_waiting(0), "Bomb fixture must group without dispatch")
	check(s.slots[0].box.kind == "normal" and s.slots[0].box.bomb_deadline < 0, "Waiting grouped bomb must disarm")
	s.advance_clock(10.0)
	check(not s.failed and s.move(0,2) and s.slots[0].box.kind == "normal", "Disarmed box rearmed after waiting or moving food")
	s.restart()
	s.advance_clock(1.0)
	check(s.move(1,0) and s.undo() and s.slots[0].box.kind == "bomb", "Undo must restore the pre-group bomb")
	s.advance_clock(2.0)
	check(s.failed, "Undo must not refund the original bomb deadline")


## 恢复同局包含解锁与时间，旧内容、损坏数据及过期奖励不能改变新局。
func _check_restore_and_rewards() -> void:
	var s := DonutSession.new()
	s.load_level(80)
	var token: String = s.request_turnover(s.slots.size() - 1)
	var attempt: int = s.attempt
	s.restart()
	check(s.attempt == attempt and not s.load_level(0), "Pending reward must block restart and switching")
	check(not s.resolve_turnover(token, false) and not s.slots.back().open, "Canceled reward unlocks slot")
	token = s.request_turnover(s.slots.size() - 1)
	check(s.resolve_turnover(token, true) and not s.resolve_turnover(token, true), "Reward must be idempotent")
	s.advance_clock(1.25)
	var path: String = get_script().resource_path.get_base_dir().path_join("../../fixtures/donut_sort/level_81_solution.json")
	var step: Array = JSON.parse_string(FileAccess.get_file_as_string(path)).steps[0]
	check(s.move(int(step[0]), int(step[1])), "Save fixture move")
	var data: Dictionary = JSON.parse_string(JSON.stringify(s.export_run()))
	var restored := DonutSession.new()
	check(restored.restore_run(data), "Valid saved game rejected")
	check(restored.level_index == 80 and restored.slots.back().open and is_equal_approx(restored.active_seconds,1.25), "Resume lost level, reward or clock")
	check(restored.can_undo() and restored.undo() and restored.tools.undo == 0 and is_equal_approx(restored.active_seconds,1.25), "Saved game lost undo or refunded bomb time")
	var malformed: Dictionary = data.duplicate(true)
	malformed.state.slots[0].box.items[0].flavor = 99
	check(not restored.restore_run(malformed), "Invalid saved flavor accepted")
	malformed = data.duplicate(true)
	malformed.content_hash = "old"
	check(not restored.restore_run(malformed), "Stale content accepted")
	s.restart()
	check(not s.resolve_turnover(token,true) and not s.slots.back().open, "Old attempt reward unlocked restarted game")
	var store := DonutProgress.new()
	root.add_child(store)
	var save_path: String = "res://hundred_test_progress.json"
	store.initialize(s,true,save_path)
	store.seen.lid = true
	store.save()
	store.save()
	check(FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path + ".tmp"), "Atomic save failed")
	var reader := DonutProgress.new()
	root.add_child(reader)
	var loaded := DonutSession.new()
	reader.initialize(loaded,true,save_path)
	check(reader.seen.has("lid") and loaded.level_index == 80, "Disk save did not restore new project data")
	store._enabled = false
	reader._enabled = false
	store.queue_free()
	reader.queue_free()
	DirAccess.remove_absolute(save_path)


## 验证教学与设置暂停、取消奖励、分页末关及重新激活后的倒计时。
func _check_new_ui() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 640)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	page.lessons_enabled = true
	viewport.add_child(page)
	await process_frame
	await process_frame
	page._cancel_interaction()
	page._maybe_show_lesson()
	check(page.lesson_dialog.visible and not page._board_input_enabled(), "First lesson must block board")
	page.lesson_dialog._answer(true)
	await process_frame
	check(page._lesson_record().has("basic") and not page.lesson_dialog.visible, "Lesson close did not record completion")
	page.session.load_level(80)
	page._cancel_interaction()
	page._maybe_show_lesson()
	var before: float = page.session.active_seconds
	page._process(2.0)
	check(page.lesson_dialog.visible and is_equal_approx(before,page.session.active_seconds), "Bomb ran during lesson")
	page.lesson_dialog._answer(true)
	await process_frame
	page._process(0.5)
	check(page.session.active_seconds > before, "Bomb did not resume after lesson")
	page._show_settings_menu()
	before = page.session.active_seconds
	page._process(2.0)
	check(is_equal_approx(before,page.session.active_seconds), "Bomb ran in settings")
	page.settings_panel.page_index = 9
	page.settings_panel._show_page()
	await process_frame
	check(page.settings_panel.get_node("Card/Choices").get_child_count()==10 and page.settings_panel.get_node("Card/Choices").get_child(9).text.contains("100"), "Last page missing level 100")
	for name: String in ["Previous","Next","Lessons"]:
		check(page.settings_panel.get_node("Card").get_global_rect().encloses(page.settings_panel.get_node("Card/"+name).get_global_rect()), "Paging button clipped")
	page.settings_panel.close()
	page._offer_turnover(page.session.slots.size()-2)
	page._process(2.0)
	check(is_equal_approx(before,page.session.active_seconds) and not page._board_input_enabled(), "Pending reward did not pause")
	page.lesson_dialog._answer(false)
	await process_frame
	check(not page.session.slots[page.session.slots.size()-2].open and page.session.pending_reward.is_empty(), "Cancel changed turnover")
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	before = page.session.active_seconds
	page._process(2.0)
	check(is_equal_approx(before,page.session.active_seconds), "Bomb ran in background")
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await process_frame
	page._process(0.5)
	check(page.session.active_seconds > before, "Bomb failed to resume on focus")
	viewport.queue_free()
	await process_frame
