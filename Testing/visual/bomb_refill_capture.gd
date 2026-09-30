extends SceneTree
## 用正式关卡路线捕获补货全过程及未回收炸弹解除后的实际画面。


## 等待引擎场景与渲染器就绪。
func _initialize() -> void:
	_run.call_deferred()


## 隔离回放第十关首批补货和第九十一关等待订单的已解除炸弹。
func _run() -> void:
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(440,956)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	page.set_process(false)
	page.session.load_level(9)
	page._cancel_interaction()
	var steps: Array = _steps(10)
	var probe := DonutSession.new(DonutLevel.load_definition(DonutLevel.catalog()[9].path))
	probe.begin()
	var first_refill: int = -1
	for index: int in steps.size():
		var previous_stock: int = probe.remaining_stock()
		assert(probe.move(int(steps[index][0]), int(steps[index][1])))
		if probe.remaining_stock() < previous_stock:
			first_refill = index
			break
	assert(first_refill >= 0)
	for index: int in first_refill:
		assert(page.session.move(int(steps[index][0]), int(steps[index][1])))
		page._cancel_interaction()
	await _save(viewport,"refill_before")
	assert(page.session.move(int(steps[first_refill][0]), int(steps[first_refill][1])))
	assert(page.event_player.refill_pending)
	page.event_player._animation.pause()
	var captured_in_flight: bool = false
	for tick: int in 200:
		page.event_player._animation.custom_step(0.02)
		for effect: Node in page.event_player.get_children():
			if effect is DonutBox and effect.visible and not effect.is_queued_for_deletion():
				var finish: Vector2 = page.board.origin(effect.box_index)
				if Rect2(Vector2.ZERO, Vector2(viewport.size)).has_point(effect.get_global_rect().get_center()) \
						and effect.position.distance_to(finish) > 12.0:
					captured_in_flight = true
					print("FLIGHT: visible refill at ",effect.position,"; target ",finish)
					break
		if captured_in_flight:
			break
	assert(captured_in_flight)
	await _save(viewport,"refill_in_flight")
	page.event_player._animation.custom_step(10.0)
	await _save(viewport,"refill_after")
	print("REFILL: level 10; move ",first_refill+1,"; remaining stock ",page.session.remaining_stock())
	page.session.load_level(90)
	page._cancel_interaction()
	var found_waiting: bool = false
	for step: Array in _steps(91):
		var target: int = int(step[1])
		var was_bomb: bool = page.session.slots[target].box != null and page.session.slots[target].box.kind == "bomb"
		assert(page.session.move(int(step[0]), target))
		page._cancel_interaction()
		if was_bomb and page.session.slots[target].box != null and page.session.slots[target].box.kind == "normal" and page.session.is_waiting(target):
			found_waiting = true
			assert(not page.board.boxes[target].get_node("Mechanic").visible)
			assert(not page.board.boxes[target].get_node("Countdown").visible)
			await _save(viewport,"bomb_disarmed_waiting")
			print("BOMB: level 91; slot ",target," grouped and waiting without countdown")
			break
	assert(found_waiting)
	viewport.queue_free()
	await process_frame
	print("PASS: bomb/refill visual")
	quit(0)


## 从与当前关卡绑定的正式回放夹具读取路线。
func _steps(level: int) -> Array:
	var path: String = get_script().resource_path.get_base_dir().path_join("../fixtures/donut_sort/level_%02d_solution.json" % level)
	return JSON.parse_string(FileAccess.get_file_as_string(path)).steps


## 捕获完成绘制的原始帧，不修改美术或拼接模拟画面。
func _save(viewport: SubViewport, name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var destination: String = OS.get_environment("UI_CAPTURE_DIR").path_join("donut_"+name+".png")
	assert(viewport.get_texture().get_image().save_png(destination) == OK)
	print("CAPTURE: ",destination)
