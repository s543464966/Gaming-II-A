class_name DonutDragPreview
extends TextureRect
## 只让首颗甜甜圈跟手，后续同味食物留在来源盒，不显示落点或数量提示。


## 使用来源盒比例显示被拿起的首颗，不将同味组绑成一个移动节点。
func configure(flavor: int, display_scale: Vector2) -> void:
	texture = DonutArt.FOOD[flavor]
	scale = display_scale
	size = DonutArt.FOOD_SIZE


## 将预览放到视口指针处，触摸时为手指留出可见距离。
func follow(viewport_position: Vector2, stage: Control, logical_pixel: float, touch: bool) -> void:
	position = stage.get_global_transform_with_canvas().affine_inverse() * viewport_position - DonutArt.FOOD_SIZE * scale * 0.5
	if touch:
		position.y -= 54.0 * logical_pixel / stage.scale.y
