class_name ShopService
extends RefCounted
## 账号商城拥有报价、购买资格及交付规则；保存和回滚由玩家会话统一负责。

const C = preload("res://game_content/runtime/content_types.gd")
var content: GameCatalog
var assets: PlayerAssets
var collection: CollectionState
var bought: Dictionary = {}
var offers: Dictionary = {}

## 按奖励 ID 建立报价索引，不把未报价内容从目录隐藏。
func _init(catalog: GameCatalog, player_assets: PlayerAssets, player_collection: CollectionState) -> void:
	content = catalog
	assets = player_assets
	collection = player_collection
	for offer in content.data.shop_offers: offers[offer.reward_id] = offer

## 目录包含实际英雄、随从、道具和遗物，不包含敌人。
func products(tab: int) -> Array:
	var rows: Array = content.data.cards.filter(func(row): return row.card_kind in [CardTypes.Kind.CoreHero, CardTypes.Kind.Minion, CardTypes.Kind.ItemCard])
	rows.append_array(content.data.relics)
	rows = rows.filter(func(row): return C.shop_tab(row) == tab)
	rows.sort_custom(func(a, b):
		var left: int = offers.get(a.id, {}).get("sort_order", 2147483647)
		var right: int = offers.get(b.id, {}).get("sort_order", 2147483647)
		return a.id < b.id if left == right else left < right)
	return rows

## 货币折扣向上取整，专属碎片不打折；空报价不是免费。
func price(id: String, method: int) -> Variant:
	var offer: Dictionary = offers.get(id, {})
	if offer.is_empty(): return null
	if method == C.Payment.StarStone and content.get_record("cards", id).get("card_kind") == CardTypes.Kind.CoreHero: return null
	if method == C.Payment.Fragments: return offer.fragment_amount if not offer.fragment_item_id.is_empty() else null
	if not method in [C.Payment.Gold, C.Payment.StarStone]: return null
	var original: Variant = offer.account_gold_price if method == C.Payment.Gold else offer.account_star_stone_price
	return null if original == null else ceili(float(original) * offer.payable_percent / 100.0)

## 查看与提交共享同一份只读交易约束。
func check_purchase(id: String, method: int) -> int:
	if not offers.has(id): return C.BuyResult.ItemNotFound
	if collection.owns(id): return C.BuyResult.AlreadyOwned
	var offer: Dictionary = offers[id]
	if bought.get(offer.id, 0) >= offer.purchase_limit: return C.BuyResult.SoldOut
	var amount: Variant = price(id, method)
	if amount == null: return C.BuyResult.PaymentUnavailable
	var enough: bool = assets.items.get(offer.fragment_item_id, 0) >= amount if method == C.Payment.Fragments else assets.has_currency(C.Currency.Gold if method == C.Payment.Gold else C.Currency.StarStone, amount)
	return C.BuyResult.Success if enough else C.BuyResult.NotEnoughCurrency

## 仅供会话事务执行：提交前重验规则，不保存、不持有回调或另建回滚快照。
func apply_purchase(id: String, method: int) -> int:
	var check = check_purchase(id, method)
	if check != C.BuyResult.Success: return check
	var offer: Dictionary = offers[id]
	var amount: int = price(id, method)
	var paid: bool = assets.remove_item(offer.fragment_item_id, amount) if method == C.Payment.Fragments else assets.spend(C.Currency.Gold if method == C.Payment.Gold else C.Currency.StarStone, amount)
	if not paid: return C.BuyResult.NotEnoughCurrency
	if not collection.unlock(id): return C.BuyResult.ItemNotFound
	bought[offer.id] = int(bought.get(offer.id, 0)) + 1
	return C.BuyResult.Success
