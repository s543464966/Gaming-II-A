extends RefCounted
## 核心包内固定的资源交付清单；远端只能提供已登记的纹理字节，不能扩展代码或资源身份。

const PATH: String = "res://game_content/generated/delivery_manifest.json"
const MAX_PACK_BYTES: int = 2 * 1024 * 1024
var data: Dictionary = {}
var error: String = ""

## 校验核心包绑定的版本、资源键和下载地址，不信任远端提供的新清单。
func parse(value: Variant, registry: Dictionary, registry_hash: String) -> bool:
	data = {}
	error = ""
	if not value is Dictionary or value.get("version") != 1 or value.get("engine") != "4.5.1": return _reject("资源交付清单版本不支持。")
	if value.get("registry_sha256") != registry_hash: return _reject("资源清单与登记表不属于同一构建。")
	if not value.get("target") in ["douyin", "wechat"] or not valid_base_url(value.get("base_url")): return _reject("资源下载地址或平台无效。")
	if not value.get("packs") is Dictionary or not value.get("assets") is Dictionary or value.packs.is_empty(): return _reject("资源交付清单为空或损坏。")
	var paths: Dictionary = {}
	var used: Dictionary = {}
	for id: Variant in value.packs:
		var pack: Variant = value.packs[id]
		if not valid_hash(id) or not pack is Dictionary: return _reject("资源包身份无效。")
		if not _positive_size(pack.get("bytes")) or not pack.get("files") is Dictionary or pack.files.is_empty(): return _reject("资源包大小或条目无效。")
		var expanded: int = 0
		for path: Variant in pack.files:
			var entry: Variant = pack.files[path]
			if not path is String or not path.begins_with(".godot/imported/") or path.get_file() != path.trim_prefix(".godot/imported/") or not path.ends_with(".ctex"): return _reject("内容包仅允许导入纹理，不允许脚本或路径跳转。")
			if paths.has(path) or not entry is Dictionary or not valid_hash(entry.get("sha256")) or not _positive_size(entry.get("bytes")): return _reject("资源包条目重复或损坏。")
			paths[path] = id
			expanded += int(entry.bytes)
		if expanded > MAX_PACK_BYTES: return _reject("资源包解压体积超出上限。")
	for key: Variant in value.assets:
		var entry: Variant = value.assets[key]
		var asset: Variant = registry.get(key)
		if not entry is Dictionary or not asset is Dictionary or asset.get("kind") != "Texture": return _reject("延迟资源键不存在或不是纹理。")
		if entry.get("path") != asset.get("path") or not str(entry.path).begins_with("res://game_content/") or not str(entry.path).ends_with(".png"): return _reject("延迟资源不属于已声明的静态内容贴图。")
		if not entry.get("file") is String or paths.get(entry.file, "") != entry.get("pack") or not value.packs.has(entry.get("pack")): return _reject("延迟资源缺少对应纹理包。")
		used[entry.pack] = true
	if used.size() != value.packs.size(): return _reject("资源清单包含无消费者的包。")
	data = value.duplicate(true)
	return true

## 只接受 HTTPS 目录地址，路径和包名不能通过查询参数或上级目录改写。
static func valid_base_url(value: Variant) -> bool:
	if not value is String or not value.begins_with("https://") or not value.ends_with("/"): return false
	var rest: String = value.trim_prefix("https://")
	return not rest.get_slice("/", 0).is_empty() and not rest.contains("@") and not rest.contains("?") and not rest.contains("#") and not rest.contains("\\") and not rest.contains(" ") and not rest.split("/").has("..") and not rest.split("/").has(".")

## 文件名只由可信清单中的小写摘要组成，不使用资源键构造磁盘路径。
static func valid_hash(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character: String in value:
		if not character in "0123456789abcdef": return false
	return true

## JSON 数字必须是有界整数，防止网络缓冲和解压分配无限增长。
static func _positive_size(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(value) and value == int(value) and value > 0 and value <= MAX_PACK_BYTES

## 失败不留下部分有效清单。
func _reject(message: String) -> bool:
	error = message
	return false
