extends SceneTree
## 在隔离页面中捕获简体中文和英文失败弹窗，不读取玩家存档。


## 等待渲染器就绪后开始截图。
func _initialize() -> void:
	_capture.call_deferred()


## 在窄屏手机、长屏手机和平板复查字形、文字边界与图片遮挡。
func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	page.session.load_level(97)
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	for dimensions: Vector2i in [Vector2i(320, 568), Vector2i(440, 956), Vector2i(768, 1024)]:
		viewport.size = dimensions
		await process_frame
		page._fit_stage()
		page.failure_panel.present()
		for locale: String in ["zh_CN", "en_US"]:
			TranslationServer.set_locale(locale)
			await process_frame
			await RenderingServer.frame_post_draw
			var name: String = "donut_failure_%s_%dx%d.png" % [locale.to_lower(), dimensions.x, dimensions.y]
			var destination: String = OS.get_environment("UI_CAPTURE_DIR").path_join(name)
			if viewport.get_texture().get_image().save_png(destination) != OK:
				push_error("Cannot save " + destination)
				quit(1)
				return
	viewport.queue_free()
	await process_frame
	print("PASS: six failure locale captures")
	quit()
