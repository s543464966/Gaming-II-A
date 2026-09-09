class_name ContentPreview
extends RefCounted
## 跨目录共用的静态基础预览；不读取账号拥有状态。

const C = preload("res://game_content/runtime/content_types.gd")

## 主能力预览只使用通用类别名，其余缺名称内容才回退到真实 ID。
static func entry(catalog: RefCounted, table: String, row: Dictionary) -> Dictionary:
	var value = {"id": row.id, "name": RuleText._tr("ability_execution.cooldown_main") if table == "main_abilities" else ContentText.field(row),
		"texture": catalog.resource(row.get("texture_key", "")), "table": table, "record": row,
		"filter_facets": {"card_tags": [], "output_types": [], "ability_facets": []}}
	value.tag_icons = []
	if table == "cards":
		value.face = card_face(BattleAssembly.new(catalog).base_definition(row.id))
		var output_type: int = int(row.output_type)
		value.filter_facets.output_types.append({"id": "output:%d" % output_type,
			"label": RuleText.enum_label("output", CombatTypes.Output, output_type), "sort_order": output_type})
		for id: String in row.card_tag_ids:
			var tag: Dictionary = catalog.get_record("card_tags", id)
			var facet = {"id": id, "label": ContentText.field(tag), "sort_order": tag.sort_order}
			value.tag_icons.append({"texture": catalog.resource("ui.card_tag." + id), "name": facet.label})
			value.filter_facets.card_tags.append(facet)
		value.filter_facets.ability_facets = _card_action_facets(catalog, row)
	return value

## 能力筛选读取原生与固有来源，输出分类、构筑激活和临时来源各自独立。
static func _card_action_facets(catalog: RefCounted, row: Dictionary) -> Array:
	var result: Array = []
	for part in row.get("ability_parts", []): _append_action_facets(catalog, part, result)
	for entry_id: String in row.get("innate_ability_ids", []):
		var entry: Dictionary = catalog.get_record("innate_abilities", entry_id)
		for part in entry.get("ability_parts", []): _append_action_facets(catalog, part, result)
	result.sort_custom(func(a, b): return a.sort_order < b.sort_order if a.sort_order != b.sort_order else a.id < b.id)
	return result

## 递归动作与持续数值都进入候选，避免被动和增益在筛选中消失。
static func _append_action_facets(catalog: RefCounted, part: Dictionary, result: Array) -> void:
	var actions: Array = part.get("actions", [])
	var main_ability_id: String = str(part.get("main_ability_id", ""))
	if not main_ability_id.is_empty(): actions = actions + catalog.get_record("main_abilities", main_ability_id).get("actions", [])
	for action in MechanicSchema.flatten(actions):
		var kind: int = int(action.kind)
		var status: int = int(action.get("status", CombatTypes.Status.None))
		var id: String = "status:%d" % status if kind == CombatTypes.CombatAction.ApplyStatus else "action:%d" % kind
		if result.any(func(facet): return facet.id == id): continue
		var label: String = RuleText.enum_label("status", CombatTypes.Status, status) if kind == CombatTypes.CombatAction.ApplyStatus else RuleText.enum_label("action", CombatTypes.CombatAction, kind)
		result.append({"id": id, "label": label, "sort_order": kind * 10 + status})
	var modifiers: Dictionary = part.get("modifiers", {})
	var stats: Array = AbilitySchema.MODIFIER_STATS.duplicate()
	stats.append_array(["max_health", "cooldown_seconds"])
	for stat: String in stats:
		if float(modifiers.get(stat, 0)) != 0: _append_stat_facet(stat, result)
	for group: String in ["stat_bonus_ratios", "team_bonuses"]:
		for stat: String in modifiers.get(group, {}):
			if float(modifiers[group][stat]) != 0: _append_stat_facet(stat, result)
	for action: Dictionary in modifiers.get("action_modifiers", []):
		if float(action.amount) != 0: _append_action_facets(catalog, {"actions": [action]}, result)

