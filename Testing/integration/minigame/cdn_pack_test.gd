extends SceneTree
## 挂载同批远程贴图包后，从核心包实例化真实关卡并检查关键视觉资源。


## 待场景树可用后进行资源包加载，避免测试脚本预先解析业务类。
func _initialize() -> void:
	_run.call_deferred()


## 远程包必须补齐两张背景，并保持可操作关卡与订单 UI 完整。
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or not ProjectSettings.load_resource_pack(args[0], false):
		_fail("Remote content pack cannot mount.")
		return
	for path: String in [
		"res://features/donut_sort/ui/art/scene/shop_background_unified.png",
		"res://features/donut_sort/ui/art/scene/tabletop_light.png",
	]:
		if load(path) == null:
			_fail("Remote background texture is missing: " + path)
			return
	var scene: PackedScene = load("res://features/home/ui/home_screen.tscn")
	if scene == null:
		_fail("Core pack has no home scene.")
		return
	var page: Control = scene.instantiate()
	root.add_child(page)
	await process_frame
	var board: Node = page.get_node_or_null("Stage/Boxes")
	var orders: Node = page.get_node_or_null("Stage/Orders")
	if board == null or orders == null or board.get("boxes").size() != 17 or orders.get("cards").size() != 4:
		_fail("Split packs cannot assemble the playable first level.")
		return
	page.queue_free()
	await process_frame
	print("PASS: minigame CDN core and remote packs")
	quit(0)


## 缺资源时返回非零状态，防止仅凭 PCK 文件存在就认为加载成功。
func _fail(message: String) -> void:
	push_error(message)
	quit(1)
