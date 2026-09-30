class_name DonutStackView
extends Control
## 在圆纸托上按真实层序绘制甜甜圈，并向拖拽与飞行动效提供位置。

const STACK_STEP: float = 48.0 # 相邻两颗露出约四成高度，纯色糖霜与饼底均可辨认。
const BOTTOM_Y: float = -6.0 # 最底层底端位于纸托内的 108 处，前沿保留 18 设计单位。
const SELECTED_LIFT: float = 14.0 # 设计单位；选中顶层轻抬，保持纸托及盒位固定。
const MAX_TOP_OVERHANG: float = 3.0 * STACK_STEP - BOTTOM_Y + SELECTED_LIFT # 四层选中堆叠的最大上沿预留。

var _item_count: int = 0
var _single: bool = false
var _selected: bool = false
var _foods: Array[TextureRect] = []
var _frost: Array[TextureRect] = []


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
		var frost := TextureRect.new()
		frost.texture = DonutMechanicArt.FROST
		frost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frost.size = DonutArt.FOOD_SIZE
		food.add_child(frost)
		_frost.append(frost)
	resized.connect(_layout_contents)
	_layout_contents()


## 已揭示食物始终显示真实口味，仅未揭示的食物使用灰色纹理。
func present(items: Array, visible_food: bool, single: bool, selected: bool, frozen: bool = false) -> void:
	_item_count = items.size()
	_single = single
	_selected = selected
	for item_index: int in _foods.size():
		var food: TextureRect = _foods[item_index]
		food.visible = visible_food and item_index < items.size()
		_frost[item_index].visible = frozen
		if food.visible:
			var item: Dictionary = items[item_index]
			food.texture = DonutArt.FOOD[int(item.flavor)] if item.revealed else DonutArt.HIDDEN
	_layout_contents()


## 返回固定层距，视口高度不改变甜甜圈堆叠比例。
func stack_step() -> float:
	return STACK_STEP


## 最底层使用统一落点保留盘沿，飞行动效可指定提交后的数量。
func food_position(item_index: int, single: bool = false, count_override: int = -1) -> Vector2:
	if single:
		return Vector2((size.x - DonutArt.FOOD_SIZE.x) * 0.5,
			BOTTOM_Y)
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
		_foods[index].position = food_position(index, _single) - Vector2(0, SELECTED_LIFT if _selected and index == 0 else 0)
