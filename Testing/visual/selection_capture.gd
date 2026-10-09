extends SceneTree
## 在真实关卡页面捕获固定选中高度及最短屏密集关卡的空间预留。


## 渲染器初始化后创建隔离页面，不接入进度服务。
func _initialize() -> void:
	_capture.call_deferred()


## 检查普通手机和两个受抬升预留影响最大的短屏关卡。
func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	for level: int in [1, 78, 89]:
		var small: bool = level > 1
		viewport.size = Vector2i(320, 568) if small else Vector2i(393, 852)
		page.viewport_metrics = func() -> Dictionary:
			return {"width": 320, "height": 568, "safeArea": {"top": 24, "bottom": 544},
				"menu": {"left": 224, "top": 40, "bottom": 72, "width": 80, "height": 32}} if small else {}
		page.session.load_level(level - 1)
		page._cancel_interaction()
		page._fit_stage()
		await process_frame
		for index: int in page.session.slots.size():
			if page.session.can_pick_top(index):
				page._on_box_pressed(index)
				break
		await process_frame
		await RenderingServer.frame_post_draw
		var box: DonutBox = page.board.boxes[page.selected_box]
		print("SELECTION ", level, " items=", page.session.slots[page.selected_box].box.items.size(),
			" local_y=", box.food_stack.food_at(0).position.y, " art_width=", box.get_global_rect().size.x)
		var path: String = OS.get_environment("UI_CAPTURE_DIR").path_join("donut_selected_%03d_%s.png" % [level, "small" if small else "phone"])
		if viewport.get_texture().get_image().save_png(path) != OK:
			push_error("Cannot save " + path)
			quit(1)
			return
	viewport.queue_free()
	await process_frame
	print("PASS: three selected height captures")
	quit()
