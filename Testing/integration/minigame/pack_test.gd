extends SceneTree
## 从真实导出包验证启动场景、关卡配置与随包中文字体。


## 延迟到场景树就绪后执行打包资源检查。
func _initialize() -> void:
	_run.call_deferred()


## 导出包必须能装配真实首关，并提供中文字符而无需系统字体。
func _run() -> void:
	var packed: PackedScene = load("res://bootstrap/app.tscn")
	if packed == null:
		_fail("Exported App scene is missing.")
		return
	var app: Node = packed.instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	var page: Control = app.get_node("SceneContainer/HomeScreen")
	if page.get_node("Stage/Boxes").get_child_count() != 16 or page.session.total_orders() <= 0 \
			or page.session.total_donuts() <= 0:
		_fail("Exported level configuration did not load.")
		return
	var font: FontFile = load("res://ui/design_system/fonts/donut_sans_sc.otf")
	if font == null:
		_fail("Bundled Chinese font is missing.")
		return
	for character: String in "甜甜圈小铺草莓巧克力抹茶蓝莓暂停继续重新开始撤回置顶餐盒订单完成取消":
		if not font.has_char(character.unicode_at(0)):
			_fail("Bundled font is missing: " + character)
			return
	app.queue_free()
	await process_frame
	print("PASS: minigame exported pack")
	quit(0)


## 输出可定位的错误并用非零状态结束检查。
func _fail(message: String) -> void:
	push_error(message)
	quit(1)
