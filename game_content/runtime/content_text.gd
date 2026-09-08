class_name ContentText
extends RefCounted
## 内容展示的窄入口；使用 Godot 原生翻译，不持有语言或玩家状态。

## 缺少定义返回空文本，缺少名称翻译只退到真实内容 ID。
static func field(record: Dictionary, name: String = "name") -> String:
	var key: String = record.get(name + "_key", "")
	if key.is_empty(): return ""
	var value = String(TranslationServer.translate(key))
	return str(record.get("id", "")) if value == key and name == "name" else value

## 模板中的命名参数允许各语言调整语序，不由界面拼接句子。
static func format_key(key: String, arguments: Dictionary = {}) -> String:
	var template = text(key)
	var pattern = RegEx.new()
	pattern.compile("\\{([a-zA-Z_][a-zA-Z0-9_]*)\\}")
	var result = ""
	var offset = 0
	for match_value in pattern.search_all(template):
		result += template.substr(offset, match_value.get_start() - offset)
		result += str(arguments.get(match_value.get_string(1), match_value.get_string()))
		offset = match_value.get_end()
	return result + template.substr(offset)

## 无参数短文案同样交由原生翻译服务处理。
static func text(key: String) -> String:
	return String(TranslationServer.translate(key))