## 属性筛选用稳定属性身份与同一名称映射，不把纯数值贡献伪装成触发词条。
static func _append_stat_facet(stat: String, result: Array) -> void:
	var id: String = "stat:" + stat
	if result.any(func(facet): return facet.id == id): return
	result.append({"id": id, "label": AttributeIcons.label(stat), "sort_order": 1000})

## 不同内容输出分组展示数据，组件无需拆分已翻译的长文本。
static func describe(catalog: RefCounted, value: Dictionary) -> Dictionary:
	var row: Dictionary = value.record
	if value.table == "cards": return card_detail(BattleAssembly.new(catalog).base_definition(row.id))
	var result = {"tags": [], "scope": "", "attributes": [], "sections": []}
	var introduction = ContentText.field(row, "description" if value.table == "aurora_rewards" else "flavor_text")
	if not introduction.is_empty(): result.sections.append({"title": "ui.detail.overview", "entries": [{"body": introduction}]})
	if value.table == "aurora_rewards": return result
	if value.table == "items":
		result.attributes.append({"label": ContentText.text("ui.detail.stack_limit"), "value": str(row.max_stack)})
		return result
	if GameContentSchema.ABILITY_TABLES.has(value.table):
		if value.table == "main_abilities":
			result.sections.append({"category": CombatTypes.AbilityCategory.Main, "entries": [{"body": RuleText.main_ability(row, true)}]})
			return result
		result.scope = ContentText.text("ui.preview.build_reference")
	if value.table == "relics":
		result.tags = [ContentText.text("ui.relic.consumable" if row.usage == C.RelicUsage.Consumable else "ui.relic.persistent")]
		result.scope = ""
		result.sections.append({"title": "ui.detail.actions", "entries": [{"body": RuleText.relic(row, true)}]})
		return result
	if row.has("required_outputs") and value.table != "relics": result.tags.append_array(row.required_outputs.map(func(output): return RuleText.enum_label("output", CombatTypes.Output, output)))
	if value.table == "synergies": result.scope = RuleText.synergy_conditions(row.activation_conditions)
	var entries: Array = []
	for part in row.ability_parts:
		entries.append({"body": RuleText.ability_parts({"ability_parts": [part]}, {}, true)})
	result.sections.append({"title": "ui.detail.actions", "entries": entries})
	return result

## 身份、属性和主能力均来自同一已装配定义，卡牌属性按核心与修正两组展示。
static func card_detail(definition: Dictionary, state: Dictionary = {}) -> Dictionary:
	var face: Dictionary = card_face(definition, state)
	var frame: Dictionary = face.state
	var rules = RuleText.card_sections(definition, frame, true)
	var sections: Array = []
	for category: int in CombatTypes.AbilityCategory.values():
		var key: String = str(CombatTypes.AbilityCategory.find_key(category)).to_snake_case()
		if not rules[key].is_empty(): sections.append({"category": category, "entries": rules[key]})
	var groups: Array = []
	if not rules.core_attributes.is_empty(): groups.append({"id": "core", "title": "rules.section.core_attributes", "entries": rules.core_attributes})
	if not rules.modifier_attributes.is_empty(): groups.append({"id": "modifier", "title": "rules.section.modifier_attributes", "entries": rules.modifier_attributes})
	return {"tags": [], "face": face, "scope": ContentText.text("ui.preview.base_stats"),
		"attributes": rules.attributes, "attribute_groups": groups, "sections": sections}

## 列表和详情共用同一装配预览帧，不为缩略图拼装第二套属性算法。
static func card_face(definition: Dictionary, state: Dictionary = {}) -> Dictionary:
	var frame: Dictionary = state if not state.is_empty() else BattleAssembly.preview_frame(BattleAssembly.snapshot("preview", definition, 0))
	return {"definition": definition, "state": frame}

## 账号成长由业务方注入，不在静态预览中查询拥有状态或碎片资产。
static func permanent_detail(definition: Dictionary) -> Dictionary:
	var result = card_detail(definition)
	result.scope = ContentText.text("ui.collection.permanent_stats")
	return result
