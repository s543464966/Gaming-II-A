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
	var bomb_levels: int = 0
	var mechanism_firsts: Dictionary = {}
	for index: int in levels.size():
		var definition: Dictionary = DonutLevel.load_definition(levels[index].path)
		if definition.is_empty():
			check(false, "Invalid definition %d" % (index + 1))
			continue
		var plan: Dictionary = plans[index]
		if index >= 30 and index <= 39:
			_check_wave_thirty_one(definition, index - 30)
		if index >= 40 and index <= 49:
			_check_wave_forty_one(definition, index + 1)
		if index >= 60 and index <= 69:
			_check_wave_sixty_one(definition, index + 1)
		if index >= 70 and index <= 79:
			_check_wave_seventy_one(definition, index + 1)
		if index >= 80 and index <= 89:
			_check_wave_eighty_one(definition, index + 1)
		if index >= 90:
			_check_wave_ninety_one(definition, index + 1)
		if index >= 50 and index <= 59:
			# 不恢复单向图标，以固定位置降低跨关辨认负担。
			for box_index: int in definition.slots.size():
				var box: Variant = definition.slots[box_index].box
				if box != null and box.kind == "in_only":
					check(box_index == definition.slots.size() - 3, "Single-direction holder must precede the two ad slots")
		for key: String in ["undo", "add_box", "top"]:
			check(int(definition.tools.get(key, -1)) == 0, "Every level must start with zero tool charges")
		var has_bomb: bool = definition.slots.any(func(slot: Dictionary) -> bool: return slot.box != null and slot.box.kind == "bomb")
		if has_bomb:
			var timer: float = float(definition.design.bomb_timing.seconds)
			bomb_levels += 1
			check(is_finite(timer) and timer >= 100.0, "Authored bomb time must be finite and leave observation time")
			check(is_equal_approx(float(definition.design.bomb_timing.estimated_seconds_per_move), 3.0), "Bomb replay budget must remain three seconds per move")
			for slot: Dictionary in definition.slots:
				if slot.box != null and slot.box.kind == "bomb":
					check(is_finite(float(slot.box.bomb_seconds)) and is_equal_approx(float(slot.box.bomb_seconds), timer), "Bomb timer differs from its authored budget")
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
		var max_bomb_disarm_step: int = 0
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
			var first_fixed_in: int = -1
			var first_in_only_in: int = -1
			var fixed_groups: int = 0
			var in_only_groups: int = 0
			var visible_cycle_steps: Array[int] = []
			var visible_cycle_slots: Dictionary = {}
			var last_recovery_step: int = 0
			var bomb_disarm_step: int = -1
			var largest_recovery_batch: int = 0
			var last_recovery_batch: int = 0
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
				if grouping and session.slots[target].box.kind == "bomb":
					if mode == 0 and index in [87, 88]:
						var disarm_flavor: int = int(session.slots[source].box.items[0].flavor)
						for initial_slot: Dictionary in definition.slots:
							if initial_slot.box != null:
								for item: Dictionary in initial_slot.box.items:
									check(not item.get("hidden", false) or int(item.flavor) != disarm_flavor, "Bomb materials must be visible before the hidden-layer challenge")
					if mode == 0 and index in [91, 92, 98]:
						var disarm_flavor: int = int(session.slots[source].box.items[0].flavor)
						for initial_slot: Dictionary in definition.slots:
							if initial_slot.box == null:
								continue
							if index == 91 and initial_slot.box.kind == "fixed":
								check(int(initial_slot.box.fixed_flavor) != disarm_flavor, "Level 92 fixed holder must not compete for bomb materials")
							if index in [92, 98]:
								for item: Dictionary in initial_slot.box.items:
									if int(item.flavor) == disarm_flavor:
										check(not item.get("hidden", false) and initial_slot.box.kind not in ["lid", "number_frozen", "in_only"], "Final-wave bomb materials must remain visible and outside locked or one-way holders")
				if session.slots[source].box.kind == "cycle":
					var remainder: Array = session.slots[source].box.items.slice(session.move_count(source, target))
					if remainder.size() > 1 and remainder[0].flavor != remainder[-1].flavor:
						visible_cycle_steps.append(step_index + 1)
						visible_cycle_slots[source] = true
				if session.slots[target].box.kind == "in_only":
					if first_in_only_in < 0:
						first_in_only_in = step_index + 1
					in_only_groups += 1 if grouping else 0
				var completed_before: int = session.completed
				if session.slots[target].box.kind == "fixed":
					if first_fixed_in < 0:
						first_fixed_in = step_index + 1
					fixed_groups += 1 if grouping else 0
				var refills_before: int = refills.size()
				if mode == 0:
					interval_split_group = interval_split_group or session.slots[source].box.grouped
				# 三秒仅为自动回放的操作预算；真人拆弹耗时仍须试玩标定。
				session.advance_clock(3.0 if has_bomb else 1.0)
				if not session.move(int(step[0]), int(step[1])):
					check(false, "Level %d mode %d invalid move %s step %d" % [index + 1, mode, step, step_index])
					break
				if has_bomb and bomb_disarm_step < 0 and not session.slots.any(func(slot: Dictionary) -> bool: return slot.box != null and slot.box.kind == "bomb"):
					bomb_disarm_step = step_index + 1
				last_recovery_batch = session.completed - completed_before
				largest_recovery_batch = maxi(largest_recovery_batch, last_recovery_batch)
				if mode == 0 and index >= 50 and session.completed > completed_before:
					check(step_index + 1 - last_recovery_step <= 12, "Wave 51-100 route waits too long for order feedback")
					last_recovery_step = step_index + 1
				if session.slots[target].kind == "single" and first_single_in < 0:
					first_single_in = step_index + 1
				if session.slots[source].kind == "single" and first_single_out < 0:
					first_single_out = step_index + 1
				if mode == 0 and grouping:
					if first_group_step < 0:
						first_group_step = step_index + 1
						if index >= 50:
							check(session.completed > 0, "Wave 51-100 first group must deliver and reward planning")
						if index == 71:
							check(in_only_groups == 1, "Level 72 first group must use the preloaded single-direction holder")
						if index == 17 or index == 18 or index == 20:
							check(session.completed > 0, "Ordinary ice practice must deliver its first group")
					var fraction: float = float(interval_progress) / session.total_orders()
					if fraction >= 0.3 and fraction <= 0.7 and step_index > interval_start and not interval_has_group and not interval_split_group:
						midgame_count += 1
					interval_start = -1
				if mode == 0 and refills.size() > refills_before:
					refill_steps.append(step_index + 1)
					# 补货教学的基线路线留有可操作余量，余量仍受顶层同味限制。
					if index == 8 or (index >= 13 and index <= 16) or (index >= 25 and index <= 27) or index in [33, 36, 37, 43, 45, 47, 53, 55, 58, 63, 65, 68, 73, 75, 78, 83, 85, 88, 93, 95, 98]:
						var usable_space: int = 0
						for slot_index: int in session.slots.size():
							if session.can_handle(slot_index):
								if index >= 40 and session.slots[slot_index].box.kind in ["fixed", "in_only"]:
									continue
								usable_space += session.capacity(slot_index) - session.slots[slot_index].box.items.size()
						check(usable_space >= 4, "Level %d refill leaves no planned working space" % (index + 1))
				check(session.remaining_donuts() + session.completed * 4 == session.total_donuts(), "Conservation %d/%d" % [index + 1, step_index])
				for slot_index: int in session.slots.size():
					check(session.slots[slot_index].box == null or session.slots[slot_index].box.items.size() <= session.capacity(slot_index), "Capacity exceeded")
			check(session.is_won() and not session.failed, "Level %d mode %d incomplete" % [index + 1, mode])
			if mode == 0:
				check(midgame_count >= int(plan.midgame_space_min) and midgame_count == int(solution.midgame_metrics.count),
					"R2 midgame %d actual %d target %d recorded %d" % [index + 1, midgame_count, plan.midgame_space_min, solution.midgame_metrics.count])
				if index >= 4:
					check(first_group_step == int(solution.opening_metrics.first_group_moves), "Early wave opening prefix no longer reaches its target")
				if index == 9:
					check(refill_steps.size() == 2 and refill_steps[1] - refill_steps[0] >= 3, "Level ten stock must enter on separate operations")
				if index in [15, 16, 26, 36, 45, 55, 58, 65, 68, 75, 78, 85, 88, 95, 98]:
					check(refill_steps.size() == 2 and refill_steps[1] - refill_steps[0] >= 5, "Wave stock must enter on separate operations")
				# 暂存练习必须实际取放；预放一颗的盒子先移出才能再次接收。
				if (index >= 23 and index <= 29) or index in [30, 33, 35, 36, 37, 38, 43, 46, 47, 56, 57, 58]:
					check(first_single_in > 0 and first_single_out > 0, "Single-box wave must exercise storage and removal")
					if index == 23 or index == 24:
						check(first_single_in <= first_group_step and first_single_out <= first_group_step + 6, "Single introduction must demonstrate an early storage cycle")
					if index in [25, 28, 35, 38, 43, 58]:
						check(first_single_out < first_single_in, "Preloaded single must empty before accepting another donut")
					if index == 25:
						check(not refill_steps.is_empty() and first_single_in <= refill_steps[0], "Level 26 must reuse its single before the stock arrives")
				if index >= 40 and index <= 49 and int(plan.restricted_space) > 0:
					check(first_fixed_in > 0 and fixed_groups > 0, "Fixed-flavor wave must use and complete its restricted box")
					if index <= 41:
						check(first_fixed_in <= first_group_step + 3, "Fixed-flavor introduction must participate early")
				if index >= 50 and index <= 59:
					check(in_only_groups == (0 if index in [53, 56] else 1), "Single-direction boxes must actually complete a group")
					check(midgame_count <= int(plan.midgame_space_min) + 1, "Wave 51-60 exceeds its planned middle-section load")
				if index >= 60 and index <= 69:
					check(visible_cycle_steps.size() >= 2, "Cycle wave must visibly rotate to a different flavor at least twice")
					check(not visible_cycle_steps.is_empty() and visible_cycle_steps[0] <= (first_group_step if index <= 61 else 12), "Cycle wave must use its mechanism early")
					check(midgame_count <= int(plan.midgame_space_min) + (0 if index in [63, 66, 69] else 1), "Cycle wave exceeds its planned middle-section load")
					if index in [66, 68]:
						check(first_single_in > 0 and first_single_out > 0, "Cycle and single-holder combination must exercise both directions")
					if index == 66:
						check(first_single_in <= 10 and steps.size() <= 50, "Level 67 relief must use storage early and keep its route short")
					if index == 68:
						check(first_single_out < first_single_in, "Level 69 must first empty its preloaded single holder")
					if index == 64:
						check(in_only_groups == 1, "Level 65 must finish the single-direction holder")
				if index >= 70 and index <= 79:
					var cycle_count: int = 0
					for slot: Dictionary in definition.slots:
						cycle_count += 1 if slot.box != null and slot.box.kind == "cycle" else 0
					if cycle_count > 0:
						check(visible_cycle_slots.size() == cycle_count and visible_cycle_steps.size() >= cycle_count + 1, "Every cycle holder must visibly change its exposed flavor")
						check(visible_cycle_steps[0] <= (first_group_step if index == 70 else 12), "Combination wave must use its cycle early")
					check(midgame_count <= int(plan.midgame_space_min) + (0 if index in [73,76,79] else 1), "Combination wave exceeds its planned middle-section load")
					if index in [73,76,79]:
						check(steps.size() <= 50, "Relief levels must keep a compact baseline route")
					if index in [72,73,77,79]:
						check(first_fixed_in > 0 and first_fixed_in <= 12 and fixed_groups == 1, "Fixed holder must take part early and finish its group")
					if index in [71,74]:
						check(in_only_groups == 1, "Combination wave must finish its single-direction holder")
					if index in [74,76,78]:
						check(first_single_in > 0 and first_single_out > 0, "Combination wave must store and remove from its single holder")
					if index in [74,78]:
						check(first_single_out <= 12 and first_single_out < first_single_in, "Preloaded single must empty early before reuse")
					if index == 76:
						check(first_single_in <= 10, "Level 77 must offer early single-holder relief")
				if index >= 80 and index <= 89:
					check(midgame_count <= int(plan.midgame_space_min) + (0 if index in [83,86,89] else 1), "Bomb wave exceeds its planned middle-section load")
					if index in [83,86,89]:
						check(steps.size() <= 50, "Bomb wave relief must keep its baseline route compact")
					if index in [82,85,89]:
						check(visible_cycle_steps.size() >= 2 and visible_cycle_steps[0] <= 12, "Bomb wave must visibly use the cycle holder")
					if index in [83,87,89]:
						check(first_fixed_in > 0 and first_fixed_in <= 12 and fixed_groups == 1, "Bomb wave must complete its fixed holder")
					if index == 84:
						check(in_only_groups == 1, "Level 85 must complete its single-direction holder")
					if index in [86,88]:
						check(first_single_in > 0 and first_single_out > 0, "Bomb wave must use both directions of single storage")
					if index == 86:
						check(first_single_in <= 6, "Level 87 must offer early storage relief")
					if has_bomb:
						check(bomb_disarm_step == int(solution.bomb_disarm_moves["0"]), "Bomb disarm event differs from saved route")
						check(bomb_disarm_step <= (first_group_step if index <= 81 else (20 if index == 88 else 16)), "Bomb wave leaves its timer pressure active too long")
				if index >= 90:
					check(first_group_step == 4, "Final wave must reward opening planning on move four")
					check(midgame_count <= int(plan.midgame_space_min) + (0 if index in [93, 96, 99] else 1), "Final wave exceeds its planned middle-section load")
					if index in [93, 96, 99]:
						check(steps.size() <= (48 if index == 99 else 50), "Final-wave relief must keep its baseline route compact")
					if index in [90, 92, 95, 97, 99]:
						check(visible_cycle_steps.size() >= 2 and visible_cycle_steps[0] <= 12, "Final wave must visibly use its cycle holder early")
					if index in [91, 96, 97, 99]:
						check(first_fixed_in > 0 and first_fixed_in <= 12 and fixed_groups == 1, "Final wave must use and complete its fixed holder")
					if index in [90, 94, 98]:
						check(first_in_only_in > 0 and first_in_only_in <= 8 and in_only_groups == 1, "Final wave must use its one-way holder early and complete it")
					if index in [93, 96]:
						check(first_single_in > 0 and first_single_in <= 6 and first_single_out > first_single_in, "Final-wave relief must offer early reusable single storage")
					if index == 95:
						check(refill_steps.size() == 2 and refill_steps[1] > bomb_disarm_step, "Level 96 second refill must follow bomb disarming")
					if index == 99:
						check(last_recovery_batch >= 2 or largest_recovery_batch >= 3, "Level 100 must finish with a double delivery or include a triple delivery")
					if has_bomb:
						check(bomb_disarm_step <= (12 if index == 91 else (20 if index == 98 else 16)), "Final wave leaves bomb pressure active too long")
			if has_bomb:
				check(bomb_disarm_step > 0 and bomb_disarm_step == int(solution.bomb_disarm_moves.get(str(mode), -1)), "Level %d mode %d actual bomb disarm differs from its saved route" % [index + 1, mode])
				check(bomb_disarm_step * 3.0 + 8.0 <= float(definition.design.bomb_timing.seconds), "Bomb operation budget leaves no observation margin")
				max_bomb_disarm_step = maxi(max_bomb_disarm_step, bomb_disarm_step)
			check(not session.slots.any(func(slot: Dictionary) -> bool: return slot.box != null and slot.box.kind == "bomb"), "Win leaves bomb %d/%d" % [index + 1, mode])
			check(session.total_orders() == int(plan.orders), "Plan orders")
			check(refills.size() == definition.stock.size(), "Level %d mode %d refill count differs from real stock" % [index + 1, mode])
			for refill_index: int in refills.size():
				var event: Dictionary = refills[refill_index]
				check(int(event.state.stock_cursor) == refill_index + 1 and event.state.slots[event.index].box != null,
					"Refill skipped queue order or failed to enter a collected position")
			for key: String in session.tools:
				check(int(session.tools[key]) == int(definition.tools[key]), "Solution used tools")
		if has_bomb:
			check(max_bomb_disarm_step == int(definition.design.bomb_timing.max_disarm_moves), "Bomb timing record must match the worst of all four actual routes")
		print("PASS: level %d; four turnover conditions; %d baseline moves" % [index + 1, solution.moves])
	check(stock_levels == 30, "Expected 30 stock levels")
	check(bomb_levels == 10, "Expected ten bomb levels with authored operation-time budgets")
	# 用户参考关提前引入数字冰冻，其余机关仍沿用 R2。
	check(mechanism_firsts == {"hidden": 6, "lid": 12, "frozen": 18, "single": 24, "number_frozen": 2,
		"fixed": 41, "in_only": 51, "cycle": 61, "bomb": 81}, "R2 and confirmed reference-level introductions differ")
	_check_mechanics()
	_check_v13_data_boundaries()
	_check_restore_and_rewards()
	_check_tool_rewards()
	await _check_tool_reward_lifecycle()
	await _check_new_ui()
	await _check_v13_presentation()
	# 页面已释放，留出停止淡出与音频线程回收的时间，再退出隔离测试。
	await create_timer(0.5).timeout
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


