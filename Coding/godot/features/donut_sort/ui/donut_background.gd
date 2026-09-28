class_name DonutBackground
extends Control
## 等比铺满桌面并在棋盘上方显示店铺下半部的装饰场景。

const TABLETOP_SIZE: Vector2 = Vector2(941, 1672)

var _shop_boundary_y: float = 360.0
@onready var _tabletop: TextureRect = $Tabletop
@onready var _shop_clip: Control = $ShopClip


## 视口变化时重排背景，使木台前沿保持靠近屏幕底边。
func _ready() -> void:
	resized.connect(_layout)
	_layout()


## 页面传入实际桌面分界，安全区上方仍由店铺背景覆盖。
func set_shop_boundary(value: float) -> void:
	_shop_boundary_y = value
	if is_node_ready():
		_layout()


## 背景仅作等比覆盖，较宽屏从顶部裁切桌面纹理。
func _layout() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	var factor: float = maxf(size.x / TABLETOP_SIZE.x, size.y / TABLETOP_SIZE.y)
	var image_size: Vector2 = TABLETOP_SIZE * factor
	_tabletop.position = Vector2((size.x - image_size.x) * 0.5, size.y - image_size.y)
	_tabletop.size = image_size
	_shop_clip.size = Vector2(size.x, _shop_boundary_y)
