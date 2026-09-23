class_name DonutBox
extends Button
## 显示固定盒位中的餐盒、隐藏食物与机关，不拥有或推断第二套玩法状态。

const FOOD: Array[Texture2D] = [
	preload("res://game_content/donuts/art/donut_pink_sprinkles.tres"),
	preload("res://game_content/donuts/art/donut_chocolate_nuts.tres"),
	preload("res://game_content/donuts/art/donut_matcha_drizzle.tres"),
	preload("res://game_content/donuts/art/donut_blueberry.tres")]
const HIDDEN: Texture2D = preload("res://features/donut_sort/ui/art/special/donut_hidden.tres")
const LOCKED: Texture2D = preload("res://features/donut_sort/ui/art/trays/tray_locked.tres")
const LID: Texture2D = preload("res://features/donut_sort/ui/art/special/number_lid.tres")
const FOOD_SIZE: Vector2 = Vector2(130, 126)
const STACK_STEP: float = 18.0 # 四颗满盒时的设计像素间距。

@export var supply_preview: bool = false
var box_index: int = 0
var _item_count: int = 0
var _foods: Array[TextureRect] = []
var _normal_style: StyleBoxEmpty = StyleBoxEmpty.new()
var _empty_style: StyleBoxFlat = StyleBoxFlat.new()
@onready var back: TextureRect = $Back
@onready var front: TextureRect = $Front
@onready var closed: TextureRect = $Closed
@onready var marker: Label = $Marker


## 创建可复用的食物节点，顶层最后绘制，避免下层盖住可搬运口味。
func _ready() -> void:
	_empty_style.bg_color = Color(1, 0.94, 0.84, 0.08)
	_empty_style.border_color = Color(0.7, 0.48, 0.32, 0.18)
	_empty_style.set_border_width_all(2)
	_empty_style.set_corner_radius_all(22)
	for item_index: int in 4:
		var food := TextureRect.new()
		food.mouse_filter = Control.MOUSE_FILTER_IGNORE
		food.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		food.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		food.size = Vector2(76, 76) if supply_preview else FOOD_SIZE
		food.z_index = item_index if supply_preview else 4 - item_index
		$Food.add_child(food)
		_foods.append(food)


## 根据只读盒位显示分层餐盒、锁定盖、白霜、等待标记及真实的隐藏口味。
func present(slot: Dictionary, selected: bool = false, available: bool = true, waiting: bool = false, drop_target: bool = false) -> void:
	var exists: bool = slot.get("box") != null
	var open: bool = bool(slot.open)
	_item_count = slot.box.items.size() if exists else 0
	var single: bool = slot.kind == "single"
	var lid: int = int(slot.box.lid) if exists else 0
	var frozen: bool = bool(slot.box.frozen) if exists else false
	back.visible = open and exists and not single and lid == 0
	front.visible = back.visible
	$Brand.visible = back.visible
	closed.texture = LID if open and lid > 0 else LOCKED
	closed.visible = not open or (exists and lid > 0)
	$SingleTray.visible = open and exists and single
	$Frozen.visible = open and exists and frozen and lid == 0
	$Lock.visible = not open
	$Badge.visible = open and exists and lid > 0
	$Badge/Count.text = str(lid)
	$Waiting.visible = open and exists and waiting
	$Selection.visible = selected or drop_target
	$Selection.modulate = Color("8affaf") if drop_target else Color.WHITE
	for item_index: int in 4:
		var food: TextureRect = _foods[item_index]
		food.visible = open and exists and lid == 0 and item_index < slot.box.items.size()
		if food.visible:
			var item: Dictionary = slot.box.items[item_index]
			food.texture = FOOD[int(item.flavor)] if item.revealed else HIDDEN
		food.position = food_position(item_index, single) - Vector2(0, 9 if selected and item_index == 0 else 0)
	marker.text = ""
	if not open:
		marker.text = "Locked" if slot.kind == "turnover" else "%d 单解锁" % int(slot.unlock_after)
	elif single and exists:
		marker.text = "单颗暂存"
	marker.position.y = 104 if not open else 123
	marker.add_theme_font_size_override("font_size", 22 if not open else 18)
	add_theme_stylebox_override("normal", _empty_style if open and not exists else _normal_style)
	modulate = Color.WHITE if available or selected or not open else Color(0.83, 0.81, 0.78, 1)
	tooltip_text = "空盒位" if open and not exists else ("等待需求" if waiting else ("冰冻" if frozen else marker.text))


## 保持可辨认的堆叠层距；餐盒与食物始终各自等比显示。
func stack_step() -> float:
	return STACK_STEP if _item_count >= 4 else 27.0


## 从盒底向上堆放；可指定目标快照数量，供跨排移动动画计算正确落点。
func food_position(item_index: int, single: bool = false, count_override: int = -1) -> Vector2:
	if supply_preview:
		var row_y: float = 35.0 if _item_count <= 2 else 12.0 + (item_index / 2) * 43.0
		var column_x: float = 62.0 if _item_count == 1 else 25.0 + (item_index % 2) * 74.0
		return Vector2(column_x, row_y)
	if single:
		return Vector2(35, 28)
	var count: int = _item_count if count_override < 0 else count_override
	var step: float = STACK_STEP if count >= 4 else 27.0
	return Vector2(35, 28 - maxi(0, count - 1 - item_index) * step)


## 搬运展示开始时隐藏实际飞走的组，后续快照负责恢复剩余食物。
func hide_moving_food(count: int) -> void:
	for index: int in mini(count, _foods.size()):
		_foods[index].hide()