## 检查固定口味教学、零空盒变化与隐藏归属，防止受限空盒被当成自由空间。
func _check_wave_forty_one(definition: Dictionary, level: int) -> void:
	var normal_empty: int = 0
	var fixed_count: int = 0
	var hidden: int = 0
	var kinds: Dictionary = {}
	for slot: Dictionary in definition.slots:
		if slot.box == null:
			continue
		var kind: String = str(slot.box.kind)
		kinds["single" if slot.kind == "single" else kind] = true
		if kind == "fixed":
			fixed_count += 1
			check(slot.box.items.is_empty(), "Fixed-flavor wave must open with an empty restricted box")
		elif kind == "normal" and slot.kind == "regular" and slot.box.items.is_empty():
			normal_empty += 1
		var hidden_indices: Array[int] = []
		for item_index: int in slot.box.items.size():
			if slot.box.items[item_index].get("hidden", false):
				hidden_indices.append(item_index)
		if not hidden_indices.is_empty():
			check(kind == "normal" and slot.kind == "regular" and hidden_indices == [1,2,3], "Fixed wave hidden layers must stay below an ordinary full box")
			hidden += hidden_indices.size()
	check(normal_empty == (0 if level in [42,45,48,49] else 1), "Fixed wave ordinary empty-box count")
	check(fixed_count == (0 if level in [44,47] else 1), "Fixed wave restricted-box count")
	check(hidden == (3 if level == 45 else (6 if level == 49 else 0)), "Fixed wave hidden count")
	if level <= 42:
		check(kinds.size() == 2 and kinds.has("normal") and kinds.has("fixed") and definition.stock.is_empty(), "First fixed-flavor levels must practice only this mechanism")


