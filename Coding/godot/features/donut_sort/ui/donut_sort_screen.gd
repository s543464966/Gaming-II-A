extends Control
## 将玩家意图交给关卡会话，按已提交事件的快照呈现出餐、机关与奖励。

signal move_requested(source: int, target: int)
signal undo_requested
signal add_box_requested
signal top_requested(box_index: int, item_index: int)
signal restart_requested
signal level_requested(index: int)

const PARCEL: Texture2D = preload("res://features/donut_sort/ui/art/trays/package_closed.tres")
const BOX_SCENE: PackedScene = preload("res://features/donut_sort/ui/donut_box.tscn")
const SPARKLE: Texture2D = preload("res://features/donut_sort/ui/art/effects/sparkle.tres")
const DESIGN_SIZE: Vector2 = Vector2(1024, 1536)
const ORDER_OPEN: Texture2D = preload("res://features/donut_sort/ui/art/ui/card_order_open.tres")
const ORDER_LOCKED: Texture2D = preload("res://features/donut_sort/ui/art/ui/card_order_locked.tres")

var session: DonutSession
var selected_box: int = -1
var _top_mode: bool = false
var _busy: bool = false
var _advance: bool = false
var _animation: Tween
var _boxes: Array[DonutBox] = []
var _drag_source: int = -1
var _drag_target: int = -1
var _drag_shown_count: int = 0
var _drag_preview: Control
var _drop_origin: Variant = null # 仅本次拖放落点使用的设计坐标，点击搬运时为空。
@onready var stage: Control = $Stage
@onready var modal: ColorRect = $Stage/Modal
@onready var board_input: DonutBoardInput = $BoardInput


## 显式连接会话依赖与操作信号，替换会话前清理旧连接。
func initialize(value: DonutSession) -> void:
	if session != null and session.changed.is_connected(_on_session_changed):
		session.changed.disconnect(_on_session_changed)
		move_requested.disconnect(session.move)
		undo_requested.disconnect(session.undo)
		add_box_requested.disconnect(session.add_box)
		top_requested.disconnect(session.bring_to_top)
		restart_requested.disconnect(session.restart)
		level_requested.disconnect(session.load_level)
	session = value
	session.changed.connect(_on_session_changed)
	move_requested.connect(session.move)
	undo_requested.connect(session.undo)
	add_box_requested.connect(session.add_box)
	top_requested.connect(session.bring_to_top)
	restart_requested.connect(session.restart)
	level_requested.connect(session.load_level)
	if is_node_ready():
		_cancel_interaction()
		session.begin()


## 装配稳定布局并开始首批餐盒入场，独立预览使用同一会话实现。
func _ready() -> void:
	if session == null:
		initialize(DonutSession.new())
	for box: DonutBox in $Stage/Boxes.get_children():
		box.box_index = _boxes.size()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.pressed.connect(_on_box_pressed.bind(box.box_index))
		_boxes.append(box)
	board_input.initialize(_boxes, _board_input_enabled)
	board_input.tapped.connect(_on_box_pressed)
	board_input.drag_began.connect(_on_drag_began)
	board_input.drag_moved.connect(_on_drag_moved)
	board_input.drag_ended.connect(_on_drag_ended)
	$Stage/Undo.pressed.connect(_on_undo_pressed)
	$Stage/AddBox.pressed.connect(_on_add_box_pressed)
	$Stage/Top.pressed.connect(_on_top_pressed)
	$Stage/Pause.pressed.connect(_show_pause)
	$Stage/Modal/Card/Resume.pressed.connect(_close_modal)
	$Stage/Modal/Card/Restart.pressed.connect(_restart_or_next)
	$ToastTimer.timeout.connect(_hide_toast)
	resized.connect(_fit_stage)
	visibility_changed.connect(_on_visibility_changed)
	_fit_stage.call_deferred()
	_render()
	_begin_after_layout()


## 等待容器完成首次布局后计算整盒入场位置。
func _begin_after_layout() -> void:
	await get_tree().process_frame
	if is_inside_tree():
		session.begin()


