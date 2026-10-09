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
const HOST_LOCALE: Script = preload("res://platforms/minigame/host_locale.gd")
# 页面统一预算使用宿主逻辑像素，模块内部仍使用各自设计尺寸。
const PAGE_MARGIN: float = 16.0
const SECTION_GAP: float = 8.0
const MIN_TOUCH_SIZE: float = 44.0
const MAX_ORDERS_WIDTH: float = 480.0 # 宽屏订单独立限宽，棋盘继续使用完整内容宽度。
const TOOL_BUTTON_SIZE: float = 263.5 # 170 设计单位的按钮在模块内放大 1.55 倍。

## 宿主尺寸读取边界；独立预览默认使用完整视口。
var viewport_metrics: Callable = HOST_VIEWPORT.read_metrics
## 广告预留边界：接收道具名与完成回调，回调参数表示是否获得奖励；未接入时临时直接领取。
var tool_reward_provider: Callable
@export var idle_hint_seconds: float = 35.0 # 连续没有有效搬运的秒数；提示不暂停炸弹。
@export var idle_hint_invalid_attempts: int = 4 # 连续无效操作达到此数也可提示。

var session: DonutSession
var progress: DonutProgress
var lessons_enabled: bool = false # 完整App启用持久教学，F6与规则测试保持独立。
var _seen_lessons: Dictionary = {}
var _dialog_kind: String = ""
var _dialog_value: Variant
var _idle_seconds: float = 0.0
var _idle_dismissed: bool = false
var _invalid_attempts: int = 0
var _clock_refresh: float = 0.0
var _review_keys: Array[String] = []
var selected_box: int = -1
var _top_mode: bool = false
var _busy: bool = false
var _continuing: bool = false # 防止完成计时或重玩操作重复提交导航。
var _suspended: bool = false # 宿主失焦时暂停自动切关，重新激活后恢复反馈。
var _drag_source: int = -1
var _drag_preview: DonutDragPreview
var _drop_origin: Variant = null # 本次首颗飞行起点；承接选中抬起或拖放位置，无玩家操作时为空。
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
@onready var lesson_dialog: DonutDialog = $Stage/LessonDialog


## 显式连接会话依赖与操作信号，替换会话前清理旧连接。
func initialize(value: DonutSession) -> void:
	if session != null:
		session.cancel_tool_reward()
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
	HOST_LOCALE.apply()
	event_player.initialize(board, orders)
	event_player.playback_finished.connect(_finish_animation)
	if session == null:
		initialize(DonutSession.new())
	board.box_pressed.connect(_on_box_pressed)
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
	settings_panel.lessons_requested.connect(_review_lessons)
	lesson_dialog.answered.connect(_on_dialog_answer.call_deferred)
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
	$Stage/IdleHint/Row/Dismiss.pressed.connect(func() -> void: $Stage/IdleHint.hide())
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
		if not _busy:
			_maybe_show_lesson()


