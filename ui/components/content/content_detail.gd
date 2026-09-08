class_name ContentDetail
extends VBoxContainer
## 只渲染业务方提供的身份、属性和能力分组，不读取账号或计算战斗。

@export var show_artwork: bool = true

const UI = preload("res://ui/components/ui.gd")
const STAR_ICON: Texture2D = preload("res://ui/design_system/icons/star.png")
var _hint_stat: String = ""
var _symbol_hints: Dictionary = {}
var _hint_anchor: Control
var _preview_height: float = 210.0

## 卡牌独立占据内容中线，图标数量和宽度不能改变它的位置。
func _ready() -> void:
	$Header/CardRow.resized.connect(_layout_card_face)
	$Header/CardRow/CardTags.minimum_size_changed.connect(_layout_card_face)
	$SymbolHint.minimum_size_changed.connect(_layout_symbol_hint)

## 同一详情节点重绑数据；语言刷新不改变宿主的滚动和业务状态。
func present(entry: Dictionary, detail: Dictionary) -> void:
	_hide_symbol_hint()
	_symbol_hints.clear()
	$Header/Portrait.texture = entry.get("texture")
	var is_card: bool = detail.has("face")
	$Header/Portrait.visible = show_artwork and not is_card and entry.get("texture") != null
	$Header/CardRow.visible = show_artwork and is_card
	if $Header/CardRow.visible: _card_face(entry, detail.face)
	$Header/Scope.text = detail.get("scope", "")
	$Header/Scope.visible = not str(detail.get("scope", "")).is_empty()
	UI.clear($Header/Tags)
	for tag in detail.get("tags", []):
		var panel = PanelContainer.new()
		panel.theme_type_variation = &"DetailTag"
		var label = _label(tag, &"DetailTagText")
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		panel.add_child(label)
		$Header/Tags.add_child(panel)
	$Header/Tags.visible = not detail.get("tags", []).is_empty()
	$Header.visible = is_card or $Header/Portrait.visible or $Header/Tags.visible or $Header/Scope.visible
	$Rule.visible = $Header.visible
	UI.clear($Attributes/Grid)
	UI.clear($Attributes/Groups)
	var attributes: Array = detail.get("attributes", [])
	var groups: Array = detail.get("attribute_groups", [])
	$Attributes.visible = not attributes.is_empty()
	$Attributes/Grid.visible = groups.is_empty() and not attributes.is_empty()
	$Attributes/Groups.visible = not groups.is_empty()
	if groups.is_empty():
		for attribute in attributes: $Attributes/Grid.add_child(_metric(attribute))
	else:
		for group in groups: _attribute_group(group)
	UI.clear($Sections)
	for section in detail.get("sections", []): _section(section)
	$Sections.visible = $Sections.get_child_count() > 0

## 独立附加模块占用高度时，先完整显示卡面与星级，长规则继续由宿主滚动。
func fit_preview(available_height: float) -> void:
	var height: float = clampf(available_height - 24, 96, 210)
	if is_equal_approx(height, _preview_height): return
	_preview_height = height
	_layout_card_face()

## 详情以同一战斗卡面等比放大，只读展示完整占位比例与顶部数值。
func _card_face(entry: Dictionary, face: Dictionary) -> void:
	var definition: Dictionary = face.definition
	var card: CardFaceView = $Header/CardRow/CardSlot/Card
	card.size = Vector2(definition.width * 100, definition.height * 118)
	card.position = Vector2(0, 12)
	var stars: HBoxContainer = $Header/CardRow/CardSlot/Stars
	UI.clear(stars)
	var star_count: int = int(definition.get("star_level", 0))
	for index in range(star_count): stars.add_child(UI.texture(STAR_ICON, Vector2.ONE * 22))
	stars.visible = stars.get_child_count() > 0
	card.set_appearance(entry.get("texture"), int(definition.get("chapter_level", 0)), int(definition.width))
	card.set_stats(face.state)
	card.set_unavailable(not entry.get("owned", true))
	UI.clear($Header/CardRow/CardTags)
	for tag in entry.get("tag_icons", []):
		var icon: TextureRect = UI.texture(tag.texture, Vector2(40, 40))
		icon.tooltip_text = tag.name
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		$Header/CardRow/CardTags.add_child(icon)
	$Header/CardRow/CardTags.visible = not entry.get("tag_icons", []).is_empty()
	_layout_card_face()

