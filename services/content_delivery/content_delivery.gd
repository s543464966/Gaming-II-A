extends Node
## 应用生命周期内的资源下载与缓存；仅挂载核心清单固定的纹理包，不接收远端代码或可变清单。

const Manifest = preload("res://game_content/runtime/delivery_manifest.gd")
const Download = preload("res://platforms/common/asset_download.gd")
signal progress(completed_bytes: int, total_bytes: int)
var manifest: RefCounted = Manifest.new()
var error: String = ""
## 可直接展示的脱敏诊断；不包含下载地址、资源路径或存档信息。
var diagnostic: String = ""
var busy: bool = false
var _cache: String
var _mounted: Dictionary = {}
var downloader: Node
var _cancelled: bool = false
var _verification_error: String = ""

## 默认完整包没有交付清单，不改变原来的同步加载和离线行为。
func initialize(directory: String) -> bool:
	error = ""
	diagnostic = ""
	if not FileAccess.file_exists(Manifest.PATH): return true
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://game_content/asset_registry.json"))
	if not registry is Dictionary:
		_fail("registry", "资源登记表无法读取。")
		return false
	return configure(JSON.parse_string(FileAccess.get_file_as_string(Manifest.PATH)), registry, FileAccess.get_sha256("res://game_content/asset_registry.json"), directory)

## 装配方提供清单及独立缓存根，网络适配器可以显式注入而不改变内容身份校验。
func configure(document: Variant, registry: Dictionary, registry_hash: String, directory: String) -> bool:
	if busy: return false
	error = ""
	diagnostic = ""
	if not manifest.data.is_empty() and manifest.data != document:
		_fail("manifest_changed", "切换资源版本需要重新启动游戏。")
		return false
	_cache = directory.path_join("content_cache")
	if downloader != null and downloader.get_parent() == null: add_child(downloader)
	if not manifest.parse(document, registry, registry_hash):
		_fail("manifest", manifest.error if not manifest.error.is_empty() else "资源登记表无法读取。")
		return false
	var cache_status: Error = DirAccess.make_dir_recursive_absolute(_cache)
	if cache_status != OK:
		_fail("cache_directory", "无法创建资源缓存目录。", "", "code=%d" % cache_status)
		return false
	# 先清理中断的临时写入；旧版本完整缓存留到本版一批实际需求准备成功。
	for file: String in DirAccess.get_files_at(_cache):
		if file.ends_with(".part") and Manifest.valid_hash(file.trim_suffix(".part")):
			DirAccess.remove_absolute(_cache.path_join(file))
	return true

## 制作校验仍检查全部资源，运行时仅延迟清单明确列出的纹理。
func deferred_assets() -> Dictionary:
	return manifest.data.get("assets", {})

## 省略参数准备全部，显式空列表表示无需资源；已挂载的包无需再次下载。
func pending(keys: Variant = null) -> Array[String]:
	var result: Array[String] = []
	var assets: Dictionary = deferred_assets()
	for key: Variant in (assets.keys() if keys == null else keys):
		if assets.has(key):
			var id: String = assets[key].pack
			if not _mounted.has(id) and id not in result: result.append(id)
	result.sort()
	return result

