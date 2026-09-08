extends Control
## 模式选择以画框巡游浏览章节，确认成功后才把同一背景交还 Home。

signal chapter_confirmed
signal return_requested
signal transition_started(expanded: bool, duration: float)
signal transition_finished(expanded: bool)
signal browse_finished
const UI = preload("res://ui/components/ui.gd")
const TRANSITION_SECONDS = 0.42
const BROWSE_SECONDS = 0.38
const CAROUSEL_STEP = 727.5
const NEIGHBOR_SCALE = 0.88
const DESIGN_SIZE = Vector2(941, 1672)
const FRAME_RECT = Rect2(107, 196, 725, 1044)
const ATLAS = preload("res://features/game_modes/ui/art/mode_atlas.png")
const CORNER_CLIP = preload("res://features/game_modes/ui/art/cut_corner.gdshader")
var session: RefCounted
var progression: RefCounted
var overlays: CanvasLayer
var _viewed: int = 0
var _transition: Tween
var _browse_motion: Tween
var _transitioning: bool = false
var _browsing: bool = false
var _queued_viewed: int = -1
var _pending_return: bool = false
var _expansion: float = 0.0
var _browse_progress: float = 1.0
var _browse_direction: float = 1.0
var _tab_motion: Tween
var _return_button: Button
var _background: Control
@onready var tabs: StandardTabGroup = $Tabs

## 页面只接收当前会话与章节用例，不拥有进入后的玩法状态。
func bind_player(player: RefCounted, flow: RefCounted, overlay: CanvasLayer) -> void:
	session = player
	progression = flow
	overlays = overlay

## 保留宿主的统一关闭组件，只替换模式页内的返回材质和位置。
func bind_return_button(button: Button) -> void:
	_return_button = button
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for event: Signal in [button.button_down, button.button_up, button.mouse_entered, button.mouse_exited, button.focus_entered, button.focus_exited]:
		event.connect(_refresh_return_tint)

## 模式过渡只改变框架背景的透明度，铺屏与安全区仍由统一页面结构维护。
func bind_background(background: Control) -> void:
	_background = background

## 返回热区与装饰分开布局，原生焦点和按压仍使用共享明度令牌反馈。
func _refresh_return_tint() -> void:
	if not is_node_ready() or not is_instance_valid(_return_button): return
	var brightness: float = UI.tokens.entry_normal_brightness
	if _return_button.is_pressed(): brightness = UI.tokens.entry_pressed_brightness
	elif _return_button.is_hovered() or _return_button.has_focus(): brightness = UI.tokens.entry_hover_brightness
	$ReturnArt.self_modulate = Color(brightness, brightness, brightness)

## 原生页签继续统一管理选择，独立场景预览不补造玩家。
func _ready() -> void:
	tabs.configure([{"id": "PveAdventure", "label": "ui.mode.adventure"}, {"id": "Pvp", "label": "ui.mode.pvp"},
		{"id": "PvpChess", "label": "ui.mode.chess"}, {"id": "PveChallenge", "label": "ui.mode.challenge"}])
	tabs.selected.connect(_select)
	$Chapter/Chrome/Previous.pressed.connect(_browse.bind(-1))
	$Chapter/Chrome/Next.pressed.connect(_browse.bind(1))
	$Chapter/Chrome/Confirm.pressed.connect(_confirm)
	resized.connect(_layout_art)
	_layout_art()
	_reset_art_layers()
	if session == null:
		$Chapter/Chrome/Confirm.disabled = true
		return
	_reset_viewed_chapter()
	_select(tabs.selected_id, false)

## 每次进入都重新定位账号已确认章节，未提交浏览不跨页面保留。
func refresh() -> void:
	cancel_transition()
	_reset_viewed_chapter()
	_select(tabs.selected_id, false)
	_play_transition.call_deferred(false)

