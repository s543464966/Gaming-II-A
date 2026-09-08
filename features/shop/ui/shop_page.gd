extends "res://ui/components/content/catalog_page.gd"
## 账号商城总览、商品巡游详情与三种真实支付入口。

signal return_requested

const Preview = preload("res://ui/components/content/content_preview.gd")
const C = preload("res://game_content/runtime/content_types.gd")
const TAB_MOTION_DURATION := 0.22
const TAB_IDLE_COLOR := Color(0.16, 0.13, 0.09, 1.0)
const TAB_SELECTED_COLOR := Color(0.90, 0.82, 0.63, 1.0)

var session: PlayerSessionState
var persist: Callable
var _visible_rows: Array = []
var _detail_index: int = -1
var _resource_clock: float = 0.0
var _tabs_initialized: bool = false
var _tab_motion: Tween
@onready var _overview: Control = $Margin/Column/Views/Overview
@onready var _detail_view: Control = $Margin/Column/Views/Detail
@onready var _detail_scroll: ScrollContainer = $Margin/Column/Views/Detail/Scroll
@onready var _detail_content: ContentDetail = %Content
@onready var _actions: HBoxContainer = %Actions
@onready var _tab_selection: NinePatchRect = $Margin/Column/Views/Overview/Tabs/Bar/Selection

## 商城接收账号聚合、保存入口和全局确认层，不直接访问仓储。
func bind_player(player: PlayerSessionState, save: Callable, overlay: CanvasLayer) -> void:
	session = player
	persist = save
	overlays = overlay

## 默认进入有真实商品的英雄分类，并接通总览和巡游操作。
func _ready() -> void:
	configure([{"id": "Recommend", "label": "ui.category.recommended"}, {"id": "Hero", "label": "ui.category.hero"}, {"id": "Minion", "label": "ui.category.minion"},
		{"id": "Item", "label": "ui.category.item"}, {"id": "Relic", "label": "ui.category.relic"}], _rows, _description, _actions_for_detail)
	%Tabs.selected_id = "Hero"
	$Margin/Column/Views/Detail/Scroll/Column/Carousel/Previous.pressed.connect(_move_detail.bind(-1))
	$Margin/Column/Views/Detail/Scroll/Column/Carousel/Next.pressed.connect(_move_detail.bind(1))
	$Margin/Column/Views/Detail/Scroll/Column/Carousel/Center.resized.connect(_layout_showcase)
	for label: Label in [$Margin/Column/Header/Resources/Row/Gold/Value, $Margin/Column/Header/Resources/Row/StarStone/Value,
		$Margin/Column/Header/Resources/Row/Stamina/Value, $Margin/Column/Views/Detail/Scroll/Column/Indicator,
		$Margin/Column/Views/Detail/Scroll/Column/Name, $Margin/Column/Views/Detail/Scroll/Column/Summary]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	super._ready()
	tabs.resized.connect(_queue_tab_layout)
	tabs.get_node("Bar").resized.connect(_queue_tab_layout)
	_tabs_initialized = true
	_queue_tab_layout()
	_refresh_resources()

## 可见商城每秒同步账号资源，不为展示推进体力或复制业务状态。
func _process(delta: float) -> void:
	if session == null or not is_visible_in_tree(): return
	_resource_clock += delta
	if _resource_clock < 1.0: return
	_resource_clock = 0.0
	_refresh_resources()

## 页面重开或交易完成后重查真实目录，详情仍绑定同一商品身份。
func refresh() -> void:
	if not is_node_ready() or session == null: return
	_refresh_resources()
	_update_tab_selection(tabs.selected_id, false)
	var selected_id: String = _detail_id
	var detail_offset: int = _detail_scroll.scroll_vertical
	var rows: Array = [] if tabs.selected_id.is_empty() else query.call(tabs.selected_id)
	_current_tab = tabs.selected_id
	_update_filters(rows)
	_render(_apply_filters(rows))
	if selected_id.is_empty():
		_show_overview(false)
		return
	var index: int = _row_index(selected_id)
	if index < 0:
		_show_overview(false)
		return
	_detail_id = selected_id
	_detail_index = index
	_overview.hide()
	_detail_view.show()
	_render_detail()
	_detail_scroll.set_deferred("scroll_vertical", detail_offset)

