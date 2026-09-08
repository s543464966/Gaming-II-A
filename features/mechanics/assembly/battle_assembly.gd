class_name BattleAssembly
extends RefCounted
## 将载体定义、构筑事实和模式选择装配为统一战斗输入，不读取章节或市场。

const MECHANISMS = ["innate_abilities", "relics", "talents", "synergies", "growth"]
var content: RefCounted
var error: String = ""

## 静态目录由调用方注入，每次装配只生成独立副本。
func _init(catalog: RefCounted) -> void:
	content = catalog

## 预览和实际战斗共用此定义投影，未启用的机制不贡献能力。
func definition(build: MechanicBuild, card: Dictionary, team_id: int, options: Dictionary) -> Dictionary:
	error = _validate(build, options)
	if not error.is_empty(): return {}
	var result: Dictionary = base_definition(card.definition_id, team_id, card.kind, false, false)
	if result.is_empty():
		error = "载体定义缺失或类型不符。"
		return {}
	var selected: Array = options.mechanisms
	if "growth" in selected:
		result = CardGrowth.project(result, build.permanent_growth.get(card.definition_id, {"star_level": 1, "fragment_steps": 0}), card.copies, content.data.growth_rules[0])
	if "talents" in selected: _append_talents(result, build.talents)
	if "innate_abilities" in selected:
		for id in result.innate_ability_ids:
			var row: Dictionary = content.get_record("innate_abilities", id)
			if InnateAbilities.matches(row, result): AbilityProjection.append(result, _contribution(row, "innate_ability"))
	if "synergies" in selected:
		var active_ids: Array = synergies(build)
		for id: String in result.synergy_ids:
			if id in active_ids: AbilityProjection.append(result, _contribution(content.get_record("synergies", id), "team_synergy"))
	if not _finite_numbers(result) or not is_finite(CombatAttributes.max_health(result)):
		error = "成长后的战斗定义超出数值表示范围。"
		return {}
	result.rules.sort_custom(func(a, b): return a.priority < b.priority if a.priority != b.priority else a.id < b.id)
	return result

## 账号卡面与开章生命使用同一永久投影，不混入章节装备或强化份数。
func permanent_definition(id: String, growth: Dictionary, talents: Array) -> Dictionary:
	error = TalentMechanic.validate(talents, content)
	if not error.is_empty(): return {}
	var result: Dictionary = base_definition(id)
	if result.is_empty(): return {}
	result = CardGrowth.project(result, growth, 1, content.data.growth_rules[0])
	_append_talents(result, talents)
	return result

## 固定加值进入现有属性池，保留每个天赋的独立来源身份。
func _append_talents(definition: Dictionary, talents: Array) -> void:
	for id: String in talents:
		var parts: Array = TalentMechanic.parts_for_card(content.get_record("talents", id), definition.kind)
		AbilityProjection.append(definition, AbilityProjection.project(parts, AbilitySource.create("talent", id, id), main_ability_definitions()))

## 最终贡献必须可用战斗精度表示，不能把无穷值提交为合法成长。
func _finite_numbers(value: Variant) -> bool:
	if value is float: return is_finite(DeterministicMath.f32(value))
	if value is Dictionary:
		for item in value.values():
			if not _finite_numbers(item): return false
	elif value is Array:
		for item in value:
			if not _finite_numbers(item): return false
	return true

## 实例 ID 默认按队伍隔离，保存生命的范围由模式显式指定。
func assemble(build: MechanicBuild, team_id: int, options: Dictionary) -> Dictionary:
	error = _validate(build, options)
	if not error.is_empty(): return {}
	var result = {"cards": [], "ability_hosts": [], "main_ability_definitions": main_ability_definitions()}
	var prefix = str(options.get("instance_prefix", "team:%d:" % team_id))
	var deployed = build.cards.filter(func(card): return card.position >= 0)
	deployed.sort_custom(func(a, b): return a.id < b.id)
	for card in deployed:
		var value = definition(build, card, team_id, options)
		if value.is_empty(): return {}
		var health = card.health if not options.has("carry_health_ids") or card.id in options.carry_health_ids else null
		result.cards.append(snapshot(prefix + card.id, value, card.position, health))
	if "relics" in options.mechanisms:
		for contribution: Dictionary in RelicMechanic.contributions(build.relics, team_id, content, prefix):
			var host: Dictionary = AbilityProjection.project(contribution.parts, contribution.source, result.main_ability_definitions)
			host.merge(contribution.host)
			result.ability_hosts.append(host)
	return result

## 羁绊只依据当前已部署载体，内容条件决定是否激活。
func synergies(build: MechanicBuild) -> Array:
	var definitions: Array = []
	for card in build.cards:
		if card.position >= 0:
			var value: Dictionary = content.get_record("cards", card.definition_id)
			if not value.is_empty() and value.card_kind == card.kind: definitions.append(value)
	return SynergyMechanic.active(definitions, content.data.synergies)

## 来源类别独立于执行方式，所有来源使用同一能力清单投影。
func _contribution(row: Dictionary, source_kind: String) -> Dictionary:
	var source = AbilitySource.create(source_kind, row.id, row.id)
	return AbilityProjection.project(row.ability_parts, source, main_ability_definitions())