## 章节定位只读取唯一账号状态，不触发选择用例或写入存档。
func _reset_viewed_chapter() -> void:
	_viewed = 0
	if session == null: return
	var chapters: Array = session.normal_chapters()
	for index in range(chapters.size()):
		if chapters[index].id == session.selected_chapter:
			_viewed = index
			return

## 快速连点只保留最终目标，当前画框完成横移后再衔接下一张。
func _browse(direction: int) -> void:
	if _transitioning or session == null: return
	var target: int = clampi((_queued_viewed if _queued_viewed >= 0 else _viewed) + direction, 0, session.normal_chapters().size() - 1)
	if _browsing:
		_queued_viewed = target
		return
	if target == _viewed: return
	var previous_chapter: Dictionary = session.normal_chapters()[_viewed]
	_browse_direction = signi(target - _viewed)
	_viewed = target
	_browsing = true
	_render_chapter()
	var outgoing: Control = $Chapter/Neighbors/Previous if _browse_direction > 0 else $Chapter/Neighbors/Next
	_present_card(outgoing, previous_chapter)
	$Chapter.clip_contents = true
	$Chapter/Neighbors.clip_contents = false
	_set_browse_progress(0.0)
	_browse_motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_browse_motion.tween_method(_set_browse_progress, 0.0, 1.0, BROWSE_SECONDS)
	_browse_motion.tween_callback(_finish_browse)

## 三张卡片沿同一水平中心线横移并缩放，章名与状态牌跟随所属画框。
func _set_browse_progress(value: float) -> void:
	_browse_progress = value
	for entry: Array in [[$Chapter/ArtStage, 0], [$Chapter/Neighbors/Previous, -1], [$Chapter/Neighbors/Next, 1]]:
		var card: Control = entry[0]
		var slot: int = entry[1]
		var start: Rect2 = _slot_rect(slot + int(_browse_direction))
		var finish: Rect2 = _slot_rect(slot)
		card.position = start.position.lerp(finish.position, value)
		card.scale = start.size.lerp(finish.size, value) / FRAME_RECT.size
		var brightness: float = lerpf(1.0 if slot + int(_browse_direction) == 0 else 0.62, 1.0 if slot == 0 else 0.62, value)
		card.modulate = Color(brightness, brightness, brightness)
		card.set_focus_weight(lerpf(1.0 if slot + int(_browse_direction) == 0 else 0.0, 1.0 if slot == 0 else 0.0, value))

## 由槽位中心计算尺寸和位置，邻章缩小后仍与主框严格居中。
func _slot_rect(slot: int) -> Rect2:
	var extent: Vector2 = FRAME_RECT.size * (1.0 if slot == 0 else NEIGHBOR_SCALE)
	var center: Vector2 = FRAME_RECT.get_center() + Vector2(slot * CAROUSEL_STEP, 0)
	return Rect2(center - extent * 0.5, extent)

## 一轮浏览结束后恢复确认状态，待处理返回优先于后续浏览。
func _finish_browse() -> void:
	_browse_motion = null
	_browsing = false
	_reset_art_layers()
	_render_chapter()
	if _pending_return:
		_pending_return = false
		_queued_viewed = -1
		request_return()
		browse_finished.emit()
		return
	var target: int = _queued_viewed
	_queued_viewed = -1
	if target >= 0 and target != _viewed:
		_browse(target - _viewed)
	else: browse_finished.emit()

## 章节确认经过原用例和保存；未解锁或动画中的章节不可提交。
func _confirm() -> void:
	if _transitioning or _browsing or session == null: return
	var chapters: Array = session.normal_chapters()
	if tabs.selected_id != "PveAdventure" or chapters.is_empty(): return
	if not chapters[_viewed].id in session.unlocked: return
	var error: String = progression.select_chapter(chapters[_viewed].id)
	if error.is_empty(): _play_transition(true, func(): chapter_confirmed.emit())
	else: overlays.toast(error)

## 返回会等待正在滑动的画框落位，再平滑还原已确认章节。
func request_return() -> void:
	if _transitioning: return
	if _browsing:
		_pending_return = true
		return
	_play_transition(true, func(): return_requested.emit())

