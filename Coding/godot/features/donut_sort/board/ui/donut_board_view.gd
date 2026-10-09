class_name DonutBoardView
extends Control
## 按独立布局配置摆放盒位并显示快照，保持关卡索引与处理顺序不变。

const DRAG_PREVIEW_SCENE: PackedScene = preload("res://features/donut_sort/board/ui/donut_drag_preview.tscn")
const BOX_SCENE: PackedScene = preload("res://features/donut_sort/board/ui/donut_box.tscn")
const LAYOUT_PATH: String = "res://game_content/donuts/layouts/board_layouts.json"
const MAX_BOX_SCALE: float = 1.08 # 少盒位关允许适度放大，仍以完整四层边界限制尺寸。
const VERTICAL_SPACE: float = 160.0 # 所有关卡共用的上下留白总量，保留四层抬起边界而不过度留空。
const PADDING_GAP_RATIO: float = 1.05 # 每侧留白均大于最大的可见排间隙。
const PADDING_GAP_MARGIN: float = 4.0 # 随纸托缩放的额外设计单位。
const PREFERRED_PADDING_GAP_RATIO: float = 1.20 # 高度富余时让外侧留白与排间距有明显层次。

signal box_pressed(index: int)

var boxes: Array[DonutBox] = []
var layout_id: String = ""
var layout_slots: Array = []
var _catalog: Dictionary = {}
var _opening_bounds: Dictionary = {} # 按关卡初始可见内容居中；局内变化不重新计算。
var _opening_gaps: Dictionary = {} # 按整排可见边界记录最大空隙，不以纸托中心距代替。
var _compact_layouts: Dictionary = {} # 只压缩排间多余预留，不改变行数、横坐标或业务索引。
var _extra_bottom: Dictionary = {} # 炸弹与置顶前沿圆标需要额外的下沿空间。


## 收集盒位并加载布局事实源，数组顺序始终对应会话中的盒位索引。
func _ready() -> void:
	for child: Node in get_children():
		if child is DonutBox:
			var box: DonutBox = child
			box.box_index = boxes.size()
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.pressed.connect(box_pressed.emit.bind(box.box_index))
			boxes.append(box)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	if parsed is Dictionary:
		_catalog = parsed
	_cache_opening_bounds()
	configure_layout(str(_catalog.get("default", "")))


## 从唯一关卡定义记录开局可见边界，避免不同堆叠高度造成视觉上的上下偏移。
func _cache_opening_bounds() -> void:
	var levels: Array = DonutLevel.catalog()
	var assignments: Array = _catalog.get("levels", [])
	for index: int in mini(levels.size(), assignments.size()):
		var key: String = str(assignments[index])
		var entries: Array = _catalog.get("templates", {}).get(key, {}).get("slots", [])
		var definition: Dictionary = DonutLevel.load_definition(levels[index].path)
		var slots: Array = definition.get("slots", [])
		if entries.is_empty() or entries.size() != slots.size():
			continue
		entries = _compact_rows(entries, slots)
		_compact_layouts[key] = entries
		var bounds := Rect2()
		var rows: Dictionary = {}
		_extra_bottom[key] = 0.0
		for slot_index: int in entries.size():
			var entry: Dictionary = entries[slot_index]
			var slot: Dictionary = slots[slot_index]
			var overhang: float = 0.0
			if slot.box != null and int(slot.get("unlock_after", 0)) == 0:
				var count: int = slot.box.items.size()
				if count > 0:
					overhang = -DonutStackView.BOTTOM_Y + maxi(0, count - 1) * DonutStackView.STACK_STEP
				if slot.box.get("kind", "normal") in ["frozen", "number_frozen"] and count > 0:
					overhang = DonutBox.frozen_top_overhang(count)
				if slot.box.get("kind", "normal") == "lid" and int(slot.box.get("lid", 0)) > 0:
					overhang = 200.0 * DonutMechanicArt.COVER.get_height() / DonutMechanicArt.COVER.get_width() - DonutBox.BOX_SIZE.y
			var extra: float = 20.0 if slot.box != null and slot.box.get("kind", "normal") in ["bomb", "cycle"] else 0.0
			_extra_bottom[key] = maxf(float(_extra_bottom[key]), extra)
			var visible_rect := Rect2(Vector2(float(entry.x) - DonutBox.BOX_SIZE.x * 0.5, float(entry.y) - overhang),
				Vector2(DonutBox.BOX_SIZE.x, DonutBox.BOX_SIZE.y + overhang + extra))
			bounds = bounds.merge(visible_rect) if bounds.has_area() else visible_rect
			var layer: int = int(entry.layer)
			rows[layer] = (rows[layer] as Rect2).merge(visible_rect) if rows.has(layer) else visible_rect
		_opening_bounds[key] = bounds
		var previous := Rect2()
		var gap: float = 0.0
		for row: Rect2 in rows.values():
			if previous.has_area():
				gap = maxf(gap, row.position.y - previous.end.y)
			previous = row
		_opening_gaps[key] = gap


