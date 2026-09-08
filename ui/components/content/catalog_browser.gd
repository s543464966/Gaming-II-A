extends "res://ui/components/content/catalog_page.gd"
## 藏品与图鉴共用的浏览外观：搜索、快捷筛选、统一返回和底部分页动画。

const TAB_MOTION_SECONDS: float = 0.28
enum FilterView { HIDDEN, OUTPUT_TYPE, ABILITY_FACET, ALL }
var _return_button: Button
var _tab_motion: Tween
var _search_text: String = ""
var _filter_view: FilterView = FilterView.HIDDEN
var _filter_available: Dictionary[String, bool] = {}
@onready var _search: LineEdit = %Search
@onready var _filter_toggle: Button = %FilterToggle
@onready var _filter_panel: PanelContainer = %FilterPanel
@onready var _quick_filters: PanelContainer = %QuickFilters
@onready var _quick_all: Button = %QuickAll
@onready var _quick_primary: Button = %QuickPrimary
@onready var _quick_secondary: Button = %QuickSecondary

## 保留宿主关闭入口，只把热区对齐到模式选择与活动共用的菱形返回装饰。
func bind_return_button(button: Button) -> void:
	_return_button = button
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for event: Signal in [button.button_down, button.button_up, button.mouse_entered, button.mouse_exited, button.focus_entered, button.focus_exited]:
		event.connect(_refresh_return_tint)

## Feature 先配置目录与操作，浏览层只连接输入和表现。
func _ready() -> void:
	_search.text_changed.connect(_search_changed)
	_filter_toggle.toggled.connect(set_filters_expanded)
	_quick_all.pressed.connect(_select_quick_filter.bind(0))
	_quick_primary.pressed.connect(_select_quick_filter.bind(1))
	_quick_secondary.pressed.connect(_select_quick_filter.bind(2))
	resized.connect(_layout_return_button)
	super._ready()
	tabs.get_node("Bar").resized.connect(_layout_category_tabs)
	visibility_changed.connect(_layout_category_tabs)
	_scroll.get_v_scroll_bar().modulate.a = 0.0
	set_filters_expanded(false)
	_refresh_category_tabs(false)
	_layout_return_button()
	_refresh_return_tint()

## 返回热区覆盖装饰图标，标题与按钮沿用模式选择页面的同一排布关系。
func _layout_return_button() -> void:
	if not is_node_ready() or not is_instance_valid(_return_button): return
	var icon_rect: Rect2 = %ReturnIcon.get_global_rect()
	_return_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_return_button.scale = Vector2.ONE
	_return_button.size = Vector2(108, 108)
	_return_button.global_position = icon_rect.get_center() - _return_button.size * 0.5
	var bounds_control := _return_button.get_parent() as Control
	if bounds_control == null: return
	var bounds: Rect2 = bounds_control.get_global_rect()
	var button_rect: Rect2 = _return_button.get_global_rect()
	var safe_position := Vector2(
		clampf(button_rect.position.x, bounds.position.x, bounds.end.x - button_rect.size.x),
		clampf(button_rect.position.y, bounds.position.y, bounds.end.y - button_rect.size.y)
	)
	_return_button.global_position += safe_position - button_rect.position

## 返回装饰只跟随宿主按钮明度，不复制另一套输入状态。
func _refresh_return_tint() -> void:
	if not is_node_ready() or not is_instance_valid(_return_button): return
	var brightness: float = UI.tokens.entry_normal_brightness
	if _return_button.is_pressed(): brightness = UI.tokens.entry_pressed_brightness
	elif _return_button.is_hovered() or _return_button.has_focus(): brightness = UI.tokens.entry_hover_brightness
	%ReturnArt.self_modulate = Color(brightness, brightness, brightness)

## 切换底部分类后回到目录顶部，并让唯一选中块平滑落位。
func _select_tab(id: String) -> void:
	var changed: bool = _current_tab != id
	if is_instance_valid(_scroll): _scroll.scroll_vertical = 0
	super._select_tab(id)
	_refresh_category_tabs(changed)

## 与模式选择一样移动唯一黑牌，并在同一动画中切换图标和文字颜色。
func _refresh_category_tabs(animate: bool = true) -> void:
	if not is_instance_valid(tabs): return
	cancel_transition()
	var active := tabs.get_node_or_null("Bar/" + tabs.selected_id) as Button
	var selection := tabs.get_node("Bar/Selection") as NinePatchRect
	selection.visible = active != null
	if active == null: return
	var bar := tabs.get_node("Bar") as Control
	var target_x: float = maxf(0.0, active.position.x - 1.0)
	var target_width: float = minf(bar.size.x, active.position.x + active.size.x + 1.0) - target_x
	var duration: float = TAB_MOTION_SECONDS if animate and is_visible_in_tree() else 0.0
	if duration > 0.0:
		_tab_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_tab_motion.tween_property(selection, "position:x", target_x, duration)
		_tab_motion.tween_property(selection, "size:x", target_width, duration)
	else:
		selection.position.x = target_x
		selection.size.x = target_width
	for option: Dictionary in tabs.options:
		var button := tabs.get_node("Bar/" + str(option.id)) as Button
		var selected: bool = tabs.selected_id == option.id
		var color := Color(0.87, 0.80, 0.61) if selected else Color(0.10, 0.09, 0.07)
		if duration > 0.0:
			_tab_motion.tween_property(button.get_node("Icon"), "self_modulate", color, duration)
			_tab_motion.tween_property(button.get_node("Caption"), "self_modulate", color, duration)
		else:
			button.get_node("Icon").self_modulate = color
			button.get_node("Caption").self_modulate = color

