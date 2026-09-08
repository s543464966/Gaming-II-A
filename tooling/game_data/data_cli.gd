extends SceneTree
## 策划数据命令入口；预览、同步和校验共用同一严格管线。

const Builder = preload("res://tooling/game_data/data_builder.gd")
const Validator = preload("res://game_content/runtime/data_validator.gd")
const Format = preload("res://game_content/runtime/snapshot_format.gd")
const Translations = preload("res://tooling/localization/translation_builder.gd")
const Bundle = preload("res://tooling/game_data/generated_bundle.gd")

## 只有全部来源和候选快照有效时才原子替换生成物。
func _init() -> void:
	var args = OS.get_cmdline_user_args()
	var operation = args[0] if not args.is_empty() else "validate"
	if not operation in ["preview", "sync", "validate"]:
		_fail(["用法: data_cli.gd -- preview|sync|validate [策划 CSV 根目录] [隔离快照路径]"])
		return
	var source = args[1] if args.size() > 1 else ProjectSettings.globalize_path("res://../../Archive/GameDesignData")
	var snapshot_path = args[2] if args.size() > 2 else Format.PATH
	var builder = Builder.new()
	var candidate = builder.build(source)
	if not builder.errors.is_empty():
		_fail(builder.errors)
		return
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string(Format.ASSETS))
	if not registry is Dictionary:
		_fail(["资源注册表损坏。"])
		return
	var validator = Validator.new()
	var errors = validator.validate(candidate, registry)
	if not errors.is_empty():
		_fail(errors)
		return
	var translations = Translations.new()
	var language_files = translations.build(source, builder.source_texts, candidate.metadata.content_hash)
	if not translations.errors.is_empty():
		_fail(translations.errors)
		return
	for warning in translations.warnings: print("DATA TRANSLATION: " + warning)
	var bundle = Bundle.new()
	var files = bundle.prepare(candidate, language_files, snapshot_path.get_file())
	if operation == "preview": _changes(candidate, snapshot_path)
	if operation == "sync":
		if not bundle.publish(snapshot_path.get_base_dir(), files):
			_fail([bundle.error])
			return
	elif operation == "validate":
		var current = JSON.new()
		var valid_json = current.parse(FileAccess.get_file_as_string(snapshot_path)) == OK and current.data is Dictionary
		if valid_json: Format.normalize_numbers(current.data)
		if not valid_json or not validator.validate(current.data, registry).is_empty() or not bundle.matches(snapshot_path.get_base_dir(), files):
			_fail(["快照与声明的 CSV 来源不一致；请先 preview 再 sync。"])
			return
	var counts: PackedStringArray = []
	for table in Format.TABLES: counts.append("%s=%d" % [table, candidate[table].size()])
	print("DATA %s PASS: %d sources; %s; hash=%s" % [operation, GameContentSchema.FILES.size(), ", ".join(counts), candidate.metadata.content_hash])
	quit(0)

## 输出可由命令行验证器识别的失败标记。
func _fail(errors: Array) -> void:
	for message in errors: printerr("DATA ERROR: " + str(message))
	quit(1)

## 比较现有生成物只用于预览，不参与候选构建或补齐。
func _changes(candidate: Dictionary, path: String) -> void:
	var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	if not previous is Dictionary: previous = {}
	for table in Format.TABLES:
		var key = "alias_id" if table == "ability_aliases" else "id"
		var before: Dictionary = {}
		for row in previous.get(table, []):
			if row is Dictionary and row.has(key): before[row[key]] = row
		var added: int = 0
		var changed: int = 0
		for row in candidate[table]:
			if not before.has(row[key]):
				added += 1
				print("DATA ADD %s/%s" % [table, row[key]])
				continue
			var old: Dictionary = before[row[key]]
			var fields: Array = []
			for field in row:
				if not old.has(field) or Format.canonical(old[field]) != Format.canonical(row[field]): fields.append(field)
			for field in old:
				if not row.has(field): fields.append("-" + field)
			if not fields.is_empty():
				changed += 1
				print("DATA CHANGE %s/%s: %s" % [table, row[key], ", ".join(fields)])
			before.erase(row[key])
		for id in before: print("DATA REMOVE %s/%s" % [table, id])
		print("DATA DIFF %s: +%d ~%d -%d" % [table, added, changed, before.size()])
	for table in previous:
		if not candidate.has(table): print("DATA REMOVE TABLE %s" % table)
	for source in candidate.metadata.sources: print("DATA SOURCE %s: %s" % [source.file, source.sha256])
