extends SceneTree
## 验证启动依赖独立可用，并在挂载同批全部贴图块后实例化真实关卡。


## 待场景树可用后进行资源包加载，避免测试脚本预先解析业务类。
func _initialize() -> void:
	_run.call_deferred()


## 核心包先提供加载界面，再由所有分块补齐可操作关卡与新界面贴图。
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		_fail("Remote content directory is required.")
		return
	var boot: PackedScene = load("res://bootstrap/app.tscn")
	if boot == null:
		_fail("Loading UI cannot load before CDN resources.")
		return
	var loading: Node = boot.instantiate()
	loading.free()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game_content/donuts/delivery_manifest.json"))
	if manifest.version != 2 or manifest.packs.is_empty():
		_fail("The CDN manifest must declare its texture chunks.")
		return
	for pack: Dictionary in manifest.packs:
		for path: String in pack.paths:
			if not path.ends_with(".ctex") or FileAccess.file_exists("res://" + path):
				_fail("CDN texture is duplicated in the core pack or contains code: " + path)
				return
		if not ProjectSettings.load_resource_pack(args[0].path_join(pack.file), false):
			_fail("Remote content pack cannot mount: " + pack.file)
			return
	for path: String in [
		"res://features/donut_sort/ui/art/scene/shop_background_unified.png",
		"res://features/donut_sort/ui/art/scene/tabletop_light.png",
		"res://features/donut_sort/failure/ui/art/panel_failure_blank.png",
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