## 检查循环教学的信息边界、缓和关空盒及单向盒位置，避免引入无提示的复合限制。
func _check_wave_sixty_one(definition: Dictionary, level: int) -> void:
	var kinds: Dictionary = {}
	var cycles: int = 0
	var ordinary_empty: int = 0
	var hidden: int = 0
	for index: int in definition.slots.size():
		var slot: Dictionary = definition.slots[index]
		if slot.box == null:
			continue
		var kind: String = str(slot.box.kind)
		kinds["single" if slot.kind == "single" else kind] = true
		cycles += 1 if kind == "cycle" else 0
		ordinary_empty += 1 if kind == "normal" and slot.kind == "regular" and slot.box.items.is_empty() else 0
		if kind == "cycle":
			check(slot.box.items.size() == 4, "Cycle wave starts with a full cycle holder")
		if kind == "in_only":
			check(index == definition.slots.size() - 3, "Cycle wave preserves single-direction placement before ad slots")
		var hidden_indices: Array[int] = []
		for item_index: int in slot.box.items.size():
			if slot.box.items[item_index].get("hidden", false):
				hidden_indices.append(item_index)
		if not hidden_indices.is_empty():
			check(kind == "normal" and slot.kind == "regular" and hidden_indices == [1,2,3], "Cycle wave hides only the bottom three layers of an ordinary holder")
			hidden += hidden_indices.size()
	check(cycles == 1 and not kinds.has("bomb"), "Cycle wave requires one cycle and no bomb")
	check(hidden == (3 if level in [68,69] else 0), "Cycle wave hidden count")
	check(ordinary_empty == (2 if level == 64 else (0 if level in [62,65,69] else 1)), "Cycle wave ordinary empty-holder budget")
	if level <= 62:
		check(kinds.size() == 2 and kinds.has("cycle") and kinds.has("normal") and definition.stock.is_empty(), "First two cycle levels must practice only the visible cycle mechanism")


