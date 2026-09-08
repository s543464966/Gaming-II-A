extends "res://ui/components/content/catalog_page.gd"
## 玩家实际持有资产的查看页面；不提供尚未设计的使用或分解。

const Preview = preload("res://ui/components/content/content_preview.gd")
const C = preload("res://game_content/runtime/content_types.gd")

var session: RefCounted

## 背包只查询当前账号资产，不接触平台或存档。
func bind_player(player: RefCounted) -> void:
	session = player

## 按全部、材料和道具筛选真实持有切片。
func _ready() -> void:
	configure([{"id": "None", "label": "ui.category.all"}, {"id": "Material", "label": "ui.category.material"}, {"id": "Prop", "label": "ui.category.item"}], _rows, _description)
	super._ready()

## UI 堆叠切片不产生第二份资产状态。
func _rows(id: String) -> Array:
	var rows: Array = []
	for stack in session.assets.display_stacks(C.Item[id]):
		var row = Preview.entry(session.content, "items", session.content.get_record("items", stack.id))
		row.caption = "× %d" % stack.quantity
		rows.append(row)
	return rows

## 明确未接入的业务，避免可点击的假操作。
func _description(row: Dictionary) -> Dictionary:
	var detail = Preview.describe(session.content, row)
	detail.sections.append({"title": "ui.detail.usage", "entries": [{"body": ContentText.text("ui.backpack.actions_unavailable")}]})
	return detail
