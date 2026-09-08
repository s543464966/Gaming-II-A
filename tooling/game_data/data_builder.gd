extends RefCounted
## 从 Schema 声明的完整 CSV 集合构建新快照，不读取旧快照补齐字段。

const Schema = preload("res://game_content/runtime/content_schema.gd")
const Csv = preload("res://tooling/game_data/strict_csv.gd")
const Codec = preload("res://game_content/runtime/rule_codec.gd")
const Format = preload("res://game_content/runtime/snapshot_format.gd")
const TextSource = preload("res://tooling/game_data/content_text_source.gd")
var errors: Array[String] = []
var tables: Dictionary = {}
var source_texts: Dictionary = {}

## 读取固定文件集合并组装父子表。
func build(source: String) -> Dictionary:
	errors.clear()
	tables.clear()
	source_texts.clear()
	_validate_file_set(source)
	if not errors.is_empty(): return {}
	var document: Dictionary = {"metadata": {"schema_version": Format.VERSION, "content_hash": "", "sources": []}}
	for file in Schema.FILES:
		var table: String = Schema.FILES[file][0]
		var path = source.path_join(file)
		var text = FileAccess.get_file_as_string(path)
		tables[table] = _read(text, table, Schema.FILES[file][1].split(","), file)
		document.metadata.sources.append({"table": table, "file": file, "sha256": FileAccess.get_sha256(path)})
	if not errors.is_empty(): return {}
	for table in Format.TABLES:
		document[table] = tables[table]
	for table in Format.TABLES:
		_index(document[table], "alias_id" if table == "ability_aliases" else "id", table)
	if not errors.is_empty(): return {}
	for join in Schema.JOINS:
		_join(_index(document[join[0]], "id", join[0]), tables[join[1]], join[2], join[3], join[4], join[5])
	_resolve_card_bases(document.cards)
	if not errors.is_empty(): return {}
	var text_source = TextSource.new()
	text_source.project(document)
	errors.append_array(text_source.errors)
	source_texts = text_source.entries
	if not errors.is_empty(): return {}
	Format.finalize(document)
	return document

## 校验五个 Owner 及固定文件集，拒绝嵌套目录和额外副本。
func _validate_file_set(source: String) -> void:
	var root = DirAccess.open(source)
	if root == null:
		errors.append("无法读取策划目录: " + source)
		return
	for directory in root.get_directories():
		if not directory in Schema.DIRECTORIES: errors.append("不允许的策划目录: " + directory)
	for file in root.get_files():
		if file != "README.md": errors.append("策划根目录不允许文件: " + file)
	for directory in Schema.DIRECTORIES:
		var owner = DirAccess.open(source.path_join(directory))
		if owner == null:
			errors.append("缺少 Owner: " + directory)
			continue
		for nested in owner.get_directories(): errors.append("不允许嵌套目录: " + directory + "/" + nested)
		for file in owner.get_files():
			if not Schema.FILES.has(directory + "/" + file) and directory + "/" + file not in Schema.TRANSLATION_FILES: errors.append("不允许的策划文件: " + directory + "/" + file)
	for file in Schema.FILES:
		if not FileAccess.file_exists(source.path_join(file)): errors.append("缺少策划文件: " + file)

## 检查列顺序和宽度后按声明类型解析每个字段。
func _read(text: String, table: String, headers: PackedStringArray, file: String) -> Array:
	var csv = Csv.new()
	var rows = csv.parse(text, file)
	errors.append_array(csv.errors)
	if rows.is_empty():
		errors.append(file + " 缺少字段头。")
		return []
	var actual = PackedStringArray(rows.pop_front().map(func(value): return value.strip_edges()))
	if actual != headers:
		errors.append(file + " 字段顺序不匹配，期望: " + ",".join(headers))
		return []
	var result: Array = []
	for i in range(rows.size()):
		var row: Array = rows[i]
		if row.size() != headers.size():
			errors.append("%s:%d 字段数量错误。" % [file, i + 2])
			continue
		var record: Dictionary = {}
		for c in range(headers.size()):
			var column = headers[c]
			var value = str(row[c]).strip_edges()
			var inherited = table == "cards" and not str(row[headers.find("combat_base_id")]).strip_edges().is_empty() and column in Schema.COMBAT_FIELDS
			if inherited:
				if not value.is_empty(): errors.append("%s:%d.%s 怪物变体必须使用基础定义，不能重复覆盖。" % [file, i + 2, column])
				record[column] = null
			else:
				record[column] = _field(value, table, column, "%s:%d.%s" % [file, i + 2, column])
		result.append(record)
	return result

