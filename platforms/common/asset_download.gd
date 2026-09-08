extends Node
## 受限的资源字节下载；小游戏使用 tt／wx 请求，桌面与普通 Web 使用引擎 HTTP。

signal completed(bytes: PackedByteArray, error: String)
var _http: HTTPRequest
var _task: JavaScriptObject
var _callbacks: Array[JavaScriptObject] = []
var _timer: Timer
var _active: bool = false
var _generation: int = 0
var _expected: int = 0

## 每次只接受一个有界请求，宿主缺失时不偷偷切换网络实现。
func start(url: String, expected_bytes: int) -> void:
	if _active: return
	_active = true
	_generation += 1
	_expected = expected_bytes
	if _timer == null:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(_timeout)
		add_child(_timer)
	_timer.start(30)
	if OS.has_feature("web") and (OS.has_feature("tt") or OS.has_feature("wechat")):
		var host: JavaScriptObject = JavaScriptBridge.get_interface("tt" if OS.has_feature("tt") else "wx")
		if host == null or host.get("request") == null:
			_finish.call_deferred(PackedByteArray(), "小游戏下载宿主不可用。", _generation)
			return
		var options: JavaScriptObject = JavaScriptBridge.create_object("Object")
		options.url = url
		options.method = "GET"
		options.responseType = "arraybuffer"
		options.dataType = "string"
		options.timeout = 30000
		_callbacks = [JavaScriptBridge.create_callback(_host_success.bind(_generation)), JavaScriptBridge.create_callback(_host_failure.bind(_generation))]
		options.success = _callbacks[0]
		options.fail = _callbacks[1]
		_task = host.request(options)
	else:
		_http = HTTPRequest.new()
		_http.body_size_limit = expected_bytes
		_http.timeout = 30
		_http.max_redirects = 0
		add_child(_http)
		_http.request_completed.connect(_http_completed.bind(_generation))
		if _http.request(url) != OK: _finish.call_deferred(PackedByteArray(), "无法发起资源下载。", _generation)

## 同一完成路径处理超时和主动取消，迟到回调不能提交新请求。
func cancel() -> void:
	if not _active: return
	_generation += 1
	if _task != null: _task.abort()
	if _http != null: _http.cancel_request()
	_finish(PackedByteArray(), "资源下载已取消。")

## JS 缓冲先检查长度，避免把无界响应复制进引擎内存。
func _host_success(args: Array, generation: int) -> void:
	if not _active or generation != _generation: return
	var response: JavaScriptObject = args[0] if not args.is_empty() else null
	if response == null or response.statusCode != 200 or response.data == null or not JavaScriptBridge.is_js_buffer(response.data) or response.data.byteLength != _expected:
		_finish.call_deferred(PackedByteArray(), "资源响应状态或大小不匹配。", generation)
		return
	_finish.call_deferred(JavaScriptBridge.js_buffer_to_packed_byte_array(response.data), "", generation)

## 不向玩家显示可能含完整地址的供应商错误对象。
func _host_failure(_args: Array, generation: int) -> void:
	if _active and generation == _generation: _finish.call_deferred(PackedByteArray(), "资源下载失败，请检查网络与平台合法域名。", generation)

## 引擎网络同样要求完整成功响应，重定向与半包均拒绝。
func _http_completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray, generation: int) -> void:
	_finish(body if result == HTTPRequest.RESULT_SUCCESS and status == 200 else PackedByteArray(), "" if result == HTTPRequest.RESULT_SUCCESS and status == 200 else "资源下载失败。", generation)

## 应用级计时保证基础库忽略 timeout 参数时仍能退出等待。
func _timeout() -> void:
	cancel()

## 完成后释放请求对象，先解除活动状态再通知消费者。
func _finish(bytes: PackedByteArray, message: String, generation: int = -1) -> void:
	if not _active or generation >= 0 and generation != _generation: return
	_active = false
	_timer.stop()
	if _http != null: _http.queue_free(); _http = null
	_task = null
	if message.is_empty() and bytes.size() != _expected: message = "资源下载不完整。"
	completed.emit(bytes, message)

## 服务离树时终止本服务发起的请求，不影响其他网络任务。
func _exit_tree() -> void:
	cancel()
	_callbacks.clear()
