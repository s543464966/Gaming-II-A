extends SceneTree
## 从真实盒子与关卡截图检查整叠冰壳、数字、纸托前沿及小屏比例。


## 延迟至渲染器就绪后启动，不创建 App 或读写进度。
func _initialize() -> void:
	_capture.call_deferred()


## 同时显示三四层冻结和三类纸托，再捕获正式五排关与教学说明。
func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1320, 880)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := Control.new()
	viewport.add_child(sheet)
	var background := ColorRect.new()
	background.size = Vector2(viewport.size)
	background.color = Color("f4d5b4")
	sheet.add_child(background)
	var cases: Array = [
		["normal", 4, "Regular rim"], ["normal", 1, "One donut"], ["single", 1, "Single slot"],
		["fixed", 4, "Fixed color"], ["hidden", 4, "Hidden layers"],
		["frozen", 3, "Ice / 3 layers"], ["frozen", 4, "Ice / 4 layers"],
		["number_frozen", 3, "Number / 3 layers"], ["number_frozen", 4, "Number / 4 layers"],
		["lid", 4, "Opaque cover"]]
	for index: int in cases.size():
		var item: Array = cases[index]
		var kind: String = item[0]
		var box: DonutBox = load("res://features/donut_sort/board/ui/donut_box.tscn").instantiate()
		sheet.add_child(box)
		box.position = Vector2(32 + index % 5 * 264, 210 + index / 5 * 400)
		var items: Array = []
		for layer: int in int(item[1]):
			items.append({"flavor": layer if kind != "fixed" else 2, "revealed": kind != "hidden" or layer == 0})
		box.present({"open": true, "kind": "single" if kind == "single" else "regular",
			"box": {"kind": kind, "fixed_flavor": 2, "frozen": kind in ["frozen", "number_frozen"],
				"lid": 2 if kind in ["lid", "number_frozen"] else 0, "items": items}})
		var label := Label.new()
		label.text = item[2]
		label.position = box.position + Vector2(0, 142)
		label.add_theme_color_override("font_color", Color("513327"))
		label.add_theme_font_size_override("font_size", 20)
		sheet.add_child(label)
	await _save(viewport, "donut_ice_shell_components")
	sheet.queue_free()
	await process_frame
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	for dimensions: Vector2i in [Vector2i(393, 852), Vector2i(320, 568)]:
		viewport.size = dimensions
		var metrics: Dictionary = {"width": dimensions.x, "height": dimensions.y,
			"safeArea": {"top": 59 if dimensions.x == 393 else 24, "bottom": dimensions.y - 24},
			"menu": {"left": dimensions.x - 96, "top": 72 if dimensions.x == 393 else 40, "width": 80, "height": 32}}
		page.viewport_metrics = func() -> Dictionary: return metrics
		await process_frame
		await process_frame
		for level: int in [2, 4, 18, 30, 86, 89]:
			page.session.load_level(level - 1)
			page._cancel_interaction()
			page._fit_stage()
			await _save(viewport, "donut_ice_shell_%d_%03d" % [dimensions.x, level])
		page._show_lesson("frozen")
		await _save(viewport, "donut_ice_shell_lesson_%d" % dimensions.x)
		page.lesson_dialog.hide()
	viewport.queue_free()
	await process_frame
	print("PASS: ice shell visual; 10 components, 12 formal pages and 2 lesson screens")
	quit(0)


## 主动绘制最终帧，后台窗口也能产出完整图像。
func _save(viewport: SubViewport, name: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	assert(viewport.get_texture().get_image().save_png(OS.get_environment("UI_CAPTURE_DIR").path_join(name + ".png")) == OK)
