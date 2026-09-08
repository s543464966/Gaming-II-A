extends RefCounted
## 将旧绑定与待分配装备按实际份数转换为章节遗物，来源存档保持只读。

var error: String = ""
const MAX_EXPANDED_RELICS: int = 100000

## 只发布完整候选；路线、奖励随机状态与账号解锁均原样保留。
func convert(saved: Dictionary, catalog: AdventureCatalog) -> Dictionary:
	error = ""
	var result: Dictionary = saved.duplicate(true)
	if not result.get("collection") is Dictionary or not result.collection.get("equipment") is Dictionary or result.collection.has("relics"): return _fail("旧遗物收藏损坏。")
	result.collection.relics = result.collection.equipment
	result.collection.erase("equipment")
	if not result.get("build") is Dictionary: return _fail("旧装备迁移缺少构筑。")
	result.build = project_build(result.build, catalog)
	if not error.is_empty(): return {}
	result.schema = 25
	return result

## 旧迁移的中间态共用此投影，不提前改写原构筑或发布版本。
func project_build(saved: Dictionary, catalog: AdventureCatalog) -> Dictionary:
	error = ""
	var build: Dictionary = saved.duplicate(true)
	if not build.is_empty():
		if build.has("relics") or not build.get("attachments") is Array or not build.get("reward_cards") is Array or not build.get("cards") is Array or not build.get("next_sequence") is int or build.next_sequence < 0: return _fail("旧装备集合损坏。")
		build.relics = []
		var seen: Array = []
		for record in build.attachments:
			if not record is Dictionary or record.size() != 4 or record.get("kind") != 0 or not record.get("content_id") is String or not record.get("target") is String: return _fail("旧装备绑定损坏。")
			var key: Array = [record.target, record.content_id]
			if key in seen or build.cards.filter(func(card): return card is Dictionary and card.get("id") == record.target).size() != 1: return _fail("旧装备目标或重复关系损坏。")
			seen.append(key)
			if not _append(build, record.content_id, record.get("copies"), catalog): return {}
		seen.clear()
		for record in build.reward_cards:
			if not record is Dictionary or record.size() != 3 or not record.get("id") is String or not record.id.begins_with("reward:") or record.id in seen: return _fail("旧装备手牌身份损坏。")
			var suffix: String = record.id.trim_prefix("reward:")
			if not suffix.is_valid_int() or int(suffix) < 0 or int(suffix) >= saved.next_sequence: return _fail("旧装备手牌序号损坏。")
			seen.append(record.id)
			var message: String = catalog.validate_reward(record.get("reward"))
			if not message.is_empty(): return _fail(message)
			if record.reward.kind != ContentTypes.DiceReward.Relic: return _fail("旧手牌包含非装备奖励。")
			if not _append(build, record.reward.content_id, record.get("copies"), catalog): return {}
		build.erase("attachments")
		build.erase("reward_cards")
	return build

## 旧成长份数逐份保全，不合并为等级，也不重新抽取奖励。
func _append(build: Dictionary, id: String, copies: Variant, catalog: AdventureCatalog) -> bool:
	if not copies is int or copies < 1 or copies > DuplicateGrowth.MAX_COPIES or catalog.content.get_record("relics", id).is_empty():
		error = "旧装备定义或累计份数损坏。"
		return false
	if copies > MAX_EXPANDED_RELICS - build.relics.size() or copies > DuplicateGrowth.MAX_COPIES - build.next_sequence:
		error = "旧装备份数超出可展开范围，原存档已保留。"
		return false
	for index in range(copies):
		build.relics.append({"id": "relic:%d" % build.next_sequence, "content_id": id, "consumed": false})
		build.next_sequence += 1
	return true

## 错误候选不能作为可保存状态返回。
func _fail(message: String) -> Dictionary:
	error = message
	return {}
