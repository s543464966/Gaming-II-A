extends SceneTree
## 用隔离缓存验证 CDN 服务校验、挂载与随后加载关卡的顺序。

const Delivery = preload("res://services/content_delivery.gd")


## 等待场景树就绪后读取核心包内的交付清单。
func _initialize() -> void:
	_run.call_deferred()


## 预置同批摘要包模拟缓存命中，不访问真实用户数据或测试 URL。
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		_fail("CDN delivery test needs a remote pack and isolated cache directory.")
		return
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(Delivery.MANIFEST_PATH))
	if not document is Dictionary or DirAccess.make_dir_recursive_absolute(args[1]) != OK:
		_fail("CDN manifest or isolated cache is invalid.")
		return
	var destination: String = args[1].path_join(document.sha256 + ".pck")
	if DirAccess.copy_absolute(args[0], destination) != OK:
		_fail("Cannot seed the isolated CDN cache.")
		return
	var service: Node = Delivery.new()
	root.add_child(service)
	if not await service.prepare(args[1]):
		_fail("Cached CDN resource cannot mount: " + service.error)
		return
	var scene: PackedScene = load("res://features/home/ui/home_screen.tscn")
	if scene == null:
		_fail("Home scene cannot load after CDN cache mount.")
		return
	var page: Control = scene.instantiate()
	root.add_child(page)
	await process_frame
	var board: Node = page.get_node_or_null("Stage/Boxes")
	if board == null or board.get("boxes").size() != 17:
		_fail("CDN mount did not restore the first level.")
		return
	page.queue_free()
	service.queue_free()
	await process_frame
	print("PASS: minigame CDN cached delivery")
	quit(0)


## 失败返回非零退出码，避免缓存命中但页面缺资源时误报通过。
func _fail(message: String) -> void:
	push_error(message)
	quit(1)
