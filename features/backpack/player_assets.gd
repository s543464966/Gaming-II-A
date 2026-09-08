class_name PlayerAssets
extends RefCounted
## 账号货币及可堆叠资产；界面切片不改变真实资产数量。

signal changed
const C = preload("res://game_content/runtime/content_types.gd")
var content: RefCounted
var gold: int = 0
var star_stone: int = 0
var items: Dictionary = {}

## 注入物品目录，不持有商城或章节运行对象。
func _init(catalog: RefCounted) -> void:
	content = catalog

## 判断指定货币能否支付非负金额。
func has_currency(currency: int, amount: int) -> bool:
	if amount < 0: return false
	return gold >= amount if currency == C.Currency.Gold else star_stone >= amount if currency == C.Currency.StarStone else false

## 余额不足不修改货币，成功后通知界面读取最终值。
func spend(currency: int, amount: int) -> bool:
	if not has_currency(currency, amount): return false
	if currency == C.Currency.Gold: gold -= amount
	else: star_stone -= amount
	changed.emit()
	return true

## 增加正数货币，不提供自动换汇或真实支付。
func grant(currency: int, amount: int) -> bool:
	if amount <= 0 or not currency in [C.Currency.Gold, C.Currency.StarStone]: return false
	if currency == C.Currency.Gold: gold += amount
	else: star_stone += amount
	changed.emit()
	return true

## 扣除特定物品，不允许负数或未知资产。
func remove_item(id: String, quantity: int) -> bool:
	if quantity < 0 or int(items.get(id, 0)) < quantity: return false
	if quantity == 0: return true
	items[id] -= quantity
	if items[id] == 0: items.erase(id)
	changed.emit()
	return true

## 只接收目录内的正数物品数量。
func add_item(id: String, quantity: int) -> bool:
	if quantity <= 0 or content.get_record("items", id).is_empty(): return false
	items[id] = int(items.get(id, 0)) + quantity
	changed.emit()
	return true

## 按静态堆叠上限生成展示切片，保留同一个事实数量。
func display_stacks(type: int = C.Item.None) -> Array:
	var result: Array = []
	var ids = items.keys()
	ids.sort()
	for id in ids:
		var row: Dictionary = content.get_record("items", id)
		if type != C.Item.None and row.item_kind != type: continue
		var remaining: int = items[id]
		while remaining > 0:
			var count = mini(remaining, row.max_stack)
			result.append({"id": id, "quantity": count})
			remaining -= count
	return result

## 保存账号货币及全部非零物品。
func capture() -> Dictionary:
	return {"gold": gold, "star_stone": star_stone, "items": items.duplicate()}

## 恢复损坏资产会报错，不把未知物品默默清空。
func restore(state: Dictionary) -> String:
	if not state.get("gold") is int or not state.get("star_stone") is int or state.gold < 0 or state.star_stone < 0 or not state.get("items") is Dictionary: return "账号资产格式损坏。"
	for id in state.items:
		if content.get_record("items", id).is_empty() or not state.items[id] is int or state.items[id] <= 0: return "账号物品定义或数量损坏。"
	gold = state.gold
	star_stone = state.star_stone
	items = state.items.duplicate()
	changed.emit()
	return ""
