extends SceneTree
## 从同次实际导出包拆出登记贴图；核心保留全部代码和导入映射，外部包仅含校验过的纹理载荷。

const Reader = preload("res://tooling/export/pck_reader.gd")
const Manifest = preload("res://game_content/runtime/delivery_manifest.gd")
const Deduplicate = preload("res://tooling/export/pck_deduplicate.gd")
const TARGET_BYTES: int = 1024 * 1024

## 只写新的隔离候选目录，不移动或修改源素材；调用方决定何时交付完整制品。
static func build(source: String, output: String, target: String, base_url: String) -> Dictionary:
	if not target in ["douyin", "wechat"] or not Manifest.valid_base_url(base_url): return {"error": "必须提供小游戏平台及真实 HTTPS 资源目录地址。"}
	if DirAccess.dir_exists_absolute(output): return {"error": "拆包候选目录已经存在。"}
	var archive = ZIPReader.new() if source.ends_with(".zip") else Reader.new()
	if archive.open(source) != OK: return {"error": "完整资源包无法读取。"}
	var registry_bytes: PackedByteArray = archive.read_file("game_content/asset_registry.json")
	var registry: Variant = JSON.parse_string(registry_bytes.get_string_from_utf8())
	if not registry is Dictionary: return {"error": "资源登记表损坏。"}
	var protected: Dictionary = {}
	_protected_images("res://", protected)
	var selected: Dictionary = {}
	var keys: Array = registry.keys()
	keys.sort()
	for key: String in keys:
		var entry: Dictionary = registry[key]
		var path: String = entry.path
		if entry.kind != "Texture" or not path.begins_with("res://game_content/") or not path.ends_with(".png") or protected.has(path): continue
		var config := ConfigFile.new()
		if config.parse(archive.read_file(path.trim_prefix("res://") + ".import").get_string_from_utf8()) != OK: return {"error": "导入映射不存在: " + path}
		var imported: String = str(config.get_value("remap", "path", "")).trim_prefix("res://")
		if not imported in archive.get_files() or not imported.ends_with(".ctex"): return {"error": "不支持的贴图导入变体: " + path}
		if not selected.has(imported): selected[imported] = {"keys": [], "bytes": archive.read_file(imported)}
		selected[imported].keys.append(key)
	if selected.is_empty(): return {"error": "未找到可安全延迟的登记贴图。"}
	if DirAccess.make_dir_recursive_absolute(output.path_join("remote")) != OK: return {"error": "无法创建拆包输出目录。"}
	var document: Dictionary = {"version": 1, "engine": "4.5.1", "target": target, "base_url": base_url,
		"registry_sha256": _hash(registry_bytes), "packs": {}, "assets": {}}
	var group: Dictionary = {}
	var size: int = 0
	for path: String in selected:
		var entry: Dictionary = selected[path]
		if entry.bytes.size() > TARGET_BYTES: return {"error": "单张延迟贴图超过 1 MiB，需先评估分辨率: " + path}
		if size + entry.bytes.size() > TARGET_BYTES:
			var message: String = _write_group(output, group, document, registry)
			if not message.is_empty(): return {"error": message}
			group = {}; size = 0
		group[path] = entry
		size += entry.bytes.size()
	if not group.is_empty():
		var message: String = _write_group(output, group, document, registry)
		if not message.is_empty(): return {"error": message}
	var manifest := Manifest.new()
	if not manifest.parse(document, registry, _hash(registry_bytes)): return {"error": manifest.error}
	var core := PCKPacker.new()
	var raw: String = output.path_join("core.raw.pck")
	if core.pck_start(raw) != OK: return {"error": "无法创建核心包。"}
	var paths: PackedStringArray = archive.get_files()
	paths.append(Manifest.PATH.trim_prefix("res://"))
	for path: String in paths:
		if selected.has(path): continue
		var bytes: PackedByteArray = (JSON.stringify(document, "  ", true) + "\n").to_utf8_buffer() if path == Manifest.PATH.trim_prefix("res://") else archive.read_file(path)
		var temporary: String = output.path_join("entries").path_join(path)
		if not _write(temporary, bytes) or core.add_file("res://" + path, temporary) != OK: return {"error": "核心条目写入失败: " + path}
	archive.close()
	if core.flush() != OK: return {"error": "核心包提交失败。"}
	var optimization: Dictionary = Deduplicate.optimize(raw, output.path_join("core.pck"))
	if optimization.has("error"): return optimization
	# 再比较实际核心和资源 ZIP 的并集，不能仅依据拆分计划宣称资源完整。
	var verifier = Reader.new()
	if verifier.open(output.path_join("core.pck")) != OK: return {"error": "核心包校验失败。"}
	if archive.open(source) != OK: return {"error": "完整包重新读取失败。"}
	for path: String in archive.get_files():
		if selected.has(path):
			if path in verifier.get_files(): return {"error": "核心包仍包含延迟载荷。"}
		elif verifier.read_file(path) != archive.read_file(path): return {"error": "核心包改变了原资源: " + path}
	verifier.close(); archive.close()
	if not _write(output.path_join("manifest.json"), (JSON.stringify(document, "  ", true) + "\n").to_utf8_buffer()): return {"error": "清单写入失败。"}
	return {"manifest": document, "core_bytes": optimization.output_bytes, "inventory": optimization.inventory, "deferred_textures": selected.size()}

