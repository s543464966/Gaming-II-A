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
		"res://features/donut_sort/ui/art/special/ice_cover.tres",
		"res://design_system/fonts/donut_sans_sc.otf",
		"res://design_system/fonts/lilita_one.ttf",
		"res://design_system/fonts/lobster_two_italic.ttf"]:
		if ResourceLoader.exists(old_path):
			push_error("Replaced resource remains in the pack: " + old_path)
			quit(1)
			return
	var theme: Theme = load("res://design_system/themes/game_theme.tres")
	var font: FontFile = load("res://design_system/fonts/chill_round_bold.ttf")
	if font == null or theme.default_font != font:
		push_error("Web pack does not use the unified game font")
		quit(1)
		return
	for character: String in "甜甜圈小铺第关撤回加餐盒置顶挑战失败再试一次吧！Level Failed Let’s try again!0123456789√×＋":
		if not font.has_char(character.unicode_at(0)):
			push_error("Unified font glyph missing: " + character)
			quit(1)
			return
	var page: Control = load("res://features/home/ui/home_screen.tscn").instantiate()
	root.add_child(page)
	await process_frame
	await process_frame
	var music: AudioStreamWAV = page.audio.music.stream
	if music == null or music.loop_mode != AudioStreamWAV.LOOP_FORWARD or music.loop_begin != 0 or music.loop_end != 1411200:
		push_error("Web pack is missing the complete looping music")
		quit(1)
		return
	for player: AudioStreamPlayer in [page.audio.move_sound, page.audio.clear_sound, page.audio.pack_sound]:
		if player.stream == null or player.stream.loop_mode != AudioStreamWAV.LOOP_DISABLED or player.stream.get_length() <= 0.0:
			push_error("Web pack is missing a one-shot audio effect: " + player.name)
			quit(1)
			return
	for index: int in [5,11,17,23,30,40,50,60,68,80,97,98,99]:
		page.session.load_level(index)
		page._cancel_interaction()
		if page.board.boxes.size() != page.session.slots.size():
			push_error("Pack layout count mismatch")
			quit(1)
			return
	page.queue_free()
	await process_frame
	await preload("../../helpers/audio_cleanup.gd").wait_for_mix(self)
	print("PASS: hundred web pack")
	quit(0)
