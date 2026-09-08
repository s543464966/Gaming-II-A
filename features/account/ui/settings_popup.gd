class_name AccountSettingsPopup
extends Control
## Home 设置小弹窗；只绑定语言服务与本机玩家说明，不持有账号状态。

signal close_requested
const PANEL_SIZE := Vector2(468, 548)
var localization: LocalizationService
var platform: Node
@onready var panel: Control = $SafeArea/Bounds/Panel
@onready var language_selector: Control = $SafeArea/Bounds/Panel/Content/Column/LanguageSelector

## 子组件入树前接收语言服务和纸面样式，避免以空依赖执行初始化。
func _enter_tree() -> void:
	var selector: Control = $SafeArea/Bounds/Panel/Content/Column/LanguageSelector
	selector.service = localization
	selector.get_node("Title").theme_type_variation = &"DetailHeading"
	selector.get_node("Title").add_theme_font_size_override("font_size", 24)
	var picker: OptionButton = selector.get_node("Picker")
	picker.theme_type_variation = &"DetailActionButton"
	picker.custom_minimum_size.y = 80
	picker.add_theme_font_size_override("font_size", 28)
	_add_picker_arrow(picker)
	selector.get_node("Feedback").theme_type_variation = &"DetailCaption"

## 场景只连接关闭、遮罩和自适应布局，不提交玩家数据。
func _ready() -> void:
	$Shade.color = GameUI.tokens.modal_shade
	$SafeArea.configure(platform)
	$Shade.gui_input.connect(_outside_input)
	$SafeArea/Bounds.resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	$SafeArea/Bounds/Panel/Title/Close.pressed.connect(close_requested.emit)
	var done: Button = $SafeArea/Bounds/Panel/Content/Column/Done
	done.pressed.connect(close_requested.emit)
	done.button_down.connect(_set_done_pressed.bind(true))
	done.button_up.connect(_set_done_pressed.bind(false))
	done.mouse_exited.connect(_set_done_pressed.bind(false))
	$SafeArea/Bounds/Panel/Title/Close.accessibility_name = ContentText.text("ui.common.close")
	_layout()
	done.grab_focus()

## 纸面下拉框补充明确墨色箭头，保持原生选项列表与键盘操作不变。
func _add_picker_arrow(picker: OptionButton) -> void:
	var arrow := Label.new()
	arrow.name = "SchemeArrow"
	arrow.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	arrow.offset_left = -52
	arrow.offset_right = -14
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.text = "▼"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.add_theme_color_override("font_color", GameUI.tokens.detail_ink_color)
	arrow.add_theme_font_size_override("font_size", 22)
	picker.add_child(arrow)

## 透明触控区只改变内层纸按钮明暗，不放大方案一的可见按钮。
func _set_done_pressed(pressed: bool) -> void:
	$SafeArea/Bounds/Panel/Content/Column/Done/Visual.modulate = Color(0.86, 0.86, 0.86) if pressed else Color.WHITE

## 弹窗按安全区等比收缩并居中，保持标题与纸面切角比例不变。
func _layout() -> void:
	if not is_node_ready(): return
	var available: Vector2 = $SafeArea/Bounds.size
	var factor: float = minf(1.0, minf(available.x * 0.86 / PANEL_SIZE.x, available.y * 0.72 / PANEL_SIZE.y))
	panel.size = PANEL_SIZE
	panel.scale = Vector2.ONE * factor
	panel.position = (available - PANEL_SIZE * factor) * 0.5

## 点按弹窗外只请求关闭，并拦截事件避免触发底层 Home 入口。
func _outside_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		close_requested.emit()

## 返回键与关闭按钮等价，不改变语言之外的任何会话状态。
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()

## 切换语言时同步关闭入口的无障碍名称，原生控件文字由翻译系统自动刷新。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		$SafeArea/Bounds/Panel/Title/Close.accessibility_name = ContentText.text("ui.common.close")