## 关卡页统一分配可用空间；平台只报告边界，背景和各模块消费页面算出的区域。
func _fit_stage() -> void:
	if not is_node_ready() or size.x <= 0 or size.y <= 0:
		return
	if board_input.is_active() or _busy:
		_cancel_interaction()
	var metrics: Dictionary = viewport_metrics.call()
	var available: Rect2 = HOST_VIEWPORT.content_rect(size, metrics)
	var menu: Rect2 = HOST_VIEWPORT.menu_rect(size, metrics)
	var logical_width: float = float(metrics.get("width", minf(size.x, 430.0)))
	if not is_finite(logical_width) or logical_width <= 0:
		logical_width = minf(size.x, 430.0)
	var logical_pixel: float = size.x / logical_width
	var content: Rect2 = available.grow(-PAGE_MARGIN * logical_pixel)
	var factor: float = content.size.x / DESIGN_SIZE.x
	stage.scale = Vector2.ONE * factor
	stage.size = content.size / factor
	stage.position = content.position
	board_input.logical_pixel = logical_pixel
	var unit: float = logical_pixel / factor
	var header_bottom: float = _fit_header(content, menu, logical_pixel)
	var safe_height: float = available.size.y / logical_pixel
	var orders_width: float = lerpf(240.0, MAX_ORDERS_WIDTH, clampf((safe_height - 520.0) / 160.0, 0.0, 1.0))
	var orders_factor: float = minf(content.size.x, orders_width * logical_pixel) / DESIGN_SIZE.x
	orders.scale = Vector2.ONE * orders_factor / factor
	var orders_top: float = header_bottom + SECTION_GAP * logical_pixel
	if menu.has_area():
		orders_top = maxf(orders_top, menu.end.y + SECTION_GAP * logical_pixel)
	orders.position = Vector2((stage.size.x - DESIGN_SIZE.x * orders.scale.x) * 0.5,
		(orders_top - content.position.y) / factor)
	# 背景与棋盘共用像素对齐后的分区边界，避免接缝与可见留白偏差。
	var table_top: float = roundf(orders_top + 232.0 * orders_factor)
	# 道具按实际按钮大小预留角标，短屏压缩装饰而不缩窄整页。
	var button_size: float = minf(clampf(safe_height * 0.11, 56.0, 86.0) * logical_pixel,
		content.size.x * TOOL_BUTTON_SIZE / DESIGN_SIZE.x)
	tools_view.scale = Vector2.ONE * button_size / TOOL_BUTTON_SIZE / factor
	tools_view.position = Vector2((stage.size.x - tools_view.size.x * tools_view.scale.x) * 0.5,
		stage.size.y - tools_view.size.y * tools_view.scale.y)
	var footer_top: float = roundf(content.position.y + tools_view.position.y * factor - button_size * 0.10 - SECTION_GAP * logical_pixel)
	# 最短屏柜体收至 12 逻辑像素，为五排满层和抬起预留空间，保留纸托与点击尺寸。
	var cabinet_height: float = lerpf(12.0, 56.0, clampf((safe_height - 520.0) / 240.0, 0.0, 1.0)) * logical_pixel
	var surface_bottom: float = roundf(footer_top - cabinet_height)
	board.fit(Rect2(Vector2(0, (table_top - content.position.y) / factor),
		Vector2(stage.size.x, (surface_bottom - table_top) / factor)))
	backdrop.fit_counter(table_top, surface_bottom, footer_top)
	_fit_footer_feedback(unit)
	event_player.entry_bounds = Rect2(-stage.position / factor, size / factor)
	event_player.size = stage.size
	$Stage/IdleHint.scale = Vector2.ONE * maxf(1.0, MIN_TOUCH_SIZE * unit / 104.0)
	# 只有大卡片需要整块避开胶囊；页面顶部仍保留可利用的左右空间。
	var modal_area: Rect2 = available
	if menu.has_area():
		var top: float = maxf(available.position.y, menu.end.y + SECTION_GAP * logical_pixel)
		modal_area = Rect2(Vector2(available.position.x, top), Vector2(available.size.x, available.end.y - top))
	_fit_modal(settings_panel, modal_area, logical_pixel)
	_fit_modal(failure_panel, modal_area, logical_pixel)
	_fit_modal(lesson_dialog, modal_area, logical_pixel)
	failure_panel.reset_feedback()
	_render()


## 设置靠左且至少可点 44 像素；标题优先屏幕居中，仅在碰到胶囊时收窄或下移。
func _fit_header(content: Rect2, menu: Rect2, logical_pixel: float) -> float:
	var height: float = MIN_TOUCH_SIZE * logical_pixel
	var gap: float = SECTION_GAP * logical_pixel
	var settings_rect := Rect2(content.position, Vector2.ONE * height)
	var obstacle: Rect2 = menu.grow(gap) if menu.has_area() else Rect2()
	if obstacle.has_area() and settings_rect.intersects(obstacle):
		settings_rect.position.y = obstacle.end.y
	_place_header_control(settings_button, settings_rect, height / 96.0)
	var title_width: float = height * 400.0 / 96.0
	var title_rect := Rect2(Vector2(content.get_center().x - title_width * 0.5, content.position.y), Vector2(title_width, height))
	var left: float = settings_rect.end.x + gap
	var right: float = content.end.x
	if obstacle.has_area() and title_rect.position.y < obstacle.end.y and title_rect.end.y > obstacle.position.y:
		if obstacle.get_center().x >= content.get_center().x:
			right = minf(right, obstacle.position.x)
		else:
			left = maxf(left, obstacle.end.x)
	if right - left >= 140.0 * logical_pixel:
		title_rect.size.x = minf(title_width, right - left)
		title_rect.position.x = clampf(content.get_center().x - title_rect.size.x * 0.5, left, right - title_rect.size.x)
	else:
		title_rect.position.y = maxf(settings_rect.end.y, obstacle.end.y) + gap
	_place_header_control($Stage/LevelPlate, title_rect, height / 96.0)
	_place_header_control($Stage/Title, title_rect, height / 96.0)
	return maxf(title_rect.end.y, settings_rect.end.y)


