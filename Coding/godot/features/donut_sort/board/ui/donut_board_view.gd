class_name DonutBoardView
extends Control
## 管理固定盒位的布局与快照显示，不处理搬运规则和会话写入。

const DRAG_PREVIEW_SCENE: PackedScene = preload("res://features/donut_sort/board/ui/donut_drag_preview.tscn")
const ROW_COUNTS: Array[int] = [5, 5, 5, 2] # 最后两位独立居中，盒位用途由关卡配置决定。
const CELL_GAP: Vector2 = Vector2(16, 18)
const MAX_BOX_SCALE: float = 0.84

var boxes: Array[DonutBox] = []


## 收集场景中固定顺序的盒位，顺序与关卡配置索引一致。
func _ready() -> void:
	for child: Node in get_children():
		if child is DonutBox:
			var box: DonutBox = child
			box.box_index = boxes.size()
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			boxes.append(box)


## 每排最多五组，短排居中；纸盒、食物及其命中区域始终整体等比缩放。
func fit(area: Rect2) -> void:
	position = area.position + Vector2(16, 12)
	size = area.size - Vector2(32, 34)
	var columns: int = ROW_COUNTS.max()
	var cell := Vector2((size.x - (columns - 1) * CELL_GAP.x) / columns,
		(size.y - (ROW_COUNTS.size() - 1) * CELL_GAP.y) / ROW_COUNTS.size())
	var full_height: float = DonutBox.BOX_SIZE.y + DonutStackView.MAX_TOP_OVERHANG
	var box_scale: float = minf(MAX_BOX_SCALE, minf(cell.x / DonutBox.BOX_SIZE.x, cell.y / full_height))
	var index: int = 0
	for row: int in ROW_COUNTS.size():
		var row_width: float = ROW_COUNTS[row] * cell.x + (ROW_COUNTS[row] - 1) * CELL_GAP.x
		for column: int in ROW_COUNTS[row]:
			var box: DonutBox = boxes[index]
			box.size = DonutBox.BOX_SIZE
			box.scale = Vector2.ONE * box_scale
			box.position = Vector2((size.x - row_width) * 0.5, 0) + Vector2(column, row) * (cell + CELL_GAP) + \
				Vector2((cell.x - box.size.x * box_scale) * 0.5,
					(cell.y - full_height * box_scale) * 0.5 + DonutStackView.MAX_TOP_OVERHANG * box_scale)
			index += 1


## 使用快照刷新食物与机关，通关后隐藏未启用的周转入口，不预告可放入目标。
func present(state: Dictionary, selected: int) -> void:
	for index: int in boxes.size():
		boxes[index].present(state.slots[index], selected == index, state.waiting[index])
		boxes[index].visible = not (state.get("won", false) and not state.slots[index].open and state.slots[index].kind == "turnover")


## 返回盒位相对于设计画布的左上角。
func origin(index: int) -> Vector2:
	return position + boxes[index].position


## 在页面的临时动效层创建棋盘专属拖拽视图。
func create_drag_preview(source: int, flavor: int, effects_layer: Control) -> DonutDragPreview:
	var preview: DonutDragPreview = DRAG_PREVIEW_SCENE.instantiate()
	effects_layer.add_child(preview)
	preview.configure(flavor, boxes[source].scale)
	return preview
