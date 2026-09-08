class_name PlayerSessionState
extends RefCounted
## 一个账号的运行聚合与原子检查点；静态目录只注入、不复制进存档。

signal changed
const SCHEMA_VERSION = 25
const Format = preload("res://game_content/runtime/snapshot_format.gd")
const Migration = preload("res://features/player_session/content_id_migration.gd")
const DiceMigration = preload("res://features/player_session/dice_save_migration.gd")
const EquipmentMigration = preload("res://features/player_session/equipment_dice_migration.gd")
const GrowthMigration = preload("res://features/player_session/growth_save_migration.gd")
const OutputMigration = preload("res://features/player_session/output_save_migration.gd")
const NodeMigration = preload("res://features/player_session/adventure_node_migration.gd")
const TalentMigration = preload("res://features/player_session/talent_save_migration.gd")
const Talents = preload("res://features/talents/talent_state.gd")
const C = preload("res://game_content/runtime/content_types.gd")
const User = preload("res://features/account/user_state.gd")
const Collection = preload("res://features/collection/collection_state.gd")
const Assets = preload("res://features/backpack/player_assets.gd")
const Shop = preload("res://features/shop/shop_service.gd")
const Build = preload("res://features/game_modes_pve_adventure/domain/run_build.gd")
const BuildCodec = preload("res://features/game_modes_pve_adventure/domain/run_build_codec.gd")
const Adventure = preload("res://features/game_modes_pve_adventure/domain/adventure_catalog.gd")
const Route = preload("res://features/game_modes_pve_adventure/domain/route_state.gd")
var user_id: String
var content: GameCatalog
var user: UserState
var collection: CollectionState
var talents: TalentState
var assets: PlayerAssets
var shop: ShopService
var adventure: AdventureCatalog
var build: RunBuild
var routes: Dictionary = {}
var unlocked: Array = []
var selected_chapter: String = ""
var busy: bool = false
var error: String = ""

## 聚合各 Feature 的状态 Owner，不在此实现交易或战斗规则。
func _init(catalog: GameCatalog, identity: String) -> void:
	content = catalog
	user_id = identity
	user = User.new()
	talents = Talents.new(content)
	collection = Collection.new(content)
	collection.talents = talents
	assets = Assets.new(content)
	shop = Shop.new(content, assets, collection)
	adventure = Adventure.new(content)
	build = Build.new()

## 首次创建本机玩家的固定赠送规则，只在无存档时执行。
func initialize_new(now: int) -> void:
	user.settled_at = now
	collection.initialize_new()
	assets.gold = 3000
	assets.add_item("IT001", 40)
	for chapter in normal_chapters(): routes[chapter.id] = Route.new()
	selected_chapter = normal_chapters()[0].id
	unlocked = [selected_chapter]

## 当前只开放普通难度，其他配置继续留在静态目录。
func normal_chapters() -> Array:
	var chapters: Array = content.data.chapters.filter(func(row): return row.difficulty == C.Difficulty.Normal)
	chapters.sort_custom(func(a, b): return a.chapter_index < b.chapter_index)
	return chapters

## 只返回当前账号拥有的活动章节对象。
func current_route() -> RouteState:
	return routes.get(selected_chapter)

## 检查点包含所有可变业务状态，排除运行回调和资源对象。
func capture() -> Dictionary:
	var chapters: Dictionary = {}
	for id in routes: chapters[id] = routes[id].capture()
	return {"schema": SCHEMA_VERSION, "user_id": user_id, "user": user.capture(), "collection": collection.capture(),
		"assets": assets.capture(), "shop": shop.bought.duplicate(), "chapters": chapters, "unlocked": unlocked.duplicate(),
		"selected_chapter": selected_chapter, "build": build.capture(), "talents": talents.capture()}

