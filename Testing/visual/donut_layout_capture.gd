extends SceneTree
## 保存真实关卡与独立布局样例的渲染截图，输出目录由验证入口注入。


## 等待图形渲染器就绪后创建隔离页面。
func _initialize() -> void:
	_capture.call_deferred()


## 同时检查短屏、安全区、机关与布局密度，不写入正式关卡。
func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(440, 956)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	var cases: Array = [
		{"name": "browser", "width": 440, "height": 956, "browser": true},
		{"name": "review_level_02", "width": 547, "height": 1188, "level": 1, "browser": true},
		{"name": "small", "width": 360, "height": 640,
			"safeArea": {"top": 24, "bottom": 624}, "menu": {"bottom": 56, "width": 80, "height": 32}},
		{"name": "phone", "width": 440, "height": 956,
			"safeArea": {"top": 62, "bottom": 922}, "menu": {"bottom": 104, "width": 80, "height": 32}},
		{"name": "tablet", "width": 768, "height": 1024},
	]
	for metrics: Dictionary in cases:
		viewport.size = Vector2i(metrics.width, metrics.height)
		page.viewport_metrics = func() -> Dictionary: return {} if metrics.get("browser", false) else metrics
		page.session.load_level(int(metrics.get("level", 0)))
		await process_frame
		await process_frame
		page._cancel_interaction()
		page._fit_stage()
		await _save(viewport, metrics.name)
		print("LAYOUT ", metrics.name, " holder width=", page.board.boxes[0].get_global_rect().size.x)
	viewport.size = Vector2i(440, 956)
	page.viewport_metrics = func() -> Dictionary: return {}
	await process_frame
	await process_frame
	for level: int in [1, 2, 3, 5, 6, 8, 9]:
		page.session.load_level(level)
		page._cancel_interaction()
		page._fit_stage()
		await _save(viewport, "level_%02d" % (level + 1))
	page.session.load_level(0)
	page._cancel_interaction()
	var snapshot: Dictionary = page.session.snapshot()
	for key: String in ["staggered_8", "staggered_12", "staggered_25"]:
		page.board.configure_layout(key)
		for index: int in page.board.boxes.size():
			page.board.boxes[index].present(snapshot.slots[index % snapshot.slots.size()])
		await _save(viewport, key)
	viewport.queue_free()
	await process_frame
	print("PASS: donut layout visual captures")
	quit()


## 等待完整一帧后保存视口，避免截到入场动画或过期布局。
func _save(viewport: SubViewport, name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var destination: String = OS.get_environment("UI_CAPTURE_DIR").path_join("donut_sort_spacing_fixed_" + name + ".png")
	var result: Error = viewport.get_texture().get_image().save_png(destination)
	if result != OK:
		push_error("Cannot save visual capture: " + destination)
	print("CAPTURE: ", destination)