## 所有静态源码及资源直连的图片留在核心包，防止导入器或 preload 提前读取缺失纹理。
static func _protected_images(directory: String, result: Dictionary) -> void:
	for child: String in DirAccess.get_directories_at(directory):
		if child.begins_with(".") or child in ["tooling", "exports"]: continue
		_protected_images(directory.path_join(child), result)
	var pattern := RegEx.new()
	pattern.compile("res://[^\\\"'\\s]+\\.png")
	for file: String in DirAccess.get_files_at(directory):
		if not file.get_extension() in ["gd", "tscn", "tres"]: continue
		for match_value: RegExMatch in pattern.search_all(FileAccess.get_file_as_string(directory.path_join(file))): result[match_value.get_string()] = true

## 每组只包含 ctex，文件名取实际 ZIP 摘要，重复构建可按字节复用远端与本地缓存。
static func _write_group(output: String, group: Dictionary, document: Dictionary, registry: Dictionary) -> String:
	var path: String = output.path_join("candidate.zip")
	var zip := ZIPPacker.new()
	if zip.open(path) != OK: return "无法创建纹理包。"
	var files: Dictionary = {}
	for name: String in group:
		var bytes: PackedByteArray = group[name].bytes
		if zip.start_file(name) != OK or zip.write_file(bytes) != OK or zip.close_file() != OK: zip.close(); return "纹理包写入失败。"
		files[name] = {"bytes": bytes.size(), "sha256": _hash(bytes)}
	if zip.close() != OK: return "纹理包提交失败。"
	if not _freeze_zip_times(path): return "纹理包时间戳规范化失败。"
	var id: String = FileAccess.get_sha256(path)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var check := ZIPReader.new()
	if check.open(path) != OK: return "纹理包无法重新读取。"
	for name: String in group:
		if check.read_file(name) != group[name].bytes: check.close(); return "纹理包原始字节不一致。"
	check.close()
	if DirAccess.rename_absolute(path, output.path_join("remote").path_join(id + ".zip")) != OK: return "纹理包命名失败。"
	document.packs[id] = {"bytes": bytes.size(), "files": files}
	for name: String in group:
		for key: String in group[name].keys: document.assets[key] = {"path": registry[key].path, "pack": id, "file": name}
	return ""

## 固定本工具刚生成的小型 ZIP 时间戳，避免相同资源因构建时间不同失去缓存身份。
static func _freeze_zip_times(path: String) -> bool:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 22 or bytes.size() > Manifest.MAX_PACK_BYTES: return false
	var end: int = bytes.size() - 22
	if bytes.decode_u32(end) != 0x06054b50 or bytes.decode_u16(end + 20) != 0: return false
	if bytes.decode_u32(end + 4) != 0 or bytes.decode_u16(end + 8) != bytes.decode_u16(end + 10): return false
	var cursor: int = bytes.decode_u32(end + 16)
	if cursor + bytes.decode_u32(end + 12) != end: return false
	for _index: int in bytes.decode_u16(end + 10):
		if cursor + 46 > end or bytes.decode_u32(cursor) != 0x02014b50: return false
		var local: int = bytes.decode_u32(cursor + 42)
		if local + 30 > cursor or bytes.decode_u32(local) != 0x04034b50: return false
		# DOS 日期 1980-01-01，时间 00:00:00；不改压缩载荷、CRC 或文件名。
		bytes.encode_u16(local + 10, 0); bytes.encode_u16(local + 12, 33)
		bytes.encode_u16(cursor + 12, 0); bytes.encode_u16(cursor + 14, 33)
		cursor += 46 + bytes.decode_u16(cursor + 28) + bytes.decode_u16(cursor + 30) + bytes.decode_u16(cursor + 32)
	return cursor == end and _write(path, bytes)

## 写入仅限调用方新建候选目录，所有错误向上传递。
static func _write(path: String, bytes: PackedByteArray) -> bool:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(bytes); file.flush()
	var result: Error = file.get_error()
	file.close()
	return result == OK

## 对导入字节计算强摘要，不用原图大小代替发行载荷大小。
static func _hash(bytes: PackedByteArray) -> String:
	var hash_value := HashingContext.new()
	hash_value.start(HashingContext.HASH_SHA256); hash_value.update(bytes)
	return hash_value.finish().hex_encode()

## 单一格式命令供本地验证和完整小游戏导出共同调用。
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 4: printerr("Usage: content_partition.gd -- <full.zip|pck> <new-directory> <douyin|wechat> <https-base-url>"); quit(2); return
	var result: Dictionary = build(args[0], args[1], args[2], args[3])
	if result.has("error"): printerr(result.error); quit(1); return
	print("CONTENT PARTITION PASS: " + JSON.stringify(result))
	quit()
