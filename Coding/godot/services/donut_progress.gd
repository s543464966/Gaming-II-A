class_name DonutProgress
extends Node
## 在新项目专用文件保存当前局与教学记录，不读取或迁移任何旧账号数据。

const SAVE_PATH: String = "user://sweet_sort_100_v1.json"
var seen: Dictionary = {}
var completed: Dictionary = {}
var _session: DonutSession
var _path: String = SAVE_PATH
var _enabled: bool = true
var _elapsed: float = 0.0


## 显式绑定会话；隔离测试可关闭磁盘读写或指定测试路径。
func initialize(session: DonutSession, enabled: bool = true, path: String = SAVE_PATH) -> void:
	_session = session
	_enabled = enabled
	_path = path
	if enabled and FileAccess.file_exists(_path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))
		if data is Dictionary and int(data.get("version", 0)) == 1:
			seen = data.get("seen", {}) if data.get("seen") is Dictionary else {}
			completed = data.get("completed", {}) if data.get("completed") is Dictionary else {}
			if data.get("run") is Dictionary:
				session.restore_run(data.run)
	session.changed.connect(_changed)


## 每两秒保存计时进展，页面失焦时另行立即保存。
func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 2.0:
		_elapsed = 0.0
		save()


## 记录完成关与已提交局面，不等待展示动画。
func _changed(_events: Array) -> void:
	if _session.is_won():
		completed[str(_session.level_index + 1)] = true
	save()


## 原子替换专用存档；失败保留原文件并在诊断中报告。
func save() -> void:
	if not _enabled or _session == null or not _session.started:
		return
	var file: FileAccess = FileAccess.open(_path + ".tmp", FileAccess.WRITE)
	if file == null:
		push_warning("Cannot write local donut progress")
		return
	file.store_string(JSON.stringify({"version": 1, "seen": seen, "completed": completed, "run": _session.export_run()}))
	file.close()
	var result: Error = DirAccess.rename_absolute(_path + ".tmp", _path)
	if result != OK:
		push_warning("Cannot replace local donut progress: %s" % result)


## 应用失焦或退出前持久化已经结算的状态。
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_EXIT_TREE]:
		save()
