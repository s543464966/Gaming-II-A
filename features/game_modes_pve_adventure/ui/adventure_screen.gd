extends Control
## 冒险流程的唯一表现协调器：路线、事件、部署、战斗、结果与战后构筑。

const UI = preload("res://ui/components/ui.gd")
const T = preload("res://features/mechanics/contracts/combat_types.gd")
const Text = preload("res://features/combat/ui/combat_text.gd")
const Generator = preload("res://features/game_modes_pve_adventure/domain/route_generator.gd")
const RouteView = preload("res://features/game_modes_pve_adventure/ui/route_view.gd")
const ROUTE_THEME = preload("res://ui/design_system/themes/adventure_route.tres")
const RewardPage = preload("res://features/game_modes_pve_adventure/ui/reward_page.tscn")
const EventPage = preload("res://features/game_modes_pve_adventure/ui/event_page.tscn")
const Request = preload("res://features/game_modes_pve_adventure/domain/battle_request.gd")
const DeploymentClock = preload("res://features/game_modes_pve_adventure/domain/deployment_timer.gd")
const Playback = preload("res://features/combat/ui/battle_playback.gd")
const BattleAudio = preload("res://features/combat/ui/battle_audio.gd")
const PausePanel = preload("res://features/game_modes_pve_adventure/ui/pause_panel.tscn")
signal navigation_requested(id: String)
var session: PlayerSessionState
var progression: AdventureProgression
var persist: Callable
var overlays: CanvasLayer
var platform: Node
var audio: AudioService

## 场景只接收本章状态与用例，不向全局查找应用或存储。
func configure(player: PlayerSessionState, flow: AdventureProgression, save: Callable, overlay: CanvasLayer, host: Node, sound: AudioService = null) -> void:
	session = player
	progression = flow
	persist = save
	overlays = overlay
	platform = host
	audio = sound

enum State { Route, Event, Deployment, Fighting, Result, Reward }
var state: int = State.Route
var timer: DeploymentTimer = DeploymentClock.new()
var playback: BattlePlayback = Playback.new()
var battle_audio: BattleAudioPresenter = BattleAudio.new()
var board: BattleBoard
var route_view: AdventureRouteView
var reward_page: AdventureRewardPage
var event_page: AdventureEventPage
var _content: VBoxContainer
var _header: Label
var _settings_button: Button
var _route_root: VBoxContainer
var _route_scroll: ScrollContainer
var _route_status: VBoxContainer
var _node_popup: Control
var _node_info: VBoxContainer
var _battle_root: VBoxContainer
var _start_error_label: Label
var _start_button: Button
var _countdown: TextureRect
var _judgment_hud: VBoxContainer
var _judgment_title: Label
var _judgment_health: Label
var _result_root: VBoxContainer
var _result_summary: Label
var _result_feedback: Label
var _result_button: Button
@onready var _relic_strip: AdventureRelicStrip = $SafeArea/Margin/Content/Battle/Relics
var _settings: AdventurePausePanel
var _card_popup: ContentPopup
var _pause_before: bool = false
var _enemies: Array = []
var _settled: bool = false
var _start_error: String = ""
var _result_error: String = ""
var _route_position_request: int = 0
var _last_judgment_second: int = -1
var _battle_background_material: ShaderMaterial