## 收紧配置中的排间空白，仍为每盒保留四层抬起、机关下沿与最小分隔。
func _compact_rows(entries: Array, slots: Array) -> Array:
	var result: Array = entries.duplicate(true)
	var row_bounds: Dictionary = {}
	for index: int in entries.size():
		var entry: Dictionary = entries[index]
		var reserved: Rect2 = _reserved_rect(entry)
		var slot: Dictionary = slots[index]
		if slot.box != null and slot.box.get("kind", "normal") in ["bomb", "cycle"]:
			reserved.size.y += 20.0
		var layer: int = int(entry.layer)
		row_bounds[layer] = (row_bounds[layer] as Rect2).merge(reserved) if row_bounds.has(layer) else reserved
	var offsets: Dictionary = {}
	var previous_bottom: float = 0.0
	for layer: int in row_bounds:
		var row: Rect2 = row_bounds[layer]
		var offset: float = previous_bottom + 2.0 - row.position.y if not offsets.is_empty() else 0.0
		offsets[layer] = offset
		previous_bottom = row.end.y + offset
	for entry: Dictionary in result:
		entry.y = float(entry.y) + float(offsets[int(entry.layer)])
	return result


## 选择与关卡盒位数量一致的视觉布局，不修改关卡数据或移动业务索引。
func configure_level(level_index: int, slot_count: int) -> void:
	var assignments: Array = _catalog.get("levels", [])
	var key: String = str(assignments[level_index]) if level_index >= 0 and level_index < assignments.size() else str(_catalog.get("default", ""))
	var definition: Dictionary = _catalog.get("templates", {}).get(key, {})
	if definition.get("slots", []).size() == slot_count:
		configure_layout(key)


## 原子切换已验证的布局，预览也可使用不同数量的盒位。
func configure_layout(key: String) -> bool:
	if key == layout_id:
		return true
	var definition: Dictionary = _catalog.get("templates", {}).get(key, {})
	var entries: Array = definition.get("slots", [])
	if not validate_layout(entries).is_empty():
		return false
	layout_slots = entries.duplicate(true)
	layout_id = key
	_resize_boxes(entries.size())
	fit(Rect2(position, size))
	return true


