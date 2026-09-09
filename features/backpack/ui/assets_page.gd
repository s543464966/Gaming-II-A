extends Control
## 账号背包以固定横向详情、四列堆叠网格和底部分类展示真实资产。

const UI = preload("res://ui/components/ui.gd")
const C = preload("res://game_content/runtime/content_types.gd")
const Slot = preload("res://features/backpack/ui/asset_slot.tscn")
const CATEGORIES: Array[Dictionary] = [
	{"id": "None", "label": "ui.category.all"},
	{"id": "Material", "label": "ui.category.material"},
	{"id": "Prop", "label": "ui.category.item"},
]

var session: RefCounted
var _entries: Array[Dictionary] = []
var _selected_key: String = ""
var _refresh_queued: bool = false
var _reset_scroll: bool = false

@onready var tabs: StandardTabGroup = %Tabs
@onready var _grid: GridContainer = %Grid
@onready var _scroll: TouchScrollContainer = %Inventory
@onready var _detail: Control = %Detail
@onready var _detail_scroll: TouchScrollContainer = %DetailScroll
@onready var _portrait: TextureRect = %Portrait
@onready var _name: Label = %ItemName
@onready var _owned: Label = %Owned
@onready var _description: Label = %Description
@onready var _stack_limit: Label = %StackLimit
@onready var _selection: NinePatchRect = %TabSelection

## 只订阅注入的账号资产，不持有存档或复制可修改的物品状态。
func bind_player(player: RefCounted) -> void:
	if session != null and session.assets.changed.is_connected(refresh):
		session.assets.changed.disconnect(refresh)
	session = player
	if session != null: session.assets.changed.connect(refresh)
	refresh()

## 分类沿用公共页签与触摸组件，F6 未注入会话时只呈现空布局。
func _ready() -> void:
	tabs.configure(CATEGORIES, "None")
	tabs.selected.connect(_select_category)
	tabs.get_node("Bar").resized.connect(_update_tabs)
	_scroll.resized.connect(_layout_grid)
	resized.connect(_layout_detail)
	visibility_changed.connect(_on_visibility_changed)
	_layout_detail()
	_update_tabs()
	refresh()

## 合并同一帧的资产通知，延后重建以避开按钮释放和事务中间状态。
func refresh() -> void:
	if not is_node_ready() or not is_visible_in_tree() or _refresh_queued: return
	_refresh_queued = true
	_rebuild.call_deferred()

## 分类切换重置列表位置，物品选择仍由同一组真实堆叠决定。
func _select_category(_id: String) -> void:
	_reset_scroll = true
	_update_tabs()
	refresh()

## 隐藏页面不重建内容，缓存返回时从当前会话重新读取。
func _on_visibility_changed() -> void:
	if is_visible_in_tree(): refresh()

## UI 键由物品身份与堆叠序号组成，数量刷新不会把选中态指向其他物品。
func _rebuild() -> void:
	_refresh_queued = false
	if not is_inside_tree() or not is_visible_in_tree(): return
	var previous_id: String = str(_selected_entry().get("id", ""))
	var previous_key: String = _selected_key
	var previous_scroll: int = _scroll.scroll_vertical
	_entries.clear()
	UI.clear(_grid)
	var ordinals: Dictionary[String, int] = {}
	if session != null:
		for stack: Dictionary in session.assets.display_stacks(C.Item[tabs.selected_id]):
			var id: String = stack.id
			var ordinal: int = ordinals.get(id, 0)
			ordinals[id] = ordinal + 1
			var record: Dictionary = session.content.get_record("items", id)
			var entry: Dictionary = {"key": "%s:%d" % [id, ordinal], "id": id, "quantity": stack.quantity,
				"record": record, "texture": session.content.resource(record.get("texture_key", ""))}
			_entries.append(entry)
			var button: Button = Slot.instantiate()
			_grid.add_child(button)
			var icon: TextureRect = button.get_node("Icon")
			var missing_art: bool = entry.texture == null
			icon.texture = _entry_texture(entry)
			button.get_node("FallbackName").visible = missing_art
			if missing_art:
				icon.offset_bottom = -92
				icon.self_modulate = UI.tokens.detail_gold_color
				button.get_node("FallbackName").text = ContentText.field(record)
			button.get_node("Quantity").text = "×%d" % stack.quantity
			button.tooltip_text = ContentText.field(record)
			button.pressed.connect(_select_slot.bind(str(entry.key)))
	if _selected_entry().is_empty():
		_selected_key = ""
		for entry: Dictionary in _entries:
			if entry.id == previous_id:
				_selected_key = entry.key
				break
		if _selected_key.is_empty() and not _entries.is_empty(): _selected_key = _entries[0].key
	_layout_grid()
	_present_selection()
	if _reset_scroll or previous_key != _selected_key: _detail_scroll.scroll_vertical = 0
	_scroll.set_deferred("scroll_vertical", 0 if _reset_scroll else previous_scroll)
	_reset_scroll = false

