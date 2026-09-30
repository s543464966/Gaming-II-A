extends SceneTree
## 使用正式网页资源包复查订单贴纸中心和失败弹窗在不同屏幕下的比例。


## 等待渲染器就绪后创建独立预览页面。
func _initialize() -> void:
	_capture.call_deferred()


## 遍历全部口味与代表视口，不连接存档或改变关卡内容。
func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(440, 956)
	root.add_child(viewport)
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	viewport.add_child(page)
	await process_frame
	await process_frame
	page.session.load_level(97)
	page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	page._fit_stage()
	for group: int in 4:
		var demands: Array = []
		for index: int in 4:
			var flavor: int = group * 4 + index
			demands.append({"open": flavor < 15, "cursor": 0, "sequence": [mini(flavor, 14)]})
		page.orders.present(demands)
		await _save(viewport, "order_alignment_%d" % group)
	for dimensions: Vector2i in [Vector2i(320, 568), Vector2i(440, 956), Vector2i(768, 1024)]:
		viewport.size = dimensions
		await process_frame
		page._fit_stage()
		page.failure_panel.present()
		await _save(viewport, "failure_%dx%d" % [dimensions.x, dimensions.y])
		page.failure_panel.hide()
	viewport.queue_free()
	await process_frame
	print("PASS: order alignment and compact failure captures")
	quit()


## 等待最终帧并检查保存结果，截图使用固定参考目录。
func _save(viewport: SubViewport, name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var destination: String = OS.get_environment("UI_CAPTURE_DIR").path_join("donut_" + name + ".png")
	if viewport.get_texture().get_image().save_png(destination) != OK:
		push_error("Cannot save " + destination)
		quit(1)
