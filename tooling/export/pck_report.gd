extends RefCounted
## 从已验证 PCK 统计唯一载荷，并把导入和场景缓存路径还原为制作资源路径。

## 报告解压后字节，不把它伪装成整体 Brotli 内可直接相加的压缩贡献。
static func summarize(reader: RefCounted) -> Dictionary:
	var sources: Dictionary = {}
	for path: String in reader.get_files():
		if not path.ends_with(".import") and not path.ends_with(".remap"): continue
		var config := ConfigFile.new()
		if config.parse(reader.read_file(path).get_string_from_utf8()) != OK: continue
		var source: String = path.trim_suffix(".import").trim_suffix(".remap")
		if config.has_section("remap"):
			for key: String in config.get_section_keys("remap"):
				if key == "path" or key.begins_with("path."):
					sources[str(config.get_value("remap", key)).trim_prefix("res://")] = source
	var payloads: Dictionary = {}
	for path: String in reader.get_files():
		var entry: Dictionary = reader.get_entry_info(path)
		var identity: String = "%d:%d" % [entry.offset, entry.size]
		if not payloads.has(identity):
			payloads[identity] = {"bytes": entry.size, "paths": [], "kind": _kind(path)}
		var original: String = sources.get(path, path)
		if original not in payloads[identity].paths: payloads[identity].paths.append(original)
	var groups: Dictionary = {}
	var rows: Array[Dictionary] = []
	for entry: Dictionary in payloads.values():
		entry.paths.sort()
		groups[entry.kind] = int(groups.get(entry.kind, 0)) + int(entry.bytes)
		rows.append(entry)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.bytes > b.bytes if a.bytes != b.bytes else a.paths[0] < b.paths[0])
	return {"measurement": "Uncompressed unique PCK payload bytes; shared paths counted once.",
		"groups": groups, "largest": rows.slice(0, mini(20, rows.size()))}

## 按引擎实际输出格式分类，避免把压缩纹理缓存误判成可删除的编辑器缓存。
static func _kind(path: String) -> String:
	if path.ends_with(".ctex"): return "textures"
	if path.get_extension() in ["fontdata", "ttf", "otf", "woff", "woff2"]: return "fonts"
	if path.get_extension() in ["gdc", "gd", "js"]: return "scripts"
	if path.get_extension() in ["res", "scn", "tres", "tscn"]: return "scenes_and_resources"
	return "other"
