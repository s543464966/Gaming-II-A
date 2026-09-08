extends VBoxContainer
## 登录与设置共用语言选择组件；列表来自已打包且开放的语言。

var service: LocalizationService
@onready var picker: OptionButton = $Picker
@onready var feedback: Label = $Feedback

## 单语言包隐藏选择控件，偏好损坏提示仍可见。
func _ready() -> void:
	if service == null or service.available.is_empty():
		hide()
		return
	$Title.visible = service.available.size() > 1
	picker.visible = service.available.size() > 1
	picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for locale in service.available: picker.add_item(locale.native_name)
	picker.item_selected.connect(_selected)
	service.locale_changed.connect(_locale_changed)
	_locale_changed(service.current_locale)

## 语言保存失败还原选项，避免下拉框与真实显示语言分离。
func _selected(index: int) -> void:
	service.select_locale(service.available[index].id)
	_locale_changed(service.current_locale)

## 其他入口切换语言时同步选项，不重复触发用户选择信号。
func _locale_changed(locale: String) -> void:
	for index in range(service.available.size()):
		if service.available[index].id == locale: picker.select(index)
	feedback.text = service.error if not service.error.is_empty() else service.preference_warning
	feedback.visible = not feedback.text.is_empty()
	visible = service.available.size() > 1 or not feedback.text.is_empty()
