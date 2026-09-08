extends RefCounted
## 标准浏览器可见性与画布安全区适配；CSS 像素在平台边界统一归一化。

var _platform: Node
var _document: JavaScriptObject
var _callback: JavaScriptObject
var _resize_callback: JavaScriptObject
var _window: JavaScriptObject
var _visual_viewport: JavaScriptObject
var _probe: JavaScriptObject
var _canvas: JavaScriptObject
var _observer: JavaScriptObject

## 绑定当前页面而非任何业务页面；桌面调用安全返回失败。
func bind(platform: Node) -> bool:
	_document = JavaScriptBridge.get_interface("document")
	if _document == null: return false
	_platform = platform
	_callback = JavaScriptBridge.create_callback(_visibility_changed)
	_document.addEventListener("visibilitychange", _callback)
	_window = _document.defaultView
	_canvas = _document.getElementById("canvas")
	_probe = _document.createElement("div")
	_probe.style.cssText = "position:fixed;visibility:hidden;pointer-events:none;padding:env(safe-area-inset-top,0px) env(safe-area-inset-right,0px) env(safe-area-inset-bottom,0px) env(safe-area-inset-left,0px)"
	_document.body.appendChild(_probe)
	_resize_callback = JavaScriptBridge.create_callback(_refresh_safe_area)
	_window.addEventListener("resize", _resize_callback)
	_visual_viewport = _window.visualViewport
	if _visual_viewport != null:
		_visual_viewport.addEventListener("resize", _resize_callback)
		_visual_viewport.addEventListener("scroll", _resize_callback)
	if _window.get("ResizeObserver") != null and _canvas != null:
		_observer = JavaScriptBridge.create_object("ResizeObserver", _resize_callback)
		_observer.observe(_canvas)
	_visibility_changed([])
	return true

## 浏览器隐藏映射为同一平台暂停语义。
func _visibility_changed(_args: Array) -> void:
	_refresh_safe_area([])
	_platform.set_suspended(bool(_document.hidden))

## 屏幕、可见窗口与画布坐标保持同一 CSS 单位，兼容嵌入式画布及浏览器工具栏。
func _refresh_safe_area(_args: Array) -> void:
	if _window == null or _probe == null: return
	var width = float(_window.innerWidth)
	var height = float(_window.innerHeight)
	var style = _window.getComputedStyle(_probe)
	var left = String(style.paddingLeft).to_float()
	var top = String(style.paddingTop).to_float()
	var right = width - String(style.paddingRight).to_float()
	var bottom = height - String(style.paddingBottom).to_float()
	if _visual_viewport != null:
		left = maxf(left, float(_visual_viewport.offsetLeft))
		top = maxf(top, float(_visual_viewport.offsetTop))
		right = minf(right, float(_visual_viewport.offsetLeft) + float(_visual_viewport.width))
		bottom = minf(bottom, float(_visual_viewport.offsetTop) + float(_visual_viewport.height))
	var info = {"screenWidth": width, "screenHeight": height, "safeArea": {"left": left, "top": top, "right": right, "bottom": bottom}}
	if _canvas != null:
		var bounds = _canvas.getBoundingClientRect()
		info.merge({"screenLeft": float(bounds.left), "screenTop": float(bounds.top), "windowWidth": float(bounds.width), "windowHeight": float(bounds.height)})
	_platform.update_safe_area(info)

## 释放文档监听与跨语言引用，避免页面退出后仍有通知。
func unbind() -> void:
	if _document != null: _document.removeEventListener("visibilitychange", _callback)
	if _window != null: _window.removeEventListener("resize", _resize_callback)
	if _visual_viewport != null:
		_visual_viewport.removeEventListener("resize", _resize_callback)
		_visual_viewport.removeEventListener("scroll", _resize_callback)
	if _observer != null: _observer.get("disconnect").call(_observer)
	if _probe != null: _probe.remove()
	_observer = null
	_probe = null
	_canvas = null
	_visual_viewport = null
	_window = null
	_resize_callback = null
	_callback = null
	_document = null
	_platform = null
