class_name ContentIdMigration
extends RefCounted
## Schema 12 的一次性内容标识迁移；实例 ID 和玩家文本保持原样。

const MAPS = {
	"cards": {
		"H001": "H001",
		"H002": "H002",
		"H003": "H003",
		"H004": "H004",
		"H005": "H005",
		"H006": "H006",
		"H007": "H007",
		"H008": "H008",
		"H009": "H009",
		"H010": "H010",
		"H011": "H011",
		"H012": "H012",
		"H013": "H013",
		"H014": "H014",
		"H015": "H015",
		"H016": "H016",
		"Hs001": "HS001",
		"Hs002": "HS002",
		"Hs003": "HS003",
		"Hs004": "HS004",
		"Hs005": "HS005",
		"Hs006": "HS006",
		"Hs007": "HS007",
		"Hs008": "HS008",
		"Hs009": "HS009",
		"Hs010": "HS010",
		"Hs011": "HS011",
		"Hs012": "HS012",
		"Hs013": "HS013",
		"Hs014": "HS014",
		"Hs015": "HS015",
		"Hs016": "HS016",
		"M010101": "MB001",
		"M010102": "ME001",
		"M010103": "ME002",
		"M010104": "ME003",
		"M010105": "M001",
		"M010106": "M002",
		"M010107": "M003",
		"M010108": "M004",
		"M010109": "M005",
		"M010110": "M006",
		"M010201": "MB002",
		"M010202": "ME004",
		"M010203": "ME005",
		"M010204": "ME006",
		"M010205": "M001",
		"M010206": "M002",
		"M010207": "M003",
		"M010208": "M004",
		"M010209": "M005",
		"M010210": "M006",
		"M010301": "MB003",
		"M010302": "ME007",
		"M010303": "ME008",
		"M010304": "ME009",
		"M010305": "M001",
		"M010306": "M002",
		"M010307": "M003",
		"M010308": "M004",
		"M010309": "M005",
		"M010310": "M006",
		"M020101": "MB004",
		"M020102": "ME010",
		"M020103": "ME011",
		"M020104": "ME012",
		"M020105": "M019",
		"M020106": "M020",
		"M020107": "M021",
		"M020108": "M022",
		"M020109": "M023",
		"M020110": "M024",
		"M020201": "MB005",
		"M020202": "ME013",
		"M020203": "ME014",
		"M020204": "ME015",
		"M020205": "M019",
		"M020206": "M020",
		"M020207": "M021",
		"M020208": "M022",
		"M020209": "M023",
		"M020210": "M024",
		"M020301": "MB006",
		"M020302": "ME016",
		"M020303": "ME017",
		"M020304": "ME018",
		"M020305": "M019",
		"M020306": "M020",
		"M020307": "M021",
		"M020308": "M022",
		"M020309": "M023",
		"M020310": "M024",
		"M030101": "MB007",
		"M030102": "ME019",
		"M030103": "ME020",
		"M030104": "ME021",
		"M030105": "M037",
		"M030106": "M038",
		"M030107": "M039",
		"M030108": "M040",
		"M030109": "M041",
		"M030110": "M042",
		"M030201": "MB008",
		"M030202": "ME022",
		"M030203": "ME023",
		"M030204": "ME024",
		"M030205": "M037",
		"M030206": "M038",
		"M030207": "M039",
		"M030208": "M040",
		"M030209": "M041",
		"M030210": "M042",
		"M030301": "MB009",
		"M030302": "ME025",
		"M030303": "ME026",
		"M030304": "ME027",
		"M030305": "M037",
		"M030306": "M038",
		"M030307": "M039",
		"M030308": "M040",
		"M030309": "M041",
		"M030310": "M042"
	},
	"abilities": {
		"Ab001": "SK001",
		"Ab016": "SK002",
		"S002": "SK003",
		"S003": "SK004",
		"S004": "SK005",
		"S005": "SK006",
		"S006": "SK007",
		"S007": "SK008",
		"S008": "SK009",
		"S009": "SK010",
		"S010": "SK011",
		"S011": "SK012",
		"S012": "SK013",
		"S013": "SK014",
		"S014": "SK015",
		"S015": "SK016",
		"EN_SACRIFICE_SHIELD": "EN001",
		"EN_ADJACENT_ACCELERATE": "EN002",
		"EN_CORE_RETALIATE": "EN003",
		"EN_LOW_POLLUTION_HEAL": "EN004",
		"EN_HIGH_POLLUTION_DAMAGE": "EN005",
		"EN_BURN_ENGINE": "EN006",
		"EN_COLD_DELAY": "EN007",
		"EN_SHIELD_ECHO": "EN008",
		"EN_HEAL_ECHO": "EN009",
		"EN_LAST_MINION": "EN010",
		"TT_HOPE_CLEAN_01": "TA001",
		"TT_HOPE_CHAIN_02": "TA002",
		"TT_WITHER_RISK_01": "TA003",
		"TT_WITHER_BURN_02": "TA004",
		"TS_HOPE_TRINITY": "SY001",
		"TS_WITHER_TRINITY": "SY002",
		"TS_DIVERSE_ELEMENTS": "SY003",
		"AU_HOPE_REBIRTH": "AU001",
		"AU_HOPE_BARRIER": "AU002",
		"AU_WITHER_SURGE": "AU003",
		"AU_WITHER_EMBER": "AU004",
		"TT_HOPE_WARD_02": "TA005",
		"TT_WITHER_FROST_02": "TA006",
		"AU_HOPE_TEMPO": "AU005",
		"AU_HOPE_PURIFY": "AU006",
		"AU_HOPE_RESCUE": "AU007",
		"AU_HOPE_WINDWALL": "AU008",
		"AU_WITHER_TOXIN": "AU009",
		"AU_WITHER_FROST": "AU010",
		"AU_WITHER_SPIKE": "AU011",
		"AU_WITHER_CORRUPT": "AU012",
		"S001": "SK001",
		"S016": "SK002"
	},
	"equipment": {
		"E0001": "GA001",
		"E0002": "GA002",
		"E0003": "GA003",
		"E0004": "GA004",
		"IC_WEAPON_QUICK": "IC001",
		"IC_WEAPON_HEAVY": "IC002",
		"IC_SHIELD": "IC003",
		"IC_HEAL": "IC004",
		"IC_BURN": "IC005",
		"IC_POISON": "IC006",
		"IC_FREEZE": "IC007",
		"IC_SLOW": "IC008",
		"IC_CHAIN": "IC009",
		"IC_POLLUTION_UP": "IC010",
		"IC_POLLUTION_DOWN": "IC011",
		"IC_RESCUE": "IC012",
		"GA_CORE_VITAL": "GA005",
		"GA_MINION_SACRIFICE": "GA006",
		"GA_ITEM_OVERCLOCK": "GA007",
		"GA_HOPE_CLEAN": "GA008",
		"GA_WITHER_RISK": "GA009",
		"GA_BURN": "GA010",
		"GA_GUARD": "GA011",
		"GA_COOLDOWN": "GA012"
	},
	"items": {
		"I001": "IT001",
		"F_H001": "FR001",
		"F_H002": "FR002",
		"F_H003": "FR003",
		"F_H004": "FR004",
		"F_H005": "FR005",
		"F_H006": "FR006",
		"F_H007": "FR007",
		"F_H008": "FR008",
		"F_H009": "FR009",
		"F_H010": "FR010",
		"F_H011": "FR011",
		"F_H012": "FR012",
		"F_H013": "FR013",
		"F_H014": "FR014",
		"F_H015": "FR015",
		"F_H016": "FR016",
		"F_Hs001": "FR017",
		"F_Hs002": "FR018",
		"F_Hs003": "FR019",
		"F_Hs004": "FR020",
		"F_Hs005": "FR021",
		"F_Hs006": "FR022",
		"F_Hs007": "FR023",
		"F_Hs008": "FR024",
		"F_Hs009": "FR025",
		"F_Hs010": "FR026",
		"F_Hs011": "FR027",
		"F_Hs012": "FR028",
		"F_Hs013": "FR029",
		"F_Hs014": "FR030",
		"F_Hs015": "FR031",
		"F_Hs016": "FR032",
		"F_E0001": "FR033",
		"F_E0002": "FR034",
		"F_E0003": "FR035",
		"F_E0004": "FR036",
		"F_IC_WEAPON_QUICK": "FR037",
		"F_IC_WEAPON_HEAVY": "FR038",
		"F_IC_SHIELD": "FR039",
		"F_IC_HEAL": "FR040",
		"F_IC_BURN": "FR041",
		"F_IC_POISON": "FR042",
		"F_IC_FREEZE": "FR043",
		"F_IC_SLOW": "FR044",
		"F_IC_CHAIN": "FR045",
		"F_IC_POLLUTION_UP": "FR046",
		"F_IC_POLLUTION_DOWN": "FR047",
		"F_IC_RESCUE": "FR048",
		"F_GA_CORE_VITAL": "FR049",
		"F_GA_MINION_SACRIFICE": "FR050",
		"F_GA_ITEM_OVERCLOCK": "FR051",
		"F_GA_HOPE_CLEAN": "FR052",
		"F_GA_WITHER_RISK": "FR053",
		"F_GA_BURN": "FR054",
		"F_GA_GUARD": "FR055",
		"F_GA_COOLDOWN": "FR056"
	},
	"monster_sets": {
		"Monster0101": "MS001",
		"Monster0102": "MS002",
		"Monster0103": "MS003",
		"Monster0201": "MS004",
		"Monster0202": "MS005",
		"Monster0203": "MS006",
		"Monster0301": "MS007",
		"Monster0302": "MS008",
		"Monster0303": "MS009"
	},
	"chapters": {
		"Chapter00101": "CH001",
		"Chapter00102": "CH002",
		"Chapter00103": "CH003",
		"Chapter00201": "CH004",
		"Chapter00202": "CH005",
		"Chapter00203": "CH006",
		"Chapter00301": "CH007",
		"Chapter00302": "CH008",
		"Chapter00303": "CH009"
	},
	"dices": {
		"RewardDice": "DI001"
	},
	"commodities": {
		"Shop_H001": "SH001",
		"Shop_H002": "SH002",
		"Commodity003": "SH003",
		"Commodity004": "SH004",
		"Commodity005": "SH005",
		"Commodity006": "SH006",
		"Commodity007": "SH007",
		"Shop_H008": "SH008",
		"Shop_H009": "SH009",
		"Shop_H010": "SH010",
		"Shop_H011": "SH011",
		"Shop_H012": "SH012",
		"Shop_H013": "SH013",
		"Shop_H014": "SH014",
		"Shop_H015": "SH015",
		"Shop_H016": "SH016",
		"Shop_Hs001": "SH017",
		"Shop_Hs002": "SH018",
		"Shop_Hs003": "SH019",
		"Shop_Hs004": "SH020",
		"Shop_Hs005": "SH021",
		"Shop_Hs006": "SH022",
		"Shop_Hs007": "SH023",
		"Shop_Hs008": "SH024",
		"Shop_Hs009": "SH025",
		"Shop_Hs010": "SH026",
		"Shop_Hs011": "SH027",
		"Shop_Hs012": "SH028",
		"Shop_Hs013": "SH029",
		"Shop_Hs014": "SH030",
		"Shop_Hs015": "SH031",
		"Shop_Hs016": "SH032",
		"Shop_E0001": "SH033",
		"Shop_E0002": "SH034",
		"Shop_E0003": "SH035",
		"Shop_E0004": "SH036",
		"Shop_IC_WEAPON_QUICK": "SH037",
		"Shop_IC_WEAPON_HEAVY": "SH038",
		"Shop_IC_SHIELD": "SH039",
		"Shop_IC_HEAL": "SH040",
		"Shop_IC_BURN": "SH041",
		"Shop_IC_POISON": "SH042",
		"Shop_IC_FREEZE": "SH043",
		"Shop_IC_SLOW": "SH044",
		"Shop_IC_CHAIN": "SH045",
		"Shop_IC_POLLUTION_UP": "SH046",
		"Shop_IC_POLLUTION_DOWN": "SH047",
		"Shop_IC_RESCUE": "SH048",
		"Shop_GA_CORE_VITAL": "SH049",
		"Shop_GA_MINION_SACRIFICE": "SH050",
		"Shop_GA_ITEM_OVERCLOCK": "SH051",
		"Shop_GA_HOPE_CLEAN": "SH052",
		"Shop_GA_WITHER_RISK": "SH053",
		"Shop_GA_BURN": "SH054",
		"Shop_GA_GUARD": "SH055",
		"Shop_GA_COOLDOWN": "SH056"
	},
	"adventure_node_rules": {
		"Rest": "NR001",
		"Relic": "NR002",
		"BlackMarket": "NR003",
		"Advanture": "NR004"
	}
}
const MARKET_OFFERS = {
	"gear:GA001": "TO001",
	"gear:GA002": "TO002",
	"gear:GA003": "TO003",
	"gear:GA004": "TO004",
	"gear:GA005": "TO005",
	"gear:GA006": "TO006",
	"gear:GA007": "TO007",
	"gear:GA008": "TO008",
	"gear:GA009": "TO009",
	"gear:GA010": "TO010",
	"gear:GA011": "TO011",
	"gear:GA012": "TO012",
	"item:IC001": "TO013",
	"item:IC002": "TO014",
	"item:IC003": "TO015",
	"item:IC004": "TO016",
	"item:IC005": "TO017",
	"item:IC006": "TO018",
	"item:IC007": "TO019",
	"item:IC008": "TO020",
	"item:IC009": "TO021",
	"item:IC010": "TO022",
	"item:IC011": "TO023",
	"item:IC012": "TO024",
	"minion:HS001": "TO025",
	"minion:HS002": "TO026",
	"minion:HS003": "TO027",
	"minion:HS004": "TO028",
	"minion:HS005": "TO029",
	"minion:HS006": "TO030",
	"minion:HS007": "TO031",
	"minion:HS008": "TO032",
	"minion:HS009": "TO033",
	"minion:HS010": "TO034",
	"minion:HS011": "TO035",
	"minion:HS012": "TO036",
	"minion:HS013": "TO037",
	"minion:HS014": "TO038",
	"minion:HS015": "TO039",
	"minion:HS016": "TO040",
	"utility:gold": "TO041",
	"utility:talent-point": "TO042"
}
var error: String = ""

