extends RefCounted
## 只读校验本次 Godot 4.5.1 导出包，供 CDN 拆包时提取原始条目。

var _file: FileAccess
var _entries: Dictionary = {}


## 检查目录边界、路径和每项 MD5，不从工程源码补齐缺失条目。
func open(path: String) -> Error:
	_entries.clear()
	_file = FileAccess.open(path, FileAccess.READ)
	if _file == null or _file.get_length() < 112 or _file.get_32() != 0x43504447:
		return _invalid()
	var version: int = _file.get_32()
	if version != 3 or [_file.get_32(), _file.get_32(), _file.get_32()] != [4, 5, 1]:
		return _invalid()
	if _file.get_32() & ~2:
		return _invalid()
	var base: int = _file.get_64()
	var directory: int = _file.get_64()
	if base < 0 or base > _file.get_length() or directory < 96 or directory > _file.get_length() - 4:
		return _invalid()
	_file.seek(directory)
	var count: int = _file.get_32()
	if count < 1 or count > 100000:
		return _invalid()
	for _index: int in count:
		if _file.get_position() + 4 > _file.get_length():
			return _invalid()
		var length: int = _file.get_32()
		if length < 1 or length > 4096 or _file.get_position() + length + 36 > _file.get_length():
			return _invalid()
		var raw: PackedByteArray = _file.get_buffer(length)
		var zero: int = raw.find(0)
		if zero >= 0:
			raw = raw.slice(0, zero)
		var name: String = raw.get_string_from_utf8().trim_prefix("res://")
		if name.is_empty() or name.begins_with("/") or name.contains(":") or name.contains("\\") or name.split("/").has("..") or name.simplify_path() != name or _entries.has(name):
			return _invalid()
		var offset: int = _file.get_64() + base
		var size: int = _file.get_64()
		var digest: String = _file.get_buffer(16).hex_encode()
		if _file.get_32() != 0 or offset < base or size < 0 or size > _file.get_length() - offset:
			return _invalid()
		_entries[name] = {"offset": offset, "size": size, "md5": digest}
	for name: String in _entries:
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_MD5)
		hashing.update(read_file(name))
		if hashing.finish().hex_encode() != _entries[name].md5:
			return _invalid()
	return OK


## 返回原包的实际条目列表，不枚举工程目录。
func get_files() -> PackedStringArray:
	return PackedStringArray(_entries.keys())


## 按已校验偏移读取单个条目的原始字节。
func read_file(name: String) -> PackedByteArray:
	if _file == null or not _entries.has(name):
		return PackedByteArray()
	_file.seek(_entries[name].offset)
	return _file.get_buffer(_entries[name].size)


## 释放输入句柄，防止拆包结束后仍占用旧制品。
func close() -> void:
	_file = null


## 损坏或不支持的文件一律拒绝，不尝试修复。
func _invalid() -> Error:
	close()
	_entries.clear()
	return ERR_FILE_CORRUPT
