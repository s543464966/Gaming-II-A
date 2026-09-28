extends Control
## 将玩家意图交给关卡会话，按已提交事件的快照呈现出餐、机关与奖励。

signal move_requested(source: int, target: int)
signal undo_requested
signal add_box_requested
signal top_requested(box_index: int, item_index: int)
signal restart_requested
signal level_requested(index: int)

const DESIGN_SIZE: Vector2 = Vector2(1024, 1536)
const HOST_VIEWPORT: Script = preload("res://platforms/minigame/host_viewport.gd")

## 宿主尺寸读取边界；独立预览默认使用完整视口。
var viewport_metrics: Callable = HOST_VIEWPORT.read_metrics

var session: DonutSession
var selected_box: int = -1
var _top_mode: bool = false
var _busy: bool = false
var _advance: bool = false
var _drag_source: int = -1
var _drag_preview: DonutDragPreview
var _drop_origin: Variant = null # 仅本次拖放落点使用的设计坐标，点击搬运时为空。
@onready var stage: Control = $Stage
@onready var backdrop: DonutBackground = $Backdrop
@onready var modal: ColorRect = $Stage/Modal
@onready var board_input: DonutBoardInput = $BoardInput
@onready var board: DonutBoardView = $Stage/Boxes
@onready var orders: DonutOrdersView = $Stage/Orders
@onready var dispatch: DonutDispatchView = $Stage/Dispatch
@onready var event_player: DonutEventPlayer = $Stage/Effects
@onready var tools_view: DonutToolsView = $Stage/Tools
@onready var top_choices: DonutTopChoices = $Stage/Modal/Card/Choices
@onready var coin_balance: DonutCoinBalance = $Stage/CoinBalance
@onready var settings_button: DonutSettingsButton = $Stage/Settings
@onready var settings_panel: DonutSettingsPanel = $Stage/SettingsPanel


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
	event_player.initialize(board, dispatch)
	event_player.playback_finished.connect(_finish_animation)
	if session == null:
		initialize(DonutSession.new())
	for box: DonutBox in board.boxes:
		box.pressed.connect(_on_box_pressed.bind(box.box_index))
	board_input.initialize(board.boxes, _board_input_enabled)
	board_input.gesture_started.connect(_settle_presentation)
	board_input.tapped.connect(_on_box_pressed)
	board_input.drag_began.connect(_on_drag_began)
	board_input.drag_moved.connect(_on_drag_moved)
	board_input.drag_ended.connect(_on_drag_ended)
	tools_view.undo_pressed.connect(_on_undo_pressed)
	tools_view.add_box_pressed.connect(_on_add_box_pressed)
	tools_view.top_pressed.connect(_on_top_pressed)
	settings_button.settings_requested.connect(_show_settings_menu)
	settings_panel.level_selected.connect(_on_settings_level_selected)
	settings_panel.restart_selected.connect(_on_settings_restart_selected)
	settings_panel.sidebar_failed.connect(func() -> void: _toast("当前设备暂不支持抖音侧边栏"))
	top_choices.picked.connect(_choose_top)
	$Stage/Title.gui_input.connect(_on_level_title_input)
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


## 顶部与底部各自固定，四排餐盒分配安全区内剩余高度；宽屏限制内容宽度。
func _fit_stage() -> void:
	if not is_node_ready() or size.x <= 0 or size.y <= 0:
		return
	if board_input.is_active() or _busy:
		_cancel_interaction()
	var metrics: Dictionary = viewport_metrics.call()
	var available: Rect2 = HOST_VIEWPORT.content_rect(size, metrics)
	var width: float = minf(available.size.x, available.size.y / 1.70)
	var factor: float = width / DESIGN_SIZE.x
	stage.scale = Vector2.ONE * factor
	stage.size = Vector2(DESIGN_SIZE.x, available.size.y / factor)
	stage.position = available.position + Vector2((available.size.x - width) * 0.5, 0)
	backdrop.set_shop_boundary(stage.position.y + 360.0 * factor)
	var logical_width: float = float(metrics.get("width", minf(size.x, 430.0)))
	board_input.logical_pixel = size.x / maxf(1, logical_width)
	var board_area := Rect2(48, 353, 928, stage.size.y - 716)
	board.fit(board_area)
	tools_view.position.y = stage.size.y - 270
	dispatch.position.y = tools_view.position.y - 48
	$Stage/Toast.position.y = stage.size.y - 376
	event_player.size = stage.size
	modal.position = -stage.position / factor
	modal.size = size / factor
	$Stage/Modal/Card.position = stage.position / factor + (stage.size - $Stage/Modal/Card.size) * 0.5
	settings_panel.position = modal.position
	settings_panel.size = modal.size
	var settings_card: Control = settings_panel.get_node("Card")
	settings_card.position = stage.position / factor + (stage.size - settings_card.size) * 0.5
	_render()


