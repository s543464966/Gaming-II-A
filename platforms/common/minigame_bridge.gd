extends RefCounted
## 微信与抖音共有的宿主事件契约，只绑定回调，不持有玩法状态。

var _platform: Node
var _host: JavaScriptObject
var _bindings: Array = []

## 平台适配器明确指定宿主名称，缺失宿主返回失败供入口回退。
func attach(platform: Node, host_name: String) -> bool:
	_host = JavaScriptBridge.get_interface(host_name)
	if _host == null: return false
	_platform = platform
	_bind("onHide", "offHide", _on_hide)
	_bind("onShow", "offShow", _on_show)
	_bind("onWindowResize", "offWindowResize", _on_resize)
	_refresh_safe_area()
	return true

## 隐藏只提交平台信号，保存与暂停由应用处理。
func _on_hide(_args: Array) -> void:
	_platform.set_suspended(true)

## 显示先更新宿主尺寸，再恢复应用状态。
func _on_show(_args: Array) -> void:
	_refresh_safe_area()
	_platform.set_suspended(false)

## 宿主缩放不改变战斗或账号状态。
func _on_resize(_args: Array) -> void:
	_refresh_safe_area()

## 保存回调强引用直到解绑，避免跨语言回调提前回收。
func _bind(on: String, off: String, callable: Callable) -> void:
	var method = _host.get(on)
	if method == null: return
	var callback = JavaScriptBridge.create_callback(callable)
	method.call(_host, callback)
	_bindings.append({"off": off, "callback": callback})

## 宿主 JSON 只送交平台状态边界，不绕过统一安全区校验。
func _refresh_safe_area() -> void:
	var info = _read_host_dictionary("getWindowInfo")
	if info.is_empty(): info = _read_host_dictionary("getSystemInfoSync")
	info.menuButton = _read_host_dictionary("getMenuButtonBoundingClientRect")
	_platform.update_safe_area(info)

## 可选宿主能力缺失时回退空对象，不构造未经支持的平台状态。
func _read_host_dictionary(method: String) -> Dictionary:
	var getter = _host.get(method)
	if getter == null: return {}
	var json = JavaScriptBridge.get_interface("JSON")
	var parsed = JSON.new()
	if parsed.parse(String(json.stringify(getter.call(_host)))) == OK and parsed.data is Dictionary:
		return parsed.data
	return {}

## 成对解绑全部已注册事件，支持应用结束与编辑器重新运行。
func unbind() -> void:
	for binding in _bindings:
		var method = _host.get(binding.off)
		if method != null: method.call(_host, binding.callback)
	_bindings.clear()
	_host = null
	_platform = null
