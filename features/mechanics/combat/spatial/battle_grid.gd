class_name BattleGrid
extends RefCounted
## 矩形棋盘的几何与占位；尺寸由本场规则提供，默认五列六行。

const ROWS = 6
const COLUMNS = 5
const SLOTS = ROWS * COLUMNS

## 返回矩形占位掩码；零表示越界或无效尺寸。
static func footprint_mask(position: int, width: int, height: int, columns: int = COLUMNS, rows: int = ROWS) -> int:
	if position < 0 or position >= columns * rows or width < 1 or height < 1:
		return 0
	@warning_ignore("integer_division")
	var row = position / columns
	var column = position % columns
	if row + height > rows or column + width > columns:
		return 0
	var result = 0
	for r in range(row, row + height):
		for c in range(column, column + width):
			result |= 1 << (r * columns + c)
	return result

