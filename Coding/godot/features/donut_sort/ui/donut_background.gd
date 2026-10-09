class_name DonutBackground
extends Control
## 按页面提供的台面、柜体与地板边界绘制背景，不反向决定玩法区域大小。

const SHOP_TOP_CROP: float = 48.0 # 原图像素；保留黑板文字与窗下绿植的取景基准。
const CABINET_SOURCE_WIDTH: float = 1137.0

var _table_top: float = 400.0
var _surface_bottom: float = 1300.0
var _cabinet_bottom: float = 1380.0


## 独立预览和窗口变化时重新绘制已分配的背景区域。
func _ready() -> void:
	resized.connect(_layout)
	_layout()


## 页面给出三个最终边界；柜体只在装饰带内伸缩，保留完整上下边框。
func fit_counter(top: float, surface_bottom: float, cabinet_bottom: float) -> void:
	_table_top = top
	_surface_bottom = surface_bottom
	_cabinet_bottom = cabinet_bottom
	_layout()


## 墙面与台面等比取景，柜体用九宫格保留边框，宽屏横向平铺完整柜门组。
func _layout() -> void:
	if not is_node_ready() or size.x <= 0 or size.y <= 0:
		return
	$ShopClip.size = Vector2(size.x, _table_top + 1.0)
	var shop: TextureRect = $ShopClip/Shop
	var shop_scale: float = maxf(size.x / shop.texture.get_width(), (_table_top + 1.0) / shop.texture.get_height())
	shop.size = shop.texture.get_size() * shop_scale
	var shop_y: float = maxf(_table_top + 1.0 - shop.size.y, -SHOP_TOP_CROP * shop_scale)
	shop.position = Vector2((size.x - shop.size.x) * 0.5, shop_y)
	$TableClip.position = Vector2(0, _table_top)
	$TableClip.size = Vector2(size.x, maxf(1.0, _surface_bottom - _table_top))
	$TableClip/Tabletop.size = $TableClip.size
	var cabinet_height: float = maxf(1.0, _cabinet_bottom - _surface_bottom)
	var cabinet_scale: float = minf(size.x / CABINET_SOURCE_WIDTH, cabinet_height / 180.0)
	$Cabinet.position = Vector2(0, _surface_bottom)
	$Cabinet.scale = Vector2.ONE * cabinet_scale
	$Cabinet.size = Vector2(size.x, cabinet_height) / cabinet_scale
	$Floor.position = Vector2(0, _cabinet_bottom - 1.0)
	$Floor.size = Vector2(size.x, maxf(1, size.y - _cabinet_bottom + 1.0))
