extends SceneTree
## 从同一次完整导出拆出两张背景贴图，保留脚本、场景、字体和导入映射于核心包。

const Reader = preload("res://tooling/export/pck_reader.gd")
const MANIFEST: String = "game_content/donuts/delivery_manifest.json"
const SOURCES: PackedStringArray = [
	"features/donut_sort/ui/art/scene/shop_background_unified.png",
	"features/donut_sort/ui/art/scene/tabletop_light.png",
]


## 命令仅写入全新的隔离目录，调用者决定何时替换固定小游戏工程。
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


## 从真实 PCK 的导入映射定位贴图，写出按摘要绑定的远程包和核心包。
func _build(source: String, output: String, base_url: String) -> Dictionary:
	if not base_url.begins_with("https://") or not base_url.ends_with("/") or base_url.contains("?") or base_url.contains("#"):
		return {"error": "CDN 地址必须是以 / 结尾的 HTTPS 目录。"}
	if DirAccess.dir_exists_absolute(output) or DirAccess.make_dir_recursive_absolute(output) != OK:
		return {"error": "拆包目标必须是全新的可写目录。"}
	var full = Reader.new()
	if full.open(source) != OK:
		return {"error": "完整资源包无法校验。"}
	var all_files: PackedStringArray = full.get_files()
	var deferred: Dictionary = {}
	for image: String in SOURCES:
		var mapping: String = image + ".import"
		if mapping not in all_files:
			return {"error": "缺少背景贴图导入映射：" + image}
		var config := ConfigFile.new()
		if config.parse(full.read_file(mapping).get_string_from_utf8()) != OK:
			return {"error": "背景贴图导入映射无效：" + image}
		var imported: String = str(config.get_value("remap", "path", "")).trim_prefix("res://")
		if not imported.begins_with(".godot/imported/") or not imported.ends_with(".ctex") or imported not in all_files:
			return {"error": "背景贴图导入载荷缺失：" + image}
		deferred[imported] = true
	var remote_path: String = output.path_join("remote.pck")
	var remote := PCKPacker.new()
	if remote.pck_start(remote_path) != OK:
		return {"error": "无法创建远程贴图包。"}
	var remote_files: PackedStringArray = PackedStringArray(deferred.keys())
	remote_files.sort()
	for name: String in remote_files:
		if not _add(remote, output, name, full.read_file(name)):
			return {"error": "远程贴图写入失败：" + name}
	if remote.flush() != OK:
		return {"error": "远程贴图包提交失败。"}
	var bytes: int = FileAccess.get_file_as_bytes(remote_path).size()
	if bytes <= 0 or bytes > 8 * 1024 * 1024:
		return {"error": "远程贴图包超过 8 MiB 上限。"}
	var sha256: String = FileAccess.get_sha256(remote_path)
	var document: Dictionary = {"version": 1, "base_url": base_url, "sha256": sha256, "bytes": bytes, "paths": Array(remote_files)}
	var manifest_bytes: PackedByteArray = (JSON.stringify(document, "  ") + "\n").to_utf8_buffer()
	var core_path: String = output.path_join("core.pck")
	var core := PCKPacker.new()
	if core.pck_start(core_path) != OK:
		return {"error": "无法创建核心包。"}
	all_files.sort()
	for name: String in all_files:
		if deferred.has(name):
			continue
		if name == MANIFEST or not _add(core, output, name, full.read_file(name)):
			return {"error": "核心资源写入失败：" + name}
	if not _add(core, output, MANIFEST, manifest_bytes) or core.flush() != OK:
		return {"error": "核心包清单提交失败。"}
	var verified_core = Reader.new()
	var verified_remote = Reader.new()
	if verified_core.open(core_path) != OK or verified_remote.open(remote_path) != OK:
		return {"error": "拆分后的资源包校验失败。"}
	for name: String in all_files:
		var target = verified_remote if deferred.has(name) else verified_core
		if target.read_file(name) != full.read_file(name):
			return {"error": "拆包改变了资源原始字节：" + name}
	if verified_core.read_file(MANIFEST) != manifest_bytes:
		return {"error": "核心包没有包含同批资源清单。"}
	full.close()
	verified_core.close()
	verified_remote.close()
	return {"core_bytes": FileAccess.get_file_as_bytes(core_path).size(), "remote_bytes": bytes,
		"sha256": sha256, "deferred_paths": Array(remote_files)}


## 每个 PCK 条目只使用本次完整包提供的字节，不读取另一份工程素材。
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