## 外层返回键在详情中先返回总览，位于总览时才请求关闭商城。
func request_return() -> void:
	if not _detail_id.is_empty():
		_show_overview()
		return
	return_requested.emit()

## 宿主关闭或替换页面时清理局部详情，不保留错误的返回层级。
func cancel_transition() -> void:
	_stop_tab_motion()
	_show_overview(false)

## 切换分类关闭旧详情并回到目录顶部，筛选仍由共享目录语义维护。
func _select_tab(id: String) -> void:
	_show_overview(false)
	if is_instance_valid(_scroll): _scroll.scroll_vertical = 0
	super._select_tab(id)
	_update_tab_selection(id, _tabs_initialized)

## 分类切换时让单格黑牌、定位菱形和文字共同移动状态。
func _update_tab_selection(id: String, animate: bool) -> void:
	if not is_node_ready(): return
	var active: Button = tabs.get_node_or_null("Bar/" + id)
	if active == null: return
	_stop_tab_motion()
	var target_x: float = active.position.x
	var target_width: float = active.size.x
	var duration: float = TAB_MOTION_DURATION if animate and is_visible_in_tree() else 0.0
	if duration <= 0.0:
		_tab_selection.position.x = target_x
		_tab_selection.size.x = target_width
	else:
		_tab_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_tab_motion.tween_property(_tab_selection, "position:x", target_x, duration)
		_tab_motion.tween_property(_tab_selection, "size:x", target_width, duration)
	for option: Dictionary in tabs.options:
		var button: Button = tabs.get_node("Bar/" + str(option.id))
		var caption: Label = button.get_node("Caption")
		var color: Color = TAB_SELECTED_COLOR if option.id == id else TAB_IDLE_COLOR
		if duration > 0.0:
			_tab_motion.tween_property(caption, "self_modulate", color, duration)
		else:
			caption.self_modulate = color

## 页面尺寸变化时立即重新对齐选中牌，避免安全区重排留下半格偏移。
func _layout_tab_selection() -> void:
	_update_tab_selection(tabs.selected_id, false)

## 等五等分锚点完成本帧重排后再读取目标格，避免使用旧位置。
func _queue_tab_layout() -> void:
	_layout_tab_selection.call_deferred()

## 快速切换、关闭或重排前结束旧动画，确保只有一个位置事实源。
func _stop_tab_motion() -> void:
	if _tab_motion != null and _tab_motion.is_valid(): _tab_motion.kill()
	_tab_motion = null

## 只有存在实际筛选候选时才显示黑金筛选面板。
func _update_filters(rows: Array) -> void:
	super._update_filters(rows)
	%FilterPanel.visible = _filters.visible

## 总览与收藏、图鉴共用无底板四列卡牌，商城仅提供价格与购买状态。
func _render(rows: Array) -> void:
	_visible_rows = rows.duplicate()
	var not_open: bool = _current_tab == "Recommend" and rows.is_empty()
	_overview.get_node("Unavailable").visible = not_open
	_scroll.visible = not not_open
	if not_open:
		GameUI.clear(_grid)
		return
	super._render(rows)

## 目录卡牌按稳定商品 ID 进入详情，筛选与滚动位置留在总览节点中。
func _open_detail(row: Dictionary) -> void:
	var index: int = _row_index(str(row.id))
	if index >= 0: _show_detail(index)

## 巡游只在当前筛选结果内移动，边界商品不循环跳转。
func _move_detail(offset: int) -> void:
	var index: int = _detail_index + offset
	if index < 0 or index >= _visible_rows.size(): return
	_show_detail(index)

