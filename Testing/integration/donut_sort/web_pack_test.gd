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
		if DonutArt.FOOD[flavor] == null or DonutOrderCard.STICKER_ART[flavor] == null \
			or not DonutArt.FOOD[flavor].atlas.resource_path.ends_with("soft_glaze_palette.png") \
			or not DonutOrderCard.STICKER_ART[flavor].atlas.resource_path.ends_with("soft_glaze_stickers.png"):
			push_error("Missing flavor resource")
			quit(1)
			return
	if not DonutArt.HIDDEN.atlas.resource_path.ends_with("soft_glaze_hidden_gray.png"):
		push_error("Missing new neutral hidden donut")
		quit(1)
		return
	if DonutMechanicArt.ICE_SHELL == null or not DonutMechanicArt.ICE_SHELL.atlas.resource_path.ends_with("ice_stack_shell.png"):
		push_error("Missing new stack ice shell")
		quit(1)
		return
	for old_path: String in ["res://game_content/donuts/art/donut_pink_plain.tres",
		"res://features/donut_sort/orders/ui/art/sticker_pink.tres",
		"res://features/donut_sort/board/ui/art/mechanics/donut_hidden_neutral.tres",
		"res://features/donut_sort/board/ui/art/mechanics/frost_donut_overlay.tres",
		"res://features/donut_sort/ui/art/special/ice_cover.tres"]:
		if ResourceLoader.exists(old_path):
			push_error("Replaced art remains in the pack: " + old_path)
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
