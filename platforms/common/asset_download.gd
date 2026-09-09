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
## 仅含白名单分类和数值，绝不保留 URL、响应正文或原始宿主错误。
var diagnostic: String = ""
var _transport: String = "http"
var _status: int = -1
var _received: int = -1
var _err_no: int = -1
var _reason: String = "pending"

## 每次只接受一个有界请求，宿主缺失时不偷偷切换网络实现。
func start(url: String, expected_bytes: int) -> void:
	if _active: return
	_active = true
	_generation += 1
	_expected = expected_bytes
	diagnostic = ""
	_status = -1
	_received = -1
	_err_no = -1
	_reason = "pending"
	_transport = "http"
	if _timer == null:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(_timeout)
		add_child(_timer)
	_timer.start(30)
	if OS.has_feature("web") and (OS.has_feature("tt") or OS.has_feature("wechat")):
		_transport = "tt" if OS.has_feature("tt") else "wx"
		var host: JavaScriptObject = JavaScriptBridge.get_interface("tt" if OS.has_feature("tt") else "wx")
		if host == null or host.get("request") == null:
			_reason = "host_unavailable"
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
		var status: Error = _http.request(url)
		if status != OK:
			_err_no = status
			_reason = "request_start"
			_finish.call_deferred(PackedByteArray(), "无法发起资源下载。", _generation)

## 主动取消保持独立诊断，迟到回调不能提交新请求。
func cancel() -> void:
	if not _active: return
	_reason = "cancelled"
	_abort("资源下载已取消。")

## 中断先作废回调代次，避免宿主同步回调覆盖超时或取消的原因。
func _abort(message: String) -> void:
	_generation += 1
	if _task != null: _task.abort()
	if _http != null: _http.cancel_request()
	_finish(PackedByteArray(), message)

## JS 缓冲先检查长度，避免把无界响应复制进引擎内存。
func _host_success(args: Array, generation: int) -> void:
	if not _active or generation != _generation: return
	var response: JavaScriptObject = args[0] if not args.is_empty() else null
	if response == null:
		_reason = "empty_response"
		_finish.call_deferred(PackedByteArray(), "资源响应为空。", generation)
		return
	_status = diagnostic_number(response.statusCode)
	var data: Variant = response.data
	var buffer: bool = data is JavaScriptObject and JavaScriptBridge.is_js_buffer(data)
	_received = diagnostic_number(data.byteLength) if buffer else -1
	_reason = "http_status" if _status != 200 else ("buffer_type" if not buffer else "size_mismatch")
	if _status != 200 or not buffer or _received != _expected:
		_finish.call_deferred(PackedByteArray(), "资源响应状态或大小不匹配。", generation)
		return
	_reason = "ok"
	_finish.call_deferred(JavaScriptBridge.js_buffer_to_packed_byte_array(data), "", generation)

## 原始宿主错误只用于分类，保留数值错误码，不显示地址或响应内容。
func _host_failure(args: Array, generation: int) -> void:
	if not _active or generation != _generation: return
	var response: JavaScriptObject = args[0] if not args.is_empty() else null
	_err_no = diagnostic_number(response.errNo) if response != null else -1
	_reason = failure_reason(str(response.errMsg) if response != null else "", _err_no)
	_finish.call_deferred(PackedByteArray(), "资源下载失败，请检查网络与平台合法域名。", generation)

## 缺失或异常字段统一用 -1 表示未知，不把未知状态误报为零。
static func diagnostic_number(value: Variant) -> int:
	if (value is int or value is float) and is_finite(value) and value >= 0 and value <= 2147483647 and value == int(value): return int(value)
	return -1

## 仅输出固定分类；包含 URL、令牌或本地路径的错误文本不能流出适配层。
static func failure_reason(message: String, err_no: int) -> String:
	var reason: String = message.to_lower().get_slice("http", 0)
	if reason.contains("domain") or err_no == 21000: return "domain"
	if reason.contains("timeout") or reason.contains("timed out"): return "timeout"
	if reason.contains("certificate") or reason.contains("ssl") or reason.contains("tls"): return "tls"
	if reason.contains("resolve") or reason.contains("dns"): return "dns"
	if reason.contains("permission") or err_no == 21102: return "permission"
	if reason.contains("background") or err_no == 10501: return "background"
	if reason.contains("abort"): return "aborted"
	if reason.contains("connect") or reason.contains("network"): return "network"
	return "host_failure"

## 引擎网络同样要求完整成功响应，重定向与半包均拒绝。
func _http_completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray, generation: int) -> void:
	if not _active or generation != _generation: return
	_status = status
	_received = body.size()
	_err_no = result
	_reason = "ok" if result == HTTPRequest.RESULT_SUCCESS and status == 200 else "http_failure"
	_finish(body if result == HTTPRequest.RESULT_SUCCESS and status == 200 else PackedByteArray(), "" if result == HTTPRequest.RESULT_SUCCESS and status == 200 else "资源下载失败。", generation)

## 应用级计时保证基础库忽略 timeout 参数时仍能退出等待。
func _timeout() -> void:
	if not _active: return
	_reason = "timeout"
	_abort("资源下载超时。")

## 完成后释放请求对象，先解除活动状态再通知消费者。
func _finish(bytes: PackedByteArray, message: String, generation: int = -1) -> void:
	if not _active or generation >= 0 and generation != _generation: return
	_active = false
	_timer.stop()
	if _http != null: _http.queue_free(); _http = null
	_task = null
	if message.is_empty() and bytes.size() != _expected:
		_reason = "size_mismatch"
		_received = bytes.size()
		message = "资源下载不完整。"
	diagnostic = "transport=%s reason=%s\nHTTP=%d errNo=%d\nbytes=%d/%d" % [_transport, _reason, _status, _err_no, _received, _expected]
	completed.emit(bytes, message)

## 服务离树时终止本服务发起的请求，不影响其他网络任务。
func _exit_tree() -> void:
	cancel()
	_callbacks.clear()
