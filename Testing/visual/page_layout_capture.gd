extends SceneTree
## 用正式页面捕获长短屏、局部胶囊及平板布局，同时记录实际区域和触控尺寸。


## 等待场景树就绪后启动隔离渲染，不加载 App 或真实进度。
func _initialize() -> void:
	_capture.call_deferred()


## 对同一组屏幕检查少盒、五排、后期密集及末关，并保存供人工复查的完整画面。
func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	var records: Array = []
	var cases: Array = [
		{"name": "browser_320", "width": 320, "height": 568},
		{"name": "browser_440", "width": 440, "height": 956},
		{"name": "host_320", "width": 320, "height": 568, "safeArea": {"top": 24, "bottom": 544},
			"menu": {"left": 224, "top": 40, "width": 80, "height": 32, "bottom": 72}},
		{"name": "host_360", "width": 360, "height": 640, "safeArea": {"top": 24, "bottom": 624},
			"menu": {"left": 268, "top": 24, "width": 80, "height": 32, "bottom": 56}},
		{"name": "host_393", "width": 393, "height": 852, "safeArea": {"top": 59, "bottom": 818},
			"menu": {"left": 301, "top": 72, "width": 80, "height": 32, "bottom": 104}},
		{"name": "tablet", "width": 768, "height": 1024, "safeArea": {"left": 12, "right": 756, "top": 24, "bottom": 1000}},
	]
	for metrics: Dictionary in cases:
		viewport.size = Vector2i(int(metrics.width), int(metrics.height))
		page.viewport_metrics = func() -> Dictionary: return metrics
		await process_frame
		await process_frame
		for level: int in [1, 3, 4, 7, 89, 100]:
			page.session.load_level(level - 1)
			page._cancel_interaction()
			page._fit_stage()
			await process_frame
			RenderingServer.force_draw(false)
			if not _check_background_seams(page, viewport.get_texture().get_image()):
				quit(1)
				return
			var name: String = "donut_page_%s_%03d" % [metrics.name, level]
			var destination: String = OS.get_environment("UI_CAPTURE_DIR").path_join(name + ".png")
			if viewport.get_texture().get_image().save_png(destination) != OK:
				push_error("Cannot save " + destination)
				quit(1)
				return
			var board_rect: Rect2 = page.board.get_global_rect()
			records.append({"name": name, "screen": [metrics.width, metrics.height],
				"stage_width": page.stage.get_global_rect().size.x,
				"board_height": board_rect.size.y,
				"board_height_ratio": board_rect.size.y / float(metrics.height),
				"holder_width": page.board.boxes[0].get_global_rect().size.x,
				"settings_size": page.settings_button.get_global_rect().size.x,
				"tool_size": page.tools_view.get_node("Undo").get_global_rect().size.x})
	var report: FileAccess = FileAccess.open(OS.get_environment("UI_CAPTURE_DIR").path_join("measurements.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(records, "\t") + "\n")
	report.close()
	viewport.queue_free()
	await process_frame
	print("PASS: page layout visual; %d captures and measured regions" % records.size())
	quit(0)


## 在背景分段交界检查真实像素，防止几何矩形相接却因取整露出清屏底色。
func _check_background_seams(page: Control, capture: Image) -> bool:
	var clear: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	for path: String in ["Cabinet", "Floor"]:
		var boundary: int = roundi(page.backdrop.get_node(path).get_global_rect().position.y)
		for y: int in range(maxi(0, boundary - 1), mini(capture.get_height(), boundary + 2)):
			for x: int in [capture.get_width() / 4, capture.get_width() / 2, capture.get_width() * 3 / 4]:
				var pixel: Color = capture.get_pixel(x, y)
				if absf(pixel.r - clear.r) < 0.01 and absf(pixel.g - clear.g) < 0.01 and absf(pixel.b - clear.b) < 0.01:
					push_error("Background seam at %s %s/%d,%d" % [capture.get_size(), path, x, y])
					return false
	return true