## 整个参考画布统一等比适配，长屏余量留给背景，保持棋盘透视和行距。
func _fit_stage() -> void:
	if not is_node_ready() or size.x <= 0 or size.y <= 0:
		return
	if board_input.is_active():
		_cancel_interaction()
	var factor: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	stage.scale = Vector2.ONE * factor
	stage.size = DESIGN_SIZE
	stage.position = (size - DESIGN_SIZE * factor) * 0.5
	modal.size = DESIGN_SIZE


## 失焦、暂停与离树中断展示，不回滚或重放已经提交的玩法事件。
func _notification(what: int) -> void:
	if is_node_ready() and what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED, NOTIFICATION_EXIT_TREE]:
		_cancel_interaction()


## 隐藏与恢复时统一清理临时输入并显示真实最终状态。
func _on_visibility_changed() -> void:
	if is_node_ready():
		_cancel_interaction()


## 返回键优先关闭面板或取消选中，再进入暂停菜单。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if modal.visible:
			_close_modal()
		elif _top_mode or selected_box >= 0 or board_input.is_active():
			_cancel_interaction()
		else:
			_show_pause()
		get_viewport().set_input_as_handled()


## 页面可操作时才接收棋盘手势，菜单和动效期间不抢占其他控件输入。
func _board_input_enabled() -> bool:
	return is_visible_in_tree() and session.started and not _busy and not modal.visible and not session.is_won()


## 拿起来源盒顶部的明牌同味组，拖动阶段不改变会话内容。
func _on_drag_began(source: int) -> void:
	if _top_mode or session.top_group_size(source) == 0:
		return
	_drag_source = source
	selected_box = source
	_drag_preview = Control.new()
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.scale = _boxes[source].scale
	$Stage/Effects.add_child(_drag_preview)
	for index: int in session.top_group_size(source):
		var food := TextureRect.new()
		food.texture = DonutBox.FOOD[int(session.slots[source].box.items[index].flavor)]
		food.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		food.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		food.mouse_filter = Control.MOUSE_FILTER_IGNORE
		food.size = DonutBox.FOOD_SIZE
		food.position.y = index * _boxes[source].stack_step()
		food.z_index = 4 - index
		_drag_preview.add_child(food)
	var count := Label.new()
	count.name = "Count"
	count.position = Vector2(99, -10)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_theme_font_size_override("font_size", 30)
	count.add_theme_color_override("font_color", Color.WHITE)
	count.add_theme_color_override("font_outline_color", Color("9c5234"))
	count.add_theme_constant_override("outline_size", 5)
	_drag_preview.add_child(count)


## 预览跟随指针，合法落点高亮；容量不足时只拿起实际能放入的数量。
func _on_drag_moved(viewport_position: Vector2) -> void:
	if _drag_preview == null:
		return
	var candidate: int = board_input.box_at(viewport_position)
	var target: int = candidate if session.can_move(_drag_source, candidate) else -1
	var count: int = session.move_count(_drag_source, target) if target >= 0 else session.top_group_size(_drag_source)
	_drag_preview.position = stage.get_global_transform_with_canvas().affine_inverse() * viewport_position - DonutBox.FOOD_SIZE * _drag_preview.scale * 0.5
	if target != _drag_target or count != _drag_shown_count:
		_drag_target = target
		_drag_shown_count = count
		_render()
		_boxes[_drag_source].hide_moving_food(count)
		for index: int in _drag_preview.get_child_count() - 1:
			_drag_preview.get_child(index).visible = index < count
		_drag_preview.get_node("Count").text = "×%d" % count


## 松手后才向统一规则提交搬运，无效落点或取消直接恢复原盒显示。
func _on_drag_ended(target: int, canceled: bool) -> void:
	if _drag_preview == null:
		return
	var source: int = _drag_source
	var origin: Vector2 = _drag_preview.position
	var valid: bool = not canceled and session.can_move(source, target)
	_clear_drag()
	selected_box = -1
	_render()
	if valid:
		_drop_origin = origin
		move_requested.emit(source, target)
		_drop_origin = null
	elif not canceled and target >= 0 and target != source:
		_toast("这里无法放入，已放回原盒")