## 逐包校验缓存或下载，取消与失败均保留其他已验证包供重试复用。
func prepare(keys: Variant = null) -> bool:
	if busy: return false
	error = ""
	diagnostic = ""
	var ids: Array[String] = pending(keys)
	if ids.is_empty(): return true
	busy = true
	_cancelled = false
	error = ""
	var total: int = 0
	var completed_bytes: int = 0
	for id: String in ids: total += int(manifest.data.packs[id].bytes)
	progress.emit(0, total)
	for id: String in ids:
		var pack: Dictionary = manifest.data.packs[id]
		var path: String = _cache.path_join(id + ".zip")
		var transfer: String = "source=cache"
		if not _verify(path, id, pack):
			if downloader == null: downloader = Download.new()
			if downloader.get_parent() == null: add_child(downloader)
			downloader.start(manifest.data.base_url + id + ".zip", int(pack.bytes))
			var response: Array = await downloader.completed
			if not is_inside_tree(): return false
			var details: Variant = downloader.get("diagnostic")
			transfer = details if details is String else "transport=unknown"
			if not str(response[1]).is_empty():
				_fail("download", response[1], id, transfer)
				break
			if _cancelled: break
			var temporary: String = _cache.path_join(id + ".part")
			var file := FileAccess.open(temporary, FileAccess.WRITE)
			if file == null:
				_fail("cache_open", "资源缓存空间不足或不可写。", id, "code=%d" % FileAccess.get_open_error())
				break
			file.store_buffer(response[0])
			file.flush()
			var status: Error = file.get_error()
			file.close()
			if status != OK:
				DirAccess.remove_absolute(temporary)
				_fail("cache_write", "资源缓存写入失败。", id, "code=%d" % status)
				break
			if not _verify(temporary, id, pack):
				DirAccess.remove_absolute(temporary)
				_fail("verify", "资源包完整性校验失败。", id, _verification_error)
				break
			var rename_status: Error = DirAccess.rename_absolute(temporary, path)
			if rename_status != OK:
				DirAccess.remove_absolute(temporary)
				_fail("cache_commit", "无法保存已验证的资源包。", id, "code=%d" % rename_status)
				break
		if _cancelled: break
		# 同一路径若已被不同字节占用，必须重启应用，不能覆盖正在使用的纹理。
		var conflict: bool = false
		for name: String in pack.files:
			if FileAccess.file_exists("res://" + name) and FileAccess.get_sha256("res://" + name) != pack.files[name].sha256: conflict = true
		if conflict:
			_fail("mount_conflict", "资源挂载失败，请重新启动游戏。", id, transfer)
			break
		if not ProjectSettings.load_resource_pack(path, false):
			_fail("mount", "资源挂载失败，请重新启动游戏。", id, transfer)
			break
		_mounted[id] = true
		completed_bytes += int(pack.bytes)
		progress.emit(completed_bytes, total)
	busy = false
	var success: bool = error.is_empty() and not _cancelled
	if success: _prune_obsolete()
	return success

## 同一诊断供手机界面与控制台使用，包身份只取摘要前十二位。
func _fail(stage: String, message: String, id: String = "", detail: String = "") -> void:
	error = message
	diagnostic = "CDN-D1 stage=%s" % stage
	if not id.is_empty(): diagnostic += "\npack=" + id.left(12)
	if not detail.is_empty(): diagnostic += "\n" + detail
	print("[ContentDelivery] " + diagnostic.replace("\n", " "))

## 本批需求成功后只回收清单外的摘要 ZIP，不等待玩家浏览全内容，也不触碰当前包与存档。
func _prune_obsolete() -> void:
	for file: String in DirAccess.get_files_at(_cache):
		var id: String = file.trim_suffix(".zip")
		if file.ends_with(".zip") and Manifest.valid_hash(id) and not manifest.data.packs.has(id):
			DirAccess.remove_absolute(_cache.path_join(file))

## 取消只停止下载与后续挂载，已经完成的缓存不回滚为缺失。
func cancel() -> void:
	_cancelled = true
	if is_instance_valid(downloader): downloader.cancel()

## ZIP 整体摘要和逐条白名单双重核验，包内不允许额外文件或压缩炸弹。
func _verify(path: String, id: String, pack: Dictionary) -> bool:
	_verification_error = ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_verification_error = "reason=read code=%d" % FileAccess.get_open_error()
		return false
	var length: int = file.get_length()
	file.close()
	if length != int(pack.bytes):
		_verification_error = "reason=size bytes=%d/%d" % [length, int(pack.bytes)]
		return false
	if FileAccess.get_sha256(path) != id:
		_verification_error = "reason=sha256 bytes=%d/%d" % [length, int(pack.bytes)]
		return false
	var zip := ZIPReader.new()
	var status: Error = zip.open(path)
	if status != OK:
		_verification_error = "reason=zip_open code=%d" % status
		return false
	var paths: PackedStringArray = zip.get_files()
	var valid: bool = paths.size() == pack.files.size()
	if not valid: _verification_error = "reason=entry_count actual=%d expected=%d" % [paths.size(), pack.files.size()]
	var seen: Dictionary = {}
	for name: String in paths:
		if seen.has(name) or not pack.files.has(name):
			_verification_error = "reason=entry_allowlist"
			valid = false
			break
		seen[name] = true
		var bytes: PackedByteArray = zip.read_file(name)
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(bytes)
		if bytes.size() != int(pack.files[name].bytes) or digest.finish().hex_encode() != pack.files[name].sha256:
			_verification_error = "reason=entry_integrity bytes=%d/%d" % [bytes.size(), int(pack.files[name].bytes)]
			valid = false
			break
	zip.close()
	return valid

## 离开 App 时不留下下载工作；已挂载包只在引擎进程结束后卸载。
func _exit_tree() -> void:
	cancel()
