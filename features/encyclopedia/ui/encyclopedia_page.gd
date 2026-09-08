extends "res://ui/components/content/catalog_browser.gd"
## 完整静态图鉴只提供目录与预览，浏览外观与藏品共用。

const Preview = preload("res://ui/components/content/content_preview.gd")
const C = preload("res://game_content/runtime/content_types.gd")
var catalog: RefCounted

## 图鉴目录只注入静态内容源。
func _ready() -> void:
	configure([{"id": "Team", "label": "ui.category.team"}, {"id": "Monsters", "label": "ui.category.monsters"},
		{"id": "ItemCard", "label": "ui.category.item_card"}, {"id": "Relic", "label": "ui.category.relic"}, {"id": "InventoryProp", "label": "ui.category.inventory_prop"}, {"id": "Aurora", "label": "ui.category.aurora"}], _rows, _description)
	super._ready()

## 每次从实际目录推导，新增定义不需要修改白名单。
func _rows(id: String) -> Array:
	var rows: Array = []
	match id:
		"Team", "Monsters":
			for row in catalog.data.cards:
				if row.card_kind in ([CardTypes.Kind.CoreHero, CardTypes.Kind.Minion] if id == "Team" else [CardTypes.Kind.Monster]): rows.append(Preview.entry(catalog, "cards", row))
		"ItemCard":
			for row in catalog.data.cards:
				if row.card_kind == CardTypes.Kind.ItemCard: rows.append(Preview.entry(catalog, "cards", row))
		"Relic":
			for row in catalog.data.relics: rows.append(Preview.entry(catalog, "relics", row))
		"InventoryProp":
			for row in catalog.data.items:
				if row.item_kind == C.Item.Prop: rows.append(Preview.entry(catalog, "items", row))
		"Aurora":
			for row in catalog.data.aurora_rewards: rows.append(Preview.entry(catalog, "aurora_rewards", row))
	rows.sort_custom(func(a, b): return a.id < b.id)
	return rows

## 所有规则来自统一静态预览，不显示购买或拥有操作。
func _description(row: Dictionary) -> Dictionary:
	return Preview.describe(catalog, row)
