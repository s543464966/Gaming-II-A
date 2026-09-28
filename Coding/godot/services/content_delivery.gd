extends Node
## 为抖音下载、校验并缓存随构建锁定的贴图分块，全部就绪后再挂载。

signal _download_finished(bytes: PackedByteArray, message: String)
signal phase_changed(message: String)

const MANIFEST_PATH: String = "res://game_content/donuts/delivery_manifest.json"
const MAX_PACK_BYTES: int = 32 * 1024 * 1024

var error: String = ""
var _request: JavaScriptObject
var _callbacks: Array[JavaScriptObject] = []
var _http: HTTPRequest
var _timer: Timer
var _active: bool = false
var _generation: int = 0


## 离线包没有清单时立即成功；CDN 包只挂载清单固定的摘要文件。
func prepare(cache_directory: String = "") -> bool:
	error = ""
	if not FileAccess.file_exists(MANIFEST_PATH):
		return true
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not document is Dictionary or not _valid_manifest(document):
		if error.is_empty():
			error = "资源清单无效，请重新打包。"
		return false
	var cache_dir: String = cache_directory if not cache_directory.is_empty() else ProjectSettings.globalize_path("user://cdn")
	if DirAccess.make_dir_recursive_absolute(cache_dir) != OK:
		error = "无法创建资源缓存目录。"
		return false
	var paths := PackedStringArray()
	for index: int in document.packs.size():
		var pack: Dictionary = document.packs[index]
		var path: String = cache_dir.path_join(pack.file)
		if not await _prepare_pack(path, pack, document.base_url, index + 1, document.packs.size()):
			return false
		paths.append(path)
	phase_changed.emit("正在进入关卡…")
	for path: String in paths:
		if not ProjectSettings.load_resource_pack(path, false):
			error = "资源包无法挂载，请重新启动游戏。"
			return false
	return true


## 分块命中缓存时跳过下载，失败重试只补齐尚未通过校验的块。
func _prepare_pack(path: String, document: Dictionary, base_url: String, index: int, count: int) -> bool:
	phase_changed.emit("正在校验游戏资源…")
	if not _verified_file(path, document):
		phase_changed.emit("正在下载游戏资源… %d/%d" % [index, count])
		var bytes: PackedByteArray = await _download(base_url + document.file, int(document.bytes))
		if not error.is_empty():
			return false
		phase_changed.emit("正在校验下载资源…")
		var temporary: String = path + ".part"
		var file := FileAccess.open(temporary, FileAccess.WRITE)
		if file == null:
			error = "无法保存下载的资源。"
			return false
		file.store_buffer(bytes)
		file.flush()
		var status: Error = file.get_error()
		file.close()
		if status != OK or not _verified_file(temporary, document):
			DirAccess.remove_absolute(temporary)
			error = "下载的资源校验失败，请重试。"
			return false
		if DirAccess.rename_absolute(temporary, path) != OK:
			DirAccess.remove_absolute(temporary)
			error = "无法保存已校验的资源。"
			return false
	return true


## 校验本地包内固定的地址、摘要和体积，远端不能更改清单内容。
func _valid_manifest(document: Dictionary) -> bool:
	if int(document.get("version", 0)) != 2:
		return false
	var base_url: String = str(document.get("base_url", ""))
	var local_pattern := RegEx.new()
	local_pattern.compile("^http://127[.]0[.]0[.]1:[0-9]+/[0-9a-f]+/$")
	var local_preview: bool = document.get("preview_only", false) == true and local_pattern.search(base_url) != null
	if local_preview and OS.has_feature("web"):
		var host: JavaScriptObject = JavaScriptBridge.get_interface("tt")
		if host == null or str(host.getSystemInfoSync().platform) != "devtools":
			error = "这是本机测试包，请在电脑模拟器中打开。"
			return false
	if (not local_preview and not base_url.begins_with("https://")) or not base_url.ends_with("/") or base_url.contains("?") or base_url.contains("#"):
		return false
	var packs: Variant = document.get("packs")
	if not packs is Array or packs.is_empty() or packs.size() > 256:
		return false
	var pattern := RegEx.new()
	pattern.compile("^[0-9a-f]{64}$")
	var seen: Dictionary = {}
	var total: int = 0
	for pack: Variant in packs:
		if not pack is Dictionary:
			return false
		var sha256: String = str(pack.get("sha256", ""))
		var size: int = int(pack.get("bytes", 0))
		if pattern.search(sha256) == null or pack.get("file") != sha256 + ".pck" or seen.has(sha256) or size <= 0 or size > MAX_PACK_BYTES:
			return false
		seen[sha256] = true
		total += size
	return total <= 512 * 1024 * 1024