## 丢弃临时拖拽显示，不退还、扣除或改写任何玩法数据。
func _clear_drag() -> void:
	if _drag_preview != null:
		_drag_preview.hide()
		_drag_preview.queue_free()
	_drag_preview = null
	_drag_source = -1
	_drag_target = -1
	_drag_shown_count = 0
	_drop_origin = null


## 选择来源与目标；空盒位、机关未解除或非法目标均不给规则状态写入机会。
func _on_box_pressed(index: int) -> void:
	if _busy or modal.visible or session.is_won():
		return
	var slot: Dictionary = session.slots[index]
	if not slot.open:
		if slot.kind == "turnover":
			_on_add_box_pressed()
		else:
			_toast("完成 %d 单后解锁" % int(slot.unlock_after))
		return
	if not session.can_handle(index):
		_toast("这里暂时没有餐盒" if slot.box == null else "餐盒限制尚未解除")
		return
	if _top_mode:
		if slot.box.items.size() < 2:
			_toast("选择至少有两颗甜甜圈的餐盒")
			return
		selected_box = index
		_show_top_choices(index)
		return
	if selected_box == index:
		selected_box = -1
		_render()
		return
	if selected_box >= 0:
		var source: int = selected_box
		if session.can_move(source, index):
			selected_box = -1
			move_requested.emit(source, index)
		else:
			_toast("餐盒已满" if slot.box.items.size() == session.capacity(index) else "只能放入空盒或同口味餐盒")
		return
	if not slot.box.items.is_empty():
		selected_box = index
		_render()


## 撤回整次操作及其回收、补位、揭示和奖励，取消选择不消耗道具。
func _on_undo_pressed() -> void:
	if _busy or modal.visible:
		return
	_cancel_interaction()
	if not session.can_undo():
		_toast("暂无可撤回操作" if int(session.tools.undo) > 0 else "撤回次数已用完")
		return
	undo_requested.emit()


## 在固定十六格中启用下一个周转盒，绝不增添第十七个盒位。
func _on_add_box_pressed() -> void:
	if _busy or modal.visible:
		return
	_cancel_interaction()
	if session.next_turnover() < 0 or int(session.tools.add_box) <= 0 or session.is_won():
		_toast("周转盒已全部启用" if session.next_turnover() < 0 else "加餐盒次数已用完")
		return
	add_box_requested.emit()


## 进入置顶模式，实际有效选择之前不扣道具。
func _on_top_pressed() -> void:
	if _busy or modal.visible or session.is_won():
		return
	if int(session.tools.top) <= 0:
		_toast("置顶次数已用完")
		return
	_top_mode = not _top_mode
	selected_box = -1
	_render()
	if _top_mode:
		_toast("选择餐盒与要置顶的甜甜圈")


## 展开已揭示的食物，隐藏层只显示包装且不可选择。
func _show_top_choices(index: int) -> void:
	$ToastTimer.stop()
	_hide_toast()
	_clear_choices()
	$Stage/Modal/Card/Heading.text = "选择要置顶的甜甜圈"
	$Stage/Modal/Card/Detail.text = "仅可选择已揭示的甜甜圈"
	$Stage/Modal/Card/Resume.text = "取消"
	$Stage/Modal/Card/Restart.hide()
	for item_index: int in session.slots[index].box.items.size():
		var item: Dictionary = session.slots[index].box.items[item_index]
		var choice := Button.new()
		choice.custom_minimum_size = Vector2(160, 155)
		choice.icon = DonutBox.FOOD[int(item.flavor)] if item.revealed else DonutBox.HIDDEN
		choice.expand_icon = true
		choice.add_theme_constant_override("icon_max_width", 143)
		choice.disabled = not session.can_bring_to_top(index, item_index)
		choice.pressed.connect(_choose_top.bind(index, item_index))
		$Stage/Modal/Card/Choices.add_child(choice)
	modal.show()