## 检查综合关的可读空间、隐藏归属和特殊盒装量，保留缓和与挑战的配置差异。
func _check_wave_seventy_one(definition: Dictionary, level: int) -> void:
	var normal_empty: int = 0
	var cycles: int = 0
	var hidden: int = 0
	var singles: Array[int] = []
	check(definition.slots.size() <= 20, "Combination wave must fit in four compact rows")
	for index: int in definition.slots.size():
		var slot: Dictionary = definition.slots[index]
		if slot.box == null:
			continue
		var kind: String = str(slot.box.kind)
		var count: int = slot.box.items.size()
		check(kind != "bomb", "Bombs remain outside the 71-80 combination wave")
		cycles += 1 if kind == "cycle" else 0
		normal_empty += 1 if kind == "normal" and slot.kind == "regular" and count == 0 else 0
		if slot.kind == "single":
			singles.append(count)
		if kind == "fixed":
			check(count == 0, "Fixed-flavor holders start empty")
		if kind == "in_only":
			check(index == definition.slots.size() - 3 and count == (1 if level == 72 else 0), "Single-direction holder placement or preload differs")
		if kind in ["cycle", "lid", "frozen", "number_frozen"]:
			check(count == 4, "Combination wave mechanism holders must start full")
		var hidden_indices: Array[int] = []
		for item_index: int in count:
			if slot.box.items[item_index].get("hidden", false):
				hidden_indices.append(item_index)
		if not hidden_indices.is_empty():
			check(kind == "normal" and slot.kind == "regular" and hidden_indices == [1,2,3], "Combination wave hides only ordinary lower layers")
			hidden += hidden_indices.size()
	check(cycles == (2 if level in [71,76,79] else (1 if level in [74,78] else 0)), "Combination wave cycle-holder count")
	check(normal_empty == (0 if level in [72,75,78,79] else 1), "Combination wave ordinary empty-holder budget")
	check(hidden == (3 if level in [75,78,79] else 0), "Combination wave hidden count")
	check(singles == ([1] if level in [75,79] else ([0] if level == 77 else [])), "Combination wave single-holder preload")


