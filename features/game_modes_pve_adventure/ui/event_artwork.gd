extends RefCounted
## 事件与遗迹共用真实内容原图映射，不维护另一份奖励或商品定义。

const C = preload("res://game_content/runtime/content_types.gd")
const GOLD = preload("res://game_content/items/art/coin_golden.png")
const STAR = preload("res://game_content/items/art/coin_mana_stone.png")
const STAMINA = preload("res://game_content/items/art/coin_energy.png")
const DICE = preload("res://features/game_modes_pve_adventure/ui/art/event_die.svg")
const UPGRADE = preload("res://ui/design_system/icons/star.png")

## 支付和兑换沿用账号货币枚举。
static func currency(kind: int) -> Texture2D:
	return preload("res://ui/design_system/icons/common/player_gold.png") if kind == C.Currency.Gold else preload("res://ui/design_system/icons/common/player_star_stone.png")

## 碎片优先使用自身原图，否则按唯一兑换关系解析整卡插画。
static func content(catalog: GameCatalog, table: String, id: String) -> Texture2D:
	var row: Dictionary = catalog.get_record(table, id)
	var texture: Texture2D = catalog.resource(row.get("texture_key", ""))
	if texture != null or table != "items": return texture
	for offer: Dictionary in catalog.data.shop_offers:
		if offer.fragment_item_id == id:
			return content(catalog, "relics" if offer.shop_tab == C.ShopTab.Relic else "cards", offer.reward_id)
	return null