## 显式查询登记映射；未知值留给完整恢复校验拒绝。
static func resolve(table: String, id: String) -> String:
	return MAPS.get(table, {}).get(id, id)

## 历史市场 ID 逐项映射为独立报价 ID，不推断编号关系。
static func offer_id(id: String) -> String:
	var prefix = id.get_slice(":", 0)
	if prefix in ["minion", "item", "gear"]:
		id = prefix + ":" + resolve("cards" if prefix == "minion" else "equipment", id.substr(prefix.length() + 1))
	return MARKET_OFFERS.get(id, id)

## 只转换候选副本；任何结构错误都由调用者保留原文件。
func convert(saved: Dictionary, catalog: RefCounted) -> Dictionary:
	error = ""
	var state = saved.duplicate(true)
	for key in ["collection", "assets", "shop", "chapters", "build"]:
		if not state.get(key) is Dictionary: return _fail("旧存档缺少 " + key)
	for table in ["cards", "equipment", "dices"]:
		if not state.collection.get(table) is Dictionary: return _fail("旧收藏集合损坏。")
		state.collection[table] = _keys(state.collection[table], table)
	if not state.collection.get("selected_hero") is String: return _fail("旧英雄选择损坏。")
	state.collection.selected_hero = resolve("cards", state.collection.selected_hero)
	if not state.assets.get("items") is Dictionary: return _fail("旧背包损坏。")
	state.assets.items = _keys(state.assets.items, "items")
	state.shop = _keys(state.shop, "commodities")
	state.chapters = _keys(state.chapters, "chapters")
	if not state.get("unlocked") is Array or not state.get("selected_chapter") is String: return _fail("旧章节选择损坏。")
	state.unlocked = _ids(state.unlocked, "chapters")
	state.selected_chapter = resolve("chapters", state.selected_chapter)
	for route in state.chapters.values():
		if not route is Dictionary or not route.get("nodes") is Array: return _fail("旧路线损坏。")
		for node in route.nodes:
			if node == null: continue
			if not node is Dictionary or not node.get("monsters") is Array: return _fail("旧节点损坏。")
			node.monsters = _ids(node.monsters, "cards")
			node.event_terms = preload("res://features/player_session/adventure_node_migration.gd").legacy_terms(node.get("type", -1), catalog.content)
	var build: Dictionary = state.build
	if build.get("started") == true:
		for key in ["cards", "gear", "talents", "auroras", "pending_auroras"]:
			if not build.get(key) is Array: return _fail("旧构筑集合损坏。")
		for card in build.cards:
			if not card is Dictionary or not card.get("definition_id") is String: return _fail("旧构筑卡牌损坏。")
			card.definition_id = resolve("equipment" if card.get("kind") == CardTypes.Kind.ItemCard else "cards", card.definition_id)
		for attachment in build.gear:
			if not attachment is Dictionary or not attachment.get("gear_id") is String: return _fail("旧附着关系损坏。")
			attachment.gear_id = resolve("equipment", attachment.gear_id)
		build.talents = _ids(build.talents, "abilities")
		build.pending_auroras = _ids(build.pending_auroras, "abilities")
		build.aurora_counts = {}
		for id in _ids(build.auroras, "abilities"):
			if build.aurora_counts.has(id): return _fail("旧星能集合重复。")
			build.aurora_counts[id] = 1
		if not build.get("market") is Dictionary: return _fail("旧市场损坏。")
		upgrade_market(build.market, catalog)
	else:
		build.aurora_counts = {}
	build.erase("auroras")
	state.schema = 13
	return state if error.is_empty() else {}