## 检查炸弹入门的信息条件、三颗装量与缓和关，避免同时叠加未知信息和计时压力。
func _check_wave_eighty_one(definition: Dictionary, level: int) -> void:
	var bombs: int = 0
	var hidden: int = 0
	var normal_empty: int = 0
	var kinds: Dictionary = {}
	check(definition.slots.size() <= 20, "Bomb wave must fit in four compact rows")
	for index: int in definition.slots.size():
		var slot: Dictionary = definition.slots[index]
		if slot.box == null:
			continue
		var kind: String = str(slot.box.kind)
		kinds[kind] = true
		if kind == "bomb":
			bombs += 1
			check(slot.box.items.size() == (3 if level == 82 else 4), "Bomb wave initial fill differs")
			check(float(slot.box.bomb_seconds) > 0, "Bomb must have an explicit time budget")
		if kind == "normal" and slot.kind == "regular" and slot.box.items.is_empty():
			normal_empty += 1
		if kind == "fixed" or slot.kind == "single":
			check(slot.box.items.is_empty(), "Bomb wave restricted and single holders start empty")
		if kind == "in_only":
			check(level == 85 and slot.box.items.is_empty() and index == definition.slots.size() - 3, "Level 85 single-direction holder placement differs")
		var hidden_indices: Array[int] = []
		for item_index: int in slot.box.items.size():
			if slot.box.items[item_index].get("hidden", false):
				hidden_indices.append(item_index)
		if not hidden_indices.is_empty():
			check(kind == "normal" and slot.kind == "regular" and hidden_indices == [1,2,3], "Bomb wave hides only ordinary lower layers")
			hidden += hidden_indices.size()
	check(bombs == (1 if level in [81,82,83,86,88,89] else 0), "Bomb and relief level distribution differs")
	check(hidden == (3 if level in [85,88,89] else 0), "Bomb wave hidden count differs")
	check(normal_empty == (2 if level == 81 else (0 if level in [88,89] else 1)), "Bomb wave ordinary empty-holder budget differs")
	if level <= 82:
		check(kinds.size() == 2 and kinds.has("normal") and kinds.has("bomb") and definition.stock.is_empty(), "Bomb introduction must use only visible ordinary and bomb holders")