## 命中缓存前仍核对长度与 SHA-256，损坏文件会重新下载。
func _verified_file(path: String, document: Dictionary) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var matches: bool = file.get_length() == int(document.bytes)
	file.close()
	return matches and FileAccess.get_sha256(path) == document.sha256


## 抖音环境使用 tt.request 的二进制响应，桌面验证使用引擎 HTTPRequest。
func _download(url: String, expected_bytes: int) -> PackedByteArray:
	_active = true
	_generation += 1
	var generation: int = _generation
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_timeout.bind(generation))
	add_child(_timer)
	_timer.start(30.0)
	if OS.has_feature("web"):
		var host: JavaScriptObject = JavaScriptBridge.get_interface("tt")
		if host == null or host.get("request") == null:
			_complete.call_deferred(PackedByteArray(), "抖音资源下载接口不可用。", generation)
		else:
			var options: JavaScriptObject = JavaScriptBridge.create_object("Object")
			options.url = url
			options.method = "GET"
			options.responseType = "arraybuffer"
			options.timeout = 30000
			_callbacks = [JavaScriptBridge.create_callback(_host_success.bind(expected_bytes, generation)), JavaScriptBridge.create_callback(_host_failure.bind(generation))]
			options.success = _callbacks[0]
			options.fail = _callbacks[1]
			_request = host.request(options)
	else:
		_http = HTTPRequest.new()
		_http.body_size_limit = expected_bytes
		_http.timeout = 30.0
		_http.max_redirects = 0
		add_child(_http)
		_http.request_completed.connect(_http_completed.bind(expected_bytes, generation))
		if _http.request(url) != OK:
			_complete.call_deferred(PackedByteArray(), "无法发起资源请求。", generation)
	var result: Array = await _download_finished
	if not str(result[1]).is_empty():
		error = result[1]
	return result[0]


## 宿主成功回调仍要核对状态码、类型和长度，拒绝错误页或截断响应。
func _host_success(args: Array, expected_bytes: int, generation: int) -> void:
	if not _active or generation != _generation:
		return
	var response: JavaScriptObject = args[0] if not args.is_empty() else null
	if response == null or int(response.statusCode) != 200 or not JavaScriptBridge.is_js_buffer(response.data) or int(response.data.byteLength) != expected_bytes:
		_complete.call_deferred(PackedByteArray(), "资源响应无效，请检查网络和合法域名。", generation)
		return
	_complete.call_deferred(JavaScriptBridge.js_buffer_to_packed_byte_array(response.data), "", generation)


## 宿主失败详情不进入游戏界面，玩家可从加载界面重试。
func _host_failure(_args: Array, generation: int) -> void:
	_complete.call_deferred(PackedByteArray(), "资源下载失败，请检查网络和合法域名。", generation)


## 桌面网络检查与真机采用同样的状态码和体积约束。
func _http_completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray, expected_bytes: int, generation: int) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or status != 200 or body.size() != expected_bytes:
		print("[ContentDelivery] http_result=%d status=%d bytes=%d/%d" % [result, status, body.size(), expected_bytes])
		_complete(PackedByteArray(), "资源下载失败，请重试。", generation)
		return
	_complete(body, "", generation)


## 应用级超时防止宿主没有触发成功或失败回调时一直等待。
func _timeout(generation: int) -> void:
	if not _active or generation != _generation:
		return
	if _request != null:
		_request.abort()
	if _http != null:
		_http.cancel_request()
	_complete(PackedByteArray(), "资源下载超时，请重试。", generation)


## 每次请求只结算一次，迟到回调不再改变当前加载结果。
func _complete(bytes: PackedByteArray, message: String, generation: int) -> void:
	if not _active or generation != _generation:
		return
	_active = false
	_timer.stop()
	_timer.queue_free()
	_timer = null
	if _http != null:
		_http.queue_free()
		_http = null
	_request = null
	_callbacks.clear()
	_download_finished.emit(bytes, message)


## 离树时取消本服务的请求，不触碰已校验的缓存文件。
func _exit_tree() -> void:
	if not _active:
		return
	if _request != null:
		_request.abort()
	if _http != null:
		_http.cancel_request()
	_complete(PackedByteArray(), "资源下载已取消。", _generation)