## 拒绝重复编号、错误阅读顺序和四层食物重叠，配置顺序即左上到右下的处理顺序。
static func validate_layout(entries: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	if entries.is_empty() or entries.size() > 25:
		errors.append("盒位数量必须在 1–25 之间")
		return errors
	var ids: Dictionary = {}
	for index: int in entries.size():
		if not entries[index] is Dictionary:
			errors.append("盒位必须是坐标对象")
			return errors
		var entry: Dictionary = entries[index]
		if not entry.has_all(["id", "order", "layer", "x", "y"]):
			errors.append("盒位缺少编号、顺序、层级或坐标")
			return errors
		if str(entry.id).is_empty() or ids.has(str(entry.id)) or int(entry.order) != index:
			errors.append("盒位编号重复或顺序不连续")
		ids[str(entry.id)] = true
		if not is_finite(float(entry.x)) or not is_finite(float(entry.y)) or int(entry.layer) < 0:
			errors.append("盒位坐标或层级无效")
		for prior: int in index:
			var previous: Dictionary = entries[prior]
			if int(entry.layer) < int(previous.layer) or (int(entry.layer) == int(previous.layer) and float(entry.x) <= float(previous.x)):
				errors.append("同层盒位必须从左到右排列")
			if int(entry.layer) > int(previous.layer) and float(entry.y) <= float(previous.y):
				errors.append("后层盒位必须位于前层下方")
			if _reserved_rect(entry).intersects(_reserved_rect(previous)):
				errors.append("盒位的四层食物空间重叠")
	return errors


## 四层食物与选中抬起共用预留边界；配置坐标表示纸托的上沿中心。
static func _reserved_rect(entry: Dictionary) -> Rect2:
	return Rect2(Vector2(float(entry.x) - DonutBox.BOX_SIZE.x * 0.5, float(entry.y) - DonutStackView.MAX_TOP_OVERHANG),
		Vector2(DonutBox.BOX_SIZE.x, DonutBox.BOX_SIZE.y + DonutStackView.MAX_TOP_OVERHANG))


## 保留数组引用和稳定编号，输入路由在布局切换后仍使用同一组盒位。
func _resize_boxes(count: int) -> void:
	while boxes.size() > count:
		var old: DonutBox = boxes.pop_back()
		remove_child(old)
		old.queue_free()
	while boxes.size() < count:
		var box: DonutBox = BOX_SCENE.instantiate()
		box.box_index = boxes.size()
		box.name = "Box%d" % box.box_index
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.pressed.connect(box_pressed.emit.bind(box.box_index))
		add_child(box)
		boxes.append(box)


## 所有行数共用对称留白，以开局可见内容居中，并保留满四层与抬起空间。
func fit(area: Rect2) -> void:
	position = area.position
	size = area.size
	if layout_slots.is_empty():
		return
	var entries: Array = _compact_layouts.get(layout_id, layout_slots)
	var bounds: Rect2 = _reserved_rect(entries[0])
	for entry: Dictionary in entries:
		bounds = bounds.merge(_reserved_rect(entry))
	bounds.size.y += float(_extra_bottom.get(layout_id, 0.0))
	var opening: Rect2 = _opening_bounds.get(layout_id, bounds)
	var gap: float = float(_opening_gaps.get(layout_id, 0.0))
	var guard: float = maxf(VERTICAL_SPACE * 0.5, maxf(opening.position.y - bounds.position.y, bounds.end.y - opening.end.y))
	var required_padding: float = maxf(guard, gap * PADDING_GAP_RATIO + PADDING_GAP_MARGIN)
	var required_height: float = maxf(bounds.size.y + VERTICAL_SPACE, opening.size.y + required_padding * 2.0)
	var factor: float = maxf(0.001, minf(MAX_BOX_SCALE, minf(size.x / bounds.size.x, size.y / required_height)))
	var layers: Array[int] = []
	for entry: Dictionary in entries:
		if not layers.has(int(entry.layer)):
			layers.append(int(entry.layer))
	var extra_per_row: float = 0.0
	if layers.size() > 1:
		# 每增加一段行距，上下留白各减少半段总高度；同时约束两者，防止把外侧留白挤小。
		var intervals: int = layers.size() - 1
		var free_height: float = size.y / factor - opening.size.y
		var gap_limit: float = (free_height - 2.0 * (gap * PREFERRED_PADDING_GAP_RATIO + PADDING_GAP_MARGIN)) / (intervals + 2.0 * PREFERRED_PADDING_GAP_RATIO)
		var guard_limit: float = (free_height - 2.0 * guard) / intervals
		var row_span: float = float(entries.back().y) - float(entries[0].y)
		var stretch_limit: float = 0.60 if layers.size() >= 4 else 0.15
		extra_per_row = maxf(0.0, minf(gap_limit, minf(guard_limit, row_span * stretch_limit / intervals)))
		bounds.size.y += extra_per_row * intervals
		opening.size.y += extra_per_row * intervals
	var inset: Vector2 = (size - bounds.size * factor) * 0.5
	inset.y -= (opening.get_center().y - bounds.get_center().y) * factor
	for index: int in boxes.size():
		var entry: Dictionary = entries[index]
		var box: DonutBox = boxes[index]
		box.size = DonutBox.BOX_SIZE
		box.scale = Vector2.ONE * factor
		var row_y: float = float(entry.y) + layers.find(int(entry.layer)) * extra_per_row
		box.position = inset + (Vector2(float(entry.x) - box.size.x * 0.5, row_y) - bounds.position) * factor


## 使用快照刷新食物与机关，通关后隐藏未启用的周转入口，不预告可放入目标。
func present(state: Dictionary, selected: int) -> void:
	var targets: Array = state.get("number_targets", [])
	for index: int in boxes.size():
		boxes[index].present(state.slots[index], selected == index, state.waiting[index], float(state.get("active_seconds", 0)))
		boxes[index].show_number_target(targets.size() >= 2 and index == int(targets[0]))
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
