extends "res://ui/components/content/catalog_browser.gd"
## 收藏展示账号永久成长；升星与英雄切换分别确认并事务保存。

const Preview = preload("res://ui/components/content/content_preview.gd")
enum Ownership { ALL, OWNED, UNOWNED }

var session: RefCounted
var progression: RefCounted
var persist: Callable
var _ownership: Ownership = Ownership.ALL

## 注入账号、英雄切换用例及保存入口，不创建第二套成长状态。
func bind_player(player: RefCounted, flow: RefCounted, overlay: CanvasLayer, save: Callable = Callable()) -> void:
	session = player
	progression = flow
	overlays = overlay
	persist = save

## 收藏类别与图鉴独立，不收录敌方卡牌。
func _ready() -> void:
	configure([{"id": "Hero", "label": "ui.category.hero"}, {"id": "Minion", "label": "ui.category.minion"},
		{"id": "Item", "label": "ui.category.item_card"}, {"id": "Relic", "label": "ui.category.relic"}], _rows, _description, _actions)
	super._ready()

## 藏品快捷栏只切换拥有状态，保留独立的名称与卡牌属性条件。
func _select_quick_filter(index: int) -> void:
	_ownership = index as Ownership
	set_filters_expanded(false)
	_scroll.scroll_vertical = 0
	_render(_apply_filters(query.call(_current_tab)))

## 拥有状态作用于四类藏品，名称搜索和卡牌属性继续取交集。
func _apply_filters(rows: Array) -> Array:
	var filtered: Array = super._apply_filters(rows)
	if _ownership == Ownership.ALL: return filtered
	return filtered.filter(func(row): return bool(row.owned) == (_ownership == Ownership.OWNED))

## 遗物也保留拥有状态快捷栏，漏斗只在存在卡牌属性时提供。
func _apply_filter_view() -> void:
	super._apply_filter_view()
	if not is_instance_valid(_quick_filters): return
	_quick_filters.show()
	_set_quick_selected(_ownership)

## 未获得定义仍显示，由共用组件灰显插画并使用暗灰框，不伪造数量。
func _rows(id: String) -> Array:
	var rows: Array = []
	var catalog: RefCounted = session.content
	if id in ["Hero", "Minion", "Item"]:
		var kind: int = {"Hero": CardTypes.Kind.CoreHero, "Minion": CardTypes.Kind.Minion, "Item": CardTypes.Kind.ItemCard}[id]
		for row in catalog.data.cards:
			if row.card_kind == kind: rows.append(Preview.entry(catalog, "cards", row))
	else:
		for row in catalog.data.relics: rows.append(Preview.entry(catalog, "relics", row))
	for row in rows:
		row.owned = session.collection.owns(row.id)
		if row.table == "cards" and row.owned:
			row.face = Preview.card_face(session.collection.definition(row.id, session.assets))
		row.caption = "ui.collection.owned" if row.owned else "ui.collection.unowned"
		if row.id == session.collection.selected_hero: row.caption = "ui.collection.current_hero"
	return rows

## 收藏读取账号永久成长；没有拥有的内容继续使用静态图鉴预览。
func _description(row: Dictionary) -> Dictionary:
	if row.table == "cards" and session.collection.owns(row.id):
		var definition: Dictionary = session.collection.definition(row.id, session.assets)
		var status: Dictionary = session.collection.star_status(row.id, session.assets)
		return Preview.permanent_detail(definition, status)
	return Preview.describe(session.content, row)

## 未满星卡牌提供升星动作，满星提示由成长模块呈现；英雄另有身份切换入口。
func _actions(row: Dictionary, parent: BoxContainer) -> void:
	if row.table == "cards":
		var status: Dictionary = session.collection.star_status(row.id, session.assets)
		if status.cost > 0:
			var upgrade = UI.button("ui.collection.star_upgrade", _confirm_upgrade.bind(row))
			upgrade.name = "StarUpgrade"
			upgrade.disabled = not status.can_upgrade or not persist.is_valid()
			parent.add_child(upgrade)
	if row.table != "cards" or row.record.card_kind != CardTypes.Kind.CoreHero: return
	var selected: bool = session.collection.selected_hero == row.id
	var button = UI.button("ui.collection.current_hero" if selected else "ui.collection.select_hero", func():
		overlays.confirm("ui.collection.change_warning", func():
			var error: String = progression.change_hero(row.id)
			overlays.toast("ui.collection.changed" if error.is_empty() else error)
			refresh(), "ui.collection.change_title"))
	button.disabled = selected or not session.collection.owns(row.id)
	parent.add_child(button)

## 确认展示实际扣除和余量；事务回滚后继续显示当前卡牌详情。
func _confirm_upgrade(row: Dictionary) -> void:
	var status: Dictionary = session.collection.star_status(row.id, session.assets)
	if not status.can_upgrade: return
	var next = {"star_level": status.star + 1, "fragment_steps": CardGrowth.fragment_steps(status.quantity - status.cost, status.star + 1, session.content.data.growth_rules[0])}
	var strength = CardGrowth.permanent_multiplier(next, session.content.data.growth_rules[0])
	overlays.confirm(func(): return ContentText.format_key("ui.collection.star_confirm", {"name": ContentText.field(row.record), "cost": status.cost,
		"remaining": status.quantity - status.cost, "star": next.star_level, "strength": RuleText.number(strength * 100)}), func():
			var error: String = session.transact(func(): return session.collection.upgrade(row.id, session.assets), persist)
			overlays.toast("ui.collection.star_success" if error.is_empty() else error)
			_render(_apply_filters(query.call(_current_tab)))
			_open_detail(row), "ui.collection.star_upgrade")

## 离开分类先关闭升星或换英雄确认，避免隐藏页面继续提交旧操作。
func _select_tab(id: String) -> void:
	if overlays != null: overlays.close_modal()
	super._select_tab(id)