## 详情切换更新主画框、相邻预览、真实规则与当前可用支付按钮。
func _show_detail(index: int) -> void:
	if index < 0 or index >= _visible_rows.size(): return
	_detail_index = index
	_detail_id = str(_visible_rows[index].id)
	_overview.hide()
	_detail_view.show()
	_detail_scroll.scroll_vertical = 0
	_render_detail()

## 同一详情节点重新绑定当前商品，购买后不会遗留旧价格或拥有状态。
func _render_detail() -> void:
	if _detail_index < 0 or _detail_index >= _visible_rows.size(): return
	var row: Dictionary = _visible_rows[_detail_index]
	var previous: Button = $Margin/Column/Views/Detail/Scroll/Column/Carousel/Previous
	var next: Button = $Margin/Column/Views/Detail/Scroll/Column/Carousel/Next
	_render_neighbor(previous, _detail_index - 1)
	_render_neighbor(next, _detail_index + 1)
	var showcase: CardArtwork = $Margin/Column/Views/Detail/Scroll/Column/Carousel/Center
	var level: int = int(row.get("face", {}).get("definition", {}).get("chapter_level", 0))
	showcase.set_appearance(row.get("texture"), level, 1)
	showcase.set_portrait_dimmed(false)
	showcase.set_unavailable(row.table == "cards" and not row.get("owned", true))
	_layout_showcase()
	$Margin/Column/Views/Detail/Scroll/Column/Indicator.text = "%d / %d" % [_detail_index + 1, _visible_rows.size()]
	$Margin/Column/Views/Detail/Scroll/Column/Name.text = row.get("name", row.id)
	$Margin/Column/Views/Detail/Scroll/Column/Summary.text = ContentText.text(str(row.get("caption", "")))
	_detail_content.present(row, _description(row))
	GameUI.clear(_actions)
	_actions_for_detail(row, _actions)

## 大图详情恢复真实占位比例；展示区随之调整，仍只绘制一层铺满的位图框。
func _layout_showcase() -> void:
	if not is_node_ready() or _detail_index < 0 or _detail_index >= _visible_rows.size(): return
	var definition: Dictionary = _visible_rows[_detail_index].get("face", {}).get("definition", {})
	var aspect: float = float(definition.get("height", 1)) * 118.0 / (float(definition.get("width", 1)) * 100.0)
	var showcase: CardArtwork = $Margin/Column/Views/Detail/Scroll/Column/Carousel/Center
	showcase.custom_minimum_size.y = maxf(1, showcase.size.x) * aspect

## 相邻画框仅在真实商品存在时出现，预览沿用相同拥有状态。
func _render_neighbor(button: Button, index: int) -> void:
	button.visible = index >= 0 and index < _visible_rows.size()
	if not button.visible: return
	button.get_node("Picture").present(_visible_rows[index])

## 返回总览恢复原商品焦点，键盘与手柄不丢失浏览位置。
func _show_overview(restore_focus: bool = true) -> void:
	var previous_id: String = _detail_id
	_detail_id = ""
	_detail_index = -1
	if not is_node_ready(): return
	_detail_view.hide()
	_overview.show()
	if not restore_focus or previous_id.is_empty(): return
	for child: Node in _grid.get_children():
		if child is Button and str(child.get_meta("content_id", "")) == previous_id:
			child.grab_focus.call_deferred()
			return

## 账号资源条与 Home 使用同一图标和完整数值口径。
func _refresh_resources() -> void:
	if session == null or not is_node_ready(): return
	$Margin/Column/Header/Resources/Row/Gold/Value.text = str(session.assets.gold)
	$Margin/Column/Header/Resources/Row/StarStone/Value.text = str(session.assets.star_stone)
	$Margin/Column/Header/Resources/Row/Stamina/Value.text = "%d/%d" % [session.user.stamina, session.user.STAMINA_MAX]