## 完整验证候选对象后才发布，任何错误都不替换当前账号状态。
func restore(saved: Dictionary) -> bool:
	error = ""
	var state: Dictionary = Format.normalize_numbers(saved.duplicate(true))
	if state.get("schema") == 12:
		var migration = Migration.new()
		state = migration.convert(state, adventure)
		if not migration.error.is_empty():
			error = migration.error
			return false
	if state.get("schema") == 13:
		var migration = Migration.new()
		state = migration.convert_market_schema(state)
		if not migration.error.is_empty():
			error = migration.error
			return false
	if state.get("schema") == 14:
		var migration = DiceMigration.new()
		state = migration.convert(state, adventure)
		if not migration.error.is_empty():
			error = migration.error
			return false
	if state.get("schema") == 15:
		var migration = EquipmentMigration.new()
		state = migration.convert(state, adventure)
		if not migration.error.is_empty():
			error = migration.error
			return false
	if state.get("schema") == 16:
		var migration = DiceMigration.new()
		state = migration.remove_healing(state)
		if not migration.error.is_empty():
			error = migration.error
			return false
	if state.get("schema") == 17:
		var migration = GrowthMigration.new()
		state = migration.convert(state, content)
		if not migration.error.is_empty():
			error = migration.error
			return false
	if state.get("schema") == 18:
		var migration = NodeMigration.new()
		state = migration.convert(state, content)
		if not migration.error.is_empty():
			error = migration.error
			return false
	if state.get("schema") == 19:
		var migration = OutputMigration.new()
		state = migration.convert(state, content)
		if not migration.error.is_empty():
			error = migration.error
			return false
	if state.get("schema") == 20:
		var migration = OutputMigration.new()
		state = migration.convert_abilities(state, content)
		if not migration.error.is_empty():
			error = migration.error
			return false
	if state.get("schema") == 21:
		# 只转换生命整数边界，不修改份数、奖励、路线与永久培养事实。
		if not state.get("build") is Dictionary or not state.build.get("cards", []) is Array:
			error = "整数数值迁移缺少构筑。"
			return false
		for card in state.build.get("cards", []):
			if not card is Dictionary or not (card.get("health") is int or card.get("health") is float) or not is_finite(float(card.health)) or card.health < 0:
				error = "整数数值迁移遇到损坏生命。"
				return false
			card.health = maxf(1, CombatAttributes.points(card.health)) if card.health > 0 else 0.0
		state.schema = 22
	if state.get("schema") == 22:
		var migration = TalentMigration.new()
		state = migration.convert(state, normal_chapters())
		if not migration.error.is_empty():
			error = migration.error
			return false
	if state.get("schema") == 23:
		var migration = preload("res://features/player_session/aurora_save_migration.gd").new()
		state = migration.convert(state, adventure)
		if not migration.error.is_empty():
			error = migration.error
			return false
	if state.get("schema") == 24:
		var migration = preload("res://features/player_session/relic_save_migration.gd").new()
		state = migration.convert(state, adventure)
		if not migration.error.is_empty():
			error = migration.error
			return false
	if state.get("schema") != SCHEMA_VERSION or state.get("user_id") != user_id:
		error = "玩家存档版本或账号归属不匹配。"
		return false
	for key in ["user", "collection", "assets", "shop", "chapters", "build", "talents"]:
		if not state.get(key) is Dictionary:
			error = "玩家存档缺少 " + key
			return false
	var candidate_user = User.new()
	error = candidate_user.restore(state.user)
	if not error.is_empty(): return false
	var candidate_talents = Talents.new(content)
	error = candidate_talents.restore(state.talents)
	if not error.is_empty(): return false
	var candidate_collection = Collection.new(content)
	candidate_collection.talents = candidate_talents
	error = candidate_collection.restore(state.collection)
	if not error.is_empty(): return false
	var candidate_assets = Assets.new(content)
	error = candidate_assets.restore(state.assets)
	if not error.is_empty(): return false
	var candidate_shop = Shop.new(content, candidate_assets, candidate_collection)
	for id in state.shop:
		if content.get_record("shop_offers", id).is_empty() or not state.shop[id] is int or state.shop[id] < 0:
			error = "商城购买次数损坏。"
			return false
	candidate_shop.bought = state.shop.duplicate()
	if not state.get("unlocked") is Array or not state.get("selected_chapter") is String or not state.selected_chapter in state.unlocked:
		error = "章节选择或解锁状态损坏。"
		return false
	var candidate_routes: Dictionary = {}
	for chapter in normal_chapters():
		if not state.chapters.get(chapter.id) is Dictionary:
			error = "缺少正式章节存档: " + chapter.id
			return false
		var route = Route.new()
		error = route.restore(state.chapters[chapter.id], content)
		if not error.is_empty(): return false
		candidate_routes[chapter.id] = route
	for id in state.unlocked:
		if not candidate_routes.has(id):
			error = "解锁了未知章节。"
			return false
	var codec = BuildCodec.new()
	var candidate_build = codec.restore(state.build, adventure)
	if candidate_build == null:
		error = codec.error
		return false
	if candidate_build.started and candidate_build.core().definition_id != candidate_collection.selected_hero:
		error = "章节英雄与账号选择不一致。"
		return false
	if candidate_build.started and candidate_build.talents != candidate_talents.learned:
		error = "章节天赋输入与账号永久选择不一致。"
		return false
	user = candidate_user
	talents = candidate_talents
	collection = candidate_collection
	assets = candidate_assets
	shop = candidate_shop
	routes = candidate_routes
	unlocked = state.unlocked.duplicate()
	selected_chapter = state.selected_chapter
	build = candidate_build
	return true

## Home 学习与当前构筑更新共用账号事务，保存失败时一起回滚。
func unlock_talent(id: String, persist: Callable) -> String:
	if current_route() != null and current_route().phase == Route.Phase.NodeInProgress: return "请先结束当前战斗。"
	return transact(func() -> String:
		var message: String = talents.unlock(id)
		if not message.is_empty(): return message
		return build.update_talents(talents.learned, adventure), persist)

## 商城只提供购买规则；整笔扣款、交付与保存复用会话唯一事务。
func purchase(id: String, method: int, persist: Callable) -> int:
	if busy: return C.BuyResult.Busy
	var eligibility: int = shop.check_purchase(id, method)
	if eligibility != C.BuyResult.Success: return eligibility
	if not persist.is_valid(): return C.BuyResult.SaveFailed
	var outcome: Array[int] = [C.BuyResult.Success]
	var failure: String = transact(func() -> String:
		outcome[0] = shop.apply_purchase(id, method)
		return "" if outcome[0] == C.BuyResult.Success else "ui.shop.failure", persist)
	if not failure.is_empty() and outcome[0] == C.BuyResult.Success:
		return C.BuyResult.SaveFailed
	return outcome[0]

## 执行、保存和回滚统一一个入口；调用者不得提前宣布成功。
func transact(operation: Callable, persist: Callable) -> String:
	if busy: return "正在提交上一项操作。"
	if not operation.is_valid() or not persist.is_valid(): return "事务缺少操作或保存入口。"
	var before = capture()
	busy = true
	var failure: String = operation.call()
	if failure.is_empty() and not persist.call(): failure = "保存失败，本次变更未提交。"
	if not failure.is_empty() and not restore(before): failure += " 回滚失败: " + error
	busy = false
	changed.emit()
	return failure