## 失焦、暂停与离树中断展示，不回滚或重放已经提交的玩法事件。
func _notification(what: int) -> void:
	if is_node_ready() and what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED, NOTIFICATION_EXIT_TREE]:
		_cancel_interaction()
	if is_node_ready() and what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_fit_stage.call_deferred()


## 隐藏与恢复时统一清理临时输入并显示真实最终状态。
func _on_visibility_changed() -> void:
	if is_node_ready():
		_cancel_interaction()


## 返回键关闭面板或取消临时选择，空闲时交还宿主处理。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if settings_panel.visible:
			settings_panel.close()
		elif modal.visible:
			_close_modal()
		elif _top_mode or selected_box >= 0 or board_input.is_active():
			_cancel_interaction()
		else:
			return
		get_viewport().set_input_as_handled()


## 页面可操作时才接收棋盘手势，菜单和动效期间不抢占其他控件输入。
func _board_input_enabled() -> bool:
	return is_visible_in_tree() and session.started and not modal.visible and not settings_panel.visible and not session.is_won()


## 拖动时只拿起首颗，连续同味的后续食物留在来源盒等待有效松手。
func _on_drag_began(source: int) -> void:
	if _top_mode or not session.can_pick_top(source):
		return
	_drag_source = source
	selected_box = source
	_drag_preview = board.create_drag_preview(source, int(session.slots[source].box.items[0].flavor), event_player)
	_render()
	board.boxes[source].hide_moving_food(1)


## 只更新首颗跟手位置，拖动中不显示文字或目标合法性提示。
func _on_drag_moved(viewport_position: Vector2) -> void:
	if _drag_preview == null:
		return
	_drag_preview.follow(viewport_position, stage, board_input.logical_pixel, board_input.is_touch())


## 松手后才向统一规则提交搬运，无效落点或取消直接恢复原盒显示。
func _on_drag_ended(target: int, canceled: bool) -> void:
	if _drag_preview == null:
		return
	var source: int = _drag_source
	var origin: Vector2 = _drag_preview.position
	var valid: bool = not canceled and session.can_move(source, target)
	var returning: DonutDragPreview = _drag_preview if not valid and not canceled else null
	if returning != null:
		_drag_preview = null
	_clear_drag()
	selected_box = -1
	_render()
	if returning != null:
		var tween: Tween = returning.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(returning, "position", board.origin(source) + board.boxes[source].food_position(0) * board.boxes[source].scale, 0.14)
		tween.tween_callback(returning.queue_free)
	if valid:
		_drop_origin = origin
		move_requested.emit(source, target)
		_drop_origin = null


## 丢弃临时拖拽显示，不退还、扣除或改写任何玩法数据。
func _clear_drag() -> void:
	if _drag_preview != null:
		_drag_preview.hide()
		_drag_preview.queue_free()
	_drag_preview = null
	_drag_source = -1
	_drop_origin = null


## 下一次真实操作先收敛已提交的动画，避免连续拖拽被吞掉。
func _settle_presentation() -> void:
	event_player.stop()
	_busy = false
	_render()


## 选择来源与目标；空盒位、机关未解除或非法目标均不给规则状态写入机会。
func _on_box_pressed(index: int) -> void:
	if modal.visible or settings_panel.visible or session.is_won():
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
	if modal.visible or settings_panel.visible:
		return
	_cancel_interaction()
	if not session.can_undo():
		_toast("暂无可撤回操作" if int(session.tools.undo) > 0 else "撤回次数已用完")
		return
	undo_requested.emit()