## 清理旧图的临时位移，防止连续浏览或强制关闭留下透明缝隙。
func _reset_art_layers() -> void:
	$Chapter.clip_contents = false
	$Chapter/Neighbors.clip_contents = true
	$Chapter/Neighbors.position = Vector2.ZERO
	$Chapter/ArtStage.modulate = Color.WHITE
	$Chapter/ArtStage.scale = Vector2.ONE
	$Chapter/ArtStage.set_focus_weight(1.0)
	for entry: Array in [[$Chapter/Neighbors/Previous, -1], [$Chapter/Neighbors/Next, 1]]:
		var neighbor: Control = entry[0]
		neighbor.position = _slot_rect(entry[1]).position
		neighbor.scale = Vector2.ONE * NEIGHBOR_SCALE
		neighbor.modulate = Color(0.62, 0.62, 0.62)
		neighbor.set_focus_weight(0.0)
	_set_expansion(_expansion)
	for art: TextureRect in [$Chapter/ArtStage/Art, $Chapter/ArtStage/PreviousArt]:
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.modulate.a = 1
	$Chapter/ArtStage/PreviousArt.hide()

## 宿主强制关闭缓存页时清理全部局部动画和排队输入。
func cancel_transition() -> void:
	if _transition != null and _transition.is_valid(): _transition.kill()
	if _tab_motion != null and _tab_motion.is_valid(): _tab_motion.kill()
	_tab_motion = null
	_transition = null
	_transitioning = false
	_stop_browse()
	$TransitionBlocker.hide()

## 切换模式只清理章节横移，保持底栏选中动画独立运行。
func _stop_browse() -> void:
	if _browse_motion != null and _browse_motion.is_valid(): _browse_motion.kill()
	_browse_motion = null
	_browsing = false
	_queued_viewed = -1
	_pending_return = false
	_reset_art_layers()

## 背景按实际视口矩形展开，保证末帧裁切与 Home 完全一致。
func _play_transition(expanded: bool, completed: Callable = Callable()) -> void:
	if not is_visible_in_tree(): return
	var target_texture: Texture2D = $Chapter/ArtStage/Art.texture
	cancel_transition()
	var confirmed_texture: Texture2D = _confirmed_background()
	if not expanded and target_texture != confirmed_texture:
		$Chapter/ArtStage/PreviousArt.texture = confirmed_texture
		$Chapter/ArtStage/PreviousArt.show()
	elif expanded and target_texture != confirmed_texture:
		$Chapter/ArtStage/PreviousArt.texture = target_texture
		$Chapter/ArtStage/Art.texture = confirmed_texture
		$Chapter/ArtStage/PreviousArt.show()
	if not expanded: _set_expansion(1.0)
	_transitioning = true
	$TransitionBlocker.show()
	transition_started.emit(expanded, TRANSITION_SECONDS)
	_transition = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_method(_set_expansion, _expansion, 1.0 if expanded else 0.0, TRANSITION_SECONDS)
	if $Chapter/ArtStage/PreviousArt.visible:
		_transition.tween_property($Chapter/ArtStage/PreviousArt, "modulate:a", 0.0, TRANSITION_SECONDS * 0.72)
	_transition.chain().tween_callback(func():
		_reset_art_layers()
		_transition = null
		_transitioning = false
		$TransitionBlocker.hide()
		transition_finished.emit(expanded)
		if completed.is_valid(): completed.call()
	)

## 同一个动画进度驱动外场、边框、邻章和控件，缩放中重排也不会跳帧。
func _set_expansion(value: float) -> void:
	_expansion = value
	var expanded: Rect2 = $Chapter.get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	$Chapter/ArtStage.position = FRAME_RECT.position.lerp(expanded.position, value)
	$Chapter/ArtStage.size = FRAME_RECT.size.lerp(expanded.size, value)
	$Chapter/ArtStage.set_home_blend(value)
	if is_instance_valid(_background): _background.modulate.a = 1.0 - value
	for part in [$Chapter/Neighbors, $Chapter/Chrome, $Tabs, $Unavailable, $ReturnArt]:
		part.modulate.a = 1.0 - value