## 必填数字与枚举严格解析，仅声明可空的字段产生 null。
func _field(text: String, table: String, column: String, label: String) -> Variant:
	if column in Schema.JSON_FIELDS:
		var json = JSON.new()
		if json.parse(text) != OK or not Csv.unique_json_keys(text):
			errors.append(label + " JSON 格式错误或含重复键。")
			return []
		var codec = Codec.new()
		var value = codec.decode(json.data, column, label)
		errors.append_array(codec.errors)
		return value
	if text.is_empty() and Schema.nullable(table, column): return null
	var options = Schema.enum_values(table, column)
	if not options.is_empty():
		if options.has(text): return options[text]
		errors.append(label + " 必须填写正式枚举名称: " + text)
		return 0
	if column in Schema.INTEGERS:
		if text.is_valid_int(): return int(text)
		errors.append(label + " 必须填写整数，不能留空。")
		return 0
	if column in Schema.FLOATS:
		if text.is_valid_float() and is_finite(float(text)): return DeterministicMath.f32(float(text))
		errors.append(label + " 必须填写有限数值，不能留空。")
		return 0.0
	return text

## 怪物外观变体只允许单层引用同职责基础卡，避免循环和隐式覆盖。
func _resolve_card_bases(cards: Array) -> void:
	var index = _index(cards, "id", "cards")
	for card in cards:
		if card.combat_base_id.is_empty(): continue
		var base: Dictionary = index.get(card.combat_base_id, {})
		if card.card_kind != CardTypes.Kind.Monster or base.is_empty() or base.card_kind != CardTypes.Kind.Monster or not base.combat_base_id.is_empty() or base.monster_role != card.monster_role:
			errors.append("怪物基础定义必须存在、同职责且不再引用其他基础: " + card.id)
			continue
		for field in Schema.COMBAT_FIELDS:
			var value: Variant = base[field]
			card[field] = value.duplicate(true) if value is Array or value is Dictionary else value

## 构建唯一 ID 索引，空 ID 和重复 ID 都是硬错误。
func _index(rows: Array, key: String, label: String) -> Dictionary:
	var result: Dictionary = {}
	for row in rows:
		var id = str(row.get(key, ""))
		if id.is_empty() or result.has(id): errors.append(label + " 含空或重复 ID: " + id)
		else: result[id] = row
	return result

## 子表索引必须从零连续，未知父记录不会被静默忽略。
func _join(parents: Dictionary, rows: Array, parent_key: String, index_key: String, field: String, scalar: String = "") -> void:
	var groups: Dictionary = {}
	for id in parents: groups[id] = {}
	for row in rows:
		var id: String = row[parent_key]
		var index = int(row[index_key])
		if not parents.has(id):
			errors.append(field + " 子表引用了未知父记录: " + id)
			continue
		if index < 0 or groups[id].has(index): errors.append(field + " 的序号为负或重复: " + id)
		var value: Variant = row.get(scalar) if not scalar.is_empty() else row.duplicate(true)
		if scalar.is_empty(): value.erase(parent_key)
		groups[id][index] = value
	for id in parents:
		var indices = groups[id].keys()
		indices.sort()
		var result: Array = []
		for i in range(indices.size()):
			if indices[i] != i: errors.append(field + " 的序号必须从零连续: " + id)
			result.append(groups[id][indices[i]])
		parents[id][field] = result