## 将标题行的逻辑像素矩形转换为舞台坐标，内部字体和图案继续等比显示。
func _place_header_control(control: Control, rect: Rect2, draw_scale: float) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.scale = Vector2.ONE * draw_scale / stage.scale.x
	control.size = rect.size / draw_scale
	control.position = (rect.position - stage.position) / stage.scale


## 底部临时选择和完成反馈共用已分配的操作区，按钮保留统一触控下限。
func _fit_footer_feedback(unit: float) -> void:
	top_choices.scale = Vector2.ONE * maxf(1.0, MIN_TOUCH_SIZE * unit / 155.0)
	top_choices.position = Vector2((stage.size.x - top_choices.size.x * top_choices.scale.x) * 0.5,
		stage.size.y - top_choices.size.y * top_choices.scale.y)
	completion_view.scale = Vector2.ONE * maxf(1.0, MIN_TOUCH_SIZE * unit / 140.0)
	completion_view.position = Vector2((stage.size.x - completion_view.size.x * completion_view.scale.x) * 0.5,
		stage.size.y - completion_view.size.y * completion_view.scale.y)
	$Stage/Toast.position.y = tools_view.position.y - 108.0


## 弹窗按安全区独立缩放，避免短屏棋盘收窄后连带缩小选关按钮；遮罩仍覆盖全屏。
func _fit_modal(panel: Control, available: Rect2, logical_pixel: float) -> void:
	var card: Control = panel.get_node("Card")
	var room: Vector2 = available.size - Vector2.ONE * 32.0 * logical_pixel
	if panel == failure_panel:
		# 失败提示保留棋盘背景，短屏同时限高；独立缩放不会缩小其他弹窗。
		room = room.min(available.size * Vector2(0.80, 0.58))
		room.x = minf(room.x, 360.0 * logical_pixel)
	var factor: float = minf(room.x / card.size.x, room.y / card.size.y)
	panel.position = -stage.position / stage.scale
	panel.scale = Vector2.ONE * factor / stage.scale
	panel.size = size / factor
	card.position = available.get_center() / factor - card.size * 0.5


## 失焦、暂停与离树中断展示，不回滚或重放已经提交的玩法事件。
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE]:
		_suspended = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_suspended = false
	if is_node_ready() and what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED, NOTIFICATION_EXIT_TREE]:
		# 激励视频可能使宿主失焦，此时保留请求；暂停或离树则撤销。
		if what != NOTIFICATION_APPLICATION_FOCUS_OUT:
			session.cancel_tool_reward()
		if progress != null:
			progress.save()
		_cancel_interaction()
	if is_node_ready() and what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_fit_stage.call_deferred()
	if is_node_ready() and what == NOTIFICATION_UNPAUSED:
		_sync_completion.call_deferred()


## 隐藏与恢复时统一清理临时输入并显示真实最终状态。
func _on_visibility_changed() -> void:
	if is_node_ready():
		if not is_visible_in_tree():
			session.cancel_tool_reward()
		_cancel_interaction()


## 返回键关闭面板或取消临时选择，空闲时交还宿主处理。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if lesson_dialog.visible:
			lesson_dialog._answer(false)
			get_viewport().set_input_as_handled()
			return
		elif failure_panel.visible:
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
	return is_visible_in_tree() and session.started and session.pending_reward.is_empty() and not event_player.refill_pending and not event_player.dispatch_pending and not settings_panel.visible and not failure_panel.visible and not lesson_dialog.visible and not session.is_won() and not session.failed and not _has_pending_lesson()


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
		_reset_idle()
		_drop_origin = origin
		move_requested.emit(source, target)
		_drop_origin = null
	elif not canceled:
		_invalid_attempts += 1
		if source >= 0 and session.slots[source].box != null and session.slots[source].box.kind == "in_only":
			_toast("这个纸托只进不出")


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
	_maybe_show_lesson()


