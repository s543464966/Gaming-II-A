class_name CardTagQuery
extends RefCounted
## 卡牌身份标签只参与集合匹配，不隐含输出、状态或元素反应。

## 标签引用必须是唯一的稳定 ID；空数组表示没有标签。
static func valid_ids(value: Variant) -> bool:
	if not value is Array: return false
	var seen: Array = []
	var pattern := RegEx.new()
	pattern.compile("^TG[0-9]{3,6}$")
	for id: Variant in value:
		if not id is String or pattern.search(id) == null or int(id.trim_prefix("TG")) <= 0 or id in seen: return false
		seen.append(id)
	return true

## 正式卡牌按主效类型约束数量，而不是按英雄或随从身份区分特殊卡。
static func valid_card(ids: Variant, output: int) -> bool:
	if not valid_ids(ids): return false
	var special: bool = output == CombatTypes.Output.Special
	return ids.size() >= (2 if special else 1) and ids.size() <= (3 if special else 2)

## Any、All、None 同时满足；禁止同一必需标签又被排除。
static func valid(query: Variant) -> bool:
	if not query is Dictionary: return false
	for key: Variant in query:
		if not key in ["any", "all", "none"] or not valid_ids(query[key]): return false
	var excluded: Array = query.get("none", [])
	for id: String in query.get("all", []):
		if id in excluded: return false
	var alternatives: Array = query.get("any", [])
	return alternatives.is_empty() or alternatives.any(func(id): return not id in excluded)

## 空查询不筛选；空标签卡仍可被 None 查询选中。
static func matches(ids: Array, query: Dictionary = {}) -> bool:
	for id: String in query.get("all", []):
		if not id in ids: return false
	for id: String in query.get("none", []):
		if id in ids: return false
	var alternatives: Array = query.get("any", [])
	return alternatives.is_empty() or alternatives.any(func(id): return id in ids)

## 判断查询是否实际限制标签，避免空条件伪装成要求。
static func restricted(query: Dictionary) -> bool:
	return query.values().any(func(ids): return not ids.is_empty())
