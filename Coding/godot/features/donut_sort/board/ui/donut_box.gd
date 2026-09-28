class_name DonutBox
extends Button
## 显示固定盒位中的餐盒、隐藏食物与机关，不拥有或推断第二套玩法状态。

const BOX_SIZE: Vector2 = Vector2(200, 157)

var box_index: int = 0
var _normal_style: StyleBoxEmpty = StyleBoxEmpty.new()
var _empty_style: StyleBoxFlat = StyleBoxFlat.new()
@onready var back: TextureRect = $Back
@onready var front: TextureRect = $Front
@onready var closed: TextureRect = $Closed
@onready var food_stack: DonutStackView = $Food
@onready var marker: Label = $Marker


## 设置空盒位轮廓并让纸盒各层保持相同画布尺寸。
func _ready() -> void:
	_empty_style.bg_color = Color(1, 0.94, 0.84, 0.08)
	_empty_style.border_color = Color(0.7, 0.48, 0.32, 0.18)
	_empty_style.set_border_width_all(2)
	_empty_style.set_corner_radius_all(22)
	resized.connect(_layout_contents)
	_layout_contents()


## 根据只读盒位显示纸盒前后层、封口包装、机关及真实的隐藏口味。
func present(slot: Dictionary, selected: bool = false, waiting: bool = false) -> void:
	var exists: bool = slot.get("box") != null
	var open: bool = bool(slot.open)
	var single: bool = slot.kind == "single"
	var lid: int = int(slot.box.lid) if exists else 0
	var frozen: bool = bool(slot.box.frozen) if exists else false
	back.visible = (exists or not open) and lid == 0
	front.visible = back.visible
	closed.visible = exists and lid > 0
	$Frozen.visible = open and exists and frozen and lid == 0
	$Lock.visible = not open
	$Badge.visible = open and exists and lid > 0
	$Badge/Count.text = str(lid)
	$Waiting.visible = open and exists and waiting
	food_stack.present(slot.box.items if exists else [], open and exists and lid == 0, single, selected)
	marker.visible = not open and slot.kind != "turnover"
	marker.text = "%d 单解锁" % int(slot.unlock_after) if marker.visible else ""
	add_theme_stylebox_override("normal", _empty_style if open and not exists else _normal_style)
	_layout_contents()
	if not open:
		tooltip_text = "加餐盒" if slot.kind == "turnover" else marker.text
	elif not exists:
		tooltip_text = "空盒位"
	elif waiting:
		tooltip_text = "等待需求"
	elif frozen:
		tooltip_text = "冰冻"
	else:
		tooltip_text = "暂存盒" if single else ""


## 转交甜甜圈堆叠布局计算，供棋盘命中与动效使用。
func food_position(item_index: int, single: bool = false, count_override: int = -1) -> Vector2:
	return food_stack.food_position(item_index, single, count_override)


## 让纸盒前后层共用固定画布，特殊覆盖层跟随盒位但不改变纸盒比例。
func _layout_contents() -> void:
	if not is_node_ready():
		return
	for panel: TextureRect in [back, front, closed]:
		panel.size = size
	var frost: NinePatchRect = $Frozen
	var factor: float = size.x / frost.texture.get_width()
	frost.scale = Vector2.ONE * factor
	frost.size = size / factor
	$Lock.position = Vector2((size.x - $Lock.size.x) * 0.5, size.y * 0.18)
	$Badge.position.y = size.y * 0.32
	$Frozen.position = Vector2.ZERO
	marker.position.y = size.y * 0.65
	food_stack.size = size


## 拿取与放入共用整叠食物及盒体范围，包含高出盒口的部分。
func interaction_rect() -> Rect2:
	var bounds := Rect2(Vector2.ZERO, size)
	var food_bounds: Rect2 = food_stack.visible_food_rect()
	if food_bounds.has_area():
		bounds = bounds.merge(food_bounds)
	return bounds


## 搬运展示开始时隐藏实际飞走的组，后续快照负责恢复剩余食物。
func hide_moving_food(count: int) -> void:
	food_stack.hide_moving_food(count)
