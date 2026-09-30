extends SceneTree
## 在真实Compatibility渲染器中保存百关各机制和高密度小屏画面。


## 等待渲染器就绪后开始截图。
func _initialize() -> void:
	_run.call_deferred()


## 使用正式关卡定义与固定视口，不改写进度或关卡内容。
func _run() -> void:
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(440,956)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	for level: int in [1,6,7,10,12,18,24,28,31,39,41,48,49,51,59,61,67,69,71,79,81,88,91,93,96,98,99,100]:
		page.session.load_level(level-1)
		page._cancel_interaction()
		page._fit_stage()
		await _save(viewport,"level_%03d" % level)
	for level: int in [1,7,28,48,59,68,88,89,90,96,98,99,100]:
		viewport.size = Vector2i(320,568)
		page.session.load_level(level-1)
		await process_frame
		page._cancel_interaction()
		page._fit_stage()
		await _save(viewport,"small_%03d" % level)
	for metrics: Dictionary in [
		{"width": 440, "height": 956, "safeArea": {"top": 62, "bottom": 922}, "menu": {"bottom": 104, "width": 80, "height": 32}},
		{"width": 360, "height": 640, "safeArea": {"top": 24, "bottom": 624}, "menu": {"bottom": 56, "width": 80, "height": 32}},
	]:
		viewport.size = Vector2i(int(metrics.width), int(metrics.height))
		page.viewport_metrics = func() -> Dictionary: return metrics
		page.session.load_level(88)
		await process_frame
		page._cancel_interaction()
		page._fit_stage()
		await _save(viewport,"host_%dx%d_089" % [metrics.width, metrics.height])
	page.viewport_metrics = func() -> Dictionary: return {}
	viewport.size = Vector2i(320,568)
	await process_frame
	page._fit_stage()
	page._show_level_menu()
	page.settings_panel.page_index = 9
	page.settings_panel._show_page()
	await _save(viewport,"menu_100")
	page.settings_panel.close()
	page._show_lesson("bomb")
	await _save(viewport,"bomb_lesson")
	viewport.queue_free()
	await process_frame
	print("PASS: hundred visual")
	quit(0)


## 保存最终帧；错误返回非零诊断，避免把不存在的截图列为完成。
func _save(viewport: SubViewport, name: String) -> void:
	await process_frame
	# 隐藏的测试窗口可能不自动重绘，主动完成绘制再读取实际纹理。
	RenderingServer.force_draw(false)
	var destination: String = OS.get_environment("UI_CAPTURE_DIR").path_join("donut_hundred_"+name+".png")
	if viewport.get_texture().get_image().save_png(destination) != OK:
		push_error("Cannot save " + destination)
		quit(1)
	print("CAPTURE: ",destination)
