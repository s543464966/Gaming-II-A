extends Control
## Home 永久天赋页：以纵向圣坛展示串行节点，并在底部纸面提交学习。

const UI = preload("res://ui/components/ui.gd")
const DESIGN_SIZE := Vector2(941, 1672)
const NODE_SIZE := Vector2(170, 170)
const NODE_BOTTOM_Y := 535.0
const NODE_STEP_Y := 255.0
const ICON_SHADER: Shader = preload("res://features/talents/ui/talent_icon.gdshader")
const GOLD := Color("dcc992")
const GOLD_DIM := Color("665437")
const INK := Color("15130f")
const LOCKED := Color("68625a")
const PURPLE := Color("59386c")

var session: PlayerSessionState
var persist: Callable
var overlays: CanvasLayer
var selected_id: String = ""
var _buttons: Dictionary = {}
var _rows: Array = []
var _return_button: Button
@onready var _design: Control = $Design
@onready var _nodes: Control = $Design/Shrine/Nodes
@onready var _unlock: Button = $Design/Detail/Margin/Column/Unlock

## 会话与保存入口由 Home 显式注入，页面不持有第二份天赋状态。
func bind_player(player: PlayerSessionState, save: Callable, overlay: CanvasLayer) -> void:
	session = player
	persist = save
	overlays = overlay

## 宿主关闭按钮保留命中与焦点，只把外观和位置交给沉浸式返回标识。
func bind_return_button(button: Button) -> void:
	_return_button = button
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for event: Signal in [button.button_down, button.button_up, button.mouse_entered, button.mouse_exited, button.focus_entered, button.focus_exited]:
		event.connect(_refresh_return_tint)

## 稳定骨架由场景持有，运行时只生成当前策划数据声明的节点。
func _ready() -> void:
	resized.connect(_layout_art)
	_layout_art()
	_refresh_return_tint()
	if session == null: return
	for label: Label in [$Design/Header/Points, $Design/Detail/Margin/Column/Scroll/Text/Title,
		$Design/Detail/Margin/Column/Scroll/Text/Effect, $Design/Detail/Margin/Column/Scroll/Text/Requirement]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_unlock.pressed.connect(_learn)
	session.changed.connect(refresh)
	_rows = session.talents.nodes()
	for index: int in range(_rows.size() - 1, -1, -1):
		_create_node(_rows[index], index)
	if not _rows.is_empty(): selected_id = _rows[0].id
	refresh()

## 画布完整等比放入安全区，并让宿主命中区对齐页面内返回标识。
func _layout_art() -> void:
	var ratio: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	if ratio <= 0: return
	_design.size = DESIGN_SIZE
	_design.scale = Vector2.ONE * ratio
	_design.position = (size - DESIGN_SIZE * ratio) * 0.5
	if is_instance_valid(_return_button):
		_return_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_return_button.size = Vector2(146, 146)
		_return_button.scale = Vector2.ONE * ratio
		_return_button.global_position = global_position + _design.position + Vector2(782.5, 23.5) * ratio

## 返回标识沿用 Home 入口的明度反馈，不额外绘制第二个可点击控件。
func _refresh_return_tint() -> void:
	if not is_node_ready() or not is_instance_valid(_return_button): return
	var brightness: float = UI.tokens.entry_normal_brightness
	if _return_button.is_pressed(): brightness = UI.tokens.entry_pressed_brightness
	elif _return_button.is_hovered() or _return_button.has_focus(): brightness = UI.tokens.entry_hover_brightness
	$Design/ReturnArt.self_modulate = Color(brightness, brightness, brightness)

