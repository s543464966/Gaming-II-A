class_name DonutFailurePanel
extends ColorRect
## 展示失败插画与双按钮，向页面转发返回和重试意图。

signal home_requested
signal retry_requested

const BODY_ZH: Texture2D = preload("res://features/donut_sort/failure/ui/art/failure_popup_body_zh.tres")
const BODY_BLANK: Texture2D = preload("res://features/donut_sort/failure/ui/art/failure_popup_body_blank.tres")

var _touch_index: int = -1 # 仅跟踪首个手指；负一表示没有按钮触摸。
var _touch_button: TextureButton


## 绑定图片按钮，按压反馈在取消与生命周期中断时统一复原。
func _ready() -> void:
	$Card/Home.pressed.connect(_request_action.bind(false))
	$Card/TryAgain.pressed.connect(_request_action.bind(true))
	for button: BaseButton in [$Card/Home, $Card/TryAgain]:
		button.button_down.connect(func() -> void: button.self_modulate = Color(0.86, 0.86, 0.86, 1))
		button.button_up.connect(reset_feedback)
		button.mouse_exited.connect(reset_feedback)
	visibility_changed.connect(reset_feedback)
	_sync_localized_body()


## 运行中切换语言时同步面板图片，未就绪阶段由首次装配处理。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_sync_localized_body()


## 中文保留定稿立体字，其他语言在同款去字底图上显示翻译，避免文字叠印。
func _sync_localized_body() -> void:
	var chinese: bool = TranslationServer.get_locale().get_slice("_", 0) == "zh"
	$Card/Panel.texture = BODY_ZH if chinese else BODY_BLANK
	$Card/Heading/Text.visible = not chinese
	$Card/Subtitle.visible = not chinese


## 每次出现都启用两个动作，不沿用上次面板的按压状态。
func present() -> void:
	$Card/Home.disabled = false
	$Card/TryAgain.disabled = false
	reset_feedback()
	show()


## 一次点击只请求一个动作，具体会话修改由页面延迟执行。
func _request_action(retry: bool) -> void:
	$Card/Home.disabled = true
	$Card/TryAgain.disabled = true
	reset_feedback()
	if retry:
		retry_requested.emit()
	else:
		home_requested.emit()


## 清除中断的按压反馈，保留失败面板和会话结果。
func reset_feedback() -> void:
	_touch_index = -1
	_touch_button = null
	if not is_node_ready():
		return
	for button: BaseButton in [$Card/Home, $Card/TryAgain]:
		button.self_modulate = Color.WHITE
		button.set_pressed_no_signal(false)


## 原生触摸独立处理取消和离开按钮，屏蔽其模拟鼠标以避免重复触发。
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
		if event.pressed and _touch_index < 0:
			for button: TextureButton in [$Card/Home, $Card/TryAgain]:
				if not button.disabled and button.get_global_rect().has_point(event.position):
					_touch_index = event.index
					_touch_button = button
					button.self_modulate = Color(0.86, 0.86, 0.86, 1)
		elif not event.pressed and event.index == _touch_index:
			var button: TextureButton = _touch_button
			var activate: bool = not event.canceled and button.get_global_rect().has_point(event.position)
			reset_feedback()
			if activate and not button.disabled:
				_request_action(button == $Card/TryAgain)
	elif event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
		if event.index == _touch_index:
			_touch_button.self_modulate = Color(0.86, 0.86, 0.86, 1) if _touch_button.get_global_rect().has_point(event.position) else Color.WHITE
