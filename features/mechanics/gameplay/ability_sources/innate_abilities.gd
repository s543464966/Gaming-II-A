class_name InnateAbilities
extends RefCounted
## 固有能力由卡牌明确绑定并校验载体与原生输出，挂载资格不等于运行中的触发条件。

## 输入来自固有能力表，适用范围不改变被动或增益分类。
static func matches(row: Dictionary, definition: Dictionary) -> bool:
	return not row.is_empty() and row.id in definition.get("innate_ability_ids", []) and definition.kind in row.applies_to_kinds and definition.output_type in row.required_outputs