## 轻点仅更新内嵌详情，不重建按钮，也不打开全局弹窗。
func _select_slot(key: String) -> void:
	_selected_key = key
	_detail_scroll.scroll_vertical = 0
	_present_selection()

## 查询当前展示切片，不将条目内容写回账号资产。
func _selected_entry() -> Dictionary:
	for entry: Dictionary in _entries:
		if entry.key == _selected_key: return entry
	return {}

## 格子显示当前堆数量，详情显示总拥有量与静态堆叠上限。
func _present_selection() -> void:
	for index: int in _entries.size():
		(_grid.get_child(index) as Button).set_pressed_no_signal(_entries[index].key == _selected_key)
	var entry: Dictionary = _selected_entry()
	var has_item: bool = not entry.is_empty()
	_portrait.texture = _entry_texture(entry) if has_item else null
	_portrait.self_modulate = UI.tokens.detail_gold_color if has_item and entry.texture == null else Color.WHITE
	%Row.visible = has_item
	%EmptyState.visible = not has_item
	_owned.visible = has_item
	_description.visible = has_item
	_stack_limit.visible = has_item
	%DetailRule.visible = has_item
	_name.text = ContentText.field(entry.record) if has_item else ContentText.text("ui.catalog.empty")
	if not has_item: return
	_owned.text = "%s  ×%d" % [ContentText.text("ui.collection.owned"), session.assets.items.get(entry.id, 0)]
	_description.text = ContentText.field(entry.record, "flavor_text")
	_stack_limit.text = "%s  %d" % [ContentText.text("ui.detail.stack_limit"), entry.record.max_stack]

## 缺少物品美术时使用现有分类符号，配合真实名称区分各类材料。
func _entry_texture(entry: Dictionary) -> Texture2D:
	if entry.texture != null: return entry.texture
	var category: String = "Material" if entry.record.item_kind == C.Item.Material else "Prop"
	return tabs.get_node("Bar/" + category + "/Icon").texture

## 四列正方形格子随可用宽度缩放，留出滚动条和金边呼吸空间。
func _layout_grid() -> void:
	if not is_node_ready(): return
	var gap: int = _grid.get_theme_constant("h_separation")
	var side: float = maxf(1, floorf((_scroll.size.x - 18 - gap * 3) / 4))
	for child: Control in _grid.get_children(): child.custom_minimum_size = Vector2(side, side)

## 详情比例跟随页面宽度，短视口仍给下方网格保留可操作空间。
func _layout_detail() -> void:
	if not is_node_ready(): return
	_detail.custom_minimum_size.y = clampf(size.x * 0.40, 210, 280)

## 共用纸面和金边素材，固定三等分页签不采用另一套导航风格。
func _update_tabs() -> void:
	if not is_node_ready() or tabs.selected_id.is_empty(): return
	var active: Control = tabs.get_node("Bar/" + tabs.selected_id)
	_selection.position = active.position
	_selection.size = active.size
	for category: Dictionary in CATEGORIES:
		var button: Button = tabs.get_node("Bar/" + category.id)
		var tint: Color = UI.tokens.detail_gold_color if category.id == tabs.selected_id else UI.tokens.detail_ink_color
		button.get_node("Icon").self_modulate = tint
		button.get_node("Caption").self_modulate = tint

## 原生页签自动翻译；动态物品正文重读语言资源并保留分类与选中身份。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): refresh()
