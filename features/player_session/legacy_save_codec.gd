class_name LegacySaveCodec
extends RefCounted
## Persistence 拥有的旧 Schema 1–11 导入边界；只转换 JSON，不依赖旧引擎。

const Migration = preload("res://features/player_session/content_id_migration.gd")
const Adventure = preload("res://features/game_modes_pve_adventure/domain/adventure_catalog.gd")
const Session = preload("res://features/player_session/player_session.gd")
const Build = preload("res://features/game_modes_pve_adventure/domain/run_build.gd")
const Route = preload("res://features/game_modes_pve_adventure/domain/route_state.gd")
const Formation = preload("res://features/game_modes_pve_adventure/domain/enemy_formation.gd")
const Account = preload("res://features/player_session/legacy_account_codec.gd")
const Format = preload("res://game_content/runtime/snapshot_format.gd")
const C = preload("res://game_content/runtime/content_types.gd")
var content: GameCatalog
var error: String = ""
var warnings: Array[String] = []
var _version: int = 1
var _identity: String = ""

## 注入当前唯一静态目录，所有旧 ID 都必须能核验。
func _init(catalog: GameCatalog) -> void:
	content = catalog

## 完整转换并通过现行恢复校验后才返回候选，失败不会部分写盘。
func convert(document: Dictionary, user_id: String) -> Dictionary:
	error = ""
	warnings.clear()
	_identity = user_id
	var raw: Dictionary = Format.normalize_numbers(document.duplicate(true))
	_version = maxi(1, _integer(raw, "schemaVersion", 1))
	if _version > 11 or not raw.get("schemaVersion", 1) is int:
		return _fail("此导入入口只接受旧 Schema 1–11。")
	if not str(raw.get("userId", "")).is_empty() and raw.userId != user_id: return _fail("旧存档不属于目标账号。")
	if _version >= 10:
		for key in ["SD_User", "SD_Collection", "SD_PlayerAssets"]:
			if not raw.get(key) is Dictionary: return _fail("旧存档缺少必要容器: " + key)
	var player = Session.new(content, user_id)
	var state: Dictionary = player.capture()
	state.schema = 14
	var user = _object(raw.get("SD_User"), "用户资料")
	state.user = {"name": user.get("playerId", "勇者"), "stamina": _integer(user, "stamina"),
		"settled_at": Account.timestamp(user.get("lastStaminaUpdateTime", "")),
		"tutorial_completed": _boolean(user, "isCompleted_NewLevel"), "dice_capacity": _integer(user, "playerDiceMax"), "auto_play": _boolean(user, "isAutoPlay")}
	if not state.user.name is String or state.user.name.is_empty(): state.user.name = "勇者"
	state.collection = _collection(raw)
	state.assets = _assets(raw, user)
	state.shop = _shop(raw)
	# 旧 Unity 存档的原始字段保持不变；停止支持该格式时随导入器一同移除。
	state.build = _build(_object(raw.get("SD_TowerRunBuild"), "章节构筑"))
	_chapters(raw, state, player.normal_chapters())
	if not error.is_empty(): return {}
	if not player.restore(state): return _fail(player.error)
	return player.capture()

