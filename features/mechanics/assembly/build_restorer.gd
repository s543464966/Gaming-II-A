class_name BuildRestorer
extends RefCounted
## 按静态定义恢复通用构筑，再经统一装配校验，不依赖某个模式的阶段。

var error: String = ""

## 只返回完整候选；棋盘规模由模式参数给出。
func restore(state: Dictionary, catalog: RefCounted, options: Dictionary, slots: int = 30) -> MechanicBuild:
	error = ""
	if state.has("attachments") or state.has("reward_cards"): return _fail("旧附着装备必须经过遗物迁移。")
	if state.has("faction"): return _fail("退役阵营字段必须经过存档版本迁移。")
	if state.has("talent_points"): return _fail("退役章节天赋点必须经过存档版本迁移。")
	for key in ["next_sequence"]:
		if not state.get(key) is int or state[key] < 0: return _fail("构筑计数无效。")
	for key in ["cards", "relics", "talents"]:
		if not state.get(key) is Array: return _fail("构筑缺少集合: " + key)
	if state.has("aurora_counts"): return _fail("退役星能能力必须经过存档迁移。")
	if not state.get("permanent_growth") is Dictionary: return _fail("开章永久成长记录缺失。")
	var result = MechanicBuild.new()
	result.next_sequence = state.next_sequence
	for id in state.permanent_growth:
		if catalog.get_record("cards", id).is_empty() or not CardGrowth.validate(state.permanent_growth[id], catalog.data.growth_rules[0]): return _fail("开章永久成长记录无效。")
	result.permanent_growth = state.permanent_growth.duplicate(true)
	var ids: Array = []
	for saved in state.cards:
		if not saved is Dictionary or not saved.get("id") is String or saved.id.is_empty() or saved.id in ids: return _fail("卡牌实例 ID 缺失或重复。")
		ids.append(saved.id)
		if not saved.get("kind") in CardTypes.Kind.values() or not saved.get("definition_id") is String: return _fail("卡牌类型或定义无效。")
		if not saved.get("copies") is int or saved.copies < 1: return _fail("卡牌累计获得数量无效。")
		if not saved.get("position") is int or saved.position < -1 or saved.position >= slots: return _fail("卡牌坐标无效。")
		if not (saved.get("health") is float or saved.get("health") is int) or not is_finite(float(saved.health)) or saved.health < 0: return _fail("卡牌生命无效。")
		var definition: Dictionary = BattleAssembly.new(catalog).base_definition(saved.definition_id, 0, saved.kind)
		if definition.is_empty(): return _fail("卡牌定义不存在或类型不符。")
		var card: Dictionary = saved.duplicate(true)
		for pair in [["max_health", "max_health"], ["width", "width"], ["height", "height"]]: card[pair[0]] = definition[pair[1]]
		result.cards.append(card)
		var suffix: String = saved.id.get_slice(":", saved.id.get_slice_count(":") - 1)
		if suffix.is_valid_int(): result.next_sequence = maxi(result.next_sequence, int(suffix) + 1)
	for saved in state.relics:
		var message = RelicMechanic.validate_record(saved, catalog)
		if not message.is_empty(): return _fail(message)
		if saved.id in ids: return _fail("遗物与构筑实例身份重复。")
		ids.append(saved.id)
		result.relics.append(saved.duplicate(true))
	var message = TalentMechanic.validate(state.talents, catalog)
	if not message.is_empty(): return _fail(message)
	result.talents = state.talents.duplicate()
	var assembly = BattleAssembly.new(catalog)
	for card in result.cards:
		var definition = assembly.definition(result, card, 0, options)
		if definition.is_empty(): return _fail(assembly.error)
		card.health = minf(CombatAttributes.points(float(card.health)), CombatAttributes.max_health(definition))
	return result

## 失败时不暴露部分恢复的候选。
func _fail(message: String) -> MechanicBuild:
	error = message
	return null
