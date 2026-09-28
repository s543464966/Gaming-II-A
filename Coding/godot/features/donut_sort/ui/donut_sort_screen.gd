extends Control
## 将玩家意图交给关卡会话，按已提交事件的快照呈现出餐、机关与奖励。

signal move_requested(source: int, target: int)
signal undo_requested
signal add_box_requested
signal top_requested(box_index: int, item_index: int)
signal restart_requested
signal level_requested(index: int)
signal home_requested # 主页尚未实现，交由后续宿主导航接入。

const DESIGN_SIZE: Vector2 = Vector2(1024, 1536)
const HOST_VIEWPORT: Script = preload("res://platforms/minigame/host_viewport.gd")

## 宿主尺寸读取边界；独立预览默认使用完整视口。
var viewport_metrics: Callable = HOST_VIEWPORT.read_metrics

var session: DonutSession
var selected_box: int = -1
var _top_mode: bool = false
var _busy: bool = false
var _continuing: bool = false # 防止完成计时或重玩操作重复提交导航。
var _suspended: bool = false # 宿主失焦时暂停自动切关，重新激活后恢复反馈。
var _drag_source: int = -1
var _drag_preview: DonutDragPreview
var _drop_origin: Variant = null # 仅本次拖放落点使用的设计坐标，点击搬运时为空。
@onready var stage: Control = $Stage
@onready var backdrop: DonutBackground = $Backdrop
@onready var board_input: DonutBoardInput = $BoardInput
@onready var board: DonutBoardView = $Stage/Boxes
@onready var orders: DonutOrdersView = $Stage/Orders
@onready var event_player: DonutEventPlayer = $Stage/Effects
@onready var tools_view: DonutToolsView = $Stage/Tools
@onready var top_choices: DonutTopChoices = $Stage/TopChoices
@onready var completion_view: DonutCompletionView = $Stage/Completion
@onready var coin_balance: DonutCoinBalance = $Stage/CoinBalance
@onready var settings_button: DonutSettingsButton = $Stage/Settings
@onready var settings_panel: DonutSettingsPanel = $Stage/SettingsPanel
@onready var failure_panel: DonutFailurePanel = $Stage/FailurePanel


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
	event_player.initialize(board)
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
	settings_panel.visibility_changed.connect(func() -> void: _sync_failure.call_deferred())
	settings_panel.visibility_changed.connect(_sync_completion)
	failure_panel.home_requested.connect(_on_failure_home.call_deferred)
	failure_panel.retry_requested.connect(_on_failure_retry.call_deferred)
	top_choices.picked.connect(_choose_top.call_deferred)
	top_choices.canceled.connect(_cancel_top_selection.call_deferred)
	completion_view.continue_requested.connect(_on_continue_requested)
	$AdvanceTimer.timeout.connect(_on_continue_requested)
	$Stage/Title.gui_input.connect(_on_level_title_input)
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
	top_choices.position = Vector2(48, tools_view.position.y - 54)
	completion_view.position.y = tools_view.position.y - 54
	$Stage/Toast.position.y = stage.size.y - 376
	event_player.size = stage.size
	settings_panel.position = -stage.position / factor
	settings_panel.size = size / factor
	var settings_card: Control = settings_panel.get_node("Card")
	settings_card.position = stage.position / factor + (stage.size - settings_card.size) * 0.5
	failure_panel.position = settings_panel.position
	failure_panel.size = settings_panel.size
	var failure_card: Control = failure_panel.get_node("Card")
	failure_card.position = stage.position / factor + (stage.size - failure_card.size) * 0.5
	failure_panel.reset_feedback()
	_render()


## 失焦、暂停与离树中断展示，不回滚或重放已经提交的玩法事件。
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE]:
		_suspended = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_suspended = false
	if is_node_ready() and what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED, NOTIFICATION_EXIT_TREE]:
		_cancel_interaction()
	if is_node_ready() and what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_fit_stage.call_deferred()
	if is_node_ready() and what == NOTIFICATION_UNPAUSED:
		_sync_completion.call_deferred()