## 可放入时直接搬运，异色且可拿取时改选新盒；受限目标不改变原选择。
func _on_box_pressed(index: int) -> void:
	if event_player.refill_pending or event_player.dispatch_pending or settings_panel.visible or failure_panel.visible or lesson_dialog.visible or session.is_won() or session.failed or _has_pending_lesson():
		return
	var slot: Dictionary = session.slots[index]
	if not slot.open:
		if slot.kind == "turnover":
			_offer_turnover(index)
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
			_reset_idle()
			var source_box: DonutBox = board.boxes[source]
			_drop_origin = board.origin(source) + source_box.food_stack.food_at(0).position * source_box.scale
			selected_box = -1
			move_requested.emit(source, index)
			_drop_origin = null
		elif session.can_pick_top(index) and slot.box.items[0].flavor != session.slots[source].box.items[0].flavor:
			selected_box = index
			_hide_toast()
			_render()
		else:
			_invalid_attempts += 1
			_toast("餐盒已满" if slot.box.items.size() == session.capacity(index) else "只能放入空盒或同口味餐盒")
		return
	if not slot.box.items.is_empty():
		if not session.can_pick_top(index):
			_toast("这个纸托只进不出")
			return
		selected_box = index
		_render()


## 撤回整次操作及其回收、补位、揭示和奖励，取消选择不消耗道具。
func _on_undo_pressed() -> void:
	if settings_panel.visible or failure_panel.visible or lesson_dialog.visible or session.is_won():
		return
	_cancel_interaction()
	if _claim_tool_if_needed("undo"):
		return
	if not session.can_undo():
		_toast("暂无可撤回操作" if int(session.tools.undo) > 0 else "撤回次数已用完")
		return
	undo_requested.emit()


## 在预设盒位中启用下一个周转盒，不动态增添棋盘位置。
func _on_add_box_pressed() -> void:
	if settings_panel.visible or failure_panel.visible or lesson_dialog.visible or session.is_won():
		return
	_cancel_interaction()
	if _claim_tool_if_needed("add_box"):
		return
	if session.next_turnover() < 0 or int(session.tools.add_box) <= 0 or session.is_won():
		_toast("没有可用的周转盒位" if session.next_turnover() < 0 else "加餐盒次数已用完")
		return
	add_box_requested.emit()


## 进入置顶模式，实际有效选择之前不扣道具。
func _on_top_pressed() -> void:
	if settings_panel.visible or failure_panel.visible or lesson_dialog.visible or session.is_won():
		return
	if _claim_tool_if_needed("top"):
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


## 首次点击只请求使用点，后续点击才进入原有执行流程。
func _claim_tool_if_needed(tool: String) -> bool:
	if not session.pending_reward.is_empty():
		return true
	if int(session.tools[tool]) > 0:
		return false
	_cancel_interaction()
	var token: String = session.request_tool_reward(tool)
	if token.is_empty():
		return true
	_render()
	var source: DonutSession = session
	var completed: Callable = func(rewarded: bool) -> void: source.resolve_tool_reward(token, rewarded)
	if tool_reward_provider.is_valid():
		tool_reward_provider.call(tool, completed)
	else:
		# 广告 SDK 接入前按当前产品约定直接发点，仍需再次点击使用。
		completed.call(true)
	return true


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
	if events.any(func(event: Dictionary) -> bool: return event.kind == "begin"):
		_reset_idle()
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
	else:
		_maybe_show_lesson()


## 更新真实状态的最终显示，取消动画时直接收敛到此状态。
func _render() -> void:
	if not board.boxes.is_empty():
		_render_state(session.snapshot())


## 呈现会话快照，具体盒位、订单和道具显示由各自视图负责。
func _render_state(state: Dictionary) -> void:
	$Stage/Title.text = "第 %d 关" % (session.level_index + 1)
	settings_panel.current_level = session.level_index
	if str(state.get("layout_id", "")).is_empty():
		board.configure_level(session.level_index, state.slots.size())
	else:
		board.configure_layout(state.layout_id)
	board.present(state, selected_box)
	if session.next_turnover() < 0 or session.is_won() or session.failed:
		$Stage/IdleHint.hide()
	orders.present(state.demands)
	tools_view.present(state.tools, state.tool_claimed, _top_mode, not session.pending_reward.is_empty())
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
	if failure_panel.visible or lesson_dialog.visible:
		return
	_cancel_interaction()
	settings_panel.show_level_selection()