## 画布等比落在安全区；背景展开仍使用整个视口，避免 Home 交接时变换裁切。
func _layout_art() -> void:
	if not is_node_ready(): return
	var ratio: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	if ratio <= 0: return
	var origin: Vector2 = (size - DESIGN_SIZE * ratio) * 0.5
	$Chapter.position = origin
	$Chapter.scale = Vector2.ONE * ratio
	$Tabs.position = origin + Vector2(34, 1454) * ratio
	$Tabs.scale = Vector2.ONE * ratio
	$ReturnArt.position = origin + Vector2(31, 40) * ratio
	$ReturnArt.scale = Vector2.ONE * ratio
	if is_instance_valid(_return_button):
		_return_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_return_button.size = Vector2(144, 144)
		_return_button.scale = Vector2.ONE * ratio
		_return_button.global_position = $ReturnArt/Icon.get_global_rect().get_center() - _return_button.size * ratio * 0.5
	_set_expansion(_expansion)
	if _browsing: _set_browse_progress(_browse_progress)

## 返回 Home 只使用账号已确认章节，浏览中的章节不会泄漏为主页状态。
func _confirmed_background() -> Texture2D:
	if session == null: return $Chapter/ArtStage/Art.texture
	var chapter: Dictionary = session.content.get_record("chapters", session.selected_chapter)
	return _chapter_background(chapter) if not chapter.is_empty() else $Chapter/ArtStage/Art.texture

## 主图、邻章和 Home 衔接都读取同一章节资源登记键。
func _chapter_background(chapter: Dictionary) -> Texture2D:
	return session.content.resource(chapter.unlocked_background_key if chapter.id in session.unlocked else chapter.locked_background_key)

## 切换页签先结束局部浏览；未开放模式只有提示，没有伪造的战斗入口。
func _select(id: String, animate: bool = true) -> void:
	if session == null: return
	if _browsing:
		_stop_browse()
		browse_finished.emit()
	_update_tab_art(id, animate)
	var adventure: bool = id == "PveAdventure"
	$Chapter.visible = adventure
	$Unavailable.visible = not adventure
	if not adventure:
		var names = {"Pvp": "ui.mode.pvp", "PvpChess": "ui.mode.chess", "PveChallenge": "ui.mode.challenge"}
		$Unavailable.present(ContentText.format_key("ui.mode.preview_title", {"mode": ContentText.text(names.get(id, "ui.page.modes"))}),
			{"Pvp": "PVP", "PvpChess": "CHESS", "PveChallenge": "PVE"}.get(id, ""))
	else: _render_chapter()

## 初始展示直接对齐；每次用户切换都移动同一黑牌并同步过渡图标和文字颜色。
func _update_tab_art(id: String, animate: bool) -> void:
	if _tab_motion != null and _tab_motion.is_valid(): _tab_motion.kill()
	_tab_motion = null
	var active: Button = tabs.get_node_or_null("Bar/" + id)
	if active == null: return
	var duration: float = 0.28 if animate and is_visible_in_tree() else 0.0
	if duration > 0:
		_tab_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_tab_motion.tween_property($Tabs/Bar/Selection, "position:x", active.position.x - 12.0, duration)
		_tab_motion.tween_property($Tabs/Bar/Selection, "size:x", active.size.x + 24.0, duration)
	else:
		$Tabs/Bar/Selection.position.x = active.position.x - 12.0
		$Tabs/Bar/Selection.size.x = active.size.x + 24.0
	for option in tabs.options:
		var button: Button = tabs.get_node("Bar/" + option.id)
		var color := Color(0.87, 0.80, 0.61) if option.id == id else Color(0.10, 0.09, 0.07)
		if duration > 0:
			_tab_motion.tween_property(button.get_node("Icon"), "self_modulate", color, duration)
			_tab_motion.tween_property(button.get_node("Caption"), "self_modulate", color, duration)
		else:
			button.get_node("Icon").self_modulate = color
			button.get_node("Caption").self_modulate = color

