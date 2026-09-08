@tool
extends Control
## 将方案画布等比放入安全区，保持所有原生入口与装饰的相对位置。

const DESIGN_SIZE := Vector2(941, 1672)

## 编辑器和运行时共用布局，不创建玩家或应用服务。
func _ready() -> void:
	get_parent_control().resized.connect(_fit)
	_fit()

## 宽屏与刘海视口保留完整画布，背景由 Home 宿主独立铺满。
func _fit() -> void:
	var available: Vector2 = get_parent_control().size
	var ratio: float = minf(available.x / DESIGN_SIZE.x, available.y / DESIGN_SIZE.y)
	size = DESIGN_SIZE
	scale = Vector2.ONE * ratio
	position = (available - DESIGN_SIZE * ratio) * 0.5