## 齿轮打开设置模块的操作面板。
func _show_settings_menu() -> void:
	if failure_panel.visible or lesson_dialog.visible:
		return
	_cancel_interaction()
	settings_panel.show_settings()


## 设置面板切关前结束手势与动画，延后提交会话操作。
func _on_settings_level_selected(index: int) -> void:
	_cancel_interaction()
	_dialog_kind = "level"
	_dialog_value = index
	lesson_dialog.present("切换关卡", "切换会放弃当前局面和本次解锁的周转盒。确定进入第 %d 关？" % (index + 1), "进入", "继续本局", false)


## 设置面板重开前结束手势与动画，延后提交会话操作。
func _on_settings_restart_selected() -> void:
	_cancel_interaction()
	_dialog_kind = "restart"
	lesson_dialog.present("重开本关", "重开会恢复原始局面和计时，两只周转盒重新锁定。", "重新开始", "继续本局", false)


## 完成反馈计时只在当前可见、活跃且设置已关闭的页面中运行。
func _sync_completion() -> void:
	if not is_inside_tree() or not is_node_ready():
		return
	var can_advance: bool = completion_view.visible and session.is_won() and not _busy and not _continuing \
		and is_visible_in_tree() and not _suspended and not get_tree().paused and not settings_panel.visible \
		and not lesson_dialog.visible \
		and session.level_index + 1 < DonutLevel.catalog().size()
	if not can_advance:
		$AdvanceTimer.stop()
	elif $AdvanceTimer.is_stopped():
		$AdvanceTimer.start()


## 反馈结束后自动切关，末关由玩家点重玩，导航延后且去重。
func _on_continue_requested() -> void:
	if _continuing or not completion_view.visible or not session.is_won() or settings_panel.visible \
			or lesson_dialog.visible or not is_visible_in_tree() or _suspended or get_tree().paused:
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
	if settings_panel.visible or failure_panel.visible or lesson_dialog.visible:
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
	$Stage/IdleHint.hide()
	settings_panel.close()
	top_choices.clear()
	_render()
	_sync_failure.call_deferred()
	_maybe_show_lesson.call_deferred()


## 给出短暂操作反馈，不让提示覆盖底部道具命中区域。
func _toast(message: String) -> void:
	$Stage/Toast/Message.text = message
	$Stage/Toast.show()
	$ToastTimer.start()


## 清除到时或中断后的短提示。
func _hide_toast() -> void:
	$Stage/Toast.hide()


## 仅活跃游戏时间推进炸弹，搬运动画照常计时，系统收餐与入场暂停。
func _process(delta: float) -> void:
	if not is_node_ready() or session == null or not session.started or not is_visible_in_tree() or _suspended or get_tree().paused:
		return
	if settings_panel.visible or lesson_dialog.visible or failure_panel.visible or _has_pending_lesson():
		return
	if not event_player.clock_blocked:
		if session.advance_clock(delta):
			_clock_refresh += delta
		if session.failed:
			_cancel_interaction()
			_sync_failure()
		elif _clock_refresh >= 0.2 and not _busy and not board_input.is_active():
			_clock_refresh = 0.0
			_render()
	if not session.is_won() and not _busy:
		_idle_seconds += delta
		if not _idle_dismissed and (_idle_seconds >= idle_hint_seconds or _invalid_attempts >= idle_hint_invalid_attempts) and session.next_turnover() >= 0 and _reward_preview_available():
			_idle_dismissed = true
			var index: int = session.next_turnover()
			var anchor: Vector2 = board.origin(index) + board.boxes[index].size * board.boxes[index].scale * Vector2(0.5, 1.0)
			var hint_size: Vector2 = $Stage/IdleHint.size * $Stage/IdleHint.scale
			$Stage/IdleHint.position = Vector2(clampf(anchor.x - hint_size.x * 0.5, 24.0, 1000.0 - hint_size.x), anchor.y + 10.0)
			$Stage/IdleHint.show()


## 有效搬运才开始下一轮停滞观察，关闭提示不会原地反复弹出。
func _reset_idle() -> void:
	_idle_seconds = 0.0
	_invalid_attempts = 0
	_idle_dismissed = false
	$Stage/IdleHint.hide()


