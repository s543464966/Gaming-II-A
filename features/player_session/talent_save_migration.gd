extends RefCounted
## Schema 22→23 清除退役章节天赋，并从已完成章节建立永久首通凭据。

## 只供受支持旧档识别；不包含旧效果，也不把旧点数兑换成永久点数。
const RETIRED = {"TA001": "", "TA002": "TA001", "TA003": "", "TA004": "TA003", "TA005": "TA001", "TA006": "TA003"}
var error: String = ""

## 显式验证后移除旧天赋，其他业务状态原样交给正式恢复。
func convert(saved: Dictionary, chapters: Array) -> Dictionary:
	error = ""
	var result: Dictionary = saved.duplicate(true)
	if not result.get("build") is Dictionary or not result.get("chapters") is Dictionary or not result.get("unlocked") is Array: return _fail("天赋迁移缺少章节状态。")
	var build: Dictionary = result.build
	if not build.is_empty():
		error = validate_retired(build)
		if not error.is_empty(): return {}
		build.erase("talent_points")
		build.talents = []
	var cleared: Array = []
	for index: int in range(chapters.size()):
		var id: String = chapters[index].id
		var route: Variant = result.chapters.get(id)
		if not route is Dictionary or not route.get("completed") is bool: return _fail("天赋迁移遇到损坏章节完成标记。")
		# 下一章已解锁也是上章曾通关的凭据，覆盖换英雄后路线进度已重置的旧档。
		if route.completed or (index + 1 < chapters.size() and chapters[index + 1].id in result.unlocked): cleared.append(id)
	result.talents = {"cleared_chapters": cleared, "learned": []}
	result.schema = 23
	return result

## 旧数据只能引用明确退役的节点；未知内容和缺前置仍视为损坏。
static func validate_retired(build: Dictionary) -> String:
	if not build.get("talent_points", 0) is int or build.get("talent_points", 0) < 0 or not build.get("talents", []) is Array: return "旧章节天赋格式损坏。"
	var selected: Array = build.get("talents", [])
	var seen: Array = []
	for id: Variant in selected:
		if not id is String or not RETIRED.has(id) or id in seen: return "旧章节天赋引用损坏。"
		if not RETIRED[id].is_empty() and not RETIRED[id] in selected: return "旧章节天赋缺少前置。"
		seen.append(id)
	return ""

## 失败不返回可被误保存的部分候选。
func _fail(message: String) -> Dictionary:
	error = message
	return {}
