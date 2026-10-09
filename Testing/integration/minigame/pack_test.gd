extends SceneTree
## 从真实导出包验证启动场景、百关配置与随包中文字体。


## 延迟到场景树就绪后执行打包资源检查。
func _initialize() -> void:
	_run.call_deferred()


## 导出包必须能装配真实首关，并提供中文字符而无需系统字体。
func _run() -> void:
	var catalog: Array = DonutLevel.catalog()
	if catalog.size() != 100:
		_fail("Exported pack must contain the complete 100-level catalog.")
		return
	for entry: Dictionary in catalog:
		if DonutLevel.load_definition(entry.path).is_empty():
			_fail("Exported level definition is missing or invalid: " + entry.path)
			return
	var first_level: Dictionary = DonutLevel.load_definition(catalog[0].path)
	var expected_slots: int = first_level.slots.size()
	var packed: PackedScene = load("res://bootstrap/app.tscn")
	if packed == null:
		_fail("Exported App scene is missing.")
		return
	var app: Node = packed.instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	var page: Control = app.get_node("SceneContainer/HomeScreen")
	if (page.get_node("Stage/Boxes") as DonutBoardView).boxes.size() != expected_slots \
			or page.session.slots.size() != expected_slots or page.session.total_orders() <= 0 \
			or page.session.total_donuts() <= 0:
		_fail("Exported first level did not assemble its %d configured slots." % expected_slots)
		return
	if (page.get_node("Stage/Orders") as DonutOrdersView).cards.size() != 4:
		_fail("Exported order cards are missing.")
		return
	if DonutArt.FOOD.size() != DonutLevel.FLAVOR_COUNT or DonutOrderCard.STICKER_ART.size() != DonutLevel.FLAVOR_COUNT:
		_fail("Exported flavor and sticker counts do not match the level content.")
		return
	for flavor: int in DonutLevel.FLAVOR_COUNT:
		if DonutArt.FOOD[flavor] == null or DonutOrderCard.STICKER_ART[flavor] == null:
			_fail("Exported flavor or sticker is missing: %d" % flavor)
			return
	var flavors: Array[String] = ["pink", "cocoa", "forest_green", "sky_blue", "orange", "ivory", "purple",
		"raspberry", "red", "caramel", "teal", "royal_blue", "lime", "lavender", "yellow"]
	for index: int in flavors.size():
		if DonutArt.FOOD[index] != load("res://game_content/donuts/art/soft_glaze_%s.tres" % flavors[index]):
			_fail("Exported pack is still using old flavor art: " + flavors[index])
			return
		if DonutOrderCard.STICKER_ART[index] != load("res://features/donut_sort/orders/ui/art/soft_glaze_sticker_%s.tres" % flavors[index]):
			_fail("Exported pack is missing the matching order sticker: " + flavors[index])
			return
	if page.board.boxes[0].back.texture != load("res://features/donut_sort/board/ui/art/paper_holder_round.tres"):
		_fail("Exported pack is missing the V8 round holder.")
		return
	for segment: String in ["top", "middle", "bottom"]:
		if not ResourceLoader.exists("res://features/donut_sort/ui/art/scene/background_%s.png" % segment):
			_fail("Exported V8 background segment is missing: " + segment)
			return
	var order: DonutOrderCard = page.orders.cards[0]
	if order.get_node_or_null("Box") == null or order.box_art.material == null:
		_fail("Exported pack still uses the old order panel.")
		return
	if page.orders.cards[0].get_global_rect().position.y - page.get_node("Stage/Title").get_global_rect().end.y > 32.0 * page.stage.scale.y + 0.01:
		_fail("Exported layout still expands the header spacing.")
		return
	for path: String in ["Stage/Tools/Undo", "Stage/Tools/AddBox",
			"Stage/Tools/Top", "Stage/Boxes/Box0/Food"]:
		if page.get_node_or_null(path) == null:
			_fail("Exported UI component is missing: " + path)
			return
	var font: FontFile = load("res://design_system/fonts/chill_round_bold.ttf")
	if font == null:
		_fail("Bundled Chinese font is missing.")
		return
	for character: String in "甜甜圈小铺草莓巧克力抹茶蓝莓选择关卡重新开始撤回置顶餐盒订单完成取消查看餐台":
		if not font.has_char(character.unicode_at(0)):
			_fail("Bundled font is missing: " + character)
			return
	app.queue_free()
	await process_frame
	print("PASS: minigame exported pack; 100 levels, fifteen flavors and configured first-level layout")
	quit(0)


## 输出可定位的错误并用非零状态结束检查。
func _fail(message: String) -> void:
	push_error(message)
	quit(1)
