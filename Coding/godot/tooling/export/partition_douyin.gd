extends SceneTree
## 按真实导出包自动拆分非启动贴图，新增美术无需人工补充 CDN 文件清单。

const Reader = preload("res://tooling/export/pck_reader.gd")
const MANIFEST: String = "game_content/donuts/delivery_manifest.json"
const TARGET_PACK_BYTES: int = 4 * 1024 * 1024
const MAX_PACK_BYTES: int = 32 * 1024 * 1024


## 只写入全新的隔离目录，由工作区工具决定何时替换固定项目。
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3:
		printerr("Usage: partition_douyin.gd -- <full-pck> <new-output-directory> <https-CDN-directory/>")
		quit(2)
		return
	var result: Dictionary = _build(args[0], args[1], args[2])
	if result.has("error"):
		printerr(result.error)
		quit(1)
		return
	print("DOUYIN PARTITION PASS: " + JSON.stringify(result))
	quit(0)


## 从导入映射选择贴图，并保留启动场景及加载界面需要的完整依赖。
func _build(source: String, output: String, base_url: String) -> Dictionary:
	var local_pattern := RegEx.new()
	local_pattern.compile("^http://127[.]0[.]0[.]1:[0-9]+/[0-9a-f]+/$")
	var local_preview: bool = local_pattern.search(base_url) != null
	if (not local_preview and not base_url.begins_with("https://")) or not base_url.ends_with("/") or base_url.contains("?") or base_url.contains("#"):
		return {"error": "CDN 地址必须是 HTTPS 目录或本机模拟器服务地址。"}
	if DirAccess.dir_exists_absolute(output) or DirAccess.make_dir_recursive_absolute(output) != OK:
		return {"error": "拆包目标必须是全新的可写目录。"}
	var full = Reader.new()
	if full.open(source) != OK:
		return {"error": "完整资源包无法校验。"}
	var all_files: PackedStringArray = full.get_files()
	all_files.sort()
	var boot: Dictionary = {}
	_collect_dependencies("res://bootstrap/app.tscn", boot)
	var deferred: Dictionary = {}
	for name: String in all_files:
		if not name.ends_with(".import") or boot.has(name.trim_suffix(".import")):
			continue
		var config := ConfigFile.new()
		if config.parse(full.read_file(name).get_string_from_utf8()) != OK:
			return {"error": "导入映射无效：" + name}
		var imported: String = str(config.get_value("remap", "path", "")).trim_prefix("res://")
		if imported.begins_with(".godot/imported/") and imported.ends_with(".ctex"):
			if imported not in all_files:
				return {"error": "导出包缺少贴图载荷：" + name}
			deferred[imported] = true
	if deferred.is_empty():
		return {"error": "没有可迁移的非启动贴图。"}
	var groups: Array[PackedStringArray] = []
	var group := PackedStringArray()
	var group_bytes: int = 256
	for name: String in all_files:
		if not deferred.has(name):
			continue
		var entry_bytes: int = full.get_file_size(name) + name.to_utf8_buffer().size() + 128
		if entry_bytes + 256 > MAX_PACK_BYTES:
			return {"error": "单张贴图超过远程包 32 MiB 上限，请优化该素材：" + name}
		if not group.is_empty() and group_bytes + entry_bytes > TARGET_PACK_BYTES:
			groups.append(group)
			group = PackedStringArray()
			group_bytes = 256
		group.append(name)
		group_bytes += entry_bytes
	if not group.is_empty():
		groups.append(group)
	var packs: Array[Dictionary] = []
	var remote_bytes: int = 0
	for index: int in groups.size():
		var temporary: String = output.path_join("remote_%03d.pck" % index)
		var result: Dictionary = _write_pack(full, output, temporary, groups[index])
		if result.has("error"):
			return result
		var size: int = FileAccess.get_file_as_bytes(temporary).size()
		if size > MAX_PACK_BYTES:
			return {"error": "远程贴图块超过 32 MiB 上限。"}
		var sha256: String = FileAccess.get_sha256(temporary)
		var filename: String = sha256 + ".pck"
		if DirAccess.rename_absolute(temporary, output.path_join(filename)) != OK:
			return {"error": "无法提交远程资源块。"}
		packs.append({"file": filename, "sha256": sha256, "bytes": size, "paths": Array(groups[index])})
		remote_bytes += size
	var document: Dictionary = {"version": 2, "base_url": base_url, "packs": packs, "preview_only": local_preview}
	var manifest_bytes: PackedByteArray = (JSON.stringify(document, "  ") + "\n").to_utf8_buffer()
	var core_files := PackedStringArray()
	for name: String in all_files:
		if name == MANIFEST:
			return {"error": "完整包不应包含上次生成的 CDN 清单。"}
		if not deferred.has(name):
			core_files.append(name)
	var core_path: String = output.path_join("core.pck")
	var result: Dictionary = _write_pack(full, output, core_path, core_files, manifest_bytes)
	if result.has("error"):
		return result
	full.close()
	return {"core_bytes": FileAccess.get_file_as_bytes(core_path).size(),
		"remote_bytes": remote_bytes, "packs": packs, "deferred_paths": Array(deferred.keys())}


## 递归读取实际资源依赖，加载页以后增加贴图时也会自动留在本地包。
func _collect_dependencies(path: String, paths: Dictionary) -> void:
	var key: String = path.trim_prefix("res://")
	if paths.has(key):
		return
	paths[key] = true
	for dependency: String in ResourceLoader.get_dependencies(path):
		var target: String = dependency.split("::")[-1]
		if target.begins_with("res://"):
			_collect_dependencies(target, paths)


## 每个资源条目只写入一个包，并逐字节核对，禁止拆包改变画面资源。
func _write_pack(full: RefCounted, output: String, destination: String, names: PackedStringArray, manifest: PackedByteArray = PackedByteArray()) -> Dictionary:
	var pack := PCKPacker.new()
	if pack.pck_start(destination) != OK:
		return {"error": "无法创建资源包：" + destination}
	for name: String in names:
		if not _add(pack, output, name, full.read_file(name)):
			return {"error": "资源写入失败：" + name}
	if not manifest.is_empty() and not _add(pack, output, MANIFEST, manifest):
		return {"error": "核心包清单写入失败。"}
	if pack.flush() != OK:
		return {"error": "资源包提交失败：" + destination}
	var verified = Reader.new()
	if verified.open(destination) != OK:
		return {"error": "拆分后的资源包校验失败。"}
	for name: String in names:
		if verified.read_file(name) != full.read_file(name):
			return {"error": "拆包改变了资源原始字节：" + name}
	if not manifest.is_empty() and verified.read_file(MANIFEST) != manifest:
		return {"error": "核心包缺少同批资源清单。"}
	verified.close()
	return {}


## 用本次完整包提供的字节生成条目，不读取另一份工程素材。
func _add(packer: PCKPacker, output: String, name: String, bytes: PackedByteArray) -> bool:
	var temporary: String = output.path_join("entries").path_join(name)
	if DirAccess.make_dir_recursive_absolute(temporary.get_base_dir()) != OK:
		return false
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	var status: Error = file.get_error()
	file.close()
	return status == OK and packer.add_file("res://" + name, temporary) == OK
