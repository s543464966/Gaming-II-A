class_name DonutStackView
extends Control
## 在纸盒上方按真实层序绘制甜甜圈，并向拖拽与飞行动效提供位置。

const STACK_STEP: float = 36.0 # 相邻两颗在纸盒上方露出的高度。
const BOTTOM_Y: float = -12.0 # 最底层甜甜圈略高于盒口，前沿遮住其下部。
const MAX_TOP_OVERHANG: float = 3.0 * STACK_STEP - BOTTOM_Y + 9.0 # 四层堆叠被选中时高出盒位的最大距离。

var _item_count: int = 0
var _single: bool = false
var _selected: bool = false
var _foods: Array[TextureRect] = []


## 创建四个复用的显示节点，顶层最后绘制。
func _ready() -> void:
	for item_index: int in 4:
		var food := TextureRect.new()
		food.mouse_filter = Control.MOUSE_FILTER_IGNORE
		food.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		food.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		food.size = DonutArt.FOOD_SIZE
		food.z_index = 4 - item_index
		add_child(food)
		_foods.append(food)
	resized.connect(_layout_contents)
	_layout_contents()


## 已揭示食物始终显示真实口味，仅未揭示的食物使用灰色纹理。
func present(items: Array, visible_food: bool, single: bool, selected: bool) -> void:
	_item_count = items.size()
	_single = single
	_selected = selected
	for item_index: int in _foods.size():
		var food: TextureRect = _foods[item_index]
		food.visible = visible_food and item_index < items.size()
		if food.visible:
			var item: Dictionary = items[item_index]
			food.texture = DonutArt.FOOD[int(item.flavor)] if item.revealed else DonutArt.HIDDEN
	_layout_contents()


## 返回固定层距，视口高度不改变甜甜圈堆叠比例。
func stack_step() -> float:
	return STACK_STEP


## 从盒底向上计算目标层位置，飞行动效可指定提交后的数量。
func food_position(item_index: int, single: bool = false, count_override: int = -1) -> Vector2:
	if single:
		return Vector2((size.x - DonutArt.FOOD_SIZE.x) * 0.5,
			(size.y - DonutArt.FOOD_SIZE.y) * 0.5)
	var count: int = _item_count if count_override < 0 else count_override
	return Vector2((size.x - DonutArt.FOOD_SIZE.x) * 0.5,
		BOTTOM_Y - maxi(0, count - 1 - item_index) * stack_step())


## 汇总当前仍在盒内的可见食物，首颗跟手隐藏后下层仍可被命中。
func visible_food_rect() -> Rect2:
	var bounds := Rect2()
	for food: TextureRect in _foods:
		if food.visible:
			bounds = bounds.merge(food.get_rect()) if bounds.has_area() else food.get_rect()
	return bounds


## 供测试与外层组件查询单颗食物的显示节点。
func food_at(index: int) -> TextureRect:
	return _foods[index]


## 动效开始时仅隐藏实际飞走的顶层食物。
func hide_moving_food(count: int) -> void:
	for index: int in mini(count, _foods.size()):
		_foods[index].hide()


## 尺寸或选中状态变化后刷新四层位置。
func _layout_contents() -> void:
	for index: int in _foods.size():
		_foods[index].position = food_position(index, _single) - Vector2(0, 9 if _selected and index == 0 else 0)
