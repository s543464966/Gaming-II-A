class_name RelicMechanic
extends RefCounted
## 遗物的独立获得记录与全队来源策略；模式决定获得、保存及跨场期限。

const C = preload("res://game_content/runtime/content_types.gd")

## 每份记录只保存身份和消耗事实，不复制静态效果或合并重复份数。
static func validate_record(record: Variant, catalog: RefCounted) -> String:
	if not record is Dictionary or record.size() != 3: return "遗物记录格式无效。"
	if not record.get("id") is String or record.id.is_empty() or not record.get("content_id") is String or not record.get("consumed") is bool: return "遗物身份或消耗状态无效。"
	var row: Dictionary = catalog.get_record("relics", record.content_id)
	if row.is_empty(): return "遗物定义不存在。"
	if record.consumed and row.usage != C.RelicUsage.Consumable: return "常驻遗物不能标记为已消耗。"
	return ""

## 只描述有效来源与宿主身份，运行贡献统一交给装配层投影。
static func contributions(records: Array, team_id: int, catalog: RefCounted, prefix: String = "") -> Array:
	var result: Array = []
	for index in range(records.size()):
		var record: Dictionary = records[index]
		if record.consumed: continue
		var row: Dictionary = catalog.get_record("relics", record.content_id)
		var source: Dictionary = AbilitySource.create("relic", row.id, record.id)
		var host: Dictionary = {"id": prefix + record.id, "scope": "team", "team_id": team_id,
			"consumable": row.usage == C.RelicUsage.Consumable,
			"consumption_order": index,
			"consumption_group": "team:%d:relic:%s" % [team_id, row.id]}
		result.append({"source": source, "parts": row.ability_parts.duplicate(true), "host": host})
	return result

## 已使用标记只前进；失败事务由模式恢复整份构筑检查点。
static func consume(records: Array, ids: Array) -> String:
	for id in ids:
		if not id is String or not records.any(func(record): return record.id == id): return "战报包含未知遗物。"
	for record in records:
		if record.id in ids: record.consumed = true
	return ""