## 隐藏与恢复时统一清理临时输入并显示真实最终状态。
func _on_visibility_changed() -> void:
	if is_node_ready():
		_cancel_interaction()


## 返回键关闭面板或取消临时选择，空闲时交还宿主处理。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if failure_panel.visible:
			get_viewport().set_input_as_handled()
			return
		elif settings_panel.visible:
			settings_panel.close()
		elif _top_mode or selected_box >= 0 or board_input.is_active():
			_cancel_interaction()
		else:
			return
		get_viewport().set_input_as_handled()


## 页面可操作时才接收棋盘手势，菜单和动效期间不抢占其他控件输入。
func _board_input_enabled() -> bool:
	return is_visible_in_tree() and session.started and not settings_panel.visible and not failure_panel.visible and not session.is_won()


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
	if settings_panel.visible or failure_panel.visible or session.is_won():
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
	if settings_panel.visible or failure_panel.visible or session.is_won():
		return
	_cancel_interaction()
	if not session.can_undo():
		_toast("暂无可撤回操作" if int(session.tools.undo) > 0 else "撤回次数已用完")
		return
	undo_requested.emit()


## 在预设盒位中启用下一个周转盒，不动态增添棋盘位置。
func _on_add_box_pressed() -> void:
	if settings_panel.visible or failure_panel.visible or session.is_won():
		return
	_cancel_interaction()
	if session.next_turnover() < 0 or int(session.tools.add_box) <= 0 or session.is_won():
		_toast("周转盒已全部启用" if session.next_turnover() < 0 else "加餐盒次数已用完")
		return
	add_box_requested.emit()


## 进入置顶模式，实际有效选择之前不扣道具。
func _on_top_pressed() -> void:
	if settings_panel.visible or failure_panel.visible or session.is_won():
		return
	if int(session.tools.top) <= 0:
		_toast("置顶次数已用完")
		return
	_settle_presentation()
	_top_mode = not _top_mode
	selected_box = -1
	top_choices.clear()
	_render()
	if _top_mode:
		_toast("选择餐盒与要置顶的甜甜圈")


## 在底部操作区展开置顶选项，棋盘保持可见并允许切换餐盒。
func _show_top_choices(index: int) -> void:
	$ToastTimer.stop()
	_hide_toast()
	top_choices.present(session.slots[index].box.items, index, session.can_bring_to_top)
	_render()


## 输入回调结束后提交仍然有效的置顶选择，忽略中断后过期的点击。
func _choose_top(index: int, item_index: int) -> void:
	if not _top_mode or not top_choices.visible or selected_box != index or not session.can_bring_to_top(index, item_index):
		return
	_cancel_top_selection()
	top_requested.emit(index, item_index)


## 取消底部置顶选择并恢复三个道具，不消耗次数。
func _cancel_top_selection() -> void:
	_top_mode = false
	selected_box = -1
	top_choices.clear()
	_render()


## 把会话事件交给独立播放器；页面只协调中断与最终状态。
func _on_session_changed(events: Array) -> void:
	if not is_node_ready():
		return
	_continuing = false
	_top_mode = false
	top_choices.clear()
	failure_panel.hide()
	if not is_visible_in_tree():
		_render()
		return
	if board_input.is_active() or events.any(func(event: Dictionary) -> bool: return event.kind == "begin") or event_player.is_playing():
		_cancel_interaction()
	if events.is_empty():
		_render()
		_sync_failure.call_deferred()
		return
	_busy = true
	event_player.play(events, _drop_origin, _render_state, _toast)


## 结算后更新底部完成入口，仅真实失败自动打开遮罩面板。
func _finish_animation() -> void:
	_busy = false
	_render()
	if session.is_failed():
		_sync_failure()
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
	orders.present(state.demands)
	tools_view.present(state.tools, _top_mode)
	coin_balance.present(int(state.coins))
	var completed: bool = bool(state.get("won", false)) and not _busy
	completion_view.visible = completed
	if completed:
		top_choices.clear()
		completion_view.present(session.level_index)
	tools_view.visible = not completed and not top_choices.visible
	_sync_completion()


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
	if failure_panel.visible:
		return
	_cancel_interaction()
	settings_panel.show_level_selection()