## 返回同局或跨关保留的教学记录，独立预览不触碰磁盘。
func _lesson_record() -> Dictionary:
	return progress.seen if progress != null else _seen_lessons


## 首次机制说明未结束前不允许用新手势跳过入场与教学。
func _has_pending_lesson() -> bool:
	if not lessons_enabled:
		return false
	for key: String in DonutLessons.available(session.snapshot()):
		if not _lesson_record().has(key):
			return true
	return false


## 稳定结算后一次呈现一项首次机制；提前跳关仍能获得实际机制说明。
func _maybe_show_lesson() -> void:
	if not lessons_enabled or not _dialog_kind.is_empty() or lesson_dialog.visible or settings_panel.visible or _busy or session.is_won() or session.failed:
		return
	for key: String in DonutLessons.available(session.snapshot()):
		if not _lesson_record().has(key):
			_show_lesson(key)
			return


## 用同一张可关闭卡片显示当前机制，图示取当前机制的实际资源。
func _show_lesson(key: String) -> void:
	_dialog_kind = "lesson"
	_dialog_value = key
	var text: Array = DonutLessons.TEXT[key]
	var message: String = str(text[1])
	if key == "in_only":
		var locations: PackedStringArray = []
		for index: int in session.slots.size():
			if session.slots[index].box != null and session.slots[index].box.kind == "in_only":
				var row: int = int(board.layout_slots[index].layer)
				var column: int = 1
				for prior: int in index:
					column += 1 if int(board.layout_slots[prior].layer) == row else 0
				locations.append("第%d排第%d个" % [row + 1, column])
		message = "、".join(locations) + "纸托只进不出。\n" + message
	lesson_dialog.present(str(text[0]), message)
	var picture: TextureRect = lesson_dialog.get_node("Card/Donut")
	picture.texture = DonutArt.FOOD[0]
	picture.position = Vector2(320, 188)
	picture.size = DonutArt.FOOD_SIZE
	if key == "lid":
		picture.texture = DonutMechanicArt.COVER
	elif key in ["frozen", "number_frozen"]:
		lesson_dialog.show_frozen_example(key == "number_frozen")
	elif key == "cycle":
		picture.texture = DonutMechanicArt.CYCLE
	elif key == "bomb":
		picture.texture = DonutMechanicArt.BOMB
	elif key == "hidden":
		picture.texture = DonutArt.HIDDEN


## 设置内可重新查看当前局使用的说明，不清空永久已读记录。
func _review_lessons() -> void:
	_review_keys = DonutLessons.available(session.snapshot())
	if not _review_keys.is_empty():
		_show_lesson(_review_keys.pop_front())


## 只有本地预览提供明确标注的模拟奖励，平台未绑定广告时不伪造成功。
func _reward_preview_available() -> bool:
	return not OS.has_feature("wechat") and not OS.has_feature("douyin")


## 点击锁定的固定ID盒位进入确认，奖励只能发给这只盒子。
func _offer_turnover(index: int) -> void:
	if not _reward_preview_available():
		_toast("广告暂不可用，请稍后再试")
		return
	_cancel_interaction()
	var token: String = session.request_turnover(index)
	if token.is_empty():
		return
	_dialog_kind = "reward"
	_dialog_value = token
	lesson_dialog.present("解锁周转盒", "完整观看后解锁所选空盒，仅限本次尝试。重开将重新锁定。\n当前为本地预览，可模拟奖励或取消。", "模拟观看完成", "取消", false)


## 确认、取消和重复回调都经过会话校验；重开不会继承旧奖励。
func _on_dialog_answer(accepted: bool) -> void:
	var kind: String = _dialog_kind
	var value: Variant = _dialog_value
	_dialog_kind = ""
	if kind == "lesson":
		_lesson_record()[str(value)] = true
		if progress != null:
			progress.save()
		if not _review_keys.is_empty():
			_show_lesson(_review_keys.pop_front())
		else:
			_maybe_show_lesson()
	elif kind == "reward":
		session.resolve_turnover(str(value), accepted)
	elif kind == "restart" and accepted:
		restart_requested.emit()
	elif kind == "level" and accepted:
		level_requested.emit(int(value))
	_sync_completion()
