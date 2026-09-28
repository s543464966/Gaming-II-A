class_name DonutOrdersView
extends Control
## 汇总四个订单位置及已完成订单数量的只读显示。

## 卡位按底图中的实际边界归一化锚定，随底板整体缩放。
@onready var cards: Array[DonutOrderCard] = [$Panel/Order0, $Panel/Order1, $Panel/Order2, $Panel/Order3]


## 同步订单卡与进度角标，页面只提供会话快照。
func present(demands: Array, completed: int, total: int) -> void:
	for index: int in cards.size():
		cards[index].present(demands[index])
	$Progress.text = "%d / %d 单" % [completed, total]