## 固定收官十关的机制分工、明牌拆弹和四排布局，并保留三次缓和及末关无计时收束。
func _check_wave_ninety_one(definition: Dictionary, level: int) -> void:
	var expected_kinds: Array = [
		{"cycle": 1, "in_only": 1}, {"bomb": 1, "fixed": 1},
		{"bomb": 1, "cycle": 1, "number_frozen": 1}, {"frozen": 1, "single": 1},
		{"lid": 1, "in_only": 1}, {"bomb": 1, "cycle": 1, "frozen": 1},
		{"fixed": 1, "single": 1}, {"cycle": 1, "fixed": 1},
		{"bomb": 1, "number_frozen": 1, "in_only": 1}, {"cycle": 1, "fixed": 1},
	]
	var actual_kinds: Dictionary = {}
	var normal_empty: int = 0
	var hidden: int = 0
	check(definition.slots.size() >= 18 and definition.slots.size() <= 20, "Final wave must keep 18-20 readable holder positions")
	for index: int in definition.slots.size():
		var slot: Dictionary = definition.slots[index]
		if slot.box == null:
			check(index >= definition.slots.size() - 2 and slot.kind == "turnover", "Final wave must not add decorative empty positions")
			continue
		var kind: String = "single" if slot.kind == "single" else str(slot.box.kind)
		var amount: int = slot.box.items.size()
		if kind != "normal":
			actual_kinds[kind] = int(actual_kinds.get(kind, 0)) + 1
		elif amount == 0:
			normal_empty += 1
		if kind in ["fixed", "single", "in_only"]:
			check(amount == 0, "Final-wave storage and restricted holders must begin empty")
		if kind in ["bomb", "cycle", "frozen", "number_frozen", "lid"]:
			check(amount == 4, "Final-wave mechanism holders must begin with four donuts")
		if kind in ["number_frozen", "lid"]:
			check(int(slot.box.lid) == 2, "Final-wave numeric gates must retain two distinct grouping prerequisites")
		if kind == "in_only":
			check(index == definition.slots.size() - 3, "Final-wave one-way holder must remain immediately before the two ad positions")
		var hidden_indices: Array[int] = []
		for item_index: int in amount:
			if slot.box.items[item_index].get("hidden", false):
				hidden_indices.append(item_index)
		if not hidden_indices.is_empty():
			check(kind == "normal" and amount == 4 and hidden_indices == [1,2,3], "Final wave may hide only the bottom three layers of an ordinary full holder")
			hidden += hidden_indices.size()
	check(actual_kinds == expected_kinds[level - 91], "Final-wave mechanism distribution differs at level %d" % level)
	check(hidden == (3 if level in [95,98,99] else 0), "Final-wave hidden-layer distribution differs")
	check(definition.stock.size() == (1 if level == 94 else (2 if level in [96,99] else 0)), "Final-wave refill distribution differs")
	for refill: Dictionary in definition.stock:
		check(refill.kind == "normal" and refill.items.size() == 4, "Final-wave refills must be ordinary full holders")
		check(not refill.items.any(func(item: Dictionary) -> bool: return item.get("hidden", false)), "Final-wave refill contents must not add hidden layers")
	if level in [94,97,100]:
		check(normal_empty >= 1 and hidden == 0 and not actual_kinds.has("bomb"), "Relief levels must preserve visible free space and have no timer")
	if level == 100:
		var flavors: Dictionary = {}
		var opening_donuts: int = 0
		for slot: Dictionary in definition.slots:
			if slot.box != null:
				opening_donuts += slot.box.items.size()
				for item: Dictionary in slot.box.items:
					flavors[int(item.flavor)] = true
		check(flavors.size() == 7 and opening_donuts == 56 and definition.stock.is_empty(), "Level 100 must close with seven visible flavors and fourteen orders")
	var layouts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DonutBoardView.LAYOUT_PATH))
	var positions: Array = layouts.templates[definition.layout_id].slots
	var rows: Dictionary = {}
	check(positions.size() == definition.slots.size(), "Final-wave layout and holder count differ")
	for position: Dictionary in positions:
		var layer: int = int(position.layer)
		if not rows.has(layer):
			rows[layer] = []
		rows[layer].append(float(position.x))
	check(rows.size() == 4, "Final wave must fit in four compact rows")
	for row: Array in rows.values():
		check(row.size() in [4,5], "Final-wave rows must contain four or five holders")
		if row.size() < 2:
			continue
		var spacing: float = float(row[1]) - float(row[0])
		check(spacing > 0, "Final-wave holder order must remain left to right")
		for column: int in range(2, row.size()):
			check(is_equal_approx(float(row[column]) - float(row[column - 1]), spacing), "Final-wave rows must not contain interior gaps")


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


