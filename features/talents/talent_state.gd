class_name TalentState
extends RefCounted
## 账号永久天赋与章节首通凭据；可用点数由首通数减已学习数派生。

var content: GameCatalog
var cleared_chapters: Array = []
var learned: Array = []
var points: int:
	get: return cleared_chapters.size() - learned.size()

## 静态目录只借用，不把定义写入账号存档。
func _init(catalog: GameCatalog) -> void:
	content = catalog

## 节点按策划顺序展示，前置关系仍由共享机制检查。
func nodes() -> Array:
	var result: Array = content.data.talents.duplicate()
	result.sort_custom(func(a: Dictionary, b: Dictionary): return a.sort_order < b.sort_order)
	return result

## 首通发点幂等执行，重复结算不会累积第二份奖励。
func award_chapter(id: String) -> String:
	var chapter: Dictionary = content.get_record("chapters", id)
	if chapter.is_empty() or chapter.difficulty != ContentTypes.Difficulty.Normal: return "天赋奖励章节无效。"
	if not id in cleared_chapters: cleared_chapters.append(id)
	return ""

## 每个节点只消费一点，费用与前置不能由界面绕过。
func unlock(id: String) -> String:
	var message: String = TalentMechanic.can_unlock(content.get_record("talents", id), learned, points)
	if not message.is_empty(): return message
	learned.append(id)
	return ""

## 保存首通凭据和选择，不保存第二份可用点数。
func capture() -> Dictionary:
	return {"cleared_chapters": cleared_chapters.duplicate(), "learned": learned.duplicate()}

## 完整验证后才替换状态，拒绝重复奖励、越点和非法前置。
func restore(state: Dictionary) -> String:
	if state.size() != 2 or not state.get("cleared_chapters") is Array or not state.get("learned") is Array: return "永久天赋存档格式损坏。"
	var seen: Array = []
	for id: Variant in state.cleared_chapters:
		if not id is String or id in seen: return "章节首通凭据重复或损坏。"
		var chapter: Dictionary = content.get_record("chapters", id)
		if chapter.is_empty() or chapter.difficulty != ContentTypes.Difficulty.Normal: return "章节首通凭据引用无效。"
		seen.append(id)
	if state.learned.size() > seen.size(): return "已学习天赋超过首通奖励点数。"
	var message: String = TalentMechanic.validate(state.learned, content)
	if not message.is_empty(): return message
	cleared_chapters = seen
	learned = state.learned.duplicate()
	return ""
