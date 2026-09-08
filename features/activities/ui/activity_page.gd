extends Control
## 活动页以统一画框和常驻页签呈现四个子页，只发出导航请求。

signal navigation_requested(id: String)

const UI = preload("res://ui/components/ui.gd")
const DESIGN_SIZE := Vector2(941, 1672)
const TAB_WIDTH := 217.75
const TAB_IDS: Array[String] = [
	"ActivityContractSummon",
	"ActivityLegendRoad",
	"ActivityDailyTask",
	"ActivitySevenSign",
]
const TITLES := {
	"Activity": "ui.page.activity",
	"ActivityContractSummon": "ui.home.contract_summon",
	"ActivityLegendRoad": "ui.page.legend_road",
	"ActivityDailyTask": "ui.page.daily_tasks",
	"ActivitySevenSign": "ui.page.seven_day_sign_in",
}

@export_enum("Activity", "ActivityContractSummon", "ActivityLegendRoad", "ActivityDailyTask", "ActivitySevenSign") var page_id: String = "Activity"

var _active_id: String
var _return_button: Button
var _tab_motion: Tween
@onready var tabs: StandardTabGroup = $Canvas/Tabs

## 关闭按钮沿用宿主输入，只替换为活动页内的菱形返回表现。
func bind_return_button(button: Button) -> void:
	_return_button = button
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for event: Signal in [button.button_down, button.button_up, button.mouse_entered, button.mouse_exited, button.focus_entered, button.focus_exited]:
		event.connect(_refresh_return_tint)

## 首次进入按页面身份选择页签；活动总入口默认落在契约召唤。
func _ready() -> void:
	assert(TITLES.has(page_id), "Unknown activity page: " + page_id)
	_active_id = _resolved_page_id()
	tabs.configure([
		{"id": TAB_IDS[0], "label": TITLES[TAB_IDS[0]]},
		{"id": TAB_IDS[1], "label": TITLES[TAB_IDS[1]]},
		{"id": TAB_IDS[2], "label": TITLES[TAB_IDS[2]]},
		{"id": TAB_IDS[3], "label": TITLES[TAB_IDS[3]]},
	], _active_id)
	tabs.selected.connect(_select_page)
	$Canvas/Previous.pressed.connect(_browse.bind(-1))
	$Canvas/Next.pressed.connect(_browse.bind(1))
	resized.connect(_layout_art)
	_render_page(false)
	_layout_art()

## 缓存页重开时恢复自己的稳定身份，不保留离开前的切换中间态。
func refresh() -> void:
	if _tab_motion != null and _tab_motion.is_valid():
		_tab_motion.kill()
		_tab_motion = null
	_active_id = _resolved_page_id()
	var handler := Callable(self, "_select_page")
	if tabs.selected.is_connected(handler): tabs.selected.disconnect(handler)
	tabs.try_select(_active_id)
	if not tabs.selected.is_connected(handler): tabs.selected.connect(handler)
	_render_page(false)

## 页签选择交回 Home 的既有页面缓存与导航，不创建活动内导航栈。
func _select_page(id: String) -> void:
	if not id in TAB_IDS or id == _active_id: return
	_update_tab_art(id, true)
	navigation_requested.emit(id)

## 左右箭头与页签使用同一选择入口，首尾不循环。
func _browse(direction: int) -> void:
	var index := TAB_IDS.find(_active_id)
	var target := clampi(index + direction, 0, TAB_IDS.size() - 1)
	if target != index: tabs.try_select(TAB_IDS[target])

## 当前占位只展示身份和未开放状态，不伪造活动数据或操作。
func _render_page(animate: bool) -> void:
	$Canvas/ReturnArt/Caption.text = TITLES[page_id]
	$Unavailable.present(TITLES[_active_id])
	var index := TAB_IDS.find(_active_id)
	$Canvas/Previous.visible = index > 0
	$Canvas/Next.visible = index < TAB_IDS.size() - 1
	_update_tab_art(_active_id, animate)
	_refresh_return_tint()

## 黑牌位置、图标和文字颜色共同表达唯一选中项。
func _update_tab_art(id: String, animate: bool) -> void:
	var target_x := TAB_IDS.find(id) * TAB_WIDTH - 12.0
	var duration := 0.22 if animate and is_visible_in_tree() else 0.0
	if duration > 0:
		_tab_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_tab_motion.tween_property($Canvas/Tabs/Bar/Selection, "position:x", target_x, duration)
	else:
		$Canvas/Tabs/Bar/Selection.position.x = target_x
	for tab_id: String in TAB_IDS:
		var button: Button = tabs.get_node("Bar/" + tab_id)
		var color := Color(0.87, 0.80, 0.61) if tab_id == id else Color(0.12, 0.10, 0.07)
		if duration > 0:
			_tab_motion.tween_property(button.get_node("Icon"), "self_modulate", color, duration)
			_tab_motion.tween_property(button.get_node("Caption"), "self_modulate", color, duration)
		else:
			button.get_node("Icon").self_modulate = color
			button.get_node("Caption").self_modulate = color

## 方案画布等比落在安全区，宿主关闭热区对齐左上角的菱形装饰。
func _layout_art() -> void:
	if not is_node_ready(): return
	var ratio := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	if ratio <= 0: return
	var origin := (size - DESIGN_SIZE * ratio) * 0.5
	$Canvas.position = origin
	$Canvas.scale = Vector2.ONE * ratio
	if is_instance_valid(_return_button):
		_return_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_return_button.size = Vector2(144, 144)
		_return_button.scale = Vector2.ONE * ratio
		_return_button.global_position = $Canvas/ReturnArt/Icon.get_global_rect().get_center() - _return_button.size * ratio * 0.5

## 返回装饰只跟随宿主按钮明度，不改变透明度或输入范围。
func _refresh_return_tint() -> void:
	if not is_node_ready() or not is_instance_valid(_return_button): return
	var brightness := UI.tokens.entry_normal_brightness
	if _return_button.is_pressed(): brightness = UI.tokens.entry_pressed_brightness
	elif _return_button.is_hovered() or _return_button.has_focus(): brightness = UI.tokens.entry_hover_brightness
	$Canvas/ReturnArt.modulate = Color(brightness, brightness, brightness)

## 活动总入口与四个直达入口最终都映射到真实子页身份。
func _resolved_page_id() -> String:
	return TAB_IDS[0] if page_id == "Activity" else page_id