## 绑定场景中的稳定布局，运行脚本只负责状态投射与业务交互。
func _ready() -> void:
	_content = $SafeArea/Margin/Content
	_header = _content.get_node("Header/Title")
	_settings_button = _content.get_node("Header/Settings")
	_route_root = _content.get_node("Route")
	_route_status = _route_root.get_node("Status")
	_node_popup = $NodePopup
	_node_info = _node_popup.content
	_route_scroll = _route_root.get_node("Map/Scroll")
	_node_popup.bind_route(_route_scroll)
	route_view = _route_scroll.get_node("RouteView")
	route_view.bind_viewport(_route_scroll)
	_battle_root = _content.get_node("Battle")
	_start_error_label = _battle_root.get_node("StartError")
	_start_button = _battle_root.get_node("ActionSlot/Start")
	_countdown = _battle_root.get_node("ActionSlot/Countdown")
	_judgment_hud = _battle_root.get_node("ActionSlot/Judgment")
	_judgment_title = _judgment_hud.get_node("Title")
	_judgment_health = _judgment_hud.get_node("Health")
	board = _battle_root.get_node("Board")
	board.audio = audio
	battle_audio.configure(audio)
	board.get_node("Effects").board = board
	board.get_node("FeedbackEffects").board = board
	_battle_background_material = $BattleBackground.material
	_result_root = _content.get_node("Result")
	_result_summary = _result_root.get_node("Summary")
	_result_feedback = _result_root.get_node("Feedback")
	_result_button = _result_root.get_node("Confirm")
	$SafeArea.configure(platform)
	$RewardOverlay/SafeArea.configure(platform)
	$SafeArea/Margin.resized.connect(_layout_route_header)
	_layout_route_header()
	if session == null:
		_header.text = "ui.home.layout_preview"
		set_process(false)
		return
	# 奖励骨架与字体在章节入口准备，整章复用；尚未绑定会话，不会提前抽奖。
	reward_page = RewardPage.instantiate()
	reward_page.hide()
	$RewardOverlay/SafeArea/Margin/Content.add_child(reward_page)
	reward_page.finished.connect(_reward_finished)
	reward_page.settings_requested.connect(open_settings)
	reward_page.get_node("DiceTray").prepare_visuals.call_deferred(session.content.resource("dice.reward_surface"))
	event_page = EventPage.instantiate()
	event_page.hide()
	_content.add_child(event_page)
	event_page.finished.connect(_event_finished)
	event_page.settings_requested.connect(open_settings)
	_settings_button.pressed.connect(open_settings)
	_content.get_node("Header/Back").pressed.connect(request_navigation.bind("home"))
	session.changed.connect(_refresh_session_view)
	_result_button.pressed.connect(_result_action)
	_start_button.pressed.connect(_deployment_action)
	route_view.focused.connect(inspect_node)
	_node_popup.dismissed.connect(func(): route_view.select_node(-1))
	board.move_requested.connect(_move_card)
	board.swap_requested.connect(_swap_cards, CONNECT_DEFERRED)
	board.can_swap = progression.can_swap_cards
	board.card_clicked.connect(open_card_details)
	timer.completed.connect(_start_battle)
	playback.projectile_launched.connect(board.launch)
	playback.event_cued.connect(board.cue_event)
	playback.frame_played.connect(board.apply_frame)
	playback.frame_played.connect(_relic_strip.apply_frame)
	_relic_strip.inspected.connect(_inspect_relic)
	playback.cooldowns_sampled.connect(board.sample_cooldowns)
	playback.event_played.connect(_play_event)
	playback.completed.connect(_battle_completed)
	var chapter: Dictionary = session.content.get_record("chapters", session.selected_chapter)
	$Background.texture = session.content.resource(chapter.unlocked_background_key)
	UI.bind_text(_header, func(): return ContentText.field(chapter))
	UI.bind_text(_content.get_node("Header/Progress"), _route_progress_text)
	UI.bind_text(_start_error_label, _deployment_error_text)
	UI.bind_text(_start_button, _start_button_text)
	UI.bind_text(_result_summary, _result_text)
	UI.bind_text(_result_feedback, _result_feedback_text)
	UI.bind_text(_judgment_title, _judgment_title_text)
	UI.bind_text(_judgment_health, _judgment_health_text)
	var error: String = progression.ensure_started(int(Time.get_unix_time_from_system()))
	if not error.is_empty():
		_show_route()
		_route_status.show()
		_route_status.add_child(UI.label(error))
		_route_status.add_child(UI.button("ui.adventure.return_home", request_navigation.bind("home")))
		return
	if session.build.pending_reward: _show_reward()
	elif progression.has_active_event(): _show_event()
	elif session.current_route().completed:
		_show_route()
		_route_status.show()
		_route_status.add_child(UI.label("ui.adventure.chapter_completed"))
		_route_status.add_child(UI.button("ui.adventure.return_home", request_navigation.bind("home")))
	else: _show_route()