## 每个数据节点只创建一个原生按钮，位置由策划顺序投影到圣坛中轴。
func _create_node(row: Dictionary, index: int) -> void:
	var button: Button = preload("res://ui/components/touch_button.gd").new()
	button.name = row.id
	button.position = Vector2((DESIGN_SIZE.x - NODE_SIZE.x) * 0.5, NODE_BOTTOM_Y - index * NODE_STEP_Y)
	button.size = NODE_SIZE
	button.custom_minimum_size = NODE_SIZE
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("step", index + 1)
	button.pressed.connect(_select.bind(row.id))
	var inset := Panel.new()
	inset.name = "Inset"
	inset.position = Vector2(12, 12)
	inset.size = NODE_SIZE - Vector2(24, 24)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inset)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(49, 34)
	icon.size = Vector2(72, 72)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var icon_material := ShaderMaterial.new()
	icon_material.shader = ICON_SHADER
	icon.material = icon_material
	var texture: Texture2D = AttributeIcons.TEXTURES.get(_primary_stat(row))
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	button.add_child(icon)
	var step := Label.new()
	step.name = "Step"
	step.position = Vector2(20, 108)
	step.size = Vector2(130, 48)
	step.mouse_filter = Control.MOUSE_FILTER_IGNORE
	step.add_theme_font_size_override("font_size", 38)
	step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(step)
	var status := Label.new()
	status.name = "Status"
	status.position = Vector2(118, 4)
	status.size = Vector2(44, 44)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_font_size_override("font_size", 31)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(status)
	_nodes.add_child(button)
	_buttons[row.id] = button

## 节点图标读取能力中首个真实数值属性，不按天赋 ID 维护第二份映射。
func _primary_stat(row: Dictionary) -> String:
	for part: Dictionary in row.get("ability_parts", []):
		var modifiers: Dictionary = part.get("modifiers", {})
		for stat: String in AttributeIcons.TEXTURES:
			var value: Variant = modifiers.get(stat, 0)
			if value is int and value != 0: return stat
			if value is float and not is_zero_approx(value): return stat
	return ""

## 点选只改变详情与视觉焦点，不消费天赋点。
func _select(id: String) -> void:
	selected_id = id
	refresh()

## 刷新点数、路径状态与详情；规则合法性仍由共享天赋机制判定。
func refresh() -> void:
	if not is_node_ready() or session == null: return
	var points: Label = $Design/Header/Points
	points.text = ContentText.format_key("ui.talents.points", {"count": session.talents.points})
	points.fit_content()
	for id: String in _buttons:
		var button: Button = _buttons[id]
		var row: Dictionary = session.content.get_record("talents", id)
		var learned: bool = id in session.talents.learned
		var blocked: bool = not row.prerequisite_id.is_empty() and not row.prerequisite_id in session.talents.learned
		button.set_pressed_no_signal(id == selected_id)
		var step: Label = button.get_node("Step")
		var status: Label = button.get_node("Status")
		step.text = str(button.get_meta("step"))
		status.text = "✓" if learned else ""
		button.accessibility_name = "%s · %s" % [str(button.get_meta("step")), ContentText.field(row)]
		button.tooltip_text = ContentText.field(row)
		_apply_node_style(button, learned, blocked, id == selected_id)
	_refresh_path()
	var row: Dictionary = session.content.get_record("talents", selected_id)
	if row.is_empty(): return
	$Design/Detail/Margin/Column/Scroll/Text/Title.text = ContentText.field(row)
	$Design/Detail/Margin/Column/Scroll/Text/Effect.text = ContentText.field(row, "flavor_text")
	var learned: bool = selected_id in session.talents.learned
	var needs_previous: bool = not row.prerequisite_id.is_empty() and not row.prerequisite_id in session.talents.learned
	var requirement: Label = $Design/Detail/Margin/Column/Scroll/Text/Requirement
	requirement.visible = needs_previous or (not learned and session.talents.points == 0)
	requirement.text = ContentText.format_key("ui.talents.requires", {"name": ContentText.field(session.content.get_record("talents", row.prerequisite_id))}) if needs_previous else ContentText.text("ui.talents.no_points")
	$Design/Detail/Margin/Column/Cost.visible = not learned
	_unlock.text = "ui.talents.learned" if learned else "ui.talents.unlock"
	_unlock.disabled = session.busy or not TalentMechanic.can_unlock(row, session.talents.learned, session.talents.points).is_empty()

