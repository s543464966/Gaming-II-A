class_name DonutOrderCard
extends Control
## 在一体式订单底板的单个卡位上显示口味、数量与锁定状态。

@onready var food: TextureRect = $Content/Illustration/Food
@onready var lock_icon: TextureRect = $Content/Illustration/Lock
@onready var count_label: Label = $Content/Count


## 按当前订单快照刷新纹理和提示，不推进需求游标。
func present(position_state: Dictionary) -> void:
	var active: bool = position_state.open and position_state.cursor < position_state.sequence.size()
	food.visible = active
	lock_icon.visible = not position_state.open
	count_label.text = "×4" if active else ("锁定" if not position_state.open else "✓")
	tooltip_text = "订单位尚未解锁" if not position_state.open else ""
	if active:
		food.texture = DonutArt.FOOD[int(position_state.sequence[position_state.cursor])]
