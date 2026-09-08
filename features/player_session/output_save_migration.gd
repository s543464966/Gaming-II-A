extends RefCounted
## 输出与能力结构迁移，保全旧装备与份数供后续遗物迁移。

const C = preload("res://game_content/runtime/content_types.gd")
var error: String = ""

## 只构造候选副本，来源存档和玩家已有进度保持到完整恢复成功后才可保存。
func convert(saved: Dictionary, content: RefCounted) -> Dictionary:
	error = ""
	var result = saved.duplicate(true)
	if not result.get("build") is Dictionary: return _fail("效果类型迁移缺少构筑。")
	var build: Dictionary = result.build
	if build.is_empty():
		result.schema = 20
		return result
	if not build.get("faction") is int or not build.faction in [0, 1, 2]: return _fail("旧构筑阵营字段损坏。")
	if not build.get("started") is bool or (build.started and build.faction == 0): return _fail("旧构筑开始状态与阵营不匹配。")
	build.erase("faction")
	if build.get("started") == false:
		result.schema = 20
		return result
	if _return_equipment(build, content, true).is_empty(): return {}
	result.schema = 20
	return result

## 二十版能力结构更新仍保留旧装备事实。
func convert_abilities(saved: Dictionary, content: RefCounted) -> Dictionary:
	error = ""
	var result = saved.duplicate(true)
	if not result.get("build") is Dictionary: return _fail("能力结构迁移缺少构筑。")
	var build: Dictionary = result.build
	if not build.is_empty() and build.get("started") == true:
		if _return_equipment(build, content, false).is_empty(): return {}
	result.schema = 21
	return result

## 两次迁移共用旧字段校验，不使用已退役的附着资格。
func _return_equipment(build: Dictionary, content: RefCounted, old_hand: bool) -> Dictionary:
	if not build.get("cards") is Array or not build.get("attachments") is Array or not build.get("reward_cards") is Array or not build.get("next_sequence") is int or build.next_sequence < 0: return _fail("旧构筑装备集合损坏。")
	for hand in build.reward_cards:
		if not hand is Dictionary or hand.size() != (2 if old_hand else 3): return _fail("旧章节手牌格式损坏。")
		if old_hand: hand.copies = 1
	var kept: Array = []
	var seen: Array = []
	for attachment in build.attachments:
		if not attachment is Dictionary or attachment.size() != 4 or attachment.get("kind") != 0 or not attachment.get("content_id") is String or not attachment.get("target") is String: return _fail("旧装备关系损坏。")
		if not attachment.get("copies") is int or attachment.copies < 1 or attachment.copies > DuplicateGrowth.MAX_COPIES: return _fail("旧装备累计份数损坏。")
		var key = [attachment.target, attachment.content_id]
		if key in seen: return _fail("旧装备关系重复。")
		seen.append(key)
		var targets: Array = build.cards.filter(func(card): return card is Dictionary and card.get("id") == attachment.target)
		var gear: Dictionary = content.get_record("relics", attachment.content_id)
		if targets.size() != 1 or gear.is_empty(): return _fail("旧装备引用或目标损坏。")
		var target: Dictionary = targets[0]
		var native: Dictionary = content.get_record("cards", target.get("definition_id", ""))
		if native.is_empty() or native.card_kind != target.get("kind"): return _fail("旧装备目标定义损坏。")
		kept.append(attachment)
	build.attachments = kept
	return build

## 失败不暴露可误存的半成品。
func _fail(message: String) -> Dictionary:
	error = message
	return {}