## 节点以金属明度区分已点亮、可达、锁定与当前焦点，不只依赖颜色传达状态。
func _apply_node_style(button: Button, learned: bool, blocked: bool, selected: bool) -> void:
	var border: Color = LOCKED if blocked else GOLD_DIM
	var fill := Color("171612")
	var text_color: Color = LOCKED if blocked else GOLD
	if learned:
		border = GOLD
		fill = Color("1c1a12")
	if selected:
		border = GOLD
		fill = INK.lerp(PURPLE, 0.2)
	for state: String in ["normal", "disabled", "hover", "pressed", "hover_pressed", "focus"]:
		button.add_theme_stylebox_override(state, _node_face(fill, border, selected, state))
	var display_color: Color = text_color.lightened(0.12) if selected else text_color
	var inset: Panel = button.get_node("Inset")
	var icon: TextureRect = button.get_node("Icon")
	var step: Label = button.get_node("Step")
	var status: Label = button.get_node("Status")
	inset.add_theme_stylebox_override("panel", _inset_ring(display_color))
	icon.self_modulate = GOLD if learned or selected else LOCKED if blocked else Color("aa9363")
	step.add_theme_color_override("font_color", display_color)
	status.add_theme_color_override("font_color", GOLD)

## 内圈补足 Home 与模式页常用的双线金属层次，不额外引入位图节点框。
func _inset_ring(color: Color) -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color.TRANSPARENT
	ring.border_color = Color(color, 0.7)
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(roundi((NODE_SIZE.x - 24) * 0.5))
	ring.anti_aliasing = true
	ring.set_content_margin_all(0)
	return ring

## 圆形徽章保持克制的金属边与选中辉光，悬停和按压只改变局部明度。
func _node_face(fill: Color, border: Color, selected: bool, state: String) -> StyleBoxFlat:
	var face := StyleBoxFlat.new()
	var brightness: float = 1.08 if state in ["hover", "focus"] else 0.88 if state in ["pressed", "hover_pressed"] else 1.0
	face.bg_color = fill.lightened(0.035) if brightness > 1 else fill.darkened(0.08) if brightness < 1 else fill
	face.border_color = border.lightened(0.1) if brightness > 1 else border.darkened(0.1) if brightness < 1 else border
	face.set_border_width_all(7 if selected else 4)
	face.set_corner_radius_all(roundi(NODE_SIZE.x * 0.5))
	face.anti_aliasing = true
	face.shadow_color = Color(GOLD, 0.32 if selected else 0.12)
	face.shadow_size = 17 if selected else 7
	face.shadow_offset = Vector2.ZERO
	face.set_content_margin_all(0)
	return face

## 连线只在下级天赋已学习后点亮，保持串行前置关系可见。
func _refresh_path() -> void:
	var connectors: Array[CanvasItem] = [$Design/Shrine/LowerConnector, $Design/Shrine/UpperConnector]
	var diamonds: Array[CanvasItem] = [$Design/Shrine/LowerDiamond, $Design/Shrine/UpperDiamond]
	for index: int in range(connectors.size()):
		var active: bool = index < _rows.size() and _rows[index].id in session.talents.learned
		var color: Color = GOLD if active else GOLD_DIM
		connectors[index].modulate = color
		diamonds[index].modulate = color

## 只有事务成功才显示点亮反馈；失败由会话回滚后重新展示。
func _learn() -> void:
	var message: String = session.unlock_talent(selected_id, persist)
	refresh()
	if overlays != null: overlays.toast("ui.talents.success" if message.is_empty() else message)

## 语言切换只重绑文字，保留当前选中节点。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): refresh.call_deferred()
