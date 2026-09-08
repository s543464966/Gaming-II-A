extends Control
## 章节卡片只呈现插画、章名与当前使用标识，三个巡游位置复用同一结构。

var _home_blend: float = 0.0
var _focus_weight: float = 1.0

## 独立材质避免一张画框缩放时影响其他章节的裁切。
func _ready() -> void:
	for part in [$Art, $PreviousArt, $Border]:
		part.material = part.material.duplicate()
	for label: Label in [$Metadata/Level, $Metadata/Title]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	resized.connect(_layout_art)
	_layout_art()

## 只接收页面已解析的展示内容，不持有会话或修改章节状态。
func present(texture: Texture2D, level: String, title: String, current: bool) -> void:
	$Art.texture = texture
	$Metadata/Level.text = level
	$Metadata/Title.text = title
	$Metadata/Current.visible = current
	_layout_art()

## 背景展开时同步收起文字与金边，裁切逐渐对齐 Home 的居中覆盖。
func set_home_blend(value: float) -> void:
	_home_blend = value
	for part in [$CaptionShade, $Border]: part.modulate.a = 1.0 - value
	$Metadata.modulate.a = (1.0 - value) * _focus_weight
	_layout_art()

## 旁侧仅预览插画，进入中央时平滑显现章名，避免画面边缘露出半截文字。
func set_focus_weight(value: float) -> void:
	_focus_weight = value
	$Metadata.modulate.a = (1.0 - _home_blend) * value

## 原图等比覆盖画框；框内略偏上取景，展开终点与 Home 使用相同裁切。
func _layout_art() -> void:
	if not is_node_ready() or size.x <= 0 or size.y <= 0: return
	for art: TextureRect in [$Art, $PreviousArt]:
		if art.texture == null: continue
		var texture_size: Vector2 = art.texture.get_size()
		var cover: float = maxf(size.x / texture_size.x, size.y / texture_size.y)
		var portion: Vector2 = size / (texture_size * cover)
		var origin: Vector2 = (Vector2.ONE - portion) * Vector2(0.5, lerpf(0.1066, 0.5, _home_blend))
		art.material.set_shader_parameter("extent", size)
		art.material.set_shader_parameter("art_region", Vector4(origin.x, origin.y, portion.x, portion.y))
		art.material.set_shader_parameter("corner", 25.0 * (1.0 - _home_blend))
	$Border.material.set_shader_parameter("extent", size)
