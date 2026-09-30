class_name DonutOrderCard
extends Control
## 在翻盖订单盒上显示配对的正俯视贴纸、整盒去色的锁定态与完成态。

# 顺序与关卡口味 ID 一致，盒盖贴纸独立于场内立体食物。
const STICKER_ART: Array[Texture2D] = [
	preload("res://features/donut_sort/orders/ui/art/sticker_pink.tres"),
	preload("res://features/donut_sort/orders/ui/art/sticker_brown.tres"),
	preload("res://features/donut_sort/orders/ui/art/sticker_green.tres"),
	preload("res://features/donut_sort/orders/ui/art/sticker_blue.tres"),
	preload("res://features/donut_sort/orders/ui/art/sticker_orange.tres"),
	preload("res://features/donut_sort/orders/ui/art/sticker_ivory.tres"),
	preload("res://features/donut_sort/orders/ui/art/sticker_purple.tres"),
	preload("res://features/donut_sort/orders/ui/art/sticker_magenta.tres"),
	preload("res://features/donut_sort/orders/ui/art/sticker_red.tres"),
	preload("res://features/donut_sort/orders/ui/art/sticker_russet.tres"),
	preload("res://features/donut_sort/orders/ui/art/sticker_teal.tres"),
	preload("res://features/donut_sort/orders/ui/art/sticker_charcoal.tres"),
	preload("res://features/donut_sort/orders/ui/art/sticker_pistachio.tres"),
	preload("res://features/donut_sort/orders/ui/art/sticker_lavender.tres"),
	preload("res://features/donut_sort/orders/ui/art/sticker_mocha.tres")]

const BOX_ART: Array[Texture2D] = [
	preload("res://features/donut_sort/orders/ui/art/order_box_pink.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_brown.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_green.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_blue.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_orange.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_brown.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_purple.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_pink.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_orange.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_brown.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_green.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_brown.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_green.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_purple.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_brown.tres")]

@onready var box_art: TextureRect = $Box
@onready var food: TextureRect = $LidContent/Food
@onready var lock_icon: TextureRect = $LidContent/Lock
@onready var count_label: Label = $LidContent/Count


## 按当前订单快照刷新纹理和提示，不推进需求游标。
func present(position_state: Dictionary) -> void:
	var active: bool = position_state.open and position_state.cursor < position_state.sequence.size()
	food.visible = active
	lock_icon.visible = not position_state.open
	count_label.visible = position_state.open and not active
	tooltip_text = "订单位尚未解锁" if not position_state.open else ""
	var flavor: int = int(position_state.sequence[position_state.cursor]) if active else 0
	box_art.texture = BOX_ART[flavor]
	var tint: ShaderMaterial = box_art.material as ShaderMaterial
	tint.set_shader_parameter("neutral_amount", 1.0 if not active or flavor == 5 else 0.0)
	tint.set_shader_parameter("neutral_tint", Color(1.12, 1.04, 0.88) if active and flavor == 5 else Color.WHITE)
	if active:
		food.texture = STICKER_ART[flavor]
