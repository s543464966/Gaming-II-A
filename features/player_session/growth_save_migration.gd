extends RefCounted
## Schema 17→18 只转换成长事实，保留旧计数凭据，不把历史占位字段解释为新星级。

var error: String = ""

## 在独立候选中迁移账号卡牌、同目标装备以及进行中章节的永久成长记录。
func convert(saved: Dictionary, content: RefCounted) -> Dictionary:
	error = ""
	var result = saved.duplicate(true)
	if not result.get("collection") is Dictionary or not result.get("build") is Dictionary or not result.get("assets") is Dictionary: return _fail("成长迁移缺少必要容器。")
	var collection: Dictionary = result.collection
	if not collection.get("cards") is Dictionary or not collection.get("equipment") is Dictionary: return _fail("成长迁移收藏格式损坏。")
	collection.migration_receipt = {}
	for id in collection.cards:
		var card: Variant = collection.cards[id]
		if not card is Dictionary or card.size() != 3: return _fail("旧收藏成长字段损坏。")
		for key in ["rank", "grade"]:
			if not card.get(key) is int or card[key] < 0: return _fail("旧收藏成长字段损坏。")
		if card.rank != 0 or card.grade != 0: collection.migration_receipt[id] = {"rank": card.rank, "grade": card.grade}
		var row: Dictionary = content.get_record("cards", id)
		if row.is_empty() or not (card.get("health") is int or card.get("health") is float) or not is_finite(float(card.health)) or card.health < 0: return _fail("旧收藏生命或内容定义损坏。")
		card.health_ratio = clampf(float(card.health) / float(row.max_health), 0, 1)
		card.erase("health")
		card.erase("rank")
		card.erase("grade")
		card.star_level = 1
	for id in collection.equipment.keys():
		var row: Dictionary = content.get_record("cards", id)
		if row.is_empty() or row.card_kind != CardTypes.Kind.ItemCard: continue
		if not collection.equipment[id] is int or collection.equipment[id] < 0: return _fail("旧道具收藏数量损坏。")
		if collection.equipment[id] > 0: collection.cards[id] = {"health_ratio": 1.0, "star_level": 1}
		collection.equipment.erase(id)
	var build: Dictionary = result.build
	build.permanent_growth = {}
	if build.get("started", false):
		build = project_build(build)
		if not error.is_empty(): return {}
		result.build = build
		var state = CollectionState.new(content)
		var assets = PlayerAssets.new(content)
		# 当前收藏仅用于推导成长；历史候选保留旧字段直到遗物版本迁移。
		var projection: Dictionary = collection.duplicate(true)
		projection.relics = projection.equipment
		projection.erase("equipment")
		error = state.restore(projection)
		if not error.is_empty(): return {}
		error = assets.restore(result.assets)
		if not error.is_empty(): return {}
		build.permanent_growth = state.growth_snapshot(assets)
	result.schema = 18
	return result

## 旧迁移中途需要检查装备候选时，共用此结构投影，不提前发布账号成长。
func project_build(saved: Dictionary) -> Dictionary:
	var result = saved.duplicate(true)
	result.permanent_growth = {}
	if not result.get("attachments") is Array: return _fail("旧附着装备记录缺失。")
	var attachments: Array = []
	for item in result.attachments:
		if not item is Dictionary or item.size() != 3 or not item.get("target") is String or not item.get("content_id") is String or not item.get("kind") is int: return _fail("旧附着关系格式损坏。")
		var found = attachments.filter(func(value): return value.target == item.target and value.content_id == item.content_id and value.kind == item.kind)
		if found.is_empty():
			var value: Dictionary = item.duplicate(true)
			value.copies = 1
			attachments.append(value)
		else: found[0].copies += 1
	result.attachments = attachments
	return result

## 失败不返回可被发布的部分候选。
func _fail(message: String) -> Dictionary:
	error = message
	return {}
