@tool
extends EditorPlugin
## CSV 主屏幕与工作区同步命令的连接层，不解释任何游戏数据。

const PanelScene = preload("res://tooling/game_data/csv_editor/csv_panel.tscn")
const NODE_SETTING: String = "magica/csv_editor/node_executable"
var _panel: Control
var _poll: Timer
var _pid: int = -1
var _report: String = ""
var _workspace: String = ""
var _last_step: String = ""
var _exit_observed: bool = false

## 将通用表格挂到主屏幕，路径配置只存在于此连接层。
func _enter_tree() -> void:
	_workspace = ProjectSettings.globalize_path("res://../..").simplify_path()
	_panel = PanelScene.instantiate()
	EditorInterface.get_editor_main_screen().add_child(_panel)
	_panel.hide()
	_panel.setup(_workspace.path_join("Archive/GameDesignData"))
	_panel.sync_requested.connect(_start_sync)
	_poll = _panel.get_node("Poll")
	_poll.timeout.connect(_poll_sync)
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if not settings.has_setting(NODE_SETTING): settings.set_setting(NODE_SETTING, "")
	settings.add_property_info({"name": NODE_SETTING, "type": TYPE_STRING, "hint": PROPERTY_HINT_GLOBAL_FILE, "hint_string": ""})

## 禁用时释放界面；已经启动的同步进程独立完成，不中途终止发布。
func _exit_tree() -> void:
	if is_instance_valid(_panel):
		_panel.get_parent().remove_child(_panel)
		_panel.queue_free()
	_panel = null
	_poll = null

## 插件以顶部主屏幕标签呈现，不混入业务场景。
func _has_main_screen() -> bool:
	return true

## 返回顶部标签的固定工具名称。
func _get_plugin_name() -> String:
	return "CSV 数据"

## 复用编辑器内置文档图标。
func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_base_control().get_theme_icon("File", "EditorIcons")

## 再次进入时重新发现实际文件与列，不缓存游戏 Schema。
func _make_visible(visible: bool) -> void:
	if not is_instance_valid(_panel): return
	_panel.visible = visible
	if visible: _panel.refresh()

## 退出项目时由 Godot 显示未保存提示，不影响单个业务场景关闭。
func _get_unsaved_status(for_scene: String) -> String:
	if not for_scene.is_empty() or not is_instance_valid(_panel): return ""
	var paths: Array[String] = _panel.dirty_paths()
	return "CSV 数据有 %d 份文件未保存。" % paths.size() if not paths.is_empty() else ""

## 编辑器明确保存外部数据时复用同一保存入口；无修改不启动同步。
func _save_external_data() -> void:
	if is_instance_valid(_panel) and not _panel.dirty_paths().is_empty(): _panel.save_documents(true)

## 异步启动已有命令，CSV 保存不依赖游戏 Schema 校验成功。
func _start_sync() -> void:
	if _pid > 0: return
	var node: String = _find_node()
	var command: String = _workspace.path_join("Tooling/data/data.mjs")
	if node.is_empty() or not FileAccess.file_exists(command):
		_panel.set_sync_state(false, "CSV 保持已保存状态；同步未启动。请检查工作区 Tooling/data/data.mjs 和 Node.js；可在编辑器设置中指定 magica/csv_editor/node_executable。", "", true)
		return
	var directory: String = _workspace.path_join("Tooling/.runtime")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		_panel.set_sync_state(false, "CSV 保持已保存状态；无法创建同步诊断目录。", "", true)
		return
	_report = directory.path_join("csv-editor-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()])
	_last_step = ""
	_exit_observed = false
	_pid = OS.create_process(node, [command, "--report", _report])
	if _pid < 0:
		_panel.set_sync_state(false, "CSV 保持已保存状态；无法启动 Node.js 同步进程。", "", true)
		return
	_panel.set_sync_state(true, "正在同步磁盘 CSV（preview → sync → validate）…")
	_poll.start()

## 读取现有命令的阶段报告，不在插件中复制同步或校验逻辑。
func _poll_sync() -> void:
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(_report)) if FileAccess.file_exists(_report) else null
	if report is Dictionary:
		var state: String = str(report.get("state", ""))
		if state in ["success", "failed"]:
			_poll.stop()
			_pid = -1
			var failed: bool = state == "failed"
			_panel.set_sync_state(false, "磁盘 CSV 的游戏数据同步失败；已保存的 CSV 不会撤回。" if failed else "游戏数据同步完成。重启游戏或等待监听预览重启后生效；未保存的修改未参与同步。", str(report.get("log", "")), failed)
			if not failed: DirAccess.remove_absolute(_report)
			return
		var step: String = str(report.get("step", ""))
		if step != _last_step:
			_last_step = step
			_panel.set_status("正在同步磁盘 CSV：%s…" % step)
	if _pid > 0 and not OS.is_process_running(_pid):
		if not _exit_observed:
			_exit_observed = true
			return
		_poll.stop()
		_pid = -1
		_panel.set_sync_state(false, "CSV 保持已保存状态；同步进程退出但没有完成报告。请重试同步。", "诊断报告：" + _report, true)

## 支持编辑器设置覆盖，其余从常见安装位置及 PATH 查找 Node。
func _find_node() -> String:
	var configured: String = str(EditorInterface.get_editor_settings().get_setting(NODE_SETTING)).strip_edges()
	if not configured.is_empty(): return configured if FileAccess.file_exists(configured) else ""
	var candidates: Array[String] = ["/usr/local/bin/node", "/opt/homebrew/bin/node", "/usr/bin/node"]
	var executable: String = "node.exe" if OS.get_name() == "Windows" else "node"
	var separator: String = ";" if OS.get_name() == "Windows" else ":"
	for directory: String in OS.get_environment("PATH").split(separator): candidates.append(directory.path_join(executable))
	for candidate: String in candidates:
		if FileAccess.file_exists(candidate): return candidate
	return ""
