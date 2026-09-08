extends SceneTree
## 开发预览装配真实 App，并只在显式指定的空目录创建一次性本机玩家。

const APP = preload("res://bootstrap/app.tscn")

## 拒绝默认玩家目录或非空目录，不让预览接触真实进度。
func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	var directory = OS.get_environment("MAGICA_DATA_DIR")
	if args.is_empty() or not args[0] in ["home", "adventure"] or args.size() > 2 or (args.size() == 2 and args[1] != "--check"):
		_fail("用法：preview.gd -- home|adventure [--check]")
		return
	if directory.is_empty() or not DirAccess.dir_exists_absolute(directory) or not DirAccess.get_files_at(directory).is_empty() or not DirAccess.get_directories_at(directory).is_empty():
		_fail("预览必须显式设置 MAGICA_DATA_DIR 为已存在的空目录。推荐从工作区 Tooling/preview/preview.mjs 启动。")
		return
	_run.call_deferred(args[0], args.size() == 2)

## 使用实际默认玩家、存档与冒险用例，不复制业务状态或建立第二套应用根。
func _run(screen: String, check_only: bool) -> void:
	var app = APP.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	if not app.accounts.startup_error.is_empty():
		_fail(app.accounts.startup_error + "\n" + app.accounts.startup_diagnostic)
		return
	if screen == "adventure":
		var error: String = app.accounts.progression.ensure_started(int(Time.get_unix_time_from_system()))
		if not error.is_empty():
			_fail(error)
			return
		app.navigate(screen)
		await process_frame
		await process_frame
	if app.current_screen_id != screen or not is_instance_valid(app.current_screen):
		_fail("目标页面未进入可运行状态。")
		return
	print("PREVIEW READY: " + screen)
	if check_only:
		app.queue_free()
		await process_frame
		quit()

## 明确失败标记供外层编排识别，退出码零不能掩盖脚本错误。
func _fail(message: String) -> void:
	printerr("PREVIEW ERROR: " + message)
	quit(1)