## 关闭选择面板后请求一次可撤回的置顶操作。
func _choose_top(index: int, item_index: int) -> void:
	_close_modal()
	top_requested.emit(index, item_index)


## 把已提交事务按事件快照串成可取消动效，不在动画回调中再次结算玩法。
func _on_session_changed(events: Array) -> void:
	if not is_node_ready():
		return
	if not is_visible_in_tree():
		_render()
		return
	if board_input.is_active() or events.any(func(event: Dictionary) -> bool: return event.kind == "begin") or (_animation != null and _animation.is_running()):
		_cancel_interaction()
	if events.is_empty():
		_render()
		return
	_busy = true
	_animation = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_animation.tween_interval(0.01)
	for event: Dictionary in events:
		match event.kind:
			"begin":
				_render_state(event.state)
				for index: int in _boxes.size():
					if event.state.slots[index].open and event.state.slots[index].box != null:
						_boxes[index].hide()
						_append_box_flight(event.state.slots[index], index, 0.07)
						_animation.tween_callback(_boxes[index].show)
			"move":
				_append_group_flight(event)
			"dispatch":
				_animation.tween_callback(_boxes[event.index].hide)
				_append_flight(PARCEL, _box_origin(event.index), Vector2(_box_origin(event.index).x, -180), _boxes[event.index].size * _boxes[event.index].scale, 0.24)
			"refill":
				_append_box_flight(event.state.slots[event.index], event.index, 0.19)
			"mechanism", "reveal", "unlock", "demand_unlock":
				_animation.tween_interval(0.06)
			"combo":
				_animation.tween_callback(_show_combo.bind(event))
				_append_flight(SPARKLE, Vector2(158, $Stage/Dispatch.position.y - 24), Vector2(158, $Stage/Dispatch.position.y - 60), Vector2(75, 70), 0.32)
			"undo":
				_animation.tween_callback(_toast.bind("已撤回，机关与奖励同步恢复"))
		_animation.tween_callback(_render_state.bind(event.state))
	_animation.finished.connect(_finish_animation)


## 结算展示完毕后释放输入锁，检查通关或暂时无可搬运目标。
func _finish_animation() -> void:
	_busy = false
	_render()
	if session.is_won():
		_show_victory()
	elif session.is_blocked():
		_toast("暂无可移动位置，可撤回、启用周转盒或重开")


## 返回餐盒在设计坐标中的左上位置。
func _box_origin(index: int) -> Vector2:
	return _boxes[index].position + $Stage/Boxes.position


## 把实际搬运数量作为一组表现，未搬走的食物保持原位直到快照刷新。
func _append_group_flight(event: Dictionary) -> void:
	var group := Control.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.scale = _boxes[event.source].scale
	group.position = _drop_origin if _drop_origin != null else _box_origin(event.source) + _boxes[event.source].food_position(0, session.slots[event.source].kind == "single") * group.scale
	group.visible = _drop_origin != null
	$Stage/Effects.add_child(group)
	if _drop_origin != null:
		_boxes[event.source].hide_moving_food(event.count)
	for index: int in int(event.count):
		var sprite := TextureRect.new()
		sprite.texture = DonutBox.FOOD[int(event.items[index].flavor)]
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.size = DonutBox.FOOD_SIZE
		sprite.position.y = index * _boxes[event.source].stack_step()
		sprite.z_index = 4 - index
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(sprite)
	_animation.tween_callback(_boxes[event.source].hide_moving_food.bind(event.count))
	_animation.tween_callback(group.show)
	var target_count: int = event.state.slots[event.target].box.items.size()
	var finish: Vector2 = _box_origin(event.target) + _boxes[event.target].food_position(0, session.slots[event.target].kind == "single", target_count) * _boxes[event.target].scale
	_animation.tween_property(group, "position", finish, 0.17)
	_animation.parallel().tween_property(group, "scale", _boxes[event.target].scale, 0.17)
	_animation.tween_callback(group.queue_free)


