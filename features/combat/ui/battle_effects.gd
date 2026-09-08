extends Control
## 棋盘前景画布；弹道和飘字仍由棋盘所有者管理生命周期。

var board: Control

## 每帧只重绘；动画时间由 BattlePlayback 显式注入。
func _process(_delta: float) -> void:
	queue_redraw()

## 位于卡牌之上的表现不接受输入，也不参与战斗规则。
func _draw() -> void:
	if is_instance_valid(board): board.draw_effects(self)