## 收藏只转换已拥有事实；不把账号收藏变成章节构筑卡牌。
func _collection(raw: Dictionary) -> Dictionary:
	var source = _object(raw.get("SD_Collection"), "收藏")
	var result = {"cards": {}, "dices": {}, "equipment": {}, "selected_hero": source.get("selectedCoreIdentityId", ""), "hero_position": _integer(source, "selectedCorePositionIndex", -1)}
	var cards = _rows(source.get("cards"), "收藏卡牌")
	if _version < 10 and cards.is_empty():
		for item in _rows(raw.get("SD_HeroCards"), "旧英雄列表"):
			if not item is Dictionary:
				error = "旧英雄记录损坏。"
				continue
			cards.append({"cardId": item.get("cardID", ""), "currentHealth": item.get("hp", 0), "rank": 0, "grade": 0})
			if str(result.selected_hero).is_empty():
				var position = _legacy_position(_integer(item, "posIndex", -1))
				if position >= 0:
					result.selected_hero = item.get("cardID", "")
					result.hero_position = position
	for item in cards:
		if not item is Dictionary:
			error = "收藏卡牌记录损坏。"
			continue
		var id = _id(item, "cardId")
		if result.cards.has(id): continue
		result.cards[id] = {"health": _real(item, "currentHealth"), "rank": maxi(0, _integer(item, "rank")), "grade": maxi(0, _integer(item, "grade"))}
	if not result.cards.has("H001"):
		result.cards.H001 = {"health": float(content.get_record("cards", "H001").max_health), "rank": 0, "grade": 0}
	result.selected_hero = Migration.resolve("cards", str(result.selected_hero))
	var selected: Dictionary = content.get_record("cards", str(result.selected_hero))
	if selected.is_empty() or selected.card_kind != CardTypes.Kind.CoreHero or not result.cards.has(result.selected_hero) or BattleGrid.footprint_mask(result.hero_position, selected.footprint_width, selected.footprint_height) == 0:
		result.selected_hero = "H001"
		result.hero_position = 22
	var dices = _rows(source.get("dices"), "收藏骰子")
	if _version < 10 and dices.is_empty():
		for item in _object(raw.get("SD_Dices"), "旧骰子列表").values():
			if not item is Dictionary:
				error = "旧骰子记录损坏。"
				continue
			dices.append({"diceId": item.get("diceID", ""), "quantity": item.get("getNum", 0), "isEquipped": item.get("isDiceFight", false)})
	for item in dices:
		if not item is Dictionary:
			error = "骰子记录损坏。"
			continue
		var id = _id(item, "diceId")
		var quantity = maxi(0, _integer(item, "quantity"))
		if id in ["D001", "D002"]:
			warnings.append("旧新手骰 %s 已不在静态目录中，按原加载规则排除；未改写成章节奖励骰。" % id)
			continue
		if not result.dices.has(id) and quantity > 0: result.dices[id] = {"quantity": quantity, "equipped": _boolean(item, "isEquipped")}
	var equipment = _rows(source.get("equipment"), "收藏装备")
	if _version < 10 and equipment.is_empty():
		for item in _object(raw.get("SD_Equips"), "旧装备列表").values():
			if not item is Dictionary:
				error = "旧装备记录损坏。"
				continue
			equipment.append({"equipmentId": item.get("equipId", ""), "quantity": item.get("getNum", 0)})
	for item in equipment:
		if not item is Dictionary:
			error = "装备收藏记录损坏。"
			continue
		var id = _id(item, "equipmentId")
		if not result.equipment.has(id): result.equipment[id] = maxi(0, _integer(item, "quantity"))
	return result

## 旧双列表坐标转换只对 Schema 1–9 的历史英雄列表执行一次。
func _legacy_position(position: int) -> int:
	if position < 0: return -1
	if _version < 3: return position + 15 if position < 15 else -1
	if _version < 7 and position < 15: return position + 15
	return position if position < 30 else -1

## 货币取既有规范字段与旧字段的较大值，物品合并正数数量。
func _assets(raw: Dictionary, user: Dictionary) -> Dictionary:
	var source = _object(raw.get("SD_PlayerAssets"), "玩家资产")
	var result = {"gold": maxi(0, _integer(source, "gold")), "star_stone": maxi(0, _integer(source, "starStone")), "items": {}}
	var items = _rows(source.get("items"), "背包物品")
	if _version < 10:
		result.gold = maxi(result.gold, _integer(user, "gold"))
		result.star_stone = maxi(result.star_stone, _integer(user, "starStone"))
		if items.is_empty():
			for item in _rows(raw.get("SD_Items"), "旧背包物品"):
				if not item is Dictionary:
					error = "旧背包记录损坏。"
					continue
				items.append({"itemId": item.get("itemID", ""), "quantity": item.get("itemCount", 0)})
	for item in items:
		if not item is Dictionary:
			error = "背包记录损坏。"
			continue
		var id = _id(item, "itemId")
		var quantity = _integer(item, "quantity")
		if quantity > 0: result.items[id] = result.items.get(id, 0) + quantity
	return result

