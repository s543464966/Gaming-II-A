extends SceneTree
## 验证实际网页PCK含全部百关、布局和后期机关资源，并能实例化真实页面。


## 挂载包后在引擎中执行资源检查。
func _initialize() -> void:
	_run.call_deferred()


## 包内读取关卡而非借用工作区源码，关键素材失败即拒绝发布预览。
func _run() -> void:
	if DonutLevel.catalog().size() != 100:
		push_error("Web pack does not contain 100 levels")
		quit(1)
		return
	for entry: Dictionary in DonutLevel.catalog():
		if DonutLevel.load_definition(entry.path).is_empty():
			quit(1)
			return
	for flavor: int in DonutLevel.FLAVOR_COUNT:
		if DonutArt.FOOD[flavor] == null or DonutOrderCard.STICKER_ART[flavor] == null:
			push_error("Missing flavor resource")
			quit(1)
			return
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	root.add_child(page)
	await process_frame
	await process_frame
	for index: int in [5,11,17,23,30,40,50,60,68,80,97,98,99]:
		page.session.load_level(index)
		page._cancel_interaction()
		if page.board.boxes.size() != page.session.slots.size():
			push_error("Pack layout count mismatch")
			quit(1)
			return
	page.queue_free()
	await process_frame
	print("PASS: hundred web pack")
	quit(0)