## 为侧边元素预留对称余量，窄屏和多格卡面仍等比居中，星级贴住卡框下沿。
func _layout_card_face() -> void:
	if not is_node_ready(): return
	var row: Control = $Header/CardRow
	if not row.visible or row.size.x <= 0: return
	var slot: Control = $Header/CardRow/CardSlot
	var card_tags: VBoxContainer = $Header/CardRow/CardTags
	var card: Control = $Header/CardRow/CardSlot/Card
	var stars: HBoxContainer = $Header/CardRow/CardSlot/Stars
	var side_space: float = 48 if card_tags.visible else 0
	var width: float = maxf(1, minf(200, row.size.x - side_space * 2))
	var factor: float = minf(width / card.size.x, _preview_height / card.size.y)
	card.scale = Vector2.ONE * factor
	var star_count: int = stars.get_child_count()
	var star_size: float = minf(22, (card.size.x * factor - 8 - maxi(0, star_count - 1) * 2) / maxi(1, star_count))
	for star: TextureRect in stars.get_children(): star.custom_minimum_size = Vector2.ONE * maxf(1, star_size)
	slot.custom_minimum_size = card.size * factor + Vector2(0, 24 if stars.visible else 12)
	slot.size = slot.custom_minimum_size
	card_tags.size = Vector2(40, card_tags.get_combined_minimum_size().y)
	row.custom_minimum_size.y = maxf(slot.size.y, card_tags.size.y + 12 if card_tags.visible else 0)
	slot.position = Vector2((row.size.x - slot.size.x) * 0.5, (row.custom_minimum_size.y - slot.size.y) * 0.5)
	card_tags.position = Vector2(slot.position.x + slot.size.x + 8, (row.custom_minimum_size.y - card_tags.size.y) * 0.5)
	stars.size = stars.get_combined_minimum_size()
	stars.position = Vector2((slot.size.x - stars.size.x) * 0.5, card.position.y + card.size.y * card.scale.y - stars.size.y * 0.5)

## 同一底色内上方为冷却、下方为效果；卡牌能力不重复展示主能力或来源名称。
func _section(section: Dictionary) -> void:
	if section.entries.is_empty(): return
	var group = VBoxContainer.new()
	group.add_theme_constant_override("separation", 12)
	if not section.has("category"): group.add_child(_label(ContentText.text(section.title), &"DetailHeading"))
	for entry in section.entries:
		var panel = PanelContainer.new()
		panel.theme_type_variation = &"DetailSection"
		var column = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 6)
		if not str(entry.get("meta", "")).is_empty():
			var timing = _rich_label(entry.meta, &"DetailRichCaption")
			column.add_child(timing)
		column.add_child(_rich_label(entry.body, &"DetailRichBody"))
		for note: String in entry.get("notes", []): column.add_child(_rich_label(note, &"DetailRichCaption"))
		panel.add_child(column)
		group.add_child(panel)
	$Sections.add_child(group)

## 卡牌属性按语义分区，每区保持两列紧凑指标，不将空组留在详情中。
func _attribute_group(data: Dictionary) -> void:
	if data.get("entries", []).is_empty(): return
	var group = VBoxContainer.new()
	group.name = StringName(str(data.get("id", "attributes")).to_pascal_case())
	group.add_theme_constant_override("separation", 6)
	group.add_child(_label(ContentText.text(data.title), &"DetailHeading"))
	var grid = GridContainer.new()
	grid.name = &"Grid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for attribute in data.entries: grid.add_child(_metric(attribute))
	group.add_child(grid)
	$Attributes/Groups.add_child(group)