## 检查三种道具的两次点击、一次上限及隐藏备货、数字顺序和停滞提示。
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
		check(page.tools_view.get_node(name+"/Badge").visible and page.tools_view.get_node(name+"/Count").text == "+", "Unclaimed tool must display a plus badge")
	var before: Dictionary = page.session.snapshot()
	var turnover: int = page.session.next_turnover()
	page.tools_view.get_node("AddBox").pressed.emit()
	check(not page.session.slots[turnover].open and page.session.tools.add_box == 1, "First click must only claim add-box")
	check(page.tools_view.get_node("AddBox/Count").text == "1", "Claimed tool must display one charge")
	page.tools_view.get_node("AddBox").pressed.emit()
	page._cancel_interaction()
	check(page.session.slots[turnover].open and page.session.tools.add_box == 0, "Add-box button did not execute its tool")
	page.tools_view.get_node("Undo").pressed.emit()
	check(page.session.slots[turnover].open and page.session.tools.undo == 1, "First click must only claim undo")
	page.tools_view.get_node("Undo").pressed.emit()
	page._cancel_interaction()
	check(page.session.slots == before.slots and page.session.tools.undo == 0 and page.session.tools.add_box == 0, "Undo button refunded spent add-box")
	page.tools_view.get_node("Top").pressed.emit()
	check(not page._top_mode and page.session.tools.top == 1, "First click must only claim top")
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
	for name: String in ["Undo", "AddBox", "Top"]:
		check(page.tools_view.get_node(name).disabled and not page.tools_view.get_node(name+"/Badge").visible, "Spent tool must be disabled without a zero badge")
	var spent: Dictionary = page.session.snapshot()
	for name: String in ["Undo", "AddBox", "Top"]:
		page.tools_view.get_node(name).pressed.emit()
	check(page.session.snapshot() == spent, "Spent button reissued a charge")
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
	check(s.move(2,1) and not s.move(0,2), "Fixed flavor allows extraction and keeps its color restriction when emptied")
	check(s.undo() and s.slots[2].box.items.size() == 1 and s.slots[2].box.fixed_flavor == 1, "Undo must restore the fixed-flavor contents and restriction")
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