## 原生十三版只迁移报价标识和轮次字段，保留已锁定的价格、数量和随机状态。
func convert_market_schema(saved: Dictionary) -> Dictionary:
	error = ""
	var state = saved.duplicate(true)
	if not state.get("build") is Dictionary: return _fail("旧章节构筑损坏。")
	if state.build.get("started") == true:
		var market: Variant = state.build.get("market")
		if not market is Dictionary or not market.get("slots") is Array or not market.get("round_rules") is Dictionary: return _fail("旧市场结构损坏。")
		var names = {"opening_cost_per_slot": "open_dice_cost_per_slot", "reroll_cost_per_slot": "reroll_dice_cost_per_slot"}
		for old in names:
			if not market.round_rules.has(old): continue
			if market.round_rules.has(names[old]): return _fail("旧市场字段冲突。")
			market.round_rules[names[old]] = market.round_rules[old]
			market.round_rules.erase(old)
		for slot in market.slots:
			if not slot is Dictionary or not slot.get("offer_id") is String: return _fail("旧市场报价引用损坏。")
			slot.offer_id = offer_id(slot.offer_id)
	state.schema = 14
	return state

## 早期市场仅规范引用供一次性骰子迁移，不再查询已经退出的报价目录。
func upgrade_market(market: Dictionary, _catalog: RefCounted) -> void:
	if not market.get("slots") is Array:
		error = "旧市场槽位损坏。"
		return
	market.round_rules = {} if market.slots.is_empty() else {"slot_count": 5, "open_dice_cost_per_slot": 1, "reroll_dice_cost_per_slot": 1}
	for slot in market.slots:
		if not slot is Dictionary or not slot.get("offer_id") is String:
			error = "旧市场候选损坏。"
			return
		slot.offer_id = offer_id(slot.offer_id)
		if not slot.offer_id in MARKET_OFFERS.values():
			error = "旧市场引用未知奖励。"
			return

## 字典键转换不允许碰撞，防止数量或进度被覆盖。
func _keys(values: Dictionary, table: String) -> Dictionary:
	var result: Dictionary = {}
	for key in values:
		if not key is String: error = "旧内容标识不是字符串。"; return {}
		var id = resolve(table, key)
		if result.has(id): error = "旧内容标识映射冲突: " + id; return {}
		result[id] = values[key]
	return result

## 列表顺序不变，非字符串不做隐式转换。
func _ids(values: Array, table: String) -> Array:
	var result: Array = []
	for id in values:
		if not id is String: error = "旧内容引用不是字符串。"; return []
		result.append(resolve(table, id))
	return result

## 迁移失败不暴露部分候选。
func _fail(message: String) -> Dictionary:
	error = message
	return {}
