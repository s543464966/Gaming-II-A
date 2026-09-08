class_name SnapshotFormat
extends RefCounted
## 快照格式、确定性指纹和只读数据的公共契约。

const VERSION = 36
const PATH = "res://game_content/generated/game_data_snapshot.json"
const ASSETS = "res://game_content/asset_registry.json"
const TABLES = ["cards", "card_tags", "monster_sets", "main_abilities", "growth_rules", "innate_abilities", "talents", "synergies", "aurora_rewards", "aurora_reward_rules", "ability_aliases", "reward_dice", "dice_reward_rules", "dice_reward_pools", "chapters", "adventure_node_rules", "items", "relics", "shop_offers"]

## SHA-256 不包含自身；使用有类型、长度边界及游戏数值位表示的规范串。
static func content_hash(document: Dictionary) -> String:
	var value = document.duplicate(true)
	value.metadata.content_hash = ""
	return canonical(value).sha256_text()

## 整数保持精确；非整数采用规则契约的完整 float32 位，避开旧版 JSON 的双精度重读误差。
static func canonical(value: Variant) -> String:
	if value == null: return "n"
	if value is bool: return "t" if value else "f"
	if value is String or value is StringName:
		var text = String(value)
		return "s%d:%s" % [text.to_utf8_buffer().size(), text]
	if value is int: return "i%d;" % value
	if value is float:
		if is_finite(value) and value == floor(value) and absf(value) < 9007199254740992.0:
			return "i%d;" % int(value)
		var bytes = PackedByteArray()
		bytes.resize(4)
		bytes.encode_float(0, value)
		return "d" + bytes.hex_encode()
	var parts = PackedStringArray()
	if value is Dictionary:
		# GDScript 的点访问可产生 StringName 键；与 JSON 字符串键统一后排序。
		var keys = value.keys().map(func(key): return String(key))
		keys.sort()
		for key in keys:
			parts.append(canonical(key))
			parts.append(canonical(value[key]))
		return "o%d{%s}" % [keys.size(), "".join(parts)]
	for item in value: parts.append(canonical(item))
	return "a%d[%s]" % [value.size(), "".join(parts)]

## 规范主表和来源顺序并刷新内容指纹。
static func finalize(document: Dictionary) -> String:
	for table in TABLES:
		var key = "alias_id" if table == "ability_aliases" else "id"
		document[table].sort_custom(func(a, b): return a.sort_order < b.sort_order if a.has("sort_order") and a.sort_order != b.sort_order else a[key] < b[key])
	document.metadata.sources.sort_custom(func(a, b): return a.table < b.table)
	document.metadata.content_hash = content_hash(document)
	return JSON.stringify(document, "  ", true, true) + "\n"

## 递归冻结公共定义，防止玩家或战斗状态写回静态数据。
static func freeze(value: Variant) -> void:
	if value is Dictionary:
		for item in value.values(): freeze(item)
		value.make_read_only()
	elif value is Array:
		for item in value: freeze(item)
		value.make_read_only()

## JSON 数字没有整数类型；恢复整数值以保持枚举和集合查找的类型一致。
static func normalize_numbers(value: Variant) -> Variant:
	if value is Dictionary:
		for key in value: value[key] = normalize_numbers(value[key])
	elif value is Array:
		for i in range(value.size()): value[i] = normalize_numbers(value[i])
	elif value is float and is_finite(value) and value == floor(value) and absf(value) < 9007199254740992.0:
		return int(value)
	return value