## 购买次数继续使用商品 ID，不误写为奖励内容 ID。
func _shop(raw: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for item in _rows(_object(raw.get("SD_Mall"), "商城").get("saveData_Commodity"), "商品购买记录"):
		if not item is Dictionary:
			error = "商品记录损坏。"
			continue
		var id = _id(item, "commodityId")
		if result.has(id): error = "商品购买记录重复。"
		result[id] = maxi(0, _integer(item, "boughtCount"))
	return result

## 原样保留章节路线与节点坐标；旧版缺失阵型才稳定补齐一次。
func _chapters(raw: Dictionary, state: Dictionary, chapters: Array) -> void:
	var saved = _object(raw.get("SD_NormalChapters"), "普通章节")
	var selected_index = _integer(raw, "selectedChapterIndex", 1)
	var known: Array = chapters.map(func(chapter): return str(chapter.chapter_index))
	for key in saved:
		if not str(key) in known:
			error = "旧档包含未知普通章节。"
			return
	state.chapters = {}
	state.unlocked = []
	state.selected_chapter = ""
	for chapter in chapters:
		var old = _object(saved.get(str(chapter.chapter_index)), "章节记录")
		var route = Route.new()
		var levels = _rows(old.get("saveData_Levels_Route"), "章节路线")
		for i in range(levels.size()):
			if levels[i] == null:
				route.nodes.append(null)
				continue
			if not levels[i] is Dictionary:
				error = "路线节点格式损坏。"
				return
			route.nodes.append(_node(levels[i], i, levels.size(), chapter.chapter_index))
		route.completed = _boolean(old, "isCompleted")
		route.phase = Route.Phase.ChapterCompleted if route.completed else Route.Phase.RouteSelection
		for node in route.nodes:
			if node != null and node.completed: route.current = node.index
		if chapter.chapter_index == selected_index:
			var index = _integer(raw, "currentLevelIndex", -1)
			var phase = _integer(raw, "currentChapterEntryState", 1)
			if index >= 0 and index < route.nodes.size() and route.nodes[index] != null:
				if phase == Route.Phase.NodeInProgress and not route.nodes[index].completed:
					route.current = index
					route.phase = phase
				elif route.nodes[index].completed: route.current = index
			elif not route.completed:
				for i in range(levels.size()):
					if levels[i] is Dictionary and levels[i].get("isSelected", false) and not route.nodes[i].completed:
						route.current = i
						route.phase = Route.Phase.NodeInProgress
		state.chapters[chapter.id] = route.capture()
		if _boolean(old, "isUnlocked"): state.unlocked.append(chapter.id)
		if chapter.chapter_index == selected_index: state.selected_chapter = chapter.id
	if state.unlocked.is_empty(): state.unlocked.append(chapters[0].id)
	if not state.selected_chapter in state.unlocked: state.selected_chapter = state.unlocked[0]

## 节点层号由固定三槽索引派生，不复制冗余同层引用。
func _node(old: Dictionary, index: int, count: int, chapter: int) -> Dictionary:
	var node = {"index": index, "layer": 0 if index == 0 else (count - 2) / 3 + 1 if index == count - 1 else (index - 1) / 3 + 1,
		"lane": 1 if index == 0 or index == count - 1 else (index - 1) % 3, "type": _integer(old, "levelType"),
		"monsters": _rows(old.get("monsterSO_List"), "怪物 ID"), "enemy_positions": _rows(old.get("enemyPositions"), "怪物坐标"),
		"monster_count": _integer(old, "monsterCount"), "reward_dice": _integer(old, "rewardDiceCount"), "stamina": _integer(old, "staminaCost"),
		"next": _rows(old.get("nextLayer"), "后继节点"), "before": _rows(old.get("beforeLayer"), "前驱节点"),
		"roads": _rows(old.get("levelRoadSpriteStatus"), "路线显示槽"), "selected_roads": _rows(old.get("levelRoadStatus"), "路线选择槽"),
		"unlocked": _boolean(old, "isUnlocked"), "completed": _boolean(old, "isCompleted"), "stars": _integer(old, "levelStar")}
	node.monsters = node.monsters.map(func(id): return Migration.resolve("cards", str(id)))
	node.event_terms = preload("res://features/player_session/adventure_node_migration.gd").legacy_terms(node.type, content)
	if _version < 11 and old.get("enemyPositions") == null:
		var footprints: Array = []
		for id in node.monsters:
			var definition: Dictionary = content.get_record("cards", str(id))
			if definition.is_empty():
				error = "旧路线引用未知怪物。"
				return node
			footprints.append(Vector2i(definition.footprint_width, definition.footprint_height))
		var formation = Formation.new()
		node.enemy_positions = formation.generate(footprints, _formation_seed("%s:%d:%d" % [_identity, chapter, index]))
		if not formation.error.is_empty(): error = formation.error
	return node

## FNV-1a 保留三十二位溢出，与既有固定阵型迁移种子一致。
static func _formation_seed(identity: String) -> int:
	var value: int = 2166136261
	for character in identity: value = ((value ^ character.unicode_at(0)) * 16777619) & 0xffffffff
	return value

## 原样保留附着顺序、待领候选与市场轮次；旧技能卡按份数一次退款。
func _build(old: Dictionary) -> Dictionary:
	var result = Build.new().capture()
	result.erase("relics")
	result.attachments = []
	result.reward_cards = []
	result.erase("aurora_rewards")
	result.aurora_counts = {}
	result.pending_auroras = []
	result.faction = 0
	if not _boolean(old, "isStarted"): return result
	result.gear = []
	result.started = true
	for pair in [["faction", "faction"], ["gold", "gold"], ["pollution", "pollution"], ["talent_points", "talentPoints"],
		["next_sequence", "nextInstanceSequence"], ["reward_seed", "pendingRewardSeed"]]: result[pair[0]] = _integer(old, pair[1])
	result.pending_reward = _boolean(old, "hasPendingPostBattleReward")
	result.talents = _rows(old.get("talentIds"), "天赋").map(func(id): return Migration.resolve("abilities", str(id)))
	for id in _rows(old.get("auroraIds"), "星能"):
		var canonical = Migration.resolve("abilities", str(id))
		if result.aurora_counts.has(canonical): error = "旧星能集合重复。"
		result.aurora_counts[canonical] = 1
	result.pending_auroras = _rows(old.get("pendingAuroraChoiceIds"), "星能候选").map(func(id): return Migration.resolve("abilities", str(id)))
	var seen: Array = []
	for card in _rows(old.get("cards"), "章节卡牌"):
		if not card is Dictionary:
			error = "章节卡牌记录损坏。"
			continue
		var id = _id(card, "instanceId")
		if id in seen:
			error = "章节实例 ID 重复。"
			continue
		seen.append(id)
		var definition_id = _id(card, "definitionId")
		var kind = _integer(card, "kind")
		var copies = _integer(card, "baseCopies", 1)
		if kind == 3:
			var ability: Dictionary = _legacy_main_ability(definition_id)
			if ability.is_empty() or copies < 1 or copies > 9:
				error = "旧技能卡引用或融合份数损坏。"
				continue
			result.gold += copies * 10
			warnings.append("已移除旧独立技能卡 %s，退还 %d 金币并在迁移后计入账号。" % [definition_id, copies * 10])
			continue
		definition_id = Migration.resolve("equipment" if kind == CardTypes.Kind.ItemCard else "cards", definition_id)
		result.cards.append({"id": id, "definition_id": definition_id, "kind": kind, "health": _real(card, "currentHealth"), "position": _integer(card, "positionIndex", -1), "copies": copies})
	for attachment in _rows(old.get("gearAttachments"), "附着装备"):
		if not attachment is Dictionary:
			error = "附着记录损坏。"
			continue
		result.gear.append({"gear_id": _id(attachment, "gearId"), "target": _id(attachment, "targetInstanceId")})
	var market = _object(old.get("rewardMarket"), "奖励市场")
	result.market = {"dice": _integer(market, "availableDice"), "seed": _integer(market, "seed"), "roll": _integer(market, "rollIndex"), "slots": []}
	for slot in _rows(market.get("slots"), "市场槽位"):
		if not slot is Dictionary:
			error = "市场槽位格式损坏。"
			continue
		var offer_id = _id(slot, "offerId")
		if offer_id.begins_with("ability:"):
			var ability: Dictionary = _legacy_main_ability(offer_id.trim_prefix("ability:"))
			if ability.is_empty():
				error = "旧市场包含未知技能。"
				continue
			offer_id = "utility:gold"
		result.market.slots.append({"index": _integer(slot, "index"), "face": _integer(slot, "face"), "offer_id": offer_id, "locked": _boolean(slot, "isLocked"), "purchased": _boolean(slot, "isPurchased")})
	result.market.slots.sort_custom(func(a, b): return a.index < b.index)
	var migration = Migration.new()
	migration.upgrade_market(result.market, Adventure.new(content))
	if not migration.error.is_empty(): error = migration.error
	return result

## 只有历史迁移解析旧能力别名，运行时按明确的内容表查询。
func _legacy_main_ability(id: String) -> Dictionary:
	var alias: Dictionary = content.get_record("ability_aliases", id)
	return content.get_record("main_abilities", str(alias.get("ability_id", id)))

## 缺失的历史容器采用旧格式默认值，错误类型则明确拒绝。
func _object(value: Variant, label: String) -> Dictionary:
	if value == null: return {}
	if value is Dictionary: return value
	error = label + "不是对象。"
	return {}

## 历史空列表可以省略，但不能把错误类型当作没有进度。
func _rows(value: Variant, label: String) -> Array:
	if value == null: return []
	if value is Array: return value.duplicate(true)
	error = label + "不是数组。"
	return []

## 整数必须来自合法 JSON 数字，拒绝字符串和隐式布尔转换。
func _integer(row: Dictionary, key: String, fallback: int = 0) -> int:
	var value: Variant = row.get(key, fallback)
	if value is int: return value
	error = "旧字段 %s 不是整数。" % key
	return fallback

## 生命保留浮点精度且拒绝非有限值。
func _real(row: Dictionary, key: String) -> float:
	var value: Variant = row.get(key, 0)
	if (value is int or value is float) and is_finite(float(value)) and value >= 0: return float(value)
	error = "旧字段 %s 不是有效生命数值。" % key
	return 0

## 缺失布尔使用历史默认值，错误类型不静默放行。
func _boolean(row: Dictionary, key: String) -> bool:
	var value: Variant = row.get(key, false)
	if value is bool: return value
	error = "旧字段 %s 不是布尔值。" % key
	return false

## 所有持久引用必须是非空稳定标识。
func _id(row: Dictionary, key: String) -> String:
	var value: Variant = row.get(key, "")
	if value is String and not value.is_empty():
		var tables = {"cardId": "cards", "equipmentId": "equipment", "gearId": "equipment", "diceId": "dices", "itemId": "items", "commodityId": "commodities"}
		return Migration.resolve(tables[key], value) if tables.has(key) else value
	error = "旧存档缺少标识 " + key
	return ""

## 失败不返回可能被误保存的部分转换结果。
func _fail(message: String) -> Dictionary:
	error = message
	return {}
