class_name DonutOrdersView
extends Control
## 汇总四个订单位置的口味、单盒需求与锁定状态。

## 四个独立翻盖盒共用固定间距，随页面等比缩放。
@onready var cards: Array[DonutOrderCard] = [$Panel/Order0, $Panel/Order1, $Panel/Order2, $Panel/Order3]


## 根据会话快照同步订单卡，不展示关卡订单总量。
func present(demands: Array) -> void:
	for index: int in cards.size():
		cards[index].present(demands[index])
