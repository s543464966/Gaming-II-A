extends RefCounted
## 只读检查 Godot 4.5.1 独立、未加密 PCK；不挂载到工程，避免本地文件掩盖缺失资源。

var _file: FileAccess
var _entries: Dictionary = {}

## 按固定引擎的 V2/V3 目录结构校验边界、重复路径与每项 MD5。
func open(path: String) -> Error:
	_entries.clear()
	_file = FileAccess.open(path, FileAccess.READ)
	if _file == null: return ERR_FILE_CANT_OPEN
	if _file.get_length() < 100 or _file.get_32() != 0x43504447: return _invalid()
	var version = _file.get_32()
	if not version in [2, 3]: return _invalid()
	if [_file.get_32(), _file.get_32(), _file.get_32()] != [4, 5, 1]: return _invalid()
	var flags = _file.get_32()
	if flags & ~2: return _invalid()
	var base = _file.get_64()
	var directory = _file.get_64() if version == 3 else 96
	if base < 0 or base > _file.get_length() or directory < 96 or directory > _file.get_length() - 4: return _invalid()
	_file.seek(directory)
	var count = _file.get_32()
	if count < 1 or count > 100000: return _invalid()
	for index in count:
		if _file.get_position() + 4 > _file.get_length(): return _invalid()
		var length = _file.get_32()
		if length < 1 or length > 4096 or _file.get_position() + length + 36 > _file.get_length(): return _invalid()
		var bytes = _file.get_buffer(length)
		var zero = bytes.find(0)
		if zero >= 0: bytes = bytes.slice(0, zero)
		var name = bytes.get_string_from_utf8().trim_prefix("res://")
		if name.is_empty() or name.begins_with("/") or name.contains(":") or name.contains("\\") or name.split("/").has("..") or name.simplify_path() != name or _entries.has(name): return _invalid()
		var offset = _file.get_64() + base
		var size = _file.get_64()
		var md5 = _file.get_buffer(16).hex_encode()
		if _file.get_32() != 0 or offset < base or size < 0 or size > _file.get_length() - offset: return _invalid()
		_entries[name] = {"offset": offset, "size": size, "md5": md5}
	for name in _entries:
		var hashing = HashingContext.new()
		hashing.start(HashingContext.HASH_MD5)
		hashing.update(read_file(name))
		if hashing.finish().hex_encode() != _entries[name].md5: return _invalid()
	return OK

## 列举真实包目录，未导出的工程文件不会出现在结果中。
func get_files() -> PackedStringArray:
	return PackedStringArray(_entries.keys())

## 返回独立的容器位置描述，供体积审计识别共用载荷，不允许调用方改写目录。
func get_entry_info(path: String) -> Dictionary:
	return _entries.get(path, {}).duplicate()

## 仅从已校验目录的明确区间读取，不回退到 res:// 文件系统。
func read_file(path: String) -> PackedByteArray:
	if _file == null or not _entries.has(path): return PackedByteArray()
	_file.seek(_entries[path].offset)
	return _file.get_buffer(_entries[path].size)

## 单次验证结束后释放文件句柄。
func close() -> void:
	_file = null

## 任何不支持或损坏的结构均关闭并拒绝，不尝试修复制品。
func _invalid() -> Error:
	close()
	_entries.clear()
	return ERR_FILE_CORRUPT