## 准备计时与战报共用正常游戏时间；设置暂停由场景树统一冻结。
func _process(delta: float) -> void:
	if state == State.Deployment:
		var blocked = not board.conflicts().is_empty()
		if not blocked: progression.prepare_battle()
		timer.tick(delta, blocked, _can_start)
		if state == State.Deployment:
			_refresh_deployment()
	elif state == State.Fighting:
		if playback.result.is_empty():
			if not progression.advance_battle() or not _begin_playback(): return
		playback.tick(delta)
		board.advance(playback.presentation_time)
		_battle_background_material.set_shader_parameter("battle_time", playback.presentation_time)
		_refresh_judgment()

## 最后十秒复用准备按钮所在空间，不挤压棋盘或增加独立时钟。
func _refresh_judgment() -> void:
	_judgment_hud.visible = state == State.Fighting and not playback.judgment_status().is_empty()
	if not _judgment_hud.visible: return
	var remaining := int(playback.judgment_status().get("remaining", -1))
	if remaining != _last_judgment_second:
		_last_judgment_second = remaining
		if audio != null and remaining >= 0 and remaining <= 5: audio.play_sfx("sfx.combat.time_warning", -3.0)
	_judgment_title.text = _judgment_title_text()
	_judgment_health.text = _judgment_health_text()

## 切换语言只重译当前倒计时，不能重新开始决胜阶段。
func _judgment_title_text() -> String:
	var status: Dictionary = playback.judgment_status()
	return ContentText.format_key("ui.adventure.judgment_countdown", {"seconds": status.remaining}) if not status.is_empty() else ""

## 双方百分比来自内核帧，死亡单位的权重仍由内核保留。
func _judgment_health_text() -> String:
	var status: Dictionary = playback.judgment_status()
	if status.is_empty(): return ""
	var ratios: Dictionary = {}
	for entry: Dictionary in status.standings: ratios[entry.team_id] = "%.1f%%" % (entry.ratio * 100.0)
	return ContentText.format_key("ui.adventure.judgment_health", {"ally": ratios.get(0, "0%"), "enemy": ratios.get(1, "0%")})

## 只展示实际启动异常，正常准备不插入说明段落。
func _deployment_error_text() -> String:
	if not _start_error.is_empty(): return tr("ui.adventure.start_failed") + "\n" + tr("ui.adventure.rollback_failed")
	return ""

## 动作文字独立于菱形倒计时，切语言只重译动作而不改变时钟。
func _start_button_text() -> String:
	if not _start_error.is_empty(): return tr("ui.adventure.retry_rollback")
	return tr("ui.adventure.start")

## 部署动作复用同一按钮；启动回退失败时只允许重试回退，不再开战或移动。
func _refresh_deployment() -> void:
	_start_error_label.text = _deployment_error_text()
	_start_error_label.visible = not _start_error.is_empty()
	_start_button.text = _start_button_text()
	_countdown.visible = _start_error.is_empty()
	_countdown.get_node("Value").text = str(ceili(timer.remaining))
	_start_button.disabled = _start_error.is_empty() and not board.conflicts().is_empty()
	if board.interactive != _start_error.is_empty(): board.set_interactive(_start_error.is_empty())

## 按当前部署状态执行唯一主动作，暂停和离开部署后拒绝迟到点击。
func _deployment_action() -> void:
	if state != State.Deployment or get_tree().paused: return
	if _start_error.is_empty(): _start_battle()
	else: _retry_start_rollback()

## 后台恢复时不得把尚未松手的拖拽当作一次合法落位。
func suspend_presentation() -> void:
	if is_instance_valid(board): board.cancel_drag()
	if is_instance_valid(_node_popup): _node_popup.close()

## 所有路线入口共用一次重建与定位；临时查看节点不触发重置。
func _show_route() -> void:
	timer.cancel()
	playback.reset()
	battle_audio.reset()
	board.clear_effects()
	_node_popup.close()
	UI.clear(_node_info)
	UI.clear(_route_status)
	_route_status.hide()
	route_view.configure(session.current_route(), session.content)
	_set_state(State.Route)
	_queue_route_position()

