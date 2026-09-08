class_name RouteGenerator
extends RefCounted
## 根据章节配额生成三槽路线；节点、连线和敌方坐标一起提交。

const RandomSource = preload("res://features/mechanics/foundation/deterministic_random.gd")
const Formation = preload("res://features/game_modes_pve_adventure/domain/enemy_formation.gd")
const C = preload("res://game_content/runtime/content_types.gd")
const Type = C.NodeType
var error: String = ""
var _content: RefCounted
var _definition: Dictionary
var _random: RefCounted
var _monster_random: RefCounted
var _damage: Array
var _used_damage: Array
var _support: Array
var _elite: Array
var _used_elite: Array
var _boss: String
var _layers: Array
var _nodes: Array

## 空返回只表示失败，调用者必须检查 error，不能覆盖现有路线。
func generate(content: RefCounted, definition: Dictionary, seed: int) -> Array:
	error = ""
	_content = content
	_definition = definition
	_random = RandomSource.new(seed)
	_monster_random = RandomSource.new(seed ^ 0x4d4f4e53)
	_damage = []
	_support = []
	_elite = []
	_used_damage = []
	_used_elite = []
	_layers = []
	_nodes = []
	_boss = ""
	var monster_set: Dictionary = content.get_record("monster_sets", definition.get("monster_set_id", ""))
	for id in monster_set.get("card_ids", []):
		var card: Dictionary = content.get_record("cards", id)
		match card.get("monster_role", C.MonsterRole.None):
			C.MonsterRole.Normal:
				if _deals_damage(id): _damage.append(id)
				elif card.output_type in [CombatTypes.Output.Healing, CombatTypes.Output.Shield]: _support.append(id)
			C.MonsterRole.Elite: _elite.append(id)
			C.MonsterRole.Boss: _boss = id
	if _damage.is_empty() or _boss.is_empty() or definition.get("sections", []).is_empty():
		error = "章节缺少普通怪物、首领或段落。"
		return []
	if not _deals_damage(_boss) or _elite.any(func(id): return not _deals_damage(id)):
		error = "精英与首领必须使用攻击类怪物。"
		return []
	var layer_count: int = 2
	for section in range(definition.sections.size()):
		var count: int = 0
		for field in ["normal_battle_count", "elite_battle_count", "relic_count", "black_market_count", "adventure_count"]:
			count += maxi(0, definition.sections[section][field])
		if count < 2 or (definition.sections[section].elite_battle_count > 0 and _elite.is_empty()):
			error = "章节段落缺少分支或精英怪物。"
			return []
		layer_count += layer_sizes(count).size()
	if definition.layers.size() != layer_count:
		error = "章节怪物数量或奖励骰子配置不足。"
		return []
	_add_layer([_node(Type.Start, 0, 0)])
	_nodes[0].unlocked = true
	var layer_index: int = 1
	for section in range(definition.sections.size()):
		for types in _section_layers(section):
			var layer: Array = []
			var empty = -1 if types.size() == 3 else _random.next_int(3)
			var index: int = 0
			for lane in range(3):
				if lane == empty: layer.append(null)
				else:
					layer.append(_node(types[index], layer_index, section))
					index += 1
			_add_layer(layer)
			layer_index += 1
	_add_layer([_node(Type.BossBattle, layer_index, definition.sections.size() - 1)])
	_connect_layers()
	for node in _nodes:
		if node == null: continue
		var footprints: Array = []
		for id in node.monsters:
			var card: Dictionary = content.get_record("cards", id)
			footprints.append(Vector2i(card.footprint_width, card.footprint_height))
		var formation = Formation.new()
		node.enemy_positions = formation.generate(footprints, _random.next_int(2147483646) + 1)
		if not formation.error.is_empty():
			error = formation.error
			return []
	return _nodes

## 节点总数拆成二至三个节点一层，四个拆为二加二。
static func layer_sizes(count: int) -> Array:
	var result: Array = []
	while count > 0:
		if count == 4:
			result.append_array([2, 2])
			break
		var amount = mini(3, count)
		result.append(amount)
		count -= amount
	return result

## 尽量让同层出现不同类型，不改变每段配额。
func _section_layers(section: int) -> Array:
	var remaining: Array = []
	for pair in [["normal_battle_count", Type.NormalBattle], ["elite_battle_count", Type.EliteBattle], ["relic_count", Type.Relic], ["black_market_count", Type.BlackMarket], ["adventure_count", Type.Adventure]]:
		for _i in range(maxi(0, _definition.sections[section][pair[0]])): remaining.append(pair[1])
	_shuffle(remaining)
	var result: Array = []
	for amount in layer_sizes(remaining.size()):
		var types: Array = []
		for _i in range(amount):
			var choices = range(remaining.size()).filter(func(index): return not remaining[index] in types)
			var selected: int = _random.next_int(remaining.size()) if choices.is_empty() else choices[_random.next_int(choices.size())]
			types.append(remaining.pop_at(selected))
		_shuffle(types)
		result.append(types)
	return result

