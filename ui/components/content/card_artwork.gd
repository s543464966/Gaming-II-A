class_name CardArtwork
extends Control
## 卡面与大幅商品展示共用的插画和单层 PNG 框，不包含徽章或业务标签。

## 大幅详情可限制装饰基准，展示区变大时不把框厚与圆角一起放粗。
@export var frame_unit_limit: float = 0.0

const FRAME_TEXTURES: Array[Texture2D] = [
	preload("res://ui/design_system/cards/card_frame_gray.png"),
	preload("res://ui/design_system/cards/card_frame_blue.png"),
	preload("res://ui/design_system/cards/card_frame_purple.png"),
	preload("res://ui/design_system/cards/card_frame_red.png"),
	preload("res://ui/design_system/cards/card_frame_orange_gold.png"),
]
var _columns: int = 1
var _frame_level: int = 0
var _unavailable: bool = false
var _backing: Panel
var _picture: TextureRect
var _border: NinePatchRect

## 只跟随宿主尺寸，不引入固定卡牌比例或额外容器底板。
func _ready() -> void:
	_bind_art_nodes()
	resized.connect(_layout_frame)
	theme_changed.connect(_refresh_availability)
	_refresh_availability()
	_layout_frame()

## 五档位图共享只读；多格卡由调用方提供单格宽度口径。
func set_appearance(texture: Texture2D, chapter_level: int, columns: int) -> void:
	_bind_art_nodes()
	_columns = maxi(1, columns)
	_picture.texture = texture
	_frame_level = clampi(chapter_level, 0, FRAME_TEXTURES.size() - 1)
	_refresh_availability()
	_layout_frame()

## 统一切换不可用外观，恢复时仍使用原强化档位；带徽章的卡面同步处理底色。
func set_unavailable(unavailable: bool) -> void:
	_bind_art_nodes()
	_unavailable = unavailable
	_refresh_availability()

## 灰显只作用于插画，详情可保留彩色而单独使用暗灰框。
func set_portrait_dimmed(dimmed: bool) -> void:
	_bind_art_nodes()
	_picture.material.set_shader_parameter("dimmed", dimmed)

## 目录文字只在插画下沿增加柔和明暗过渡，PNG 框及透明边缘保持原样。
func set_caption_band(height: float) -> void:
	_bind_art_nodes()
	_picture.material.set_shader_parameter("caption_height", height)

## 卡面允许入树前配置，场景内节点不依赖 onready 才能绑定。
func _bind_art_nodes() -> void:
	if _picture != null: return
	_backing = $Backing
	_picture = $Portrait
	_border = $Frame

## 只对本实例的框层调色，不改 PNG、Alpha、插画或数值徽章。
func _refresh_availability() -> void:
	_border.texture = FRAME_TEXTURES[0 if _unavailable else _frame_level]
	_border.self_modulate = get_theme_color("unavailable_frame_tint", "CardArtwork") if _unavailable else Color.WHITE

## 插画和缺图底色共用圆角，九宫格压边与框厚始终使用相同单格口径。
func _layout_frame() -> void:
	var cell_width: float = size.x / _columns
	if frame_unit_limit > 0: cell_width = minf(cell_width, frame_unit_limit)
	var frame_scale: float = maxf(cell_width / 1000.0, 0.001)
	_border.scale = Vector2.ONE * frame_scale
	_border.size = size / frame_scale
	var inset: Vector2 = Vector2.ONE * cell_width * 0.025
	_backing.position = inset
	_backing.size = size - inset * 2
	_picture.position = inset
	_picture.size = size - inset * 2
	var corner_radius: int = roundi(cell_width * 0.075)
	var backing_style := _backing.get_theme_stylebox("panel") as StyleBoxFlat
	backing_style.set_corner_radius_all(corner_radius)
	_picture.material.set_shader_parameter("extent", _picture.size)
	_picture.material.set_shader_parameter("corner_radius", float(corner_radius))
