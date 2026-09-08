extends RefCounted
## 从明确白名单投影中文原文；只修改候选，不回写或清空主表。

const Schema = preload("res://game_content/runtime/content_schema.gd")
var errors: Array[String] = []
var entries: Dictionary = {}

## 记录唯一中文事实源位置，然后让生成定义仅持有文本键。
func project(document: Dictionary) -> void:
	errors.clear()
	entries.clear()
	for table in Schema.TEXT_FIELDS:
		var source_file = ""
		for file in Schema.FILES:
			if Schema.FILES[file][0] == table: source_file = file
		var names: Array[String] = []
		for row in document[table]:
			for field in Schema.TEXT_FIELDS[table]:
				var text: String = row[field]
				if (field != "flavor_text" and text.strip_edges().is_empty()) or text == "This is Information":
					errors.append("展示中文为空或仍是占位: %s/%s.%s" % [table, row.id, field])
				if field == "name":
					if text in names: errors.append("内容名称重复: " + row.id)
					names.append(text)
				var key = Schema.text_key(table, row.id, field)
				entries[key] = {"source": text, "file": source_file, "id": row.id, "field": field, "source_hash": text.sha256_text()}
				row[field + "_key"] = "" if text.is_empty() else key
				row.erase(field)
	for table in Schema.EDITOR_FIELDS:
		for row in document[table]:
			for field in Schema.EDITOR_FIELDS[table]:
				if str(row[field]).strip_edges().is_empty(): errors.append("编辑标签不能为空: " + row.id)
				row.erase(field)