## 创建节点的静态引用与初始进度；不复制卡牌定义。
func _node(type: int, layer: int, _section: int) -> Dictionary:
	var monsters: Array = []
	var count: int = maxi(0, _definition.layers[layer].normal_monster_count)
	if is_battle(type):
		var leader = _draw(_elite, _used_elite) if type == Type.EliteBattle else _boss if type == Type.BossBattle else ""
		var total = count + (0 if leader.is_empty() else 1)
		var support_limit: int = 2 if total > 5 else 1 if total > 3 else 0
		var supports: Array = _support.duplicate()
		var support_count: int = _monster_random.next_int(mini(support_limit, supports.size()) + 1)
		for index in range(support_count):
			if supports.is_empty(): break
			var member: String = supports[_monster_random.next_int(supports.size())]
			monsters.append(member)
			var output: int = _content.get_record("cards", member).output_type
			supports = supports.filter(func(id): return _content.get_record("cards", id).output_type != output)
		var attackers: Array = []
		var attack_count: int = count - monsters.size()
		var type_count: int = 1 if attack_count < 2 else 1 + _monster_random.next_int(2)
		if not leader.is_empty() and attack_count >= 2: type_count = 2
		for index in range(type_count): attackers.append(_draw(_damage, _used_damage, attackers))
		for index in range(attack_count): monsters.append(attackers[index % type_count])
		if not leader.is_empty(): monsters.append(leader)
	return {"index": -1, "layer": layer, "lane": 0, "type": type, "monsters": monsters, "enemy_positions": [],
		"event_terms": _content.node_terms(type), "monster_count": count, "reward_dice": AdventureCatalog.new(_content).dice_count(type),
		"stamina": maxi(0, _definition.stamina_cost), "next": [], "before": [], "roads": [0, 0, 0],
		"selected_roads": [0, 0, 0], "unlocked": false, "completed": false, "stars": 0}

## 攻击成员只取四种伤害主输出；辅助名额与怪物总数在生成节点时统一决定。
func _deals_damage(id: String) -> bool:
	return _content.get_record("cards", id).output_type in [CombatTypes.Output.Physical, CombatTypes.Output.Witchcraft, CombatTypes.Output.Burn, CombatTypes.Output.Poison]

## 判断起点、普通、精英和首领战斗类型。
static func is_battle(type: int) -> bool:
	return type in [Type.Start, Type.NormalBattle, Type.EliteBattle, Type.BossBattle]

## 展平后仍保留三槽中的空位，维持路线坐标与历史索引。
func _add_layer(layer: Array) -> void:
	for i in range(layer.size()):
		if layer[i] != null:
			layer[i].index = _nodes.size()
			layer[i].lane = i if layer.size() == 3 else 1
		_nodes.append(layer[i])
	_layers.append(layer)

## 相邻槽连接、移除交叉斜边并保证目标可达。
func _connect_layers() -> void:
	for layer in range(_layers.size() - 1):
		var source: Array = _layers[layer]
		var target: Array = _layers[layer + 1]
		if source.size() == 1:
			for lane in range(target.size()): _connect(source[0], target[lane], lane)
			continue
		if target.size() == 1:
			for lane in range(source.size()): _connect(source[lane], target[0], 2 - lane)
			continue
		for a in range(3):
			for b in range(maxi(0, a - 1), mini(2, a + 1) + 1): _connect(source[a], target[b], b - a + 1)
		for left in range(2):
			var right = left + 1
			if source[left] == null or source[right] == null or target[left] == null or target[right] == null: continue
			if not target[right].index in source[left].next or not target[left].index in source[right].next: continue
			var choice = _random.next_int(3)
			if choice in [0, 2]: _disconnect(source[left], target[right], 2)
			if choice in [1, 2]: _disconnect(source[right], target[left], 0)
		for lane in range(3):
			if target[lane] == null or not target[lane].before.is_empty(): continue
			for offset in [0, -1, 1]:
				var from = clampi(lane + offset, 0, 2)
				var road = lane - from + 1
				if source[from] != null and road >= 0 and road < 3:
					_connect(source[from], target[lane], road)
					break

## 建立双向可核验的有向边。
static func _connect(source: Variant, target: Variant, road: int) -> void:
	if source == null or target == null: return
	source.roads[road] = 1
	if not target.index in source.next: source.next.append(target.index)
	if not source.index in target.before: target.before.append(source.index)

## 删除交叉边时同步两个节点和显示槽。
static func _disconnect(source: Dictionary, target: Dictionary, road: int) -> void:
	source.roads[road] = 0
	source.next.erase(target.index)
	target.before.erase(source.index)

## 同场优先不同输出且不重复同卡；已用池循环恢复后继续按稳定随机流抽取。
func _draw(available: Array, used: Array, selected: Array = []) -> String:
	var outputs: Array = selected.map(func(id): return _content.get_record("cards", id).output_type)
	var distinct: Callable = func(id): return not id in selected and not _content.get_record("cards", id).output_type in outputs
	if not available.any(distinct) and used.any(distinct):
		available.append_array(used)
		used.clear()
	if available.is_empty() or (available.all(func(id): return id in selected) and used.any(func(id): return not id in selected)):
		available.append_array(used)
		used.clear()
	var choices: Array = available.filter(distinct)
	if choices.is_empty(): choices = available.filter(func(id): return not id in selected)
	if choices.is_empty(): choices = available
	var id: String = choices[_random.next_int(choices.size())]
	available.erase(id)
	used.append(id)
	return id

## 稳定 Fisher–Yates 洗牌。
func _shuffle(values: Array) -> void:
	for i in range(values.size() - 1, 0, -1):
		var swap = _random.next_int(i + 1)
		var value = values[i]
		values[i] = values[swap]
		values[swap] = value