## 齿轮打开设置模块的操作面板。
func _show_settings_menu() -> void:
	if failure_panel.visible:
		return
	_cancel_interaction()
	settings_panel.show_settings()


## 设置面板切关前结束手势与动画，延后提交会话操作。
func _on_settings_level_selected(index: int) -> void:
	_cancel_interaction()
	level_requested.emit.call_deferred(index)


## 设置面板重开前结束手势与动画，延后提交会话操作。
func _on_settings_restart_selected() -> void:
	_cancel_interaction()
	restart_requested.emit.call_deferred()


## 完成反馈计时只在当前可见、活跃且设置已关闭的页面中运行。
func _sync_completion() -> void:
	if not is_inside_tree() or not is_node_ready():
		return
	var can_advance: bool = completion_view.visible and session.is_won() and not _busy and not _continuing \
		and is_visible_in_tree() and not _suspended and not get_tree().paused and not settings_panel.visible \
		and session.level_index + 1 < DonutLevel.catalog().size()
	if not can_advance:
		$AdvanceTimer.stop()
	elif $AdvanceTimer.is_stopped():
		$AdvanceTimer.start()


## 反馈结束后自动切关，末关由玩家点重玩，导航延后且去重。
func _on_continue_requested() -> void:
	if _continuing or not completion_view.visible or not session.is_won() or settings_panel.visible \
			or not is_visible_in_tree() or _suspended or get_tree().paused:
		return
	_continuing = true
	$AdvanceTimer.stop()
	_continue_level.call_deferred(session, session.level_index)


## 导航前再次确认原会话仍处于完成状态，避免中断或主动切关后重复推进。
func _continue_level(completed_session: DonutSession, completed_index: int) -> void:
	if not _continuing or session != completed_session or session.level_index != completed_index:
		return
	if not is_visible_in_tree() or _suspended or get_tree().paused or settings_panel.visible:
		_continuing = false
		_sync_completion()
		return
	if session.level_index + 1 < DonutLevel.catalog().size():
		level_requested.emit(session.level_index + 1)
	else:
		restart_requested.emit()


## 动画结束或中断恢复后呈现真实失败状态，选关面板优先占用输入。
func _sync_failure() -> void:
	if not is_inside_tree() or not is_node_ready() or not is_visible_in_tree() or _busy:
		return
	if not session.is_failed():
		failure_panel.hide()
		return
	if settings_panel.visible or failure_panel.visible:
		return
	board_input.cancel()
	_clear_drag()
	selected_box = -1
	_top_mode = false
	$ToastTimer.stop()
	_hide_toast()
	_render()
	failure_panel.present()


## 转发预留的主页导航意图，未接入主页时保留失败面板与重试入口。
func _on_failure_home() -> void:
	failure_panel.present()
	home_requested.emit()


## 在输入回调结束后重开当前关卡，完整清空上局奖励和临时选择。
func _on_failure_retry() -> void:
	failure_panel.hide()
	_cancel_interaction()
	restart_requested.emit()


## 动效取消后释放所有临时精灵并显示真实已提交状态。
func _cancel_interaction() -> void:
	_continuing = false
	$AdvanceTimer.stop()
	board_input.cancel()
	_clear_drag()
	event_player.stop()
	_busy = false
	tools_view.reset_feedback()
	failure_panel.reset_feedback()
	_top_mode = false
	selected_box = -1
	$ToastTimer.stop()
	_hide_toast()
	settings_panel.close()
	top_choices.clear()
	_render()
	_sync_failure.call_deferred()


## 给出短暂操作反馈，不让提示覆盖底部道具命中区域。
func _toast(message: String) -> void:
	$Stage/Toast/Message.text = message
	$Stage/Toast.show()
	$ToastTimer.start()


## 清除到时或中断后的短提示。
func _hide_toast() -> void:
	$Stage/Toast.hide()
