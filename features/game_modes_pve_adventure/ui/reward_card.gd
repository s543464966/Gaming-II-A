extends VBoxContainer
## 三选一候选以完整纸面提交领取，独立刷新入口不触发选奖。

signal selected
signal refresh_requested
const UI = preload("res://ui/components/ui.gd")
const RULE: Texture2D = preload("res://features/game_modes_pve_adventure/ui/art/reward_divider.tres")
var _render: Callable
var _remaining: int = 0
var _press_position: Vector2
var _tracking: bool = false
var _dragged: bool = false
var _released_tap: bool = false

## 整张候选轻点松开才提交；独立刷新与正文拖动不能触发领取。
func _ready() -> void:
	visibility_changed.connect(func():
		if not is_visible_in_tree(): _cancel_pointer())
	$Paper.pressed.connect(func():
		if not _dragged: selected.emit())
	$Refresh.pressed.connect(func(): refresh_requested.emit())
	$Paper/Margin/Body/Scroll.gui_input.connect(_scroll_input)
	$Paper/Margin/Body/Art.resized.connect(_layout_face)
	# 完整纸面与标题底分别九宫格缩放，四角不随屏幕比例拉长。
	$Paper.resized.connect(_layout_skin)
	$Paper/Margin/Body/Title.resized.connect(_layout_skin)
	_layout_skin()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		$Paper.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	$Paper.mouse_entered.connect(_paper_tint)
	$Paper.mouse_exited.connect(_paper_tint)
	$Paper.button_down.connect(_paper_tint)
	$Paper.button_up.connect(_paper_tint)
	$Paper.focus_entered.connect(_paper_tint)
	$Paper.focus_exited.connect(_paper_tint)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var icon := StyleBoxTexture.new()
		icon.texture = preload("res://features/game_modes_pve_adventure/ui/art/reward_refresh_button.tres")
		icon.set_content_margin_all(0)
		icon.expand_margin_left = -22
		icon.expand_margin_right = -22
		icon.expand_margin_top = -14
		icon.expand_margin_bottom = -30
		var brightness: float = 1.12 if state in ["hover", "focus"] else 0.78 if state == "pressed" else 0.42 if state == "disabled" else 1.0
		icon.modulate_color = Color(brightness, brightness, brightness)
		$Refresh.add_theme_stylebox_override(state, icon)

## 只拉伸纸面和标题底的中间部分，原图边框与四角保持统一的显示尺度。
func _layout_skin() -> void:
	$Paper/Background.size = $Paper.size / $Paper/Background.scale
	$Paper/Margin/Body/Title/Frame.size = $Paper/Margin/Body/Title.size / $Paper/Margin/Body/Title/Frame.scale

## 用轻微明度变化表达可选和按下，不覆盖纸面的细边与浅色纹理。
func _paper_tint() -> void:
	var brightness: float = 0.90 if $Paper.button_pressed else 1.06 if $Paper.is_hovered() or $Paper.has_focus() else 1.0
	$Paper/Background.modulate = Color(brightness, brightness, brightness)
	$Paper/Margin/Body/Title/Frame.modulate = Color(brightness, brightness, brightness)

## 滚动容器位于领取按钮内部，记录手势位移以排除其未向祖先传播的滑动取消。
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.canceled: _cancel_pointer()
		elif event.pressed:
			_tracking = $Paper.get_global_rect().has_point(event.position)
			_press_position = event.position
			_dragged = false
			_released_tap = false
		else:
			_released_tap = _tracking and not _dragged
			_tracking = false
	elif event is InputEventMouseMotion and _tracking:
		if event.position.distance_to(_press_position) > $Paper/Margin/Body/Scroll.touch_drag_deadzone: _dragged = true
	elif event is InputEventKey and event.pressed:
		_dragged = false

## 正文独占滚动输入，只有其内部未滑动的轻点转交领取，滚动条不参与选奖。
func _scroll_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or event.pressed or event.canceled or not _released_tap: return
	_released_tap = false
	var scroll: ScrollContainer = $Paper/Margin/Body/Scroll
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	if bar.visible and bar.get_global_rect().has_point(scroll.get_global_mouse_position()): return
	selected.emit()

## 中断后清空本次领取候选，迟到松手不能被当作正文轻点。
func _cancel_pointer() -> void:
	_tracking = false
	_released_tap = false
	_dragged = true

## 宿主提供同一详情投影，组件不读取玩家状态或抽取候选。
func configure(render: Callable, remaining: int) -> void:
	_render = render
	_remaining = remaining
	_translate_view()

## 只刷新身份、等比卡面和实际效果，不显示技能名称或重建候选身份。
func _translate_view() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not _render.is_valid(): return
	var value: Dictionary = _render.call()
	$Paper/Margin/Body/Title.text = value.title
	$Paper.accessibility_name = value.title
	$Refresh/Remaining.text = str(_remaining)
	$Refresh/Remaining.modulate.a = 1.0 if _remaining > 0 else 0.4
	$Refresh.disabled = _remaining <= 0
	$Refresh.tooltip_text = ContentText.format_key("ui.reward.refresh_count", {"count": _remaining})
	$Refresh.accessibility_name = $Refresh.tooltip_text
	var detail: Dictionary = value.detail
	var art: Control = $Paper/Margin/Body/Art
	art.get_node("Image").texture = value.texture
	art.get_node("Image").visible = not detail.has("face")
	var card: CardFaceView = art.get_node("Card")
	card.visible = detail.has("face")
	if card.visible:
		var definition: Dictionary = detail.face.definition
		card.size = Vector2(definition.width * 100, definition.height * 118)
		card.set_appearance(value.texture, int(definition.get("chapter_level", 0)), int(definition.width))
		card.set_stats(detail.face.state)
	var body: VBoxContainer = $Paper/Margin/Body/Scroll/Effects
	UI.clear(body)
	if not str(detail.get("scope", "")).is_empty(): _text(body, detail.scope, true)
	for section in detail.get("sections", []):
		if section.entries.is_empty(): continue
		if body.get_child_count() > 0:
			var rule: TextureRect = UI.texture(RULE, Vector2(0, 12))
			rule.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rule.material = preload("res://features/game_modes_pve_adventure/ui/art/reward_divider_cutout.tres")
			body.add_child(rule)
		for entry in section.entries:
			if not str(entry.get("meta", "")).is_empty(): _text(body, entry.meta, true)
			_text(body, entry.body)
			for note: String in entry.get("notes", []): _text(body, note, true)
	_layout_face()

## 行内属性沿用详情图标与墨色文字，点按由整张候选统一响应。
func _text(body: VBoxContainer, value: String, caption: bool = false) -> void:
	var label := AttributeText.new()
	label.theme_type_variation = &"DetailRichCaption" if caption else &"DetailRichBody"
	label.add_theme_font_size_override("normal_font_size", 22 if caption else 25)
	body.add_child(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.present(value)

## 卡面按真实占位比例缩放，竖向奖励纸面的高度不能拉伸卡牌插画。
func _layout_face() -> void:
	if not is_node_ready(): return
	var art: Control = $Paper/Margin/Body/Art
	var card: Control = art.get_node("Card")
	if not card.visible: return
	var factor: float = minf(maxf(1, art.size.x - 4) / card.size.x, (art.size.y - 16) / card.size.y)
	card.scale = Vector2.ONE * factor
	card.position = (art.size - card.size * factor) * 0.5 + Vector2(0, 3)

## 切换语言保留滚动位置、按键焦点与同一候选实例。
func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]: _cancel_pointer()
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _translate_view.call_deferred()
