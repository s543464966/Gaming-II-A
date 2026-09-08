class_name ContentArtwork
extends Control
## 目录与商城直接显示卡牌本体和卡内文字，其他内容保持独立图标。

@export var show_labels: bool = false

@onready var _icon: TextureRect = $Icon
@onready var _card: CardFaceView = $Card
@onready var _dimmed_icon: Material = $Icon.material
@onready var _footer: VBoxContainer = $Footer

## 图片位随容器缩放，输入始终交给外层条目按钮。
func _ready() -> void:
	resized.connect(_layout_artwork)
	_footer.minimum_size_changed.connect(_layout_artwork)

## 业务方提供只读预览帧和拥有状态，组件不查询账号或重新装配数值。
func present(entry: Dictionary) -> void:
	var face: Dictionary = entry.get("face", {})
	var dimmed: bool = not entry.get("owned", true)
	_icon.visible = face.is_empty()
	_card.visible = not face.is_empty()
	_icon.texture = entry.get("texture")
	_icon.material = _dimmed_icon if dimmed else null
	_footer.visible = show_labels
	_footer.get_node("Title").text = entry.get("name", entry.get("id", ""))
	var caption: String = str(entry.get("caption", ""))
	_footer.get_node("Caption").text = ContentText.text(caption)
	_footer.get_node("Caption").visible = not caption.is_empty()
	if _card.visible:
		var definition: Dictionary = face.definition
		_card.size = CardFaceView.STANDARD_SIZE
		_card.set_appearance(entry.get("texture"), int(definition.get("chapter_level", 0)), 1)
		_card.set_stats(face.state)
		_card.set_portrait_dimmed(dimmed)
		_card.set_unavailable(dimmed)
	_layout_artwork()

## 所有列表条目统一竖卡比例；卡面和顶部徽章一起适配，不改写定义的真实占位。
func _layout_artwork() -> void:
	if not is_node_ready(): return
	var body: Rect2 = Rect2(Vector2.ZERO, size)
	if _card.visible:
		var bounds: Rect2 = _card.get_visual_rect()
		var factor: float = maxf(0.001, minf(size.x / bounds.size.x, size.y / bounds.size.y))
		_card.scale = Vector2.ONE * factor
		_card.position = (size - bounds.size * factor) * Vector2(0.5, 1.0 if show_labels else 0.5) - bounds.position * factor
		body = Rect2(_card.position, _card.size * factor)
		_card.set_caption_band((_footer.get_combined_minimum_size().y + 26) / factor if show_labels else 0)
	if not show_labels: return
	var inset: float = maxf(7, body.size.x * 0.055)
	_footer.size = Vector2(maxf(1, body.size.x - inset * 2), _footer.get_combined_minimum_size().y)
	_footer.position = Vector2(body.position.x + inset, body.end.y - inset - _footer.size.y)
