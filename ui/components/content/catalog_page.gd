class_name CatalogPage
extends Control
## 可复用目录表现：Feature 提供条目与详情，不在组件内查询业务状态。

const UI = preload("res://ui/components/ui.gd")
const CARD = preload("res://ui/components/content/catalog_card.tscn")
const FILTER_GROUPS: Array[String] = ["card_tags", "output_types", "ability_facets"]
var query: Callable
var describe: Callable
var actions: Callable
var overlays: CanvasLayer
var tabs: ScrollContainer
var _options: Array = []
var _grid: GridContainer
var _scroll: ScrollContainer
var _filters: HBoxContainer
var _filter_columns: Dictionary = {}
var _filter_pickers: Dictionary = {}
var _filter_options: Dictionary = {}
var _filter_values: Dictionary = {}
var _popup: ContentPopup
var _current_tab: String = ""
var _detail_id: String = ""

## 数据来源与账号依赖由具体 Feature 决定。
func configure(options: Array, rows: Callable, detail: Callable, buttons: Callable = Callable()) -> void:
	_options = options
	query = rows
	describe = detail
	actions = buttons

## 页面只拥有目录，详情通过显式注入的全局浮层展示。
func _ready() -> void:
	tabs = %Tabs
	_scroll = %Catalog
	_grid = %Grid
	_filters = %Filters
	_filter_columns = {"card_tags": %CardTag, "output_types": %OutputType, "ability_facets": %AbilityFacet}
	_filter_pickers = {"card_tags": %CardTagPicker, "output_types": %OutputTypePicker, "ability_facets": %AbilityFacetPicker}
	for group: String in FILTER_GROUPS:
		var picker: OptionButton = _filter_pickers[group]
		picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		picker.fit_to_longest_item = false
		picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		picker.item_selected.connect(_select_filter.bind(group))
	tabs.configure(_options)
	tabs.selected.connect(_select_tab)
	_scroll.resized.connect(_layout_grid)
	_select_tab(tabs.selected_id)

## 页面重开刷新拥有与价格，但保留仍可用的分类。
func refresh() -> void:
	if is_instance_valid(_grid): _select_tab(tabs.selected_id)

## 切分类清空旧详情，隐藏分类不能通过入口查询。
func _select_tab(id: String) -> void:
	if is_instance_valid(_popup): overlays.close_modal()
	_current_tab = id
	_detail_id = ""
	if not is_instance_valid(_grid): return
	var rows: Array = [] if id.is_empty() else query.call(id)
	_update_filters(rows)
	_render(_apply_filters(rows))

## 当前分类的实际卡牌决定标签、主输出和能力效果候选，非卡牌分类清空筛选。
func _update_filters(rows: Array) -> void:
	var has_filters: bool = false
	for group: String in FILTER_GROUPS:
		var options: Array = _facet_options(rows, group)
		_filter_options[group] = options
		_filter_values[group] = _valid_filter(str(_filter_values.get(group, "")), options)
		var column: Control = _filter_columns[group]
		column.visible = not options.is_empty()
		has_filters = has_filters or column.visible
		var picker: OptionButton = _filter_pickers[group]
		_rebuild_picker(picker, options, str(_filter_values[group]))
	_filters.visible = has_filters

## 筛选候选按数据顺序稳定排列，同一身份在多张卡中只显示一次。
func _facet_options(rows: Array, group: String) -> Array:
	var unique: Dictionary = {}
	for row in rows:
		for facet in row.get("filter_facets", {}).get(group, []):
			if facet is Dictionary and not str(facet.get("id", "")).is_empty(): unique[facet.id] = facet
	var result: Array = unique.values()
	result.sort_custom(func(a, b): return a.get("sort_order", 0) < b.get("sort_order", 0) if a.get("sort_order", 0) != b.get("sort_order", 0) else a.id < b.id)
	return result

## 仅当稳定筛选身份仍存在时保留选择，否则回到全部。
func _valid_filter(id: String, options: Array) -> String:
	return id if options.any(func(option): return option.id == id) else ""

## 下拉框显示当前语言名称，元数据保留不随翻译变化的筛选身份。
func _rebuild_picker(picker: OptionButton, options: Array, selected: String) -> void:
	picker.clear()
	picker.add_item(ContentText.text("ui.category.all"))
	picker.set_item_metadata(0, "")
	var selected_index: int = 0
	for option in options:
		picker.add_item(option.label)
		var index: int = picker.item_count - 1
		picker.set_item_metadata(index, option.id)
		if option.id == selected: selected_index = index
	picker.select(selected_index)

