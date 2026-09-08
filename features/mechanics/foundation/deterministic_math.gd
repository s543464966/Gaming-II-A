class_name DeterministicMath
extends RefCounted
## 确定性数值基础，保留单精度边界与中点取偶，不持有游戏状态。

## 显式保留既有单精度运算边界，避免迁移后冷却提前一个模拟步。
static func f32(value: float) -> float:
	return PackedFloat32Array([value])[0]

## 污染使用中点取偶；不能替换为默认的远离零舍入。
static func round_even(value: float) -> int:
	var base = floori(value)
	var fraction = value - base
	if fraction == 0.5:
		return base if base % 2 == 0 else base + 1
	return base if fraction < 0.5 else base + 1
