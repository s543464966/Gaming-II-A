extends "res://ui/components/content/catalog_browser.gd"
## 收藏只读展示账号永久卡牌与拥有状态；培养和出战管理各有独立入口。

const Preview = preload("res://ui/components/content/content_preview.gd")
enum Ownership { ALL, OWNED, UNOWNED }

var session: RefCounted
var _ownership: Ownership = Ownership.ALL

## 收藏只注入只读会话与详情浮层，不持有培养或切换英雄操作。
func bind_player(player: RefCounted, overlay: CanvasLayer) -> void:
	session = player
	overlays = overlay

## 收藏类别与图鉴独立，不收录敌方卡牌。
func _ready() -> void:
	configure([{"id": "Hero", "label": "ui.category.hero"}, {"id": "Minion", "label": "ui.category.minion"},
		{"id": "Item", "label": "ui.category.item_card"}, {"id": "Relic", "label": "ui.category.relic"}], _rows, _description)
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
			row.face = Preview.card_face(session.collection.definition(row.id))
		row.caption = "ui.collection.owned" if row.owned else "ui.collection.unowned"
		if row.id == session.collection.selected_hero: row.caption = "ui.collection.current_hero"
	return rows

## 收藏读取账号永久成长；没有拥有的内容继续使用静态图鉴预览。
func _description(row: Dictionary) -> Dictionary:
	if row.table == "cards" and session.collection.owns(row.id):
		var definition: Dictionary = session.collection.definition(row.id)
		return Preview.permanent_detail(definition)
	return Preview.describe(session.content, row)
