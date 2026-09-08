class_name DuplicateGrowth
extends RefCounted
## 卡牌和装备共用的重复获取门槛；只计算等级与进度，不决定成长量或持有周期。

const MAX_COPIES: int = 9223372036854775807

## 总份数包含一份本体；强化一级依次需要一、二、三份额外内容。
static func level(copies: int) -> int:
	var duplicates = maxi(1, copies) - 1
	var result = floori((sqrt(1.0 + 8.0 * duplicates) - 1.0) / 2.0)
	while required_total(result + 1) <= duplicates: result += 1
	while result > 0 and required_total(result) > duplicates: result -= 1
	return result

## 达到指定强化等级需要的累计重复份数，不包含最初本体。
static func required_total(value: int) -> int:
	if value <= 0: return 0
	# 下一级三角数超出整数表示范围时返回哨兵；这不是玩法等级上限。
	if value >= 4294967296: return MAX_COPIES
	@warning_ignore("integer_division")
	return (value / 2) * (value + 1) if value % 2 == 0 else value * ((value + 1) / 2)

## 当前级内已积累的份数，未达门槛的进度不提前提供下一级数值。
static func progress(copies: int) -> int:
	return maxi(1, copies) - 1 - required_total(level(copies))

## 返回下一次升级的完整门槛，而不是剩余份数。
static func required_next(copies: int) -> int:
	return level(copies) + 1
