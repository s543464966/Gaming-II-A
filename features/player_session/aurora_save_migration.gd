extends RefCounted
## Schema 23→24 退役星能被动，保留触发进度并将待领奖励稳定转为八项选择。

const RETIRED_IDS = ["AU001", "AU002", "AU003", "AU004", "AU005", "AU006", "AU007", "AU008", "AU009", "AU010", "AU011", "AU012"]
var error: String = ""

## 已兑现的被动不补发账号资产；未领取奖励只转换一次，原始输入保持不变。
func convert(saved: Dictionary, catalog: RefCounted) -> Dictionary:
	error = ""
	var result: Dictionary = saved.duplicate(true)
	if result.get("schema") != 23 or not result.get("build") is Dictionary: return _fail("星能迁移缺少章节构筑。")
	var build: Dictionary = result.build
	if build.is_empty():
		result.schema = 24
		return result
	error = validate_retired(build)
	if not error.is_empty(): return {}
	var maximum: int = catalog.content.data.aurora_reward_rules[0].max_triggers
	var earned: int = 0
	for copies: int in build.aurora_counts.values(): earned = mini(maximum, earned + mini(maximum, copies))
	var pending: bool = not build.pending_auroras.is_empty()
	if not build.get("started") is bool or (not build.started and (earned > 0 or pending)): return _fail("未开始章节夹带旧星能。")
	if not build.get("pending_reward") is bool or (pending and not build.pending_reward): return _fail("旧星能候选与奖励阶段不符。")
	build.erase("aurora_counts")
	build.erase("pending_auroras")
	var rewards := AuroraRewards.new()
	rewards.trigger_count = mini(earned, maximum - 1) if pending else earned
	if pending:
		if not build.get("reward_seed") is int: return _fail("旧星能缺少奖励种子。")
		var restorer := BuildRestorer.new()
		var relics = preload("res://features/player_session/relic_save_migration.gd").new()
		var projection: Dictionary = relics.project_build(build, catalog)
		if not relics.error.is_empty(): return _fail(relics.error)
		var growth = preload("res://features/player_session/category_growth_migration.gd").new()
		projection = growth.project_build(projection)
		if not growth.error.is_empty(): return _fail(growth.error)
		var restored: MechanicBuild = restorer.restore(projection, catalog.content, {"mechanisms": AdventureBattleRules.MECHANISMS})
		if restored == null: return _fail(restorer.error)
		error = rewards.begin(build.reward_seed ^ 0x51F15E, catalog, restored)
		if not error.is_empty(): return {}
	build.aurora_rewards = rewards.capture()
	# 中间版本必须保留当时的三字段协议，事件迁移统一补齐后续字段。
	build.aurora_rewards.erase("choice_seed")
	build.aurora_rewards.erase("active_offer_ids")
	result.schema = 24
	return result

## 旧引用仅保留在迁移边界，未知 ID、重复候选及非法份数不能被清洗为合法存档。
static func validate_retired(build: Dictionary) -> String:
	if not build.get("aurora_counts") is Dictionary or not build.get("pending_auroras") is Array: return "旧星能字段损坏。"
	for id: Variant in build.aurora_counts:
		if not id is String or not id in RETIRED_IDS or not build.aurora_counts[id] is int or build.aurora_counts[id] <= 0: return "旧星能引用或份数损坏。"
	if not build.pending_auroras.size() in [0, 3]: return "旧星能三项候选不完整。"
	var seen: Array = []
	for id: Variant in build.pending_auroras:
		if not id is String or not id in RETIRED_IDS or id in seen: return "旧星能候选引用无效或重复。"
		seen.append(id)
	return ""

## 失败只返回错误，不暴露可被误保存的部分候选。
func _fail(message: String) -> Dictionary:
	error = message
	return {}
