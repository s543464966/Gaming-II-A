class_name CombatUnit
extends RefCounted
## 单场中的独立载体状态，队伍身份与内容类别分离。

const T = preload("res://features/mechanics/contracts/combat_types.gd")

var id: String
var definition: Dictionary
var position: int
var health: float
var maximum_health: float
var shield: float = 0.0
var defeated: bool = false
var statuses: Dictionary = {}
var mechanics: MechanicState = MechanicState.new()
var modifiers: CombatModifiers
var ammo_expansion: int = 0
var main_abilities: CombatMainAbilities
var ammo_capacity: int
var ammo_remaining: int
var team_id: int
var kind: int
var row: int
var column: int

## 从战前快照复制数值，棋盘尺寸由本场规则提供。
func _init(value: Dictionary, columns: int = BattleGrid.COLUMNS) -> void:
	id = value.id
	definition = value.definition.duplicate(true)
	position = value.position
	health = CombatAttributes.points(value.health)
	maximum_health = CombatAttributes.max_health(definition)
	modifiers = CombatModifiers.new({} if definition.has("modifier_sources") else definition.modifiers)
	for part in definition.get("modifier_sources", []):
		if part.target == T.Target.Self and CardTagQuery.matches(definition.get("card_tag_ids", []), part.get("target_tags", {})):
			var source = AbilitySource.for_host(part.source, id)
			modifiers.set_source(AbilitySource.key(id, part.source_id, part.id), part.modifiers, source)
	for main_ability in definition.main_abilities:
		main_ability.actions = AbilitySchema.new().decode(main_ability.actions, "actions", main_ability.id, false)
		if main_ability.has("source"): main_ability.source = AbilitySource.for_host(main_ability.source, id)
	for rule in definition.rules: rule.actions = AbilitySchema.new().decode(rule.actions, "actions", rule.id, false)
	main_abilities = CombatMainAbilities.new(definition.main_abilities, {}, float(definition.get("haste_ratio", 0)), modifiers)
	definition.modifiers = modifiers.values()
	ammo_capacity = CombatAttributes.ammo_capacity(definition)
	ammo_remaining = ammo_capacity
	team_id = definition.team_id
	kind = definition.kind
	@warning_ignore("integer_division")
	row = position / columns
	column = position % columns

## 生命耗尽立即失去行动资格，不等待击败事件。
func alive() -> bool:
	return not defeated and health > 0.0

## 冻结和眩晕阻止主动行动，不阻止事件规则。
func blocked() -> bool:
	return statuses.has(T.Status.Freeze) or statuses.has(T.Status.Stun)

## 次数耗尽只限制主能力，不关闭被动规则。
func can_activate() -> bool:
	return alive() and not blocked() and mechanics.downtime <= 0 and (ammo_capacity == 0 or ammo_remaining > 0)

## 运行属性仅从来源账本派生，容量或生命上限下降时夹紧当前值。
func refresh_modifiers() -> void:
	definition.modifiers = modifiers.values()
	maximum_health = CombatAttributes.max_health(definition)
	health = minf(health, maximum_health)
	ammo_capacity = CombatAttributes.ammo_capacity(definition) + ammo_expansion
	ammo_remaining = mini(ammo_remaining, ammo_capacity)
	main_abilities.refresh_modifiers()

## 输出主能力列表和卡面摘要；摘要只派生自同一主能力状态。
func capture() -> Dictionary:
	refresh_modifiers()
	var kinds = statuses.keys()
	kinds.sort()
	var active_main_abilities = main_abilities.capture()
	var first: Dictionary = active_main_abilities[0] if not active_main_abilities.is_empty() else {}
	return {"id": id, "team_id": team_id, "health": health, "maximum_health": maximum_health, "shield": shield,
		"card_tag_ids": definition.get("card_tag_ids", []).duplicate(),
		"main_abilities": active_main_abilities, "cooldown": first.get("cooldown"), "remaining": first.get("remaining", 0.0), "defeated": not alive(), "statuses": kinds,
		"output_type": definition.get("output_type", T.Output.Special), "stats": CombatAttributes.stats(definition), "modifiers": definition.modifiers.duplicate(true), "ammo_capacity": ammo_capacity, "ammo_remaining": ammo_remaining,
		"modifier_sources": modifiers.capture(), "mechanics": mechanics.capture(),
		"status_stacks": status_stacks()}

## 持续伤害汇总实际层数，控制状态显示一次；来源批数不是层数。
func status_stacks() -> Dictionary:
	var result: Dictionary = {}
	for status in statuses:
		if not status in [T.Status.Burn, T.Status.Poison]:
			result[status] = 1
			continue
		var count: int = 0
		for source: Dictionary in statuses[status].sources.values(): count += int(source.stacks)
		result[status] = count
	return result

## 卡牌上下文携带来源与分类，队伍规则无需伪造一张英雄卡。
func ability_context(source_id: String = "") -> Dictionary:
	refresh_modifiers()
	return {"id": id, "team_id": team_id, "scope": "card", "unit": self,
		"modifiers": definition.modifiers, "source_id": source_id}


## 修正账本与主能力计时各自推进一次，无主能力的单位也会失去过期修正。
func tick_abilities(delta: float) -> void:
	var stopped: float = minf(delta, mechanics.downtime)
	modifiers.tick(delta)
	main_abilities.tick(delta, blocked() or mechanics.downtime > delta + 0.0001 or (ammo_capacity > 0 and ammo_remaining == 0), statuses.has(T.Status.Slow), stopped)
	# 形态恢复在当前主能力计时之后，原主能力的来源时限不会在恢复帧被扣两遍。
	mechanics.tick(self, delta)
