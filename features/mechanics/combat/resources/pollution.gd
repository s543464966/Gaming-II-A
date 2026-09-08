class_name PollutionMechanic
extends RefCounted
## 污染数值、阈值和跨场继承公式；每场实例显式选择全场或队伍作用域。

var scope: String = "battle"
var values: Dictionary = {}

## 从模式初始值复制资源，空配置表示没有启用污染。
func _init(configuration: Dictionary = {}) -> void:
	if not configuration.is_empty():
		scope = configuration.scope
		for key in configuration.values: values[str(key)] = clampi(int(configuration.values[key]), 0, 100)

## 根据来源队伍读取对应污染，不让不同队伍意外共享。
func value(team_id: int) -> int:
	return int(values.get(_key(team_id), 0))

## 返回实际变化及跨档结果，未启用的作用域不建立隐藏状态。
func change(team_id: int, amount: float) -> Dictionary:
	var key = _key(team_id)
	var previous = value(team_id)
	if not values.has(key): return {"delta": 0, "value": previous, "crossed": false}
	values[key] = clampi(previous + DeterministicMath.round_even(amount), 0, 100)
	@warning_ignore("integer_division")
	return {"delta": values[key] - previous, "value": values[key], "crossed": previous / 25 != values[key] / 25}

## 返回不带实例引用的结果资源。
func capture() -> Dictionary:
	return {"scope": scope, "values": values.duplicate()}

## 跨场仅携带变化量的指定比例，不默认绑定章节或账号。
static func carry(initial: int, final_value: int, ratio: float) -> int:
	return clampi(initial + DeterministicMath.round_even(DeterministicMath.f32((final_value - initial) * DeterministicMath.f32(clampf(ratio, 0, 1)))), 0, 100)

## 全场资源使用唯一键，队伍资源使用稳定队伍编号。
func _key(team_id: int) -> String:
	return "battle" if scope == "battle" else str(team_id)