## 等容器和安全区完成布局后，只执行最后一次路线入口的定位请求。
func _queue_route_position() -> void:
	_route_position_request += 1
	_position_route(_route_position_request)

## 当前锚点位于视口下部，向上保留更多空间展示下一层候选。
func _position_route(request: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if request != _route_position_request or not is_inside_tree() or is_queued_for_deletion() or session == null or state != State.Route or _node_popup.visible: return
	route_view.position_progress_anchor()

## 顶栏沿用 Home 的设计比例与安全区起点，章节内容在其下方自然延续。
func _layout_route_header() -> void:
	var bounds: Vector2 = $SafeArea/Margin.size
	var ratio: float = minf(bounds.x / 941.0, bounds.y / 1672.0)
	var profile: Control = _content.get_node("RouteProfile")
	var header: Control = profile.get_node("PlayerHeader")
	header.scale = Vector2.ONE * ratio
	header.position = Vector2((bounds.x - 941.0 * ratio) * 0.5 - 24.0, -24.0)
	profile.custom_minimum_size.y = maxf(0.0, 185.0 * ratio - 24.0)

## 领奖立即更新遗物栏；开战提交不提前展示尚未回放的消耗。
func _refresh_session_view() -> void:
	_refresh_route_header()
	if state == State.Reward: _relic_strip.configure(session.content, session.build.relics)
	elif state == State.Event and is_instance_valid(event_page): event_page.refresh()

## 顶栏读取已提交账号值；路线内交易和奖励返回时保持同步。
func _refresh_route_header() -> void:
	if session == null or not is_node_ready(): return
	_content.get_node("RouteProfile/PlayerHeader").present(session.user.name, session.assets.gold, session.assets.star_stone, session.user.stamina, session.user.STAMINA_MAX)
	_content.get_node("Header/Progress").text = _route_progress_text()

## 总层数由当前章节实际路线派生，不把效果图里的十八层写死。
func _route_progress_text() -> String:
	if session == null or session.current_route().nodes.is_empty(): return ""
	var route: RouteState = session.current_route()
	var floor: int = 1 if route.current < 0 else route.nodes[route.current].layer + 1
	return ContentText.format_key("ui.route.progress", {"floor": floor, "total": route.nodes.back().layer + 1})

## 所有节点均可查询，但主动作绑定节点与当前阶段并再次校验。
func inspect_node(index: int) -> void:
	if state != State.Route: return
	UI.clear(_node_info)
	if index < 0:
		_node_popup.close()
		return
	var route: RouteState = session.current_route()
	if index >= route.nodes.size() or route.nodes[index] == null: return
	if audio != null: audio.play_ui_cue("sfx.adventure.route_select", -5.0)
	var node: Dictionary = route.nodes[index]
	var is_battle = Generator.is_battle(node.type)
	var rule: Dictionary = session.content.node_definition(node)
	var known: bool = node.unlocked or node.completed or index in route.candidates()
	_node_popup.present(route_view.node_control(index))
	_node_info.add_child(UI.bound_label(func(): return ContentText.format_key("ui.adventure.node_title", {"floor": node.layer + 1, "type": tr("ui.route.unknown") if not known else ContentText.field(rule, "title") if not is_battle and not rule.is_empty() else tr(RouteView.TITLES[node.type])}), 28))
	if not known:
		_node_info.add_child(UI.label("ui.route.unknown"))
		var unavailable = UI.button("ui.adventure.node_unavailable")
		unavailable.disabled = true
		_node_info.add_child(unavailable)
		return
	if is_battle:
		_node_info.add_child(UI.bound_label(func(): return ContentText.format_key("ui.adventure.enemies", {"names": ", ".join(node.monsters.map(func(id): return ContentText.field(session.content.get_record("cards", id)))), "stamina": node.stamina, "dice": node.reward_dice}), 20))
	else: _node_info.add_child(UI.bound_label(func(): return RuleText.node_rule(rule), 20))
	var allowed = index in route.candidates()
	var button = UI.button("ui.adventure.enter_battle" if is_battle else rule.get("action_label_key", "ui.adventure.node_unavailable"), enter_node.bind(index))
	button.disabled = not allowed or (not is_battle and rule.is_empty())
	_node_info.add_child(button)
	if not allowed: _node_info.add_child(UI.label("ui.adventure.node_completed" if node.completed else "ui.adventure.node_unavailable", 20))

## 战斗入口先校验资源和固定阵型，正式扣体力成功后才开始部署。
func enter_node(index: int) -> void:
	if state != State.Route: return
	var route: RouteState = session.current_route()
	if not index in route.candidates(): return
	var node: Dictionary = route.nodes[index]
	if not Generator.is_battle(node.type):
		var error: String = progression.execute_node(index)
		if error.is_empty():
			if session.build.pending_reward: _show_reward()
			elif progression.has_active_event(): _show_event()
			else: _show_route()
		else: overlays.toast(error)
		return
	_enemies = Request.enemies_for(node)
	var error: String = progression.begin_battle(index, int(Time.get_unix_time_from_system()))
	if not error.is_empty():
		overlays.toast(error)
		return
	_refresh_board()
	_settled = false
	_start_error = ""
	_set_state(State.Deployment)
	timer.begin()
	_refresh_deployment()

## 刷新部署卡面时重新生成实际战斗定义；冲突仍留给部署门禁。
func _refresh_board() -> void:
	var player: PlayerSessionState = session
	var values: Array = []
	for card in player.build.cards:
		var definition: Dictionary = player.adventure.player_definition(player.build, card, 0, AdventureBattleRules.assembly_options(player.build.core().id))
		values.append(BattleAssembly.snapshot(card.id, definition, card.position, card.health))
	for enemy in _enemies:
		values.append(BattleAssembly.snapshot(enemy.id, player.adventure.enemy_definition(enemy.card_id, player.content.get_record("chapters", player.selected_chapter), enemy.get("layer_index", -1), enemy.get("encounter_type", ContentTypes.NodeType.NormalBattle)), enemy.position))
	var assembled: Dictionary = player.adventure.assemble_player(player.build, 0, AdventureBattleRules.assembly_options(player.build.core().id))
	_relic_strip.configure(session.content, player.build.relics)
	board.configure(session.content, values, {"ability_hosts": assembled.get("ability_hosts", []), "resources": {"pollution": {"scope": "battle", "values": {"battle": player.build.pollution}}}})
	if board.selected.is_empty(): board.select_card(player.build.core().id)

## 等当前触摸派发结束后再交换和重建卡面，避免移除仍持有输入焦点的卡牌。
func _swap_cards(first_id: String, second_id: String) -> void:
	if state != State.Deployment or not _start_error.is_empty() or get_tree().paused: return
	var error: String = progression.swap_cards(first_id, second_id)
	if audio != null: audio.play_ui_cue("sfx.adventure.card_swap" if error.is_empty() else "sfx.ui.error", -3.0)
	_refresh_board()
	_refresh_deployment()
	if not error.is_empty(): overlays.toast(error)

## 仅部署阶段接受站位事务；失败重新投射已恢复位置。
func _move_card(id: String, position: int) -> void:
	if state != State.Deployment or not _start_error.is_empty(): return
	var error: String = progression.place_card(id, position)
	if audio != null: audio.play_ui_cue("sfx.adventure.card_place" if error.is_empty() else "sfx.ui.error", -3.0)
	_refresh_board()
	_refresh_deployment()
	if not error.is_empty(): overlays.toast(error)

## 开战前取消视觉拖拽，再按已提交占位校验全棋盘。
func _can_start() -> bool:
	board.cancel_drag()
	return board.conflicts().is_empty()

## 手动开始与倒计时共用入口，停止准备后仅启动一次，系统失败仍走原回退。
func _start_battle() -> void:
	if state != State.Deployment or get_tree().paused or not _start_error.is_empty(): return
	if not _can_start(): return
	timer.cancel()
	var error: String = progression.start_battle()
	if not error.is_empty():
		_start_error = error
		push_warning(error)
		_retry_start_rollback()
		return
	_set_state(State.Fighting)
	if not progression.battle_result.is_empty(): _begin_playback()

## 完整战报就绪便交给原回放器，不额外等待下一帧才绑定冷却状态。
func _begin_playback() -> bool:
	var error: String = playback.start(progression.battle_result)
	if error.is_empty(): return true
	push_error(error)
	request_navigation("home")
	return false

## 回退未落盘时保留已支付状态，提供明确重试且不重复返还体力。
func _retry_start_rollback() -> void:
	var error: String = progression.reject_battle_start()
	if error.is_empty():
		_show_route()
		overlays.toast(Callable(get_script(), "_start_failure_text"))
	else:
		_refresh_deployment()

## 语义事件按回放命中时刻驱动棋盘飘字，不追加文字日志。
func _play_event(event: Dictionary) -> void:
	battle_audio.play_event(event)
	board.clock_time = playback.presentation_time
	board.play_event(event, event.time + playback.impact_delay)

## 轻提示可能跨页面存活，翻译回调只依赖脚本资源，避免引用已释放的冒险实例。
static func _start_failure_text() -> String:
	return ContentText.text("ui.adventure.start_failed") + "\n" + ContentText.text("ui.adventure.rolled_back")

## 最后一次命中结束后提交胜负，胜利保存成功便直接展示骰子和结果。
func _battle_completed(result: Dictionary) -> void:
	if state != State.Fighting: return
	battle_audio.play_completion(result)
	_set_state(State.Result)
	board.clear_effects()
	_result_summary.text = _result_text()
	if _persist_result() and result.reason == T.Completion.Victory:
		_show_reward(float(playback.result.duration))

## 结果文字从完成原因与真实数值派生，不调用结算或修改奖励。
func _result_text() -> String:
	if playback.result.is_empty(): return ""
	var result: Dictionary = playback.result
	return ContentText.format_key("ui.adventure.result", {"title": tr("ui.adventure.victory" if result.reason == T.Completion.Victory else "ui.adventure.defeat"),
		"explanation": Text.completion(result.reason, result.duration, result.get("judgment", {})), "seconds": "%.1f" % result.duration, "pollution": result.pollution})

## 保存状态保持当前语言，切语言不会重试写盘。
func _result_feedback_text() -> String:
	return tr("ui.adventure.saved") if _settled else ContentText.text(_result_error)

## 已成功提交的战报不再重复奖励或推进路线。
func _persist_result() -> bool:
	if _settled: return true
	var error: String = progression.resolve_battle()
	_settled = error.is_empty()
	_result_error = error
	_result_button.text = "ui.adventure.confirm_defeat" if _settled else "ui.adventure.retry_save"
	_result_feedback.text = _result_feedback_text()
	return _settled

## 保存失败只重试同一结算，成功后进入奖励或确认退出失败结果。
func _result_action() -> void:
	if state != State.Result or not _persist_result(): return
	if playback.result.reason == T.Completion.Victory: _show_reward(float(playback.result.duration))
	else: navigation_requested.emit("home")

## 新胜利附带本场结果；重进及非战斗奖励只恢复已保存候选。
func _show_reward(victory_seconds: float = -1.0) -> void:
	reward_page.configure(session, progression, victory_seconds, audio)
	board.clear_effects()
	_set_state(State.Reward)

## 黑市与奇遇共享事件页，页面只读取进入节点时已经保存的随机结果。
func _show_event() -> void:
	event_page.configure(session, progression, audio)
	board.clear_effects()
	_set_state(State.Event)

## 事件完成后按实际结果进入额外骰奖励或返回路线。
func _event_finished() -> void:
	if state != State.Event: return
	if session.build.pending_reward: _show_reward()
	elif session.current_route().completed: navigation_requested.emit("home")
	else: _show_route()

## 奖励页整章只连接一次，保存完成后进入下一段路线或返回首页。
func _reward_finished() -> void:
	if state != State.Reward: return
	if session.current_route().completed: navigation_requested.emit("home")
	else: _show_route()

## 单一状态决定全部可交互区域，结果保留最后战斗帧。
func _set_state(value: int) -> void:
	if value != State.Route: _node_popup.close()
	state = value
	_last_judgment_second = -1
	if value != State.Fighting: _relic_strip.configure(session.content, session.build.relics)
	if value == State.Route: _refresh_route_header()
	$EventBackground.visible = value == State.Event
	if value == State.Event:
		$EventBackground.texture = preload("res://features/game_modes_pve_adventure/ui/art/black_market_background.png") if session.build.events.node_type == ContentTypes.NodeType.BlackMarket else preload("res://features/game_modes_pve_adventure/ui/art/encounter_background.png")
	$RewardOverlay/RuinsBackground.visible = value == State.Reward and progression.is_aurora_node()
	$RewardOverlay/Shade.visible = not $RewardOverlay/RuinsBackground.visible
	$RewardOverlay/SafeArea/Margin.add_theme_constant_override("margin_top", 24 if $RewardOverlay/RuinsBackground.visible else 48)
	$RouteBackground.visible = value == State.Route
	var showing_battle: bool = value in [State.Deployment, State.Fighting, State.Result] or (value == State.Reward and not progression.is_aurora_node() and not board.snapshots.is_empty())
	$BattleBackground.visible = showing_battle
	$Background.visible = value not in [State.Route, State.Event] and not showing_battle
	_content.get_node("RouteProfile").visible = value == State.Route
	_content.get_node("Header/Back").visible = value == State.Route
	_content.get_node("Header").visible = value != State.Event
	_content.get_node("Header").theme = ROUTE_THEME if value == State.Route else null
	_settings_button.theme = ROUTE_THEME
	_header.visible = value == State.Route
	_content.get_node("Header/Progress").visible = value == State.Route
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if value == State.Route else HORIZONTAL_ALIGNMENT_LEFT
	$SafeArea/Margin.add_theme_constant_override("margin_bottom", 0 if value == State.Route else 24)
	_route_root.visible = value == State.Route
	_battle_root.visible = showing_battle
	if is_instance_valid(event_page): event_page.visible = value == State.Event
	$RewardOverlay.visible = value == State.Reward
	_result_root.visible = value == State.Result
	# 结算保留顶部占位，避免遮罩下的最后战斗帧重新排版。
	_settings_button.visible = value in [State.Deployment, State.Fighting] or (value == State.Reward and showing_battle)
	_settings_button.self_modulate.a = 0.0 if value == State.Reward else 1.0
	_start_error_label.visible = value == State.Deployment and not _start_error.is_empty()
	_start_button.visible = value == State.Deployment
	_countdown.visible = value == State.Deployment and _start_error.is_empty()
	_refresh_judgment()
	if is_instance_valid(reward_page): reward_page.visible = value == State.Reward
	board.set_interactive(value == State.Deployment)
	board.set_cooldown_enabled(value == State.Fighting)
	_refresh_music()

## 当前章节显式提供路线与战斗音乐键，页面阶段只选择对应表现。
func _refresh_music() -> void:
	if audio == null or session == null: return
	var chapter: Dictionary = session.content.get_record("chapters", session.selected_chapter)
	var route_phase: bool = state in [State.Route, State.Event] or (state == State.Reward and progression.is_aurora_node())
	var key := str(chapter.get("route_music_key" if route_phase else "battle_music_key", ""))
	if key.is_empty(): audio.stop_music()
	else: audio.play_music(key)

## 设置自身保持输入，游戏树暂停会冻结部署、弹道、状态帧和反馈。
func open_settings() -> void:
	_create_pause_panel("ui.adventure.paused")

## 详情仅允许准备阶段查询当前棋盘卡牌，开战后的迟到请求不得暂停回放。
func open_card_details(id: String) -> void:
	if state != State.Deployment or not _start_error.is_empty() or session == null: return
	if not board.cards.has(id) or is_instance_valid(_settings) or is_instance_valid(_card_popup): return
	_node_popup.close()
	board.cancel_drag()
	_pause_before = get_tree().paused
	get_tree().paused = true
	_card_popup = overlays.open_content(_card_presentation.bind(id))
	_card_popup.closed.connect(_card_detail_closed)

## 只读已装配快照及零时刻帧，不在详情中构造或推进战斗。
func _card_presentation(id: String) -> Dictionary:
	if state != State.Deployment or not board.cards.has(id): return {}
	var snapshot: Dictionary = board.cards[id].snapshot
	var row: Dictionary = session.content.get_record("cards", snapshot.definition.id)
	return {"entry": ContentPreview.entry(session.content, "cards", row), "detail": Text.battle_detail(snapshot.definition, board.cards[id].frame)}

## 无论关闭按钮、遮罩或导航销毁，详情退出都恢复原准备时钟。
func _card_detail_closed() -> void:
	_card_popup = null
	get_tree().paused = _pause_before

## 设置拥有独立操作面板，不能叠在卡牌详情上改变暂停所有权。
func _create_pause_panel(title: String) -> AdventurePausePanel:
	var event_settings: bool = state == State.Event or (state == State.Reward and progression.is_aurora_node())
	if (not event_settings and not state in [State.Route, State.Deployment, State.Fighting]) or is_instance_valid(_settings) or is_instance_valid(_card_popup): return null
	_node_popup.close()
	board.cancel_drag()
	_pause_before = get_tree().paused
	get_tree().paused = true
	_settings = PausePanel.instantiate()
	_settings.audio = audio
	add_child(_settings)
	_settings.configure(title, platform, audio, not event_settings)
	_settings.show_relics(session.content, _relic_strip.records if state == State.Fighting else session.build.relics)
	_settings.continued.connect(close_settings)
	_settings.reload_requested.connect(request_navigation.bind("adventure"))
	_settings.exit_requested.connect(request_navigation.bind("home"))
	if audio != null: audio.play_ui_cue("sfx.ui.open", -6.0)
	return _settings

## 关闭设置恢复之前的暂停状态，不强制修改全局时间倍率。
func close_settings() -> void:
	if not is_instance_valid(_settings): return
	if audio != null: audio.play_ui_cue("sfx.ui.close", -6.0)
	UI.dismiss(_settings)
	_settings = null
	get_tree().paused = _pause_before

## 导航前先保存或原子放弃当前战斗，失败保留原页面和暂停状态。
func request_navigation(destination: String) -> void:
	if not state in [State.Route, State.Deployment, State.Fighting]: return
	var error: String = ""
	if state in [State.Deployment, State.Fighting]: error = progression.abandon()
	elif not persist.call(): error = "ui.save.failed"
	if not error.is_empty():
		overlays.toast(error)
		return
	close_settings()
	timer.cancel()
	playback.reset()
	board.clear_effects()
	navigation_requested.emit(destination)

## 场景销毁切断单场时钟，不能留下一次迟到结算。
func _exit_tree() -> void:
	if is_instance_valid(_card_popup): overlays.close_modal()
	timer.cancel()
	playback.reset()
	battle_audio.reset()
	if progression != null: progression.interrupt_battle()
	if is_instance_valid(board): board.clear_effects()
	if is_instance_valid(_settings): get_tree().paused = _pause_before

## 遗物详情使用当前静态定义；沿用页面暂停与关闭所有权。
func _inspect_relic(id: String) -> void:
	if state not in [State.Deployment, State.Fighting] or is_instance_valid(_settings) or is_instance_valid(_card_popup): return
	board.cancel_drag()
	_pause_before = get_tree().paused
	get_tree().paused = true
	_card_popup = overlays.open_content(func():
		var entry: Dictionary = ContentPreview.entry(session.content, "relics", session.content.get_record("relics", id))
		return {"entry": entry, "detail": ContentPreview.describe(session.content, entry)})
	_card_popup.closed.connect(_card_detail_closed)
