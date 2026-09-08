class_name DeterministicRandom
extends RefCounted
## 固定 xorshift32 算法，保证跨平台和重进后的随机序列一致。

var state: int

## 零种子映射到固定非零状态。
func _init(seed_value: int = 0) -> void:
	state = seed_value & 0xffffffff
	if state == 0:
		state = 0x9e3779b9

## 推进一个无符号 32 位随机状态。
func next_uint() -> int:
	state = (state ^ (state << 13)) & 0xffffffff
	state = (state ^ (state >> 17)) & 0xffffffff
	state = (state ^ (state << 5)) & 0xffffffff
	return state

## 返回不含上界的非负整数。
func next_int(exclusive_maximum: int) -> int:
	assert(exclusive_maximum > 0, "随机上界必须为正数")
	return next_uint() % exclusive_maximum

## 返回半开区间 [0, 1) 内的单精度数值。
func next_unit() -> float:
	return DeterministicMath.f32(float(next_uint() & 0x00ffffff) / 16777216.0)
