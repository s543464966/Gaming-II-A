class_name LegacyImport
extends RefCounted
## 旧本地账号的只读预览与整目录发布；源目录和既有目标账号永不覆盖。

const Repository = preload("res://services/save/json_repository.gd")
const Account = preload("res://features/player_session/legacy_account_codec.gd")
const SaveCodec = preload("res://features/player_session/legacy_save_codec.gd")
var content: RefCounted
var error: String = ""
var warnings: Array[String] = []
var account_count: int = 0
var _source: String = ""
var _records: Array = []
var _players: Dictionary = {}
var _preferred_id: String = ""

## 导入只使用现行静态目录和保存协议。
func _init(catalog: RefCounted) -> void:
	content = catalog

## 先校验全部账号及其完整存档，任何一个失败都不发布部分账号。
func preview(directory: String) -> bool:
	error = ""
	warnings.clear()
	_records.clear()
	_players.clear()
	_preferred_id = ""
	account_count = 0
	_source = ProjectSettings.globalize_path(directory).simplify_path().trim_suffix("/")
	if not DirAccess.dir_exists_absolute(_source): return _fail("源存档目录不存在。")
	var source = Repository.new(_source)
	if source.exists("account_deletion.json"): return _fail("源目录存在未完成的删除事务，已拒绝导入。")
	var accounts = source.read("accounts.json", func(value): return Account.decode(value).error.is_empty())
	if accounts.is_empty(): return _fail("源账号表无法恢复：" + source.error)
	var decoded = Account.decode(accounts)
	if decoded.records.is_empty(): return _fail("源目录没有可导入账号。")
	for record in decoded.records:
		var codec = SaveCodec.new(content)
		var converted: Dictionary = {}
		# 转换是纯函数；主档语义失败时仓储继续检查备份。
		var saved = source.read(decoded.files[record.user_id], func(value): return not codec.convert(value, record.user_id).is_empty())
		if saved.is_empty(): return _fail("一个账号的玩家存档无法完整恢复：" + codec.error)
		converted = codec.convert(saved, record.user_id)
		_players[record.user_id] = converted
		warnings.append_array(codec.warnings)
	_records = decoded.records
	account_count = _records.size()
	if account_count == 1: _preferred_id = _records[0].user_id
	var old_session = source.read("auth_session.json")
	if not old_session.is_empty():
		for record in _records:
			if old_session.get("userId") == record.user_id and old_session.get("accountId") == record.account:
				_preferred_id = record.user_id
	return true

## 在空目标旁先写齐所有文件，再一次改名发布；失败只清理本次创建的暂存。
func publish(target: RefCounted) -> bool:
	error = ""
	if _records.is_empty() or _players.size() != _records.size(): return _fail("必须先成功预览全部源存档。")
	var destination = ProjectSettings.globalize_path(target.root).simplify_path().trim_suffix("/")
	if destination.is_empty() or destination == _source or destination.begins_with(_source + "/") or _source.begins_with(destination + "/"):
		return _fail("源与目标目录不能相同、嵌套或指向文件系统根。")
	if FileAccess.file_exists(destination) or not _empty_or_missing(destination): return _fail("目标已有内容，已拒绝覆盖；请使用空存档目录。")
	var staging = destination + ".import-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
	if DirAccess.dir_exists_absolute(staging) or FileAccess.file_exists(staging): return _fail("临时导入目录冲突。")
	var staged = Repository.new(staging)
	var names: Array = []
	for id in _players:
		var name = Repository.player_file(id)
		names.append(name)
		if not staged.write(name, _players[id]):
			_cleanup(staged, names)
			return _fail("导入暂存写入失败，目标未改变。")
	if not _preferred_id.is_empty():
		names.append("local_player.json")
		if not staged.write("local_player.json", {"schema": 1, "user_id": _preferred_id}):
			_cleanup(staged, names)
			return _fail("导入默认身份写入失败，目标未改变。")
	# 仅移除刚刚确认为空的目标目录；若其间有内容写入，删除会失败。
	if DirAccess.dir_exists_absolute(destination) and (not _empty_or_missing(destination) or DirAccess.remove_absolute(destination) != OK):
		_cleanup(staged, names)
		return _fail("目标目录在导入期间发生变化，已停止发布。")
	if DirAccess.rename_absolute(staging, destination) != OK:
		_cleanup(staged, names)
		return _fail("导入目录发布失败，原存档仍未改变。")
	return true

## 隐藏文件同样视为既有内容，不能借空目录判断覆盖其他状态。
static func _empty_or_missing(path: String) -> bool:
	if not DirAccess.dir_exists_absolute(path): return true
	var directory = DirAccess.open(path)
	if directory == null: return false
	directory.include_hidden = true
	return directory.get_files().is_empty() and directory.get_directories().is_empty()

## 只回收已知的本次暂存文件，不递归删除来源或目标目录。
static func _cleanup(staged: RefCounted, names: Array) -> void:
	for name in names: staged.erase(name)
	DirAccess.remove_absolute(staged.root)

## 命令行导入只保留必要诊断，不打印凭据或原存档内容。
func _fail(diagnostic: String) -> bool:
	error = diagnostic
	return false
