class_name JsonRepository
extends RefCounted
## 原子 JSON 仓储；主文件损坏时读取上一份成功写入的备份。

var root: String
var error: String = ""
var recovered_from_backup: bool = false
var _preserve_backup: Dictionary = {}
const Format = preload("res://game_content/runtime/snapshot_format.gd")

## 根路径由启动或导入入口明确提供，实例化本身不创建目录。
func _init(directory: String = "user://MagicA") -> void:
	root = directory.trim_suffix("/")

## 用户 ID 只用于稳定散列文件名，避免账号输入成为路径。
static func player_file(user_id: String) -> String:
	return "player_" + user_id.sha256_text().left(24) + ".json"

## 依次校验主文件和备份；业务 Owner 可注入完整 Schema 与归属检查。
func read(name: String, validator: Callable = Callable()) -> Dictionary:
	error = ""
	recovered_from_backup = false
	if not _safe(name):
		error = "非法存档文件名。"
		return {}
	var failures: Array = []
	for path in [_path(name), _path(name + ".bak")]:
		if not FileAccess.file_exists(path):
			failures.append(path + " 不存在")
			continue
		var value: Variant = _read_object(path)
		if value is Dictionary:
			Format.normalize_numbers(value)
			if not validator.is_valid() or validator.call(value):
				recovered_from_backup = path == _path(name + ".bak")
				if recovered_from_backup: _preserve_backup[name] = true
				return value
			failures.append(path + " 未通过存档完整性检查")
		else: failures.append(path + " 不是有效 JSON 对象")
	error = "；".join(failures)
	return {}

## 区分首次账号与已存在但损坏的文件，不能把损坏存档当作新账号覆盖。
func exists(name: String) -> bool:
	return _safe(name) and (FileAccess.file_exists(_path(name)) or FileAccess.file_exists(_path(name + ".bak")))

## 临时文件落盘后原子替换；恢复过备份时绝不把损坏主文件覆盖到备份。
func write(name: String, value: Dictionary) -> bool:
	error = ""
	if not _safe(name):
		error = "非法存档文件名。"
		return false
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root)) != OK:
		error = "无法创建存档目录。"
		return false
	var primary = _path(name)
	var temporary = _path(name + ".tmp")
	var backup = _path(name + ".bak")
	var backup_next = _path(name + ".bak.tmp")
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		error = "无法打开存档临时文件。"
		return false
	file.store_string(JSON.stringify(value, "  ", true, true) + "\n")
	file.flush()
	var result = file.get_error()
	file.close()
	if result != OK:
		DirAccess.remove_absolute(temporary)
		error = "存档临时文件写入失败。"
		return false
	if FileAccess.file_exists(primary) and not _preserve_backup.has(name):
		# 未经读取的写入仍不能把语法损坏的主文件轮换成恢复点。
		var previous: Variant = _read_object(primary)
		if previous is Dictionary:
			if DirAccess.copy_absolute(primary, backup_next) != OK or DirAccess.rename_absolute(backup_next, backup) != OK:
				DirAccess.remove_absolute(temporary)
				if FileAccess.file_exists(backup_next): DirAccess.remove_absolute(backup_next)
				error = "无法建立存档备份，原文件未改变。"
				return false
	if DirAccess.rename_absolute(temporary, primary) != OK:
		if FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
		error = "无法发布存档，原文件与备份仍保留。"
		return false
	_preserve_backup.erase(name)
	return true

## 删除明确的主文件、备份和未完成临时文件。
func erase(name: String) -> bool:
	error = ""
	if not _safe(name): return false
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var path = _path(name + suffix)
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
			error = "无法删除: " + path
			return false
	_preserve_backup.erase(name)
	return true

## 文件名不能包含目录或特殊路径片段。
static func _safe(name: String) -> bool:
	return not name.is_empty() and name == name.get_file() and name not in [".", ".."]

## 损坏文件是可恢复的输入，不使用会额外打印引擎错误的快捷解析入口。
static func _read_object(path: String) -> Variant:
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return null
	return parser.data

## 将虚拟路径统一转换成绝对路径供原子改名。
func _path(name: String) -> String:
	return ProjectSettings.globalize_path(root.path_join(name))
