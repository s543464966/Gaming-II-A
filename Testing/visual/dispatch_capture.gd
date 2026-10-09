extends SceneTree
## 用正式第一关的首次收餐捕获连续原始帧，供检查逐颗飞行与盒口遮挡。


## 等待场景与渲染器就绪后启动隔离回放。
func _initialize() -> void:
	_capture.call_deferred()


## 手机与短屏各捕获一段完整收餐，关卡状态只由正式搬运推进。
func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	page.set_process(false)
	var path: String = get_script().resource_path.get_base_dir().path_join("../fixtures/donut_sort/level_01_solution.json")
	var steps: Array = JSON.parse_string(FileAccess.get_file_as_string(path)).steps
	for metrics: Dictionary in [
		{"name": "phone", "width": 393, "height": 852, "safeArea": {"top": 59, "bottom": 818},
			"menu": {"left": 301, "top": 72, "width": 80, "height": 32, "bottom": 104}},
		{"name": "short", "width": 320, "height": 568, "safeArea": {"top": 24, "bottom": 544},
			"menu": {"left": 224, "top": 40, "width": 80, "height": 32, "bottom": 72}},
	]:
		viewport.size = Vector2i(int(metrics.width), int(metrics.height))
		page.viewport_metrics = func() -> Dictionary: return metrics
		await process_frame
		await process_frame
		page.session.load_level(0)
		page._cancel_interaction()
		page._fit_stage()
		await process_frame
		for step: Array in steps:
			assert(page.session.move(int(step[0]), int(step[1])))
			if page.event_player.dispatch_pending:
				break
			page._cancel_interaction()
		assert(page.event_player.dispatch_pending)
		var timeline: Tween = page.event_player._animation
		timeline.pause()
		var committed: Dictionary = page.session.snapshot()
		for frame: int in 80:
			if frame >= 10 and timeline.is_valid():
				timeline.custom_step(1.0 / 30.0)
			await process_frame
			RenderingServer.force_draw(false)
			var destination: String = OS.get_environment("UI_CAPTURE_DIR").path_join("%s_%03d.png" % [metrics.name, frame])
			assert(viewport.get_texture().get_image().save_png(destination) == OK)
		assert(page.session.snapshot() == committed and not page.event_player.dispatch_pending)
	viewport.queue_free()
	await process_frame
	print("PASS: dispatch visual; phone and short screen, 160 unmodified rendered frames")
	quit(0)
