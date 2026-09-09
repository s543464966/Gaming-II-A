extends RefCounted
## Schema 26→27 将逐卡碎片成长合并为分类培养；不扣除或补发资产。

const LEGACY_COSTS = [10, 20, 40, 80]
const LEGACY_STEPS = 10
var error: String = ""

## 同类取最高星级及该星级最高进度；活动章节只改字段名，保持原数值。
func convert(saved: Dictionary, content: RefCounted) -> Dictionary:
	error = ""
	var result: Dictionary = saved.duplicate(true)
	if result.get("schema") != 26 or not result.get("collection") is Dictionary or not result.get("assets") is Dictionary or not result.get("build") is Dictionary: return _fail("分类成长迁移缺少必要容器。")
	var collection: Dictionary = result.collection
	if collection.has("category_growth") or not collection.get("cards") is Dictionary: return _fail("旧收藏成长格式损坏。")
	var facts: Dictionary = legacy_snapshot(collection.cards, result.assets, content)
	if not error.is_empty(): return {}
	var categories: Dictionary = CollectionState.fresh_growth()
	var lookup := CollectionState.new(content)
	for id: String in collection.cards:
		var category: String = lookup.category_for(id)
		if category.is_empty(): return _fail("旧收藏卡牌分类损坏。")
		var fact: Dictionary = facts[id]
		var current: Dictionary = categories[category]
		if fact.star_level > current.star_level or (fact.star_level == current.star_level and fact.fragment_steps > current.training_steps):
			categories[category] = {"star_level": fact.star_level, "training_steps": fact.fragment_steps}
		collection.cards[id].erase("star_level")
	collection.category_growth = categories
	result.build = project_build(result.build)
	if not error.is_empty(): return {}
	result.schema = 27
	return result

## 历史算法固定在迁移边界，不随新价格调整；供更早版本补齐锁定事实。
func legacy_snapshot(cards: Dictionary, assets: Dictionary, content: RefCounted) -> Dictionary:
	if not assets.get("items") is Dictionary: return _fail("旧碎片资产格式损坏。")
	var result: Dictionary = {}
	var lookup := CollectionState.new(content)
	for row: Dictionary in content.data.cards:
		if row.card_kind == CardTypes.Kind.Monster: continue
		var star: int = 1
		var steps: int = 0
		if cards.has(row.id):
			var saved: Variant = cards[row.id]
			if not saved is Dictionary or saved.size() != 2 or not saved.get("star_level") is int or saved.star_level < 1 or saved.star_level > 5: return _fail("旧收藏星级损坏。")
			star = saved.star_level
			var quantity: Variant = assets.items.get(lookup.fragment_id(row.id), 0)
			if not quantity is int or quantity < 0: return _fail("旧碎片数量损坏。")
			if star < 5:
				@warning_ignore("integer_division")
				steps = clampi(quantity, 0, LEGACY_COSTS[star - 1]) / (LEGACY_COSTS[star - 1] / LEGACY_STEPS)
		result[row.id] = {"star_level": star, "fragment_steps": steps}
	for id: Variant in cards:
		if not result.has(id): return _fail("旧收藏包含未知卡牌。")
	return result

## 中间迁移读取独立副本，不将账号统一成长覆盖已开始的章节。
func project_build(saved: Dictionary) -> Dictionary:
	var result: Dictionary = saved.duplicate(true)
	if result.is_empty(): return result
	if not result.get("permanent_growth") is Dictionary: return _fail("旧章节成长格式损坏。")
	for id: Variant in result.permanent_growth:
		var fact: Variant = result.permanent_growth[id]
		if not fact is Dictionary or fact.size() != 2 or not fact.get("star_level") is int or not fact.get("fragment_steps") is int: return _fail("旧章节成长字段损坏。")
		if fact.star_level < 1 or fact.star_level > 5 or fact.fragment_steps < 0 or fact.fragment_steps > LEGACY_STEPS or (fact.star_level == 5 and fact.fragment_steps != 0): return _fail("旧章节成长数值损坏。")
		fact.training_steps = fact.fragment_steps
		fact.erase("fragment_steps")
	return result

## 损坏候选不能被当成新号，也不能发布半份迁移结果。
func _fail(message: String) -> Dictionary:
	error = message
	return {}