## 在预设盒位中启用下一个周转盒，不动态增添棋盘位置。
func _on_add_box_pressed() -> void:
	if modal.visible or settings_panel.visible:
		return
	_cancel_interaction()
	if session.next_turnover() < 0 or int(session.tools.add_box) <= 0 or session.is_won():
		_toast("周转盒已全部启用" if session.next_turnover() < 0 else "加餐盒次数已用完")
		return
	add_box_requested.emit()


## 进入置顶模式，实际有效选择之前不扣道具。
func _on_top_pressed() -> void:
	if modal.visible or settings_panel.visible or session.is_won():
		return
	if int(session.tools.top) <= 0:
		_toast("置顶次数已用完")
		return
	_settle_presentation()
	_top_mode = not _top_mode
	selected_box = -1
	_render()
	if _top_mode:
		_toast("选择餐盒与要置顶的甜甜圈")


## 打开专属置顶选择列表，共用页面弹窗容器。
func _show_top_choices(index: int) -> void:
	$ToastTimer.stop()
	_hide_toast()
	_clear_choices()
	$Stage/Modal/Card/Heading.text = "选择要置顶的甜甜圈"
	$Stage/Modal/Card/Detail.text = "灰色甜甜圈置顶后揭晓口味"
	$Stage/Modal/Card/Resume.text = "取消"
	$Stage/Modal/Card/Restart.hide()
	top_choices.present(session.slots[index].box.items, index, session.can_bring_to_top)
	modal.show()


## 关闭选择面板后请求一次可撤回的置顶操作。
func _choose_top(index: int, item_index: int) -> void:
	_close_modal()
	top_requested.emit(index, item_index)


## 把会话事件交给独立播放器；页面只协调中断与最终状态。
func _on_session_changed(events: Array) -> void:
	if not is_node_ready():
		return
	if not is_visible_in_tree():
		_render()
		return
	if board_input.is_active() or events.any(func(event: Dictionary) -> bool: return event.kind == "begin") or event_player.is_playing():
		_cancel_interaction()
	if events.is_empty():
		_render()
		return
	_busy = true
	event_player.play(events, _drop_origin, _render_state, _toast)


## 结算展示完毕后释放输入锁，检查通关或暂时无可搬运目标。
func _finish_animation() -> void:
	_busy = false
	_render()
	if session.is_won():
		_show_victory()
	elif session.is_blocked():
		_toast("暂无可移动位置，可撤回、启用周转盒或重开")


## 更新真实状态的最终显示，取消动画时直接收敛到此状态。
func _render() -> void:
	if not board.boxes.is_empty():
		_render_state(session.snapshot())


## 呈现会话快照，具体盒位、订单和道具显示由各自视图负责。
func _render_state(state: Dictionary) -> void:
	$Stage/Title.text = "第 %d 关" % (session.level_index + 1)
	board.present(state, selected_box)
	orders.present(state.demands, state.completed, session.total_orders())
	tools_view.present(state.tools, _top_mode)
	coin_balance.present(int(state.coins))


## 标题在有效松开时打开关卡选择，取消的触摸不会误开面板。
func _on_level_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_show_level_menu()
		$Stage/Title.accept_event()
	elif event is InputEventScreenTouch and not event.pressed and not event.canceled:
		_show_level_menu()
		$Stage/Title.accept_event()


## 关卡标题打开设置模块的选关视图，不改变场景树暂停状态。
func _show_level_menu() -> void:
	_cancel_interaction()
	settings_panel.show_level_selection(session.coins, session.diamonds)


## 齿轮打开设置模块的操作面板，展示真实的本关奖励。
func _show_settings_menu() -> void:
	_cancel_interaction()
	settings_panel.show_settings(session.coins, session.diamonds)


## 设置面板切关前结束手势与动画，延后提交会话操作。
func _on_settings_level_selected(index: int) -> void:
	_cancel_interaction()
	level_requested.emit.call_deferred(index)


## 设置面板重开前结束手势与动画，延后提交会话操作。
func _on_settings_restart_selected() -> void:
	_cancel_interaction()
	restart_requested.emit.call_deferred()


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
	top_choices.clear()


## 动效取消后释放所有临时精灵并显示真实已提交状态。
func _cancel_interaction() -> void:
	board_input.cancel()
	_clear_drag()
	event_player.stop()
	_busy = false
	tools_view.reset_feedback()
	_top_mode = false
	selected_box = -1
	_advance = false
	$ToastTimer.stop()
	_hide_toast()
	settings_panel.close()
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
