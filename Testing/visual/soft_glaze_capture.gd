extends SceneTree
## 用正式资源检查十五组口味配对、固定纸托原色与备用着色及新版灰圈，再捕获长短屏实景。

const COLORS: Array[String] = ["pink", "cocoa", "forest_green", "sky_blue", "orange", "ivory", "purple", "raspberry", "red", "caramel", "teal", "royal_blue", "lime", "lavender", "yellow"]


## 场景树就绪后开始，不访问 App 或真实进度。
func _initialize() -> void:
	_capture.call_deferred()


## 色板使用正式盒子和订单贴纸，额外显示四层、隐藏层与冰霜覆盖。
func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := Control.new()
	viewport.add_child(sheet)
	var background := ColorRect.new()
	background.color = Color("f4d5b4")
	background.size = Vector2(viewport.size)
	sheet.add_child(background)
	var boxes: Array[DonutBox] = []
	for flavor: int in 15:
		var food: AtlasTexture = DonutArt.FOOD[flavor]
		var sticker: AtlasTexture = DonutOrderCard.STICKER_ART[flavor]
		assert(food.resource_path.ends_with("soft_glaze_%s.tres" % COLORS[flavor]))
		assert(sticker.resource_path.ends_with("soft_glaze_sticker_%s.tres" % COLORS[flavor]))
		assert(Rect2(Vector2.ZERO, food.atlas.get_size()).encloses(food.region))
		assert(Rect2(Vector2.ZERO, sticker.atlas.get_size()).encloses(sticker.region))
		var origin := Vector2(20 + (flavor % 5) * 240, 80 + (flavor / 5) * 230)
		var box: DonutBox = _make_box(sheet, origin, flavor, 1, false, false)
		boxes.append(box)
		var badge := TextureRect.new()
		badge.texture = sticker
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.size = Vector2(52, 52)
		badge.position = origin + Vector2(150, -60)
		sheet.add_child(badge)
		_label(sheet, origin + Vector2(0, 130), "%02d  %s" % [flavor, COLORS[flavor]])
	for flavor: int in boxes.size():
		var material: ShaderMaterial = boxes[flavor].back.material
		assert(material.get_shader_parameter("flavor_color") == DonutArt.FLAVOR_COLORS[flavor])
		assert(material.get_shader_parameter("enabled") == (flavor in DonutMechanicArt.TINTED_FIXED_FLAVORS))
		assert(boxes[flavor].back.texture == DonutMechanicArt.FIXED[flavor])
		assert(boxes[flavor].front.texture.atlas == boxes[flavor].back.texture.atlas)
		if flavor > 0:
			assert(material != boxes[flavor - 1].back.material)
	for sample: int in 4:
		var origin := Vector2(40 + sample * 290, 900)
		_make_box(sheet, origin, sample, 4, sample == 1, sample == 2)
		_label(sheet, origin + Vector2(0, 130), ["Four layers", "Hidden layers", "Frozen layers", "Mixed flavors"][sample])
	await _save(viewport, "donut_soft_glaze_palette")
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
		for level: int in [1, 4, 6, 86, 89]:
			page.session.load_level(level - 1)
			page.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			page._cancel_interaction()
			page._fit_stage()
			await _save(viewport, "donut_soft_glaze_%d_%03d" % [dimensions.x, level])
	viewport.queue_free()
	await process_frame
	print("PASS: soft glaze; 15 atlas/sticker pairs, original fixed holders and independent fallback tints, gray/frozen stacks and 10 page captures")
	quit(0)


## 只构造表现快照，不更改正式关卡文件或保存状态。
func _make_box(parent: Control, origin: Vector2, flavor: int, count: int, hidden: bool, frozen: bool) -> DonutBox:
	var box: DonutBox = load("res://features/donut_sort/board/ui/donut_box.tscn").instantiate()
	parent.add_child(box)
	box.position = origin
	var items: Array = []
	for index: int in count:
		items.append({"flavor": (flavor + index) % 15, "revealed": not hidden or index == 0})
	box.present({"open": true, "kind": "regular", "unlock_after": 0,
		"box": {"kind": "fixed", "fixed_flavor": flavor, "lid": 0, "frozen": frozen, "items": items}})
	return box


## 图鉴标注只用于测试输出，不进入玩家界面。
func _label(parent: Control, origin: Vector2, caption: String) -> void:
	var label := Label.new()
	label.position = origin
	label.text = caption
	label.add_theme_color_override("font_color", Color("513327"))
	label.add_theme_font_size_override("font_size", 20)
	parent.add_child(label)


## 等待最终帧并确认图片写入成功。
func _save(viewport: SubViewport, name: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	var destination: String = OS.get_environment("UI_CAPTURE_DIR").path_join(name + ".png")
	assert(viewport.get_texture().get_image().save_png(destination) == OK)