## 只验证被调用的机制；不存在的挂载目标和未识别能力不能悄悄丢失。
func _validate(build: MechanicBuild, options: Dictionary) -> String:
	if not options.get("mechanisms") is Array: return "模式必须显式选择机制集合。"
	for mechanism in options.mechanisms:
		if not mechanism in MECHANISMS: return "未知机制: " + str(mechanism)
	if "growth" in options.mechanisms:
		for id in build.permanent_growth:
			if not CardGrowth.validate(build.permanent_growth[id], content.data.growth_rules[0]) or content.get_record("cards", id).is_empty(): return "永久成长快照无效。"
		for card in build.cards:
			if not card.get("copies") is int or card.copies < 1: return "章节成长份数无效。"
	if "relics" in options.mechanisms:
		var seen: Array = []
		for relic in build.relics:
			var message = RelicMechanic.validate_record(relic, content)
			if not message.is_empty(): return message
			if relic.id in seen: return "遗物实例身份重复。"
			seen.append(relic.id)
	if "talents" in options.mechanisms:
		var message = TalentMechanic.validate(build.talents, content)
		if not message.is_empty(): return message
	return ""

## 创建独立的战前快照，禁止模拟写回构筑定义。
static func snapshot(id: String, definition: Dictionary, position: int, health: Variant = null) -> Dictionary:
	var maximum = CombatAttributes.max_health(definition)
	return {"id": id, "definition": definition.duplicate(true), "position": position, "health": clampf(maximum if health == null else CombatAttributes.points(float(health)), 0.0, maximum)}


## 只创建零时刻的只读卡面帧，允许未完成或有冲突的部署预览。
static func preview_frame(value: Dictionary, columns: int = BattleGrid.COLUMNS) -> Dictionary:
	return preview_frames([value], columns).cards[0]

## 同一阵容的零时刻预览解析群体贡献，不触发开场效果或推进计时。
static func preview_frames(values: Array, columns: int = BattleGrid.COLUMNS, resources: Dictionary = {}, hosts: Array = []) -> Dictionary:
	var units: Array = []
	for value in values: units.append(CombatUnit.new(value, columns))
	var passives = SustainedContributions.new()
	var pollution = PollutionMechanic.new(resources.get("pollution", {}))
	passives.refresh(units, hosts, pollution)
	var frames: Array = []
	for unit in units: frames.append(unit.capture())
	return {"time": 0.0, "cards": frames}

## 英雄、随从、怪物与道具共用一份载体定义，全部基础主能力按引用装配。
func base_definition(id: String, team_id: int = 0, expected_kind: int = -1, include_innate_abilities: bool = true, include_synergies: bool = true) -> Dictionary:
	var row = content.get_record("cards", id)
	if row.is_empty() or (expected_kind >= 0 and row.card_kind != expected_kind): return {}
	var result = {"id": id, "kind": row.card_kind, "team_id": team_id, "output_type": row.output_type,
		"card_tag_ids": row.card_tag_ids.duplicate(), "synergy_ids": row.synergy_ids.duplicate(),
		"crit_chance": row.crit_chance, "crit_multiplier": row.crit_multiplier, "haste_ratio": row.haste_ratio, "lifesteal_ratio": row.lifesteal_ratio,
		"ammo_capacity": row.ammo_capacity, "max_health": row.max_health, "innate_ability_ids": row.innate_ability_ids.duplicate(),
		"width": row.footprint_width, "height": row.footprint_height, "projectile": row.default_projectile_key}
	for key in CombatTypes.OUTPUT_STATS: result[key] = row[key]
	result.merge(AbilityProjection.project(row.ability_parts, AbilitySource.create("card", id, "card:" + id), main_ability_definitions()))
	if include_innate_abilities:
		for entry_id in result.innate_ability_ids:
			var entry: Dictionary = content.get_record("innate_abilities", entry_id)
			if InnateAbilities.matches(entry, result): AbilityProjection.append(result, _contribution(entry, "innate_ability"))
	if include_synergies:
		# 无阵容预览只装配没有阵容门槛的卡牌羁绊；实际部署统一由 definition 装配。
		for synergy_id: String in result.synergy_ids:
			var synergy: Dictionary = content.get_record("synergies", synergy_id)
			if synergy.activation_conditions.is_empty(): AbilityProjection.append(result, _contribution(synergy, "team_synergy"))
	AbilityProjection.refresh(result)
	return result

## 主能力的运行定义只取唯一能力行，卡牌不保留第二份主动效果。
func main_ability_definition(id: String) -> Dictionary:
	var row = content.get_record("main_abilities", id)
	if row.is_empty(): return {}
	return {"id": row.id, "cooldown_seconds": row.cooldown_seconds, "priority": row.priority, "multicast_count": row.multicast_count, "actions": row.actions.duplicate(true)}

## 主能力授予只能引用当前完整目录，模拟不在运行中访问内容服务。
func main_ability_definitions() -> Dictionary:
	var result: Dictionary = {}
	for row in content.data.main_abilities: result[row.id] = main_ability_definition(row.id)
	return result