## 使用同一餐盒场景表现整盒从底部进入原盒位，保留隐藏和机关外观。
func _append_box_flight(slot: Dictionary, index: int, duration: float) -> void:
	var sprite: DonutBox = BOX_SCENE.instantiate()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.box_index = index
	sprite.size = _boxes[index].size
	sprite.position = $Stage/Dispatch.position + Vector2(90, 10)
	sprite.hide()
	$Stage/Effects.add_child(sprite)
	sprite.present(slot)
	_animation.tween_callback(sprite.show)
	_animation.tween_property(sprite, "position", _box_origin(index), duration)
	_animation.parallel().tween_property(sprite, "scale", _boxes[index].scale, duration)
	_animation.tween_callback(sprite.queue_free)


## 将打包纹理加入同一时间线，隐藏或离树时可以统一释放。
func _append_flight(texture: Texture2D, start: Vector2, finish: Vector2, dimensions: Vector2, duration: float) -> void:
	var sprite := TextureRect.new()
	sprite.texture = texture
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.position = start
	sprite.size = dimensions
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.hide()
	$Stage/Effects.add_child(sprite)
	_animation.tween_callback(sprite.show)
	_animation.tween_property(sprite, "position", finish, duration)
	_animation.tween_callback(sprite.queue_free)


## 更新真实状态的最终显示，取消动画时直接收敛到此状态。
func _render() -> void:
	if not _boxes.is_empty():
		_render_state(session.snapshot())


## 呈现会话提供的只读快照，包括四需求、队首备货与本关奖励。
func _render_state(state: Dictionary) -> void:
	$Stage/Title.text = "Level %d" % (session.level_index + 1)
	$Stage/Progress.text = "%d/%d Orders" % [state.completed, session.total_orders()]
	for index: int in _boxes.size():
		var available: bool = selected_box < 0 or session.can_move(selected_box, index)
		_boxes[index].present(state.slots[index], selected_box == index, available, state.waiting[index], _drag_target == index)
		_boxes[index].show()
	for index: int in 4:
		var card: Control = stage.get_node("Order%d" % index)
		var position: Dictionary = state.demands[index]
		var active: bool = position.open and position.cursor < position.sequence.size()
		card.get_node("Plate").texture = ORDER_OPEN if position.open else ORDER_LOCKED
		card.get_node("Food").visible = active
		card.get_node("Lock").visible = not position.open
		card.get_node("Count").text = "×4" if active else ("?" if not position.open else "✓")
		card.tooltip_text = "完成 %d 单后解锁" % int(position.unlock_after) if not position.open else ""
		card.get_node("Count").add_theme_font_size_override("font_size", 37)
		if active:
			card.get_node("Food").texture = DonutBox.FOOD[int(position.sequence[position.cursor])]
	for index: int in 2:
		var preview: DonutBox = $Stage/Dispatch.get_node("Preview%d" % index)
		preview.visible = index < state.stock_preview.size()
		if preview.visible:
			var definition: Dictionary = state.stock_preview[index]
			var box: Dictionary = {"kind": definition.get("kind", "normal"), "lid": int(definition.get("lid", 0)),
				"frozen": definition.get("kind", "normal") == "frozen", "items": definition.items}
			preview.present({"kind": "regular", "open": true, "box": box})
	$Stage/Dispatch/PreviewLabel.text = "Next Boxes" if state.remaining_stock > 0 else "All Boxes Served"
	$Stage/Dispatch/Supply.text = "剩余 %d 盒" % int(state.remaining_stock)
	$Stage/Undo/Count.text = str(state.tools.undo)
	$Stage/AddBox/Count.text = str(state.tools.add_box)
	$Stage/Top/Count.text = str(state.tools.top)
	$Stage/Earnings.visible = state.coins > 0 or state.diamonds > 0
	$Stage/Earnings/Coins.text = str(state.coins)
	$Stage/Earnings/Diamonds.text = str(state.diamonds)
	$Stage/Top.modulate = Color(1, 0.9, 0.6) if _top_mode else Color.WHITE


