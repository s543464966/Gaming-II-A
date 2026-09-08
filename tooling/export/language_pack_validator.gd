extends RefCounted
## 对实际资源 ZIP 或 PCK 核验语言边界与字节，不把导出器成功退出当作产物正确。

const Profile = preload("res://tooling/export/language_profile.gd")
const Manifest = preload("res://game_content/runtime/language_manifest.gd")
var errors: Array[String] = []

## 使用刚通过来源校验的配置，拒绝残缺、额外或同名重复资源。
func verify(profile: RefCounted, path: String) -> bool:
	errors.clear()
	if profile.manifest.is_empty() or not profile.errors.is_empty():
		errors.append("没有有效的语言打包配置。")
		return false
	var archive = preload("res://tooling/export/pck_reader.gd").new() if path.ends_with(".pck") else ZIPReader.new()
	if archive.open(path) != OK:
		errors.append("语言资源包无法读取或已损坏: " + path)
		return false
	var expected: Dictionary = {}
	for file in profile.files: expected[(Profile.ROOT + file).trim_prefix("res://")] = profile.files[file]
	for file in profile.assets: expected[file.trim_prefix("res://")] = profile.assets[file]
	var snapshot = "game_content/generated/game_data_snapshot.json"
	expected[snapshot] = FileAccess.get_sha256("res://" + snapshot)
	var paths = archive.get_files()
	var seen: Dictionary = {}
	var manifest_path = Profile.MANIFEST.trim_prefix("res://")
	var manifest_bytes = (JSON.stringify(profile.manifest, "  ", true) + "\n").to_utf8_buffer()
	if not manifest_path in paths or archive.read_file(manifest_path) != manifest_bytes:
		errors.append("资源包语言清单与本次配置不一致。")
	for file in expected:
		if not file in paths or _hash(archive.read_file(file)) != expected[file]:
			errors.append("资源包缺失或字节不一致: " + file)
	for file in paths:
		if seen.has(file): errors.append("资源包存在重复条目: " + file)
		seen[file] = true
		if file.ends_with("-game_theme.res") and archive.read_file(file).size() >= 128 * 1024:
			errors.append("派生主题意外内嵌大资源，请检查 Theme 导出: " + file)
		if file.begins_with("game_content/localization/") or (file.ends_with(".fontdata") and not expected.has(file)) or file == "game_content/generated/bundle.json":
			errors.append("资源包夹带作者数据或字体缓存: " + file)
		elif (file.begins_with("game_content/generated/localization/") or file.begins_with(Manifest.FONT_ROOT.trim_prefix("res://"))) and file != manifest_path and not expected.has(file):
			errors.append("资源包夹带未选择的语言或字体: " + file)
	archive.close()
	return errors.is_empty()

## 核验原始资源字节，不依赖导入缓存与文件时间。
static func _hash(bytes: PackedByteArray) -> String:
	var hashing = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()
