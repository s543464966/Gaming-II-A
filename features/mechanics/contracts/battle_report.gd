class_name BattleReport
extends RefCounted
## 已结算战报的只读容器约定；帧和事件生成后封存，表现可以共享而不复制整场。

## 仅封存战报拥有的值；已封存子树直接复用，不能传入仍由业务修改的活状态。
static func seal(value: Variant) -> Variant:
	if value is Dictionary:
		if value.is_read_only(): return value
		for child: Variant in value.values(): seal(child)
		value.make_read_only()
	elif value is Array:
		if value.is_read_only(): return value
		for child: Variant in value: seal(child)
		value.make_read_only()
	return value
