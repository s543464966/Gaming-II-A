class_name StandardTabGroup
extends "res://ui/components/touch_scroll_container.gd"
## 标准页签唯一拥有选择与显隐，稳定 ID 不随排序变化。

signal selected(id: String)
enum Presentation { CONTENT, FOOTER }
@export var presentation: Presentation = Presentation.CONTENT
@export var authored_buttons: Array[NodePath] = []
const UI = preload("res://ui/components/ui.gd")
var selected_id: String = ""
var options: Array = []
var _buttons: Dictionary = {}
var _row: HBoxContainer

## 已编排按钮保留场景布局；普通页签自动创建等宽滚动容器。
func _ready() -> void:
	set_touch_scrolling_enabled(authored_buttons.is_empty())
	if not authored_buttons.is_empty():
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_rebuild()
		return
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	custom_minimum_size.y = UI.tokens.button_height + 12
	_row = HBoxContainer.new()
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_row)
	resized.connect(_layout)
	_rebuild()

## 配置 ID、名称、显隐与交互，不保存另一份 Feature 选择。
func configure(values: Array, initial: String = "") -> void:
	options = values.duplicate(true)
	if selected_id.is_empty(): selected_id = initial
	if is_node_ready(): _rebuild()

## 当前项隐藏后自动回退，全部不可用时发出空选择。
func set_tab_visible(id: String, visible: bool) -> void:
	for option in options:
		if option.id == id: option.visible = visible
	_rebuild()

## 禁用与选中状态独立，当前选中按钮仍可交互。
func set_tab_interactable(id: String, interactable: bool) -> void:
	for option in options:
		if option.id == id: option.interactable = interactable
	_rebuild()

## 快捷入口也必须通过同一可见与交互规则。
func try_select(id: String) -> bool:
	if not _available(id): return false
	var changed = selected_id != id
	selected_id = id
	_refresh_buttons()
	if changed: selected.emit(id)
	return true

## 刷新配置时只在原选择失效后回退。
func _rebuild() -> void:
	if not is_node_ready(): return
	if is_instance_valid(_row): UI.clear(_row)
	_buttons.clear()
	for option in options:
		var button: Button
		if authored_buttons.is_empty():
			button = UI.button(option.label, func(): try_select(option.id))
			button.custom_minimum_size = Vector2(128, UI.tokens.button_height)
			if presentation == Presentation.FOOTER: button.theme_type_variation = &"FooterTabButton"
			_row.add_child(button)
		else:
			for path in authored_buttons:
				var candidate: Button = get_node(path)
				if str(candidate.name) == option.id: button = candidate
			if button == null: continue
			var activate: Callable = try_select.bind(str(option.id))
			if not button.pressed.is_connected(activate): button.pressed.connect(activate)
		button.toggle_mode = true
		button.visible = option.get("visible", true)
		button.disabled = not option.get("interactable", true)
		_buttons[option.id] = button
	var previous = selected_id
	if not _available(selected_id):
		selected_id = ""
		for option in options:
			if _available(option.id):
				selected_id = option.id
				break
	_refresh_buttons()
	_layout()
	if previous != selected_id: selected.emit(selected_id)

## 可见入口等宽，隐藏入口不占任何布局空间。
func _layout() -> void:
	if not is_instance_valid(_row): return
	var count = options.filter(func(option): return option.get("visible", true)).size()
	var minimum: float = 128
	var padding: float = 16 if presentation == Presentation.FOOTER else 40
	for option in options:
		if not option.get("visible", true): continue
		var button: Button = _buttons[option.id]
		var font = button.get_theme_font("font")
		var label = button.tr(option.label)
		minimum = maxf(minimum, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x + padding)
	for button in _buttons.values(): button.custom_minimum_size.x = minimum
	_row.custom_minimum_size.x = maxf(size.x, count * minimum + maxi(0, count - 1) * 12)

## 原生控件更新译文后重算等宽，不改变选择或显隐配置。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _layout.call_deferred()

## 选中样式不通过禁用按钮表达。
func _refresh_buttons() -> void:
	for id in _buttons:
		_buttons[id].set_pressed_no_signal(id == selected_id)
	_reveal_selected.call_deferred()

## 延后布局时重新解析当前按钮，避免显隐重建后滚向已移除的旧节点。
func _reveal_selected() -> void:
	if not authored_buttons.is_empty(): return
	if not is_inside_tree() or not _buttons.has(selected_id): return
	var button: Control = _buttons[selected_id]
	if is_instance_valid(button) and is_ancestor_of(button): ensure_control_visible(button)

## 稳定身份不存在时不能误选默认分类。
func _available(id: String) -> bool:
	for option in options:
		if option.id == id: return option.get("visible", true) and option.get("interactable", true)
	return false
