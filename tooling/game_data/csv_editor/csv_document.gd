@tool
extends RefCounted
## 单份 CSV 的原始文本模型、编辑历史、磁盘冲突检查与原位保存。

const Csv = preload("res://tooling/game_data/strict_csv.gd")
var path: String = ""
var headers: Array = []
var rows: Array = []
var error: String = ""
var conflict: bool = false
var _hash: String = ""
var _saved_rows: Array = []
var _bom: bool = false
var _newline: String = "\n"
var _trailing_newline: bool = true
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []

## 读取实际表头和字符串单元格；失败不覆盖内存中的编辑内容。
func open(file_path: String) -> bool:
	error = ""
	if not FileAccess.file_exists(file_path):
		error = "CSV 不存在：" + file_path
		return false
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		error = "CSV 无法读取：" + file_path
		return false
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	if bytes.is_empty():
		error = "CSV 不存在、无法读取或缺少表头：" + file_path
		return false
	var has_bom: bool = bytes.slice(0, 3) == PackedByteArray([239, 187, 191])
	var payload: PackedByteArray = bytes.slice(3) if has_bom else bytes
	var text: String = payload.get_string_from_utf8()
	if text.to_utf8_buffer() != payload:
		error = "CSV 必须使用 UTF-8 编码：" + file_path
		return false
	var parser = Csv.new()
	var parsed: Array = parser.parse(text, file_path, true)
	if not parser.errors.is_empty() or parsed.is_empty():
		error = "\n".join(parser.errors) if not parser.errors.is_empty() else "CSV 缺少表头。"
		return false
	var next_headers: Array = parsed.pop_front()
	for index in range(parsed.size()):
		if parsed[index].size() != next_headers.size():
			error = "第 %d 条记录的列数与表头不一致。" % (index + 1)
			return false
	path = file_path
	headers = next_headers
	rows = parsed
	_saved_rows = rows.duplicate(true)
	_hash = _fingerprint(bytes)
	_bom = has_bom
	_newline = _record_newline(text)
	_trailing_newline = text.ends_with("\n") or text.ends_with("\r")
	conflict = false
	_undo.clear()
	_redo.clear()
	return true

## 只比较编辑数据，不把视图排序或筛选视为文件修改。
func is_dirty() -> bool:
	return rows != _saved_rows

## 比较读取时的文件指纹，外部删除或替换均视为冲突。
func check_external_change() -> bool:
	conflict = not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != _hash
	return conflict

## 全部值原样保留为字符串；详情连续输入可合并为一次撤销。
func set_cell(row: int, column: int, value: String, merge: bool = false) -> void:
	if row < 0 or row >= rows.size() or column < 0 or column >= headers.size() or rows[row][column] == value: return
	var action: Dictionary = {"kind": "cell", "row": row, "column": column, "before": rows[row][column], "after": value}
	if merge and _redo.is_empty() and not _undo.is_empty() and _undo.back().kind == "cell" and _undo.back().row == row and _undo.back().column == column:
		_undo.back().after = value
	else:
		_record(action)
	_redo.clear()
	rows[row][column] = value

## 在原始行序中插入空行或所选行副本，不自动生成 ID 或填默认值。
func insert_row(index: int, values: Array = []) -> void:
	var row: Array = values.duplicate()
	if row.is_empty():
		for _column in headers: row.append("")
	if row.size() != headers.size(): return
	index = clampi(index, 0, rows.size())
	_record({"kind": "insert", "row": index, "values": row.duplicate()})
	rows.insert(index, row)

## 删除只作用当前表，关联记录由现有数据同步校验报告。
func remove_row(index: int) -> void:
	if index < 0 or index >= rows.size(): return
	_record({"kind": "remove", "row": index, "values": rows[index].duplicate()})
	rows.remove_at(index)

## 返回当前文档是否还有可撤销操作。
func can_undo() -> bool:
	return not _undo.is_empty()

## 返回当前文档是否还有可重做操作。
func can_redo() -> bool:
	return not _redo.is_empty()

## 撤销最近一次数据修改，不触碰磁盘文件。
func undo() -> void:
	if _undo.is_empty(): return
	var action: Dictionary = _undo.pop_back()
	_apply(action, false)
	_redo.append(action)

## 重做最近一次撤销的数据修改。
func redo() -> void:
	if _redo.is_empty(): return
	var action: Dictionary = _redo.pop_back()
	_apply(action, true)
	_undo.append(action)

