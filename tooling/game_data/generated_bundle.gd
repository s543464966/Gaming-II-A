extends RefCounted
## 同一次发布拥有快照与各语言文件；预写全部候选，失败回滚已替换文件。

const Translations = preload("res://tooling/localization/translation_builder.gd")
var error: String = ""

## 隔离路径只改变输出根，业务和文本始终以同一份候选构建。
func prepare(document: Dictionary, translation_files: Dictionary, snapshot_name: String) -> Dictionary:
	var result = translation_files.duplicate()
	result[snapshot_name] = SnapshotFormat.finalize(document).to_utf8_buffer()
	var checksums: Dictionary = {}
	for path in result: checksums[path] = Translations._hash(result[path])
	result["bundle.json"] = (JSON.stringify({"version": 1, "files": checksums}, "  ", true) + "\n").to_utf8_buffer()
	return result

## 所有文件均须与本次候选一致，新增文件或内容变化不能被旧缓存掩盖。
func matches(root: String, files: Dictionary) -> bool:
	for path in files:
		if not FileAccess.file_exists(root.path_join(path)) or FileAccess.get_file_as_bytes(root.path_join(path)) != files[path]: return false
	return true

## 只处理声明的生成文件；保留未知文件，绝不递归清理调用方目录。
func publish(root: String, files: Dictionary) -> bool:
	error = ""
	root = ProjectSettings.globalize_path(root)
	var paths = files.keys()
	paths.erase("bundle.json")
	paths.append("bundle.json")
	var previous: Dictionary = {}
	var written: Array[String] = []
	for relative in paths:
		var path = root.path_join(relative)
		if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK or not _write(path + ".pending", files[relative]):
			error = "无法预写完整生成候选，原文件未改变。"
			_clean_pending(root, paths)
			return false
		previous[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	for relative in paths:
		var path = root.path_join(relative)
		if DirAccess.rename_absolute(path + ".pending", path) != OK:
			error = "生成发布失败，正在还原原文件。"
			for changed in written:
				if previous[changed] == null: DirAccess.remove_absolute(changed)
				elif not _write(changed + ".pending", previous[changed]) or DirAccess.rename_absolute(changed + ".pending", changed) != OK: error += " 无法还原: " + changed
			_clean_pending(root, paths)
			return false
		written.append(path)
	return true

## 落盘检查写入错误，不把成功打开文件误当成成功发布。
static func _write(path: String, bytes: PackedByteArray) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(bytes)
	file.flush()
	var result = file.get_error() == OK
	file.close()
	return result

## 只删除本次精确列出的临时文件，不扫描或删除其他用户内容。
static func _clean_pending(root: String, paths: Array) -> void:
	for relative in paths:
		var path = root.path_join(relative) + ".pending"
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
