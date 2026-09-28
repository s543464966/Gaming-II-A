extends Node
## 为抖音测试包下载、校验并缓存随构建锁定的远程贴图包。

signal _download_finished(bytes: PackedByteArray, message: String)
signal phase_changed(message: String)

const MANIFEST_PATH: String = "res://game_content/donuts/delivery_manifest.json"
const MAX_PACK_BYTES: int = 8 * 1024 * 1024

var error: String = ""
var _request: JavaScriptObject
var _callbacks: Array[JavaScriptObject] = []
var _http: HTTPRequest
var _timer: Timer
var _active: bool = false


## 离线包没有清单时立即成功；CDN 包只挂载清单固定的摘要文件。
func prepare(cache_directory: String = "") -> bool:
	error = ""
	if not FileAccess.file_exists(MANIFEST_PATH):
		return true
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not document is Dictionary or not _valid_manifest(document):
		error = "资源清单无效，请重新打包。"
		return false
	var cache_dir: String = cache_directory if not cache_directory.is_empty() else ProjectSettings.globalize_path("user://cdn")
	if DirAccess.make_dir_recursive_absolute(cache_dir) != OK:
		error = "无法创建资源缓存目录。"
		return false
	var path: String = cache_dir.path_join(document.sha256 + ".pck")
	phase_changed.emit("正在校验游戏资源…")
	if not _verified_file(path, document):
		phase_changed.emit("正在下载游戏资源…")
		var bytes: PackedByteArray = await _download(document.base_url + document.sha256 + ".pck", int(document.bytes))
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
	phase_changed.emit("正在进入关卡…")
	if not ProjectSettings.load_resource_pack(path, false):
		error = "资源包无法挂载，请重新启动游戏。"
		return false
	return true


## 校验本地包内固定的地址、摘要和体积，远端不能更改清单内容。
func _valid_manifest(document: Dictionary) -> bool:
	if int(document.get("version", 0)) != 1:
		return false
	var base_url: String = str(document.get("base_url", ""))
	if not base_url.begins_with("https://") or not base_url.ends_with("/") or base_url.contains("?") or base_url.contains("#"):
		return false
	var sha256: String = str(document.get("sha256", ""))
	var pattern := RegEx.new()
	pattern.compile("^[0-9a-f]{64}$")
	return pattern.search(sha256) != null and int(document.get("bytes", 0)) > 0 and int(document.bytes) <= MAX_PACK_BYTES


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
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_timeout)
	add_child(_timer)
	_timer.start(30.0)
	if OS.has_feature("web"):
		var host: JavaScriptObject = JavaScriptBridge.get_interface("tt")
		if host == null or host.get("request") == null:
			_complete.call_deferred(PackedByteArray(), "抖音资源下载接口不可用。")
		else:
			var options: JavaScriptObject = JavaScriptBridge.create_object("Object")
			options.url = url
			options.method = "GET"
			options.responseType = "arraybuffer"
			options.timeout = 30000
			_callbacks = [JavaScriptBridge.create_callback(_host_success.bind(expected_bytes)), JavaScriptBridge.create_callback(_host_failure)]
			options.success = _callbacks[0]
			options.fail = _callbacks[1]
			_request = host.request(options)
	else:
		_http = HTTPRequest.new()
		_http.body_size_limit = expected_bytes
		_http.timeout = 30.0
		_http.max_redirects = 0
		add_child(_http)
		_http.request_completed.connect(_http_completed.bind(expected_bytes))
		if _http.request(url) != OK:
			_complete.call_deferred(PackedByteArray(), "无法发起资源请求。")
	var result: Array = await _download_finished
	if not str(result[1]).is_empty():
		error = result[1]
	return result[0]


## 宿主成功回调仍要核对状态码、类型和长度，拒绝错误页或截断响应。
func _host_success(args: Array, expected_bytes: int) -> void:
	if not _active:
		return
	var response: JavaScriptObject = args[0] if not args.is_empty() else null
	if response == null or int(response.statusCode) != 200 or not JavaScriptBridge.is_js_buffer(response.data) or int(response.data.byteLength) != expected_bytes:
		_complete.call_deferred(PackedByteArray(), "资源响应无效，请检查网络和合法域名。")
		return
	_complete.call_deferred(JavaScriptBridge.js_buffer_to_packed_byte_array(response.data), "")


## 宿主失败详情不进入游戏界面，玩家可从加载界面重试。
func _host_failure(_args: Array) -> void:
	_complete.call_deferred(PackedByteArray(), "资源下载失败，请检查网络和合法域名。")


## 桌面网络检查与真机采用同样的状态码和体积约束。
func _http_completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray, expected_bytes: int) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or status != 200 or body.size() != expected_bytes:
		print("[ContentDelivery] http_result=%d status=%d bytes=%d/%d" % [result, status, body.size(), expected_bytes])
		_complete(PackedByteArray(), "资源下载失败，请重试。")
		return
	_complete(body, "")


## 应用级超时防止宿主没有触发成功或失败回调时一直等待。
func _timeout() -> void:
	if _request != null:
		_request.abort()
	if _http != null:
		_http.cancel_request()
	_complete(PackedByteArray(), "资源下载超时，请重试。")


## 每次请求只结算一次，迟到回调不再改变当前加载结果。
func _complete(bytes: PackedByteArray, message: String) -> void:
	if not _active:
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
	_complete(PackedByteArray(), "资源下载已取消。")