## 所有章节共用标题、解锁反馈、邻章预览和指示器，不按章节硬编码状态。
func _render_chapter() -> void:
	var chapters: Array = session.normal_chapters()
	if chapters.is_empty():
		$Chapter.hide()
		$Unavailable.show()
		$Unavailable.present("ui.mode.empty")
		return
	_viewed = clampi(_viewed, 0, chapters.size() - 1)
	var chapter: Dictionary = chapters[_viewed]
	var unlocked: bool = chapter.id in session.unlocked
	_present_card($Chapter/ArtStage, chapter)
	$Chapter/ArtStage/Art.tooltip_text = ContentText.format_key("ui.mode.chapter_terms", {
		"stamina": chapter.stamina_cost, "status": ContentText.text("ui.mode.unlocked" if unlocked else "ui.mode.locked")})
	for entry: Array in [["Previous", _viewed - 1], ["Next", _viewed + 1]]:
		var available: bool = entry[1] >= 0 and entry[1] < chapters.size()
		get_node("Chapter/Chrome/" + entry[0]).visible = available
		get_node("Chapter/Neighbors/" + entry[0]).visible = available
		if available: _present_card(get_node("Chapter/Neighbors/" + entry[0]), chapters[entry[1]])
	$Chapter/Chrome/Confirm/Caption.text = "ui.mode.confirm" if unlocked else "ui.mode.locked_label"
	$Chapter/Chrome/Confirm.disabled = not unlocked or _browsing
	$Chapter/Chrome/Confirm/Art.modulate = Color.WHITE if unlocked else Color(0.56, 0.56, 0.56)
	$Chapter/Chrome/Confirm.tooltip_text = ContentText.text("ui.mode.unlocked" if unlocked else "ui.mode.locked")
	_render_indicators(chapters.size())

## 主框与邻章采用同一份展示绑定，当前使用只来自账号已确认章节。
func _present_card(card: Control, chapter: Dictionary) -> void:
	card.present(_chapter_background(chapter), ContentText.format_key("ui.mode.level", {"number": chapter.chapter_index}), ContentText.field(chapter), chapter.id == session.selected_chapter)

## 定位标记紧凑排列并连接细线，增加章节时限制总宽度。
func _render_indicators(count: int) -> void:
	UI.clear($Chapter/Chrome/Indicators/Dots)
	var width: float = minf(maxi(count - 1, 0) * 72.5, 290.0)
	var start: float = (290.0 - width) * 0.5
	$Chapter/Chrome/Indicators/Line.visible = count > 1
	$Chapter/Chrome/Indicators/Line.points = PackedVector2Array([Vector2(start, 12), Vector2(start + width, 12)])
	for index in range(count):
		var dot := TextureRect.new()
		var texture := AtlasTexture.new()
		texture.atlas = ATLAS
		texture.region = Rect2(453, 1253, 25, 25) if index == _viewed else Rect2(532, 1254, 20, 23)
		texture.filter_clip = true
		dot.texture = texture
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var side: float = 24.0 if index == _viewed else 20.0
		dot.size = Vector2.ONE * side
		dot.position = Vector2(start + index * width / maxf(count - 1, 1), 12) - dot.size * 0.5
		var material := ShaderMaterial.new()
		material.shader = CORNER_CLIP
		material.set_shader_parameter("extent", dot.size)
		material.set_shader_parameter("corner", dot.size * 0.5)
		dot.material = material
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Chapter/Chrome/Indicators/Dots.add_child(dot)

## 切换语言只刷新展示，不重启动画或改变玩家选择。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _select.call_deferred(tabs.selected_id, false)

## 场景释放时不让未完成动画触发保存或导航回调。
func _exit_tree() -> void:
	cancel_transition()
