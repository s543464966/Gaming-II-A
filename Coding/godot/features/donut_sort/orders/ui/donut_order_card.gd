class_name DonutOrderCard
extends Control
## 在翻盖订单盒上显示配对的正俯视贴纸、整盒去色的锁定态与完成态。

# 顺序与关卡口味 ID 一致，盒盖贴纸独立于场内立体食物。
const STICKER_ART: Array[Texture2D] = [
	preload("res://features/donut_sort/orders/ui/art/soft_glaze_sticker_pink.tres"),
	preload("res://features/donut_sort/orders/ui/art/soft_glaze_sticker_cocoa.tres"),
	preload("res://features/donut_sort/orders/ui/art/soft_glaze_sticker_forest_green.tres"),
	preload("res://features/donut_sort/orders/ui/art/soft_glaze_sticker_sky_blue.tres"),
	preload("res://features/donut_sort/orders/ui/art/soft_glaze_sticker_orange.tres"),
	preload("res://features/donut_sort/orders/ui/art/soft_glaze_sticker_ivory.tres"),
	preload("res://features/donut_sort/orders/ui/art/soft_glaze_sticker_purple.tres"),
	preload("res://features/donut_sort/orders/ui/art/soft_glaze_sticker_raspberry.tres"),
	preload("res://features/donut_sort/orders/ui/art/soft_glaze_sticker_red.tres"),
	preload("res://features/donut_sort/orders/ui/art/soft_glaze_sticker_caramel.tres"),
	preload("res://features/donut_sort/orders/ui/art/soft_glaze_sticker_teal.tres"),
	preload("res://features/donut_sort/orders/ui/art/soft_glaze_sticker_royal_blue.tres"),
	preload("res://features/donut_sort/orders/ui/art/soft_glaze_sticker_lime.tres"),
	preload("res://features/donut_sort/orders/ui/art/soft_glaze_sticker_lavender.tres"),
	preload("res://features/donut_sort/orders/ui/art/soft_glaze_sticker_yellow.tres")]

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
	preload("res://features/donut_sort/orders/ui/art/order_box_blue.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_green.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_purple.tres"),
	preload("res://features/donut_sort/orders/ui/art/order_box_orange.tres")]


@onready var box_art: TextureRect = $Box
@onready var lid_content: Control = $LidContent
@onready var food: TextureRect = $LidContent/Food
@onready var lock_icon: TextureRect = $LidContent/Lock
@onready var count_label: Label = $LidContent/Count


## 在盒体尺寸变化后保持贴纸、锁和完成标记位于原图标牌中心。
func _ready() -> void:
	box_art.resized.connect(_align_lid_content)
	_align_lid_content()


## 按当前订单快照刷新纹理和提示，不推进需求游标。
func present(position_state: Dictionary) -> void:
	var active: bool = position_state.open and position_state.cursor < position_state.sequence.size()
	food.visible = active
	lock_icon.visible = not position_state.open
	count_label.visible = position_state.open and not active
	tooltip_text = "订单位尚未解锁" if not position_state.open else ""
	var flavor: int = int(position_state.sequence[position_state.cursor]) if active else 0
	box_art.texture = BOX_ART[flavor]
	_align_lid_content()
	var tint: ShaderMaterial = box_art.material as ShaderMaterial
	tint.set_shader_parameter("neutral_amount", 1.0 if not active or flavor == 5 else 0.0)
	tint.set_shader_parameter("neutral_tint", Color(1.12, 1.04, 0.88) if active and flavor == 5 else Color.WHITE)
	if active:
		food.texture = STICKER_ART[flavor]


## 各色盒裁切略有差异，使用原图标牌中心和实际等比留白换算位置。
func _align_lid_content() -> void:
	var atlas: AtlasTexture = box_art.texture as AtlasTexture
	var factor: float = minf(box_art.size.x / atlas.get_width(), box_art.size.y / atlas.get_height())
	var inset: Vector2 = (box_art.size - atlas.get_size() * factor) * 0.5
	lid_content.position = box_art.position + inset + (Vector2(621, 412) - atlas.region.position) * factor


## 按原图盒口前沿换算落入区域，动效落到下边界后被盒壁遮住。
func receiving_rect() -> Rect2:
	var atlas: AtlasTexture = box_art.texture as AtlasTexture
	var factor: float = minf(box_art.size.x / atlas.get_width(), box_art.size.y / atlas.get_height())
	var inset: Vector2 = (box_art.size - atlas.get_size() * factor) * 0.5
	var mouth: Vector2 = box_art.position + inset + (Vector2(624, 866) - atlas.region.position) * factor
	var dimensions: Vector2 = Vector2(640, 456) * factor
	return Rect2(mouth - Vector2(dimensions.x * 0.5, dimensions.y), dimensions)