## 以独立短提示展示已结算的连单，不额外发放奖励。
func _show_combo(event: Dictionary) -> void:
	_toast("%d 连单！金币 +%d · 钻石 +%d" % [event.count, event.coins, event.diamonds])


## 暂停菜单同时提供实际内容目录中的关卡入口。
func _show_pause() -> void:
	_cancel_interaction()
	_clear_choices()
	_advance = false
	$Stage/Modal/Card/Heading.text = "营业休息中"
	$Stage/Modal/Card/Detail.text = "选择关卡 · 本关奖励随重开重置"
	$Stage/Modal/Card/Resume.text = "继续营业"
	$Stage/Modal/Card/Restart.text = "重新开始"
	$Stage/Modal/Card/Restart.show()
	var levels: Array = DonutLevel.catalog()
	for index: int in levels.size():
		var button := Button.new()
		button.text = "第 %d 关\n%s" % [index + 1, levels[index].title]
		button.custom_minimum_size = Vector2(218, 130)
		button.add_theme_font_size_override("font_size", 26)
		button.pressed.connect(_choose_level.bind(index))
		$Stage/Modal/Card/Choices.add_child(button)
	modal.show()


## 清理当前展示后延后切关，避免在输入派发中删除按钮。
func _choose_level(index: int) -> void:
	_close_modal()
	_cancel_interaction()
	level_requested.emit.call_deferred(index)


## 显示真实订单、步数与本关奖励，并提供下一关入口。
func _show_victory() -> void:
	$ToastTimer.stop()
	_hide_toast()
	_clear_choices()
	_advance = session.level_index + 1 < DonutLevel.catalog().size()
	$Stage/Modal/Card/Heading.text = "今日订单全部完成！"
	$Stage/Modal/Card/Detail.text = "%d 步 · %d 单\n金币 %d · 钻石 %d" % [session.moves, session.completed, session.coins, session.diamonds]
	$Stage/Modal/Card/Resume.text = "查看餐台"
	$Stage/Modal/Card/Restart.text = "下一关" if _advance else "再玩一遍"
	$Stage/Modal/Card/Restart.show()
	modal.show()


## 关闭页面内面板，只取消临时选择而不改变规则与道具数量。
func _close_modal() -> void:
	modal.hide()
	_top_mode = false
	selected_box = -1
	_clear_choices()
	_render()


## 根据结束面板状态重开或前往下一关。
func _restart_or_next() -> void:
	var advance: bool = _advance
	_close_modal()
	_cancel_interaction()
	if advance:
		level_requested.emit.call_deferred(session.level_index + 1)
	else:
		restart_requested.emit.call_deferred()


## 删除旧面板内容，稳定界面节点始终复用。
func _clear_choices() -> void:
	for choice: Node in $Stage/Modal/Card/Choices.get_children():
		$Stage/Modal/Card/Choices.remove_child(choice)
		choice.queue_free()


## 动效取消后释放所有临时精灵并显示真实已提交状态。
func _cancel_interaction() -> void:
	board_input.cancel()
	_clear_drag()
	if _animation != null and _animation.is_running():
		_animation.kill()
	for effect: Node in $Stage/Effects.get_children():
		effect.queue_free()
	_busy = false
	_top_mode = false
	selected_box = -1
	_advance = false
	$ToastTimer.stop()
	_hide_toast()
	if modal.visible:
		modal.hide()
		_clear_choices()
	_render()


## 给出短暂操作反馈，不让提示覆盖底部道具命中区域。
func _toast(message: String) -> void:
	$Stage/Toast/Message.text = message
	$Stage/Toast.show()
	$ToastTimer.start()


## 清除到时或中断后的短提示。
func _hide_toast() -> void:
	$Stage/Toast.hide()