## 三个维度使用交集筛选，切换筛选不会修改 Feature 的目录来源。
func _select_filter(index: int, group: String) -> void:
	var picker: OptionButton = _filter_pickers[group]
	if index < 0 or index >= picker.item_count: return
	if is_instance_valid(_popup): overlays.close_modal()
	_detail_id = ""
	_filter_values[group] = str(picker.get_item_metadata(index))
	_scroll.scroll_vertical = 0
	_render(_apply_filters(query.call(_current_tab)))

## 空筛选表示全部，卡牌标签、主输出和能力效果选中时必须同时匹配。
func _apply_filters(rows: Array) -> Array:
	return rows.filter(_matches_filters)

## 每个筛选组只匹配自己的稳定身份，避免主输出与能力效果混用。
func _matches_filters(row: Dictionary) -> bool:
	var facets: Dictionary = row.get("filter_facets", {})
	for group: String in FILTER_GROUPS:
		var selected: String = str(_filter_values.get(group, ""))
		if not selected.is_empty() and not facets.get(group, []).any(func(value): return value.id == selected): return false
	return true

## 根据筛选后的目录重新生成卡片，空结果仍使用统一空态。
func _render(rows: Array) -> void:
	UI.clear(_grid)
	if rows.is_empty():
		var empty: Label = UI.label("ui.catalog.empty", 24)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_grid.add_child(empty)
		_layout_grid()
		return
	for row in rows:
		var button = CARD.instantiate()
		button.set_meta("content_id", row.id)
		button.tooltip_text = row.get("name", row.id)
		button.pressed.connect(_open_detail.bind(row))
		_grid.add_child(button)
		var picture: ContentArtwork = button.get_node("Picture")
		picture.present(row)
	_layout_grid()

## 常规宽度每排四张，卡牌占满分配宽度；窄容器减少列数而不挤压卡面。
func _layout_grid() -> void:
	if not is_node_ready(): return
	var available: float = maxf(1, _scroll.size.x - _scroll.get_v_scroll_bar().get_combined_minimum_size().x)
	if _grid.get_child_count() == 1 and not _grid.get_child(0).has_meta("content_id"):
		_grid.columns = 1
		_grid.get_child(0).custom_minimum_size = Vector2(available, 96)
		return
	_grid.columns = 4 if available >= 570 else 3 if available >= 420 else 2
	var gap: int = _grid.get_theme_constant("h_separation")
	var width: float = maxf(1, floorf((available - gap * (_grid.columns - 1)) / _grid.columns))
	for item: Control in _grid.get_children():
		if item.has_meta("content_id"):
			item.custom_minimum_size = Vector2(width, ceilf(width * 1.2352))

## 详情不替换目录，关闭后原分类、卡牌位置和滚动位置保持不变。
func _open_detail(row: Dictionary) -> void:
	if overlays == null: return
	var popup: ContentPopup = overlays.open_content(_presentation.bind(row.id), actions)
	_popup = popup
	_detail_id = row.id
	popup.closed.connect(func():
		if _popup == popup:
			_popup = null
			_detail_id = "")

## 每次绑定重新查询当前业务记录，不保存第二份拥有、价格或成长状态。
func _presentation(id: String) -> Dictionary:
	for row in query.call(_current_tab):
		if row.id == id: return {"entry": row, "detail": describe.call(row)}
	return {}

## 切语言只重绑文本，保留分类、详情身份及两侧滚动位置。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _translate_view.call_deferred()

## 绕过业务切分类回调，避免切语言撤销购买确认或改变页面状态。
func _translate_view() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not query.is_valid(): return
	var source: Array = query.call(_current_tab)
	_update_filters(source)
	var rows: Array = _apply_filters(source)
	var buttons = _grid.get_children()
	if buttons.size() != rows.size():
		_render(rows)
		return
	for index in range(mini(rows.size(), buttons.size())):
		var button = buttons[index]
		if not button.has_node("Picture"): continue
		button.tooltip_text = rows[index].get("name", rows[index].id)
		button.get_node("Picture").present(rows[index])