## 指标卡统一处理图标、数值与补充提示，普通内容和卡牌分组共用渲染。
func _metric(attribute: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.theme_type_variation = &"DetailMetric"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	var stat: String = attribute.get("stat", "")
	if not stat.is_empty() and not str(attribute.get("hint", "")).is_empty(): _symbol_hints[stat] = AttributeIcons.plain(attribute.hint)
	if AttributeIcons.TEXTURES.has(stat):
		column.add_child(_rich_label(AttributeIcons.symbol(stat, true) + " " + attribute.value, &"DetailRichValue"))
	else:
		column.add_child(_label(attribute.label, &"DetailCaption"))
		column.add_child(_label(attribute.value, &"DetailValue"))
	if not str(attribute.get("hint", "")).is_empty(): panel.tooltip_text = AttributeIcons.plain(attribute.hint)
	panel.add_child(column)
	return panel

## 动态文字已按当前语言生成，内容名和 ID 不再进行第二次自动翻译。
func _label(text: String, variation: StringName) -> Label:
	var label = UI.label(text)
	label.theme_type_variation = variation
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return label

## 行内图标保留独立交互，普通说明保持自然换行。
func _rich_label(text: String, variation: StringName) -> AttributeText:
	var label := AttributeText.new()
	label.theme_type_variation = variation
	label.present(text)
	label.symbol_pressed.connect(_show_symbol.bind(label))
	return label

## 触屏点按显示属性名称，再点同一图标收起；不创建全局模态。
func _show_symbol(stat: String, anchor: Control) -> void:
	_hint_stat = "" if _hint_stat == stat else stat
	_hint_anchor = anchor
	_refresh_symbol_hint()

## 可见提示随当前属性和语言刷新，补充说明不会变成第二份规则。
func _refresh_symbol_hint() -> void:
	$SymbolHint/Text.text = str(_symbol_hints.get(_hint_stat, AttributeIcons.label(_hint_stat))) if not _hint_stat.is_empty() else ""
	$SymbolHint.visible = not _hint_stat.is_empty()
	if _hint_stat.is_empty(): return
	var caption: Label = $SymbolHint/Text
	var natural_width: float = caption.get_theme_font("font").get_string_size(caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption.get_theme_font_size("font_size")).x + $SymbolHint.get_theme_stylebox("panel").get_minimum_size().x
	$SymbolHint.size = Vector2(minf(ceilf(natural_width), minf(360, get_viewport_rect().size.x * 0.65)), 0)
	_layout_symbol_hint.call_deferred()

## 名称提示不参与详情容器测量，点按前后弹窗和图标位置保持不变。
func _layout_symbol_hint() -> void:
	if _hint_stat.is_empty() or not is_instance_valid(_hint_anchor): return
	var hint: Control = $SymbolHint
	hint.size.y = hint.get_combined_minimum_size().y
	var bounds: Rect2 = get_viewport_rect().grow(-12)
	var anchor: Rect2 = _hint_anchor.get_global_rect()
	hint.position = Vector2(clampf(anchor.position.x, bounds.position.x, bounds.end.x - hint.size.x), anchor.end.y + 6)
	if hint.position.y + hint.size.y > bounds.end.y: hint.position.y = maxf(bounds.position.y, anchor.position.y - hint.size.y - 6)

## 其他点按或滚动收起局部提示，事件继续交给原业务控件。
func _input(event: InputEvent) -> void:
	if _hint_stat.is_empty(): return
	if event is InputEventScreenDrag:
		_hide_symbol_hint()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index != MOUSE_BUTTON_LEFT or not is_instance_valid(_hint_anchor):
			_hide_symbol_hint()
			return
		var local: InputEventMouseButton = _hint_anchor.make_input_local(event)
		if not Rect2(Vector2.ZERO, _hint_anchor.size).has_point(local.position): _hide_symbol_hint()

## 重绑或离开时只释放局部查看状态，不改变任何内容或玩家事实。
func _hide_symbol_hint() -> void:
	_hint_stat = ""
	_hint_anchor = null
	if is_node_ready(): $SymbolHint.hide()
