class_name AdventureBattleRequest
extends RefCounted
## 战前锁定时把当前构筑和已保存敌方部署复制成不可变模拟输入。

var error: String = ""

## 页面和数值测量共用章节与节点种子，奖励随机流随同一场战斗派生。
static func seed_for(chapter_id: String, node_index: int) -> int:
	var hash_value: int = 17
	for character in chapter_id: hash_value = (hash_value * 31 + character.unicode_at(0)) & 0xffffffff
	return (hash_value * 31 + node_index) & 0xffffffff

## 失败时返回空请求，不自动挪动任何一方卡牌。
func create(build: RefCounted, enemies: Array, catalog: RefCounted, seed: int, chapter: Dictionary = {}) -> Dictionary:
	error = build.validate_board()
	if not error.is_empty(): return {}
	var assembled = catalog.assembly.assemble(build, 0, AdventureBattleRules.assembly_options(build.core().id, build.cards))
	if assembled.is_empty():
		error = catalog.assembly.error
		return {}
	var snapshots: Array = assembled.cards
	var ordered = enemies.duplicate(true)
	ordered.sort_custom(func(a, b): return a.id < b.id)
	for enemy in ordered:
		var definition: Dictionary = catalog.enemy_definition(enemy.card_id, chapter, enemy.get("layer_index", -1), enemy.get("encounter_type", ContentTypes.NodeType.NormalBattle))
		if definition.is_empty():
			error = "敌方卡牌定义缺失。"
			return {}
		snapshots.append(BattleAssembly.snapshot(enemy.id, definition, enemy.position))
	var request = {"seed": seed, "cards": snapshots, "rules": AdventureBattleRules.create(build.core().id),
		"ability_hosts": assembled.ability_hosts, "main_ability_definitions": assembled.main_ability_definitions,
		"resources": {"pollution": {"scope": "battle", "values": {"battle": build.pollution}}}}
	var errors = BattleRequestValidator.validate(request)
	if not errors.is_empty():
		error = "\n".join(errors)
		return {}
	return request

## 怪物实例 ID 保留节点与原始列表顺序，重复定义仍是独立实例。
static func enemies_for(node: Dictionary) -> Array:
	var result: Array = []
	for i in range(node.monsters.size()):
		result.append({"id": "enemy:%d:%d:%s" % [node.index, i, node.monsters[i]], "card_id": node.monsters[i], "position": node.enemy_positions[i], "layer_index": node.layer, "encounter_type": node.get("type", ContentTypes.NodeType.NormalBattle)})
	return result