## 道具奖励独立于棋盘历史，取消、存档、重复和跨种类回调均不能多发次数。
func _check_tool_rewards() -> void:
	var s := DonutSession.new()
	s.load_level(80)
	var initial: Dictionary = s.snapshot()
	check(s.request_tool_reward("unknown").is_empty(), "Unknown tool accepted")
	var token: String = s.request_tool_reward("top")
	check(not token.is_empty() and s.request_tool_reward("undo").is_empty(), "Concurrent reward accepted")
	check(not s.advance_clock(5) and not s.move(0, 1) and not s.add_box(), "Pending reward allowed gameplay")
	check(not s.resolve_turnover(token, true) and not s.pending_reward.is_empty(), "Tool token accepted as turnover")
	check(not s.resolve_tool_reward("wrong", true) and not s.pending_reward.is_empty(), "Foreign token consumed pending reward")
	check(not s.resolve_tool_reward(token, false) and s.snapshot() == initial, "Canceled reward changed game")
	var retry: String = s.request_tool_reward("top")
	check(not s.resolve_tool_reward(token, true), "Canceled callback granted a later request")
	check(s.resolve_tool_reward(retry, true) and s.tools.top == 1, "Retry did not grant exactly one charge")
	check(not s.resolve_tool_reward(retry, true) and s.request_tool_reward("top").is_empty(), "Duplicate charge granted")
	check(s.slots == initial.slots and s.moves == 0, "Claim executed a tool")
	var restored := DonutSession.new()
	check(restored.restore_run(JSON.parse_string(JSON.stringify(s.export_run()))) and restored.tools.top == 1, "Earned charge lost on resume")
	check(restored.request_tool_reward("top").is_empty(), "Resume allowed claiming twice")
	var turnover: int = s.next_turnover()
	token = s.request_turnover(turnover)
	check(not s.resolve_tool_reward(token, true) and s.resolve_turnover(token, false) == false, "Turnover token accepted as tool")
	check(s.resolve_tool_reward(s.request_tool_reward("add_box"), true) and s.add_box(), "Add-box fixture failed")
	check(s.resolve_tool_reward(s.request_tool_reward("undo"), true) and s.undo(), "Earned undo failed")
	check(s.tools.top == 1 and s.tools.add_box == 0 and s.tools.undo == 0 and not s.slots[turnover].open, "Undo changed charge ledger")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.export_run()))
	check(restored.restore_run(saved) and restored.tools == s.tools, "Spent charges lost on resume")
	for tool: String in ["undo", "add_box", "top"]:
		check(restored.request_tool_reward(tool).is_empty(), "Spent/earned tool could be reclaimed after resume")
	for malformed: Dictionary in [{"undo": 2}, {"top": 0.5}, {"add_box": "0"}]:
		var invalid: Dictionary = saved.duplicate(true)
		invalid.state.tools.merge(malformed, true)
		check(not restored.restore_run(invalid), "Invalid tool charge accepted")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.state.tool_claimed.top = false
	check(not restored.restore_run(invalid), "Unclaimed charge accepted")
	s.restart()
	check(s.tools == initial.tools and s.tool_claimed == initial.tool_claimed and not s.resolve_tool_reward(retry, true), "Restart retained charges or accepted stale reward")
	token = s.request_tool_reward("undo")
	check(restored.restore_run(JSON.parse_string(JSON.stringify(s.export_run()))) and restored.pending_reward.is_empty() and restored.tools.undo == 0, "Pending reward persisted as earned")
	s.cancel_tool_reward()
	check(s.load_level(1) and not s.resolve_tool_reward(token, true), "Canceled callback crossed levels")
	print("PASS: tool reward idempotency, once-per-attempt ledger, undo and save boundaries")


## 用延迟广告替身验证取消、失焦、暂停、隐藏、离树与会话替换，恢复后可重新领取。
func _check_tool_reward_lifecycle() -> void:
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	root.add_child(page)
	await process_frame
	await process_frame
	page._cancel_interaction()
	var callbacks: Array[Callable] = []
	page.tool_reward_provider = func(_tool: String, complete: Callable) -> void: callbacks.append(complete)
	page.tools_view.get_node("Top").pressed.emit()
	check(callbacks.size() == 1 and not page._board_input_enabled() and page.tools_view.get_node("Top").disabled, "Ad request did not lock gameplay")
	page.tools_view.get_node("Undo").pressed.emit()
	check(callbacks.size() == 1, "Pending ad opened another request")
	callbacks.pop_front().call(false)
	check(page.tools_view.get_node("Top/Count").text == "+" and not page.tools_view.get_node("Top").disabled, "Canceled ad lost plus/retry")
	page.tools_view.get_node("Top").pressed.emit()
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	callbacks.pop_front().call(true)
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(page.session.tools.top == 1 and not page._top_mode, "Ad focus change lost charge or auto-used it")
	page.tools_view.get_node("Top").pressed.emit()
	page._cancel_top_selection()
	check(page.session.tools.top == 1, "Canceled top selection spent charge")
	for interruption: String in ["hide", "pause", "replace", "exit"]:
		page._cancel_interaction()
		var source: DonutSession = page.session
		page.tools_view.get_node("Undo").pressed.emit()
		check(callbacks.size() == 1 and not source.pending_reward.is_empty(), "Could not request after interruption")
		match interruption:
			"hide":
				page.hide()
				page.show()
			"pause":
				paused = true
				paused = false
			"replace":
				page.initialize(DonutSession.new())
			"exit":
				root.remove_child(page)
		callbacks.pop_front().call(true)
		check(source.pending_reward.is_empty() and source.tools.undo == 0 and not source.tool_claimed.undo, "Late callback granted after " + interruption)
		await process_frame
	page.free()
	print("PASS: delayed tool ad callback, cancel, focus, pause, hide, replacement and exit")


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
	check(s.resolve_tool_reward(s.request_tool_reward("undo"), true), "Save fixture reward")
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
