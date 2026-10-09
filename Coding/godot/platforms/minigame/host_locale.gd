extends RefCounted
## 为小游戏读取宿主语言；桌面和普通浏览器沿用 Godot 的系统语言。


## 页面首次装配时应用有效宿主语言，读取失败时保留当前语言。
static func apply() -> void:
	if not OS.has_feature("web"):
		return
	var bridge: JavaScriptObject = JavaScriptBridge.get_interface("__donutHostLocale")
	if bridge == null:
		return
	var locale: Variant = bridge.read()
	if locale is String and not locale.is_empty():
		TranslationServer.set_locale(locale)