## 尺寸或缓存页可见性变化时直接对齐当前分类，避免保留半途滑动状态。
func _layout_category_tabs() -> void:
	_refresh_category_tabs(false)

## 宿主关闭页面或快速连点时停止旧动画，下次从当前黑牌位置继续。
func cancel_transition() -> void:
	if _tab_motion != null and _tab_motion.is_valid(): _tab_motion.kill()
	_tab_motion = null

## 浏览层在目录筛选上叠加名称与稳定 ID 搜索。
func _apply_filters(rows: Array) -> Array:
	var filtered: Array = super._apply_filters(rows)
	if _search_text.is_empty(): return filtered
	return filtered.filter(func(row):
		return str(row.get("name", row.id)).to_lower().contains(_search_text) or str(row.id).to_lower().contains(_search_text))

## 搜索只刷新当前分类并回到目录顶部。
func _search_changed(value: String) -> void:
	_search_text = value.strip_edges().to_lower()
	_scroll.scroll_vertical = 0
	_render(_apply_filters(query.call(_current_tab)))

## 筛选入口仅在当前分类存在候选时出现，默认收起以优先浏览卡牌。
func _update_filters(rows: Array) -> void:
	super._update_filters(rows)
	var available: bool = _filters.visible
	for group: String in FILTER_GROUPS:
		_filter_available[group] = _filter_columns[group].visible
	_quick_filters.visible = available
	_filter_toggle.visible = available
	if not available: _filter_view = FilterView.HIDDEN
	_apply_filter_view()

## 工具栏拥有面板展开状态，收起不会清空已选筛选条件。
func set_filters_expanded(expanded: bool) -> void:
	_filter_view = FilterView.ALL if expanded else FilterView.HIDDEN
	_apply_filter_view()

## 快捷条切换单一筛选维度，并清除隐藏维度避免不可见条件影响结果。
func _select_quick_filter(index: int) -> void:
	var group: String = ["", "output_types", "ability_facets"][index]
	for id: String in FILTER_GROUPS:
		if id == group: continue
		_filter_values[id] = ""
		var picker: OptionButton = _filter_pickers[id]
		if picker.item_count > 0: picker.select(0)
	_filter_view = FilterView.OUTPUT_TYPE if group == "output_types" else FilterView.ABILITY_FACET if group == "ability_facets" else FilterView.HIDDEN
	_filter_toggle.set_pressed_no_signal(false)
	_scroll.scroll_vertical = 0
	_apply_filter_view()
	_render(_apply_filters(query.call(_current_tab)))

## 下拉选项变化后同步折叠态提示，避免隐藏条件与“全部”状态相互矛盾。
func _select_filter(index: int, group: String) -> void:
	super._select_filter(index, group)
	_apply_filter_view()

## 快捷模式只显示对应下拉框，完整筛选显示卡牌标签、主输出和能力效果。
func _apply_filter_view() -> void:
	if not is_instance_valid(_filter_panel): return
	var has_filters: bool = _filters.visible
	var active_count: int = _active_filter_count()
	var single_active_filter: String = _single_active_filter(active_count)
	var all_selected: bool = active_count == 0 and _filter_view in [FilterView.HIDDEN, FilterView.ALL]
	var output_type_selected: bool = _filter_view == FilterView.OUTPUT_TYPE or single_active_filter == "output_types"
	var ability_facet_selected: bool = _filter_view == FilterView.ABILITY_FACET or single_active_filter == "ability_facets"
	_filter_panel.visible = has_filters and _filter_view != FilterView.HIDDEN
	_filter_toggle.set_pressed_no_signal(_filter_view == FilterView.ALL)
	_filter_toggle.self_modulate = Color(1.0, 0.84, 0.70, 1.0) if active_count > 0 else Color.WHITE
	_filter_columns.card_tags.visible = _filter_available.get("card_tags", false) and _filter_view == FilterView.ALL
	_filter_columns.output_types.visible = _filter_available.get("output_types", false) and _filter_view in [FilterView.OUTPUT_TYPE, FilterView.ALL]
	_filter_columns.ability_facets.visible = _filter_available.get("ability_facets", false) and _filter_view in [FilterView.ABILITY_FACET, FilterView.ALL]
	_set_quick_selected(0 if all_selected else 1 if output_type_selected else 2 if ability_facet_selected else -1)

## 快捷栏只维护一组选中表现，具体身份由 Feature 决定；负数表示没有单项选中。
func _set_quick_selected(index: int) -> void:
	var buttons: Array[Button] = [_quick_all, _quick_primary, _quick_secondary]
	for slot: int in range(buttons.size()):
		buttons[slot].set_pressed_no_signal(slot == index)
		buttons[slot].get_node("Indicator").visible = slot == index

## 折叠提示只统计当前分类仍然有效的非空筛选维度。
func _active_filter_count() -> int:
	var count: int = 0
	for group: String in FILTER_GROUPS:
		if not str(_filter_values.get(group, "")).is_empty(): count += 1
	return count

## 折叠时仅让唯一生效的快捷维度保持高亮，多维组合不误亮任一入口。
func _single_active_filter(active_count: int) -> String:
	if _filter_view != FilterView.HIDDEN or active_count != 1: return ""
	for group: String in FILTER_GROUPS:
		if not str(_filter_values.get(group, "")).is_empty(): return group
	return ""
