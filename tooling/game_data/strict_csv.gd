@tool
extends RefCounted
## 严格的 RFC 风格 CSV 解析，拒绝未闭合引号和引号外杂字；列数由调用方校验。

var errors: Array[String] = []

## 允许 BOM、换行与转义引号；默认规范化换行，编辑模式保留原始字符。
func parse(text: String, label: String, preserve_line_endings: bool = false) -> Array:
	errors.clear()
	text = text.trim_prefix("\ufeff")
	if not preserve_line_endings: text = text.replace("\r\n", "\n").replace("\r", "\n")
	var rows: Array = []
	var row: Array[String] = []
	var field = ""
	var quoted = false
	var closed = false
	var line = 1
	var i = 0
	while i < text.length():
		var ch = text[i]
		if quoted:
			if ch == '"':
				if i + 1 < text.length() and text[i + 1] == '"':
					field += '"'
					i += 1
				else:
					quoted = false
					closed = true
			else:
				field += ch
		elif ch == ',' or ch == '\n' or ch == '\r':
			row.append(field)
			field = ""
			closed = false
			if ch != ',':
				if preserve_line_endings or row.size() > 1 or not row[0].is_empty(): rows.append(row)
				row = []
				if ch == '\r' and i + 1 < text.length() and text[i + 1] == '\n': i += 1
		elif ch == '"':
			if not field.is_empty() or closed:
				errors.append("%s:%d 引号只能出现在字段起点。" % [label, line])
				return []
			quoted = true
		else:
			if closed:
				errors.append("%s:%d 闭合引号后只能是分隔符。" % [label, line])
				return []
			field += ch
		if ch == '\n': line += 1
		i += 1
	if quoted:
		errors.append("%s 含未闭合的引号。" % label)
		return []
	if not field.is_empty() or not row.is_empty() or closed:
		row.append(field)
		rows.append(row)
	return rows

## JSON 解析前拒绝同一对象中的重复键，嵌套对象有各自作用域。
static func unique_json_keys(text: String) -> bool:
	var stack: Array = []
	var i = 0
	while i < text.length():
		var ch = text[i]
		if ch == "{" or ch == "[":
			stack.append({} if ch == "{" else null)
		elif ch == "}" or ch == "]":
			if not stack.is_empty(): stack.pop_back()
		elif ch == '"':
			var start = i
			i += 1
			while i < text.length():
				if text[i] == "\\": i += 2
				elif text[i] == '"': break
				else: i += 1
			var token = text.substr(start, i - start + 1)
			var next = i + 1
			while next < text.length() and text[next] in [" ", "\t", "\r", "\n"]: next += 1
			if next < text.length() and text[next] == ":" and not stack.is_empty() and stack.back() is Dictionary:
				var key = JSON.parse_string(token)
				if stack.back().has(key): return false
				stack.back()[key] = true
		i += 1
	return true