## 返回筛选后的原始行号；排序仅改变视图索引。
func visible_rows(query: String, column: int = -1, ascending: bool = true) -> Array[int]:
	var result: Array[int] = []
	for index in range(rows.size()):
		if query.is_empty() or rows[index].any(func(value: String) -> bool: return value.to_lower().contains(query.to_lower())): result.append(index)
	if column >= 0 and column < headers.size():
		result.sort_custom(func(a: int, b: int) -> bool:
			var compared: int = str(rows[a][column]).naturalnocasecmp_to(str(rows[b][column]))
			return a < b if compared == 0 else (compared < 0 if ascending else compared > 0))
	return result

## 将原始文本编码为合法 CSV，保持空值、嵌入换行及文件换行习惯。
func encode() -> PackedByteArray:
	var lines: PackedStringArray = []
	for row: Array in [headers] + rows:
		var fields: PackedStringArray = []
		for value: String in row:
			var quoted: bool = value.contains(",") or value.contains('"') or value.contains("\r") or value.contains("\n") or (row.size() == 1 and value.is_empty())
			fields.append('"' + value.replace('"', '""') + '"' if quoted else value)
		lines.append(",".join(fields))
	return (("\ufeff" if _bom else "") + _newline.join(lines) + (_newline if _trailing_newline else "")).to_utf8_buffer()

## 原位替换当前文件；外部冲突或写入失败时保留旧文件和内存修改。
func save() -> bool:
	error = ""
	if check_external_change():
		error = "文件已被外部修改或删除，请先重新载入：" + path
		return false
	if not is_dirty(): return true
	var parent: DirAccess = DirAccess.open(path.get_base_dir())
	if parent == null or parent.is_link(path.get_file()):
		error = "CSV 必须是可写的实际文件：" + path
		return false
	if OS.get_name() in ["macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD"] and (FileAccess.get_unix_permissions(path) & (FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_WRITE_GROUP | FileAccess.UNIX_WRITE_OTHER)) == 0:
		error = "CSV 已设为只读，未覆盖原文件：" + path
		return false
	var pending: String = path.get_base_dir().path_join(".magica-csv-%d-%d.tmp" % [OS.get_process_id(), Time.get_ticks_usec()])
	var file: FileAccess = FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		error = "无法写入 CSV 所在目录：" + path
		return false
	var bytes: PackedByteArray = encode()
	file.store_buffer(bytes)
	file.flush()
	var success: bool = file.get_error() == OK
	file.close()
	if success: success = FileAccess.get_file_as_bytes(pending) == bytes and not check_external_change()
	if success and OS.get_name() in ["macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD"]:
		success = FileAccess.set_unix_permissions(pending, FileAccess.get_unix_permissions(path)) == OK
	if success: success = DirAccess.rename_absolute(pending, path) == OK
	if not success:
		DirAccess.remove_absolute(pending)
		error = "CSV 保存失败或文件发生外部变化，原文件未替换：" + path
		return false
	_hash = _fingerprint(bytes)
	_saved_rows = rows.duplicate(true)
	_undo.clear()
	_redo.clear()
	conflict = false
	return true

## 指纹来自同一次实际读取或写入的字节，避免二次读盘掩盖外部变更。
static func _fingerprint(bytes: PackedByteArray) -> String:
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()

## 仅使用引号外的首个记录分隔符，不误认单元格内部换行。
static func _record_newline(text: String) -> String:
	var quoted: bool = false
	var index: int = 0
	while index < text.length():
		if text[index] == '"':
			if quoted and index + 1 < text.length() and text[index + 1] == '"': index += 1
			else: quoted = not quoted
		elif not quoted:
			if text[index] == "\r": return "\r\n" if index + 1 < text.length() and text[index + 1] == "\n" else "\r"
			if text[index] == "\n": return "\n"
		index += 1
	return "\n"

## 枚举实际目录中的 CSV，不依赖游戏 Schema，也不跟随符号链接。
static func discover(root: String) -> Array[String]:
	var result: Array[String] = []
	var directory: DirAccess = DirAccess.open(root)
	if directory == null: return result
	for name in directory.get_files():
		if name.get_extension().to_lower() == "csv" and not directory.is_link(name): result.append(root.path_join(name))
	for name in directory.get_directories():
		if not name.begins_with(".") and not directory.is_link(name): result.append_array(discover(root.path_join(name)))
	result.sort()
	return result

## 历史仅记录变更量并限制深度，不复制整个数据集。
func _record(action: Dictionary) -> void:
	_undo.append(action)
	if _undo.size() > 200: _undo.pop_front()
	_redo.clear()

## 按方向应用单元格或行操作，供撤销与重做共用。
func _apply(action: Dictionary, forward: bool) -> void:
	if action.kind == "cell": rows[action.row][action.column] = action.after if forward else action.before
	elif (action.kind == "insert") == forward: rows.insert(action.row, action.values.duplicate())
	else: rows.remove_at(action.row)
