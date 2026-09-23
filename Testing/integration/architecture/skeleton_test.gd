extends SceneTree
## 验证真实主场景装配、页面替换和独立关卡首页。


## 等待场景树建立后执行请求的检查组。
func _initialize() -> void:
	_run.call_deferred()


## 使用当前工程入口加载场景，并为每个通过的组输出完成标记。
func _run() -> void:
	var app_scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	if app_scene == null or not app_scene.can_instantiate():
		_fail("Main scene cannot instantiate.")
		return
	var app: Node = app_scene.instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	for suite in OS.get_cmdline_user_args():
		var passed: bool = false
		if suite == "architecture":
			passed = await _check_architecture(app)
		elif suite == "home":
			passed = await _check_home()
		if not passed:
			_fail("Suite failed: " + suite)
			return
		print("PASS: " + suite)
	app.queue_free()
	await process_frame
	quit(0)


## 替换内容页后验证长生命周期容器存活且旧页面已经释放。
func _check_architecture(app: Node) -> bool:
	var services: Node = app.get_node_or_null("Services")
	var container: Control = app.get_node_or_null("SceneContainer") as Control
	var overlay: CanvasLayer = app.get_node_or_null("Overlay") as CanvasLayer
	if services == null or container == null or overlay == null:
		return false
	if container.get_child_count() != 1 or not container.get_child(0) is Control:
		return false
	var original: Node = container.get_child(0)
	var next_scene: PackedScene = load(original.scene_file_path)
	if next_scene == null:
		return false
	container.remove_child(original)
	original.queue_free()
	container.add_child(next_scene.instantiate())
	await process_frame
	return is_instance_valid(app) and is_instance_valid(services) \
		and is_instance_valid(overlay) and not is_instance_valid(original) \
		and container.get_child_count() == 1 and app == current_scene


## 独立首页必须在无会话注入时显示完整棋盘和可见订单。
func _check_home() -> bool:
	var scene: PackedScene = load("res://features/home/ui/home_screen.tscn")
	if scene == null or not scene.can_instantiate():
		return false
	var page: Control = scene.instantiate() as Control
	if page == null:
		return false
	root.add_child(page)
	await process_frame
	var title: Label = page.get_node_or_null("Stage/Title") as Label
	var boxes: Control = page.get_node_or_null("Stage/Boxes") as Control
	var passed: bool = page.is_visible_in_tree() and page.theme != null \
		and page.size.x > 0 and page.size.y > 0 and title != null
	if passed:
		passed = title.is_visible_in_tree() and not title.text.is_empty() \
			and title.size.x > 0 and title.size.y > 0 and boxes != null \
			and boxes.get_child_count() == 16 and page.session.slots.size() == 16 and page.session.demands.size() == 4
	page.queue_free()
	await process_frame
	return passed


## 失败保留明确诊断并返回非零状态，避免仅凭进程退出误报成功。
func _fail(message: String) -> void:
	push_error(message)
	quit(1)
