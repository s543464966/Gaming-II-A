class_name DonutBox
extends Button
## 显示固定盒位中的纸托、隐藏食物与机关，不拥有或推断第二套玩法状态。

const BOX_SIZE: Vector2 = Vector2(200, 126)

var box_index: int = 0
@onready var back: TextureRect = $Back
@onready var closed: TextureRect = $Closed
@onready var food_stack: DonutStackView = $Food
@onready var marker: Label = $Marker


## 让纸托与机关保持相同画布尺寸，按钮背景沿用场景中的透明样式。
func _ready() -> void:
	resized.connect(_layout_contents)
	_layout_contents()


## 按快照显示纸托、食物与机关；已收走的盒子不绘制占位痕迹。
func present(slot: Dictionary, selected: bool = false, waiting: bool = false, clock: float = 0.0) -> void:
	var exists: bool = slot.get("box") != null
	var open: bool = bool(slot.open)
	var single: bool = slot.kind == "single"
	var lid: int = int(slot.box.lid) if exists else 0
	var frozen: bool = bool(slot.box.frozen) if exists else false
	var covered: bool = exists and slot.box.kind == "lid" and lid > 0
	back.texture = DonutMechanicArt.holder(slot)
	back.visible = (exists or not open) and not covered
	back.self_modulate = Color(1.12, 1.08, 1.0) if selected else Color.WHITE
	closed.texture = DonutMechanicArt.COVER
	closed.visible = covered
	$Frozen.visible = false
	$Lock.visible = not open
	$Badge.visible = open and exists and lid > 0
	$Badge/Count.text = str(lid)
	$Waiting.visible = open and exists and waiting
	food_stack.present(slot.box.items if exists else [], open and exists and not covered, single, selected, frozen)
	$Mechanic.visible = exists and open and slot.box.kind in ["cycle", "bomb"]
	if $Mechanic.visible:
		$Mechanic.texture = DonutMechanicArt.CYCLE if slot.box.kind == "cycle" else DonutMechanicArt.BOMB
	$Countdown.visible = exists and open and slot.box.kind == "bomb"
	if $Countdown.visible:
		$Countdown.text = str(maxi(0, ceili(float(slot.box.bomb_deadline) - clock)))
		$Countdown.add_theme_color_override("font_color", Color("db3f54") if float(slot.box.bomb_deadline) - clock < 15 else Color("68371f"))
	marker.visible = not open and slot.kind != "turnover"
	marker.text = "%d 单解锁" % int(slot.unlock_after) if marker.visible else ""
	_layout_contents()
	if not open:
		tooltip_text = "看广告解锁空盒" if slot.kind == "turnover" else marker.text
	elif not exists:
		tooltip_text = ""
	elif waiting:
		tooltip_text = "等待需求"
	elif frozen:
		tooltip_text = "冰冻"
	elif slot.box.kind == "in_only":
		tooltip_text = "单向收纳盒：只进不出"
	else:
		tooltip_text = "暂存盒" if single else ""


## 转交甜甜圈堆叠布局计算，供棋盘命中与动效使用。
func food_position(item_index: int, single: bool = false, count_override: int = -1) -> Vector2:
	return food_stack.food_position(item_index, single, count_override)


## 数字队列有多个目标时只轻亮下一只数字周围，不泄露盒内口味或提示搬运解法。
func show_number_target(enabled: bool) -> void:
	$NumberTarget.visible = enabled
	$NumberTarget.position = $Badge.position + Vector2(31, 7)


## 纸托作为完整底座绘制，特殊覆盖层跟随盒位而不改变素材比例。
func _layout_contents() -> void:
	if not is_node_ready():
		return
	back.size = size
	if back.texture == DonutMechanicArt.SINGLE:
		back.size = Vector2(180, 118)
	back.position = Vector2((size.x - back.size.x) * 0.5, size.y - back.size.y)
	closed.size = Vector2(size.x, size.x * closed.texture.get_height() / closed.texture.get_width())
	closed.position = Vector2(0, size.y - closed.size.y)
	food_stack.size = size
	var contents: Rect2 = Rect2(Vector2.ZERO, size).merge(food_stack.visible_food_rect())
	var frost: NinePatchRect = $Frozen
	var factor: float = size.x / frost.texture.get_width()
	frost.scale = Vector2.ONE * factor
	frost.size = contents.size / factor
	frost.position = contents.position
	$Lock.position = Vector2((size.x - $Lock.size.x) * 0.5, size.y * 0.18)
	$Badge.position.y = contents.get_center().y - 42.0
	$Waiting.position = Vector2(size.x - $Waiting.size.x - 5.0, contents.position.y + 10.0)
	marker.position.y = size.y * 0.65


## 拿取与放入共用整叠食物及盒体范围，包含高出盒口的部分。
func interaction_rect() -> Rect2:
	var bounds := Rect2(Vector2.ZERO, size)
	if closed.visible:
		bounds = bounds.merge(closed.get_rect())
	var food_bounds: Rect2 = food_stack.visible_food_rect()
	if food_bounds.has_area():
		bounds = bounds.merge(food_bounds)
	if $Mechanic.visible:
		bounds = bounds.merge($Mechanic.get_rect())
	return bounds


## 搬运展示开始时隐藏实际飞走的组，后续快照负责恢复剩余食物。
func hide_moving_food(count: int) -> void:
	food_stack.hide_moving_food(count)
