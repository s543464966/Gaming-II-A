class_name DonutBackground
extends Control
## 等比组合墙面、台面柜体与地板；台面前景遮住订单盒底部。

const MIDDLE_SIZE: Vector2 = Vector2(1137, 1383)
const CABINET_HEIGHT: float = 258.0 # 原图完整台面前沿与柜体高度，不裁去柜门下边框。
const SHOP_TOP_CROP: float = 48.0 # 原图像素；只裁掉文字上方空白，完整保留黑板四行字。

var _table_top: float = 400.0
var _table_bottom: float = 1500.0
@onready var _table_clip: Control = $TableClip
@onready var _tabletop: TextureRect = $TableClip/Tabletop


## 独立预览和窗口变化均重新计算背景的等比裁切。
func _ready() -> void:
	resized.connect(_layout)
	_layout()


## 页面传入安全区布局对应的台面起止位置，返回可摆放纸托的桌沿高度。
func fit_counter(top: float, bottom: float) -> float:
	_table_top = top
	_table_bottom = bottom
	_layout()
	return bottom - CABINET_HEIGHT * _middle_scale()


## 墙面按黑板文字上沿取景且不露空，餐台底部与地板衔接并完整展示柜门。
func _layout() -> void:
	if not is_node_ready() or size.x <= 0 or size.y <= 0:
		return
	$ShopClip.size = Vector2(size.x, _table_top + 1.0)
	var shop: TextureRect = $ShopClip/Shop
	var shop_scale: float = maxf(size.x / shop.texture.get_width(), (_table_top + 1.0) / shop.texture.get_height())
	shop.size = shop.texture.get_size() * shop_scale
	var shop_y: float = maxf(_table_top + 1.0 - shop.size.y, -SHOP_TOP_CROP * shop_scale)
	shop.position = Vector2((size.x - shop.size.x) * 0.5, shop_y)
	var middle_size: Vector2 = MIDDLE_SIZE * _middle_scale()
	_table_clip.position = Vector2(0, _table_top)
	_table_clip.size = Vector2(size.x, _table_bottom - _table_top)
	_tabletop.size = middle_size
	_tabletop.position = Vector2((size.x - middle_size.x) * 0.5, _table_clip.size.y - middle_size.y)
	$Floor.position = Vector2(0, _table_bottom - 1.0)
	$Floor.size = Vector2(size.x, maxf(1, size.y - _table_bottom + 1.0))


## 同一等比系数用于绘图和桌沿边界，避免长屏棋盘压到柜门上。
func _middle_scale() -> float:
	return maxf(size.x / MIDDLE_SIZE.x, (_table_bottom - _table_top) / MIDDLE_SIZE.y)