## 商品来自真实目录，未报价项仍可查看但不能购买。
func _rows(id: String) -> Array:
	var rows: Array = []
	for record: Dictionary in session.shop.products(C.ShopTab[id]):
		var table: String = "cards" if record.has("card_kind") else "relics"
		var row: Dictionary = Preview.entry(session.content, table, record)
		row.owned = session.collection.owns(row.id)
		var price: Variant = session.shop.price(row.id, C.Payment.Gold)
		row.caption = "ui.collection.owned" if row.owned else "ui.shop.unpriced" if price == null else ContentText.format_key("ui.shop.gold_price", {"amount": price})
		rows.append(row)
	return rows

## 详情显示独立报价、实际规则与碎片持有量。
func _description(row: Dictionary) -> Dictionary:
	var offer: Dictionary = session.shop.offers.get(row.id, {})
	var detail: Dictionary = Preview.describe(session.content, row)
	var prices: Array = []
	if not offer.is_empty():
		for method: int in [C.Payment.Gold, C.Payment.StarStone]:
			var original: Variant = offer.account_gold_price if method == C.Payment.Gold else offer.account_star_stone_price
			if original != null:
				prices.append({"body": ContentText.format_key("ui.shop.price_detail", {"currency": _currency(method), "original": original, "amount": session.shop.price(row.id, method)})})
		if not offer.fragment_item_id.is_empty():
			var fragment: Dictionary = session.content.get_record("items", offer.fragment_item_id)
			prices.append({"body": ContentText.format_key("ui.shop.fragments_detail", {"name": ContentText.field(fragment), "owned": session.assets.items.get(fragment.id, 0), "required": offer.fragment_amount})})
	if not prices.is_empty(): detail.sections.append({"title": "ui.detail.purchase", "entries": prices})
	return detail

## 详情只展示实际可用的支付种类，资格不足时保留禁用反馈。
func _actions_for_detail(row: Dictionary, parent: BoxContainer) -> void:
	if row.get("owned", false): return
	for method: int in [C.Payment.Gold, C.Payment.StarStone, C.Payment.Fragments]:
		var amount: Variant = session.shop.price(row.id, method)
		if amount == null: continue
		var button: Button = GameUI.button(ContentText.format_key("ui.shop.buy_button", {"amount": amount, "currency": _currency(method)}), func() -> void:
			overlays.confirm(func() -> String: return ContentText.format_key("ui.shop.buy_confirm", {"name": ContentText.field(row.record), "amount": amount, "currency": _currency(method)}), func() -> void:
				var result: int = session.purchase(row.id, method, persist)
				overlays.toast(_result_text(result))
				refresh(), "ui.shop.buy_title"))
		button.name = ["Gold", "StarStone", "Fragments"][method]
		button.set("compact", true)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.theme_type_variation = &"DetailActionButton"
		button.disabled = session.shop.check_purchase(row.id, method) != C.BuyResult.Success
		parent.add_child(button)

## 当前分类标签读取现有本地化键，不创建商城专属副本。
func _tab_label(id: String) -> String:
	for option: Dictionary in tabs.options:
		if option.id == id: return str(option.label)
	return "ui.category.recommended"

## 通过稳定身份定位筛选结果中的商品。
func _row_index(id: String) -> int:
	for index: int in range(_visible_rows.size()):
		if str(_visible_rows[index].id) == id: return index
	return -1

## 支付枚举保持稳定，货币名称只在展示层翻译。
static func _currency(method: int) -> String:
	return ContentText.text(["ui.currency.gold", "ui.currency.star_stone", "ui.currency.fragments"][method])

## 所有失败都按真实交易结果反馈。
static func _result_text(result: int) -> String:
	return {C.BuyResult.Success: "ui.shop.success", C.BuyResult.SaveFailed: "ui.shop.save_failed",
		C.BuyResult.AlreadyOwned: "ui.shop.owned", C.BuyResult.NotEnoughCurrency: "ui.shop.insufficient", C.BuyResult.Busy: "ui.shop.busy"}.get(result, "ui.shop.failure")

## 切换语言重新读取当前目录与详情，不改变分类、筛选或商品身份。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and session != null: refresh.call_deferred()
