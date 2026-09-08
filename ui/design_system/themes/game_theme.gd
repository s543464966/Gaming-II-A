@tool
extends Theme
## 从唯一设计令牌生成原生 Theme，编辑器和运行时使用相同样式。

@export var tokens: DesignTokens:
	set(value):
		if tokens != null and tokens.changed.is_connected(rebuild): tokens.changed.disconnect(rebuild)
		tokens = value
		if tokens != null:
			tokens.changed.connect(rebuild)
			rebuild()

## Theme 是令牌的投影，不在组件里另外维护同名颜色与间距。
func rebuild() -> void:
	if tokens == null: return
	default_font_size = tokens.body_font_size
	var normal = _box(tokens.surface_color, tokens.border_color, 1, tokens.corner_radius)
	var selected = _box(tokens.selected_color, tokens.accent_color, 0, tokens.corner_radius)
	selected.border_width_bottom = 3
	var focus = _box(Color.TRANSPARENT, tokens.focus_color, 2, tokens.corner_radius)
	var panel = _box(tokens.panel_color, Color.TRANSPARENT, 0, tokens.panel_radius)
	for side in ["left", "top", "right", "bottom"]: panel.set("content_margin_" + side, tokens.page_margin)
	for state in ["normal", "disabled"]: set_stylebox(state, "Button", normal)
	for state in ["hover", "pressed"]: set_stylebox(state, "Button", selected)
	set_stylebox("focus", "Button", focus)
	set_stylebox("panel", "PanelContainer", panel)
	set_stylebox("normal", "LineEdit", normal)
	set_stylebox("focus", "LineEdit", focus)
	for type in ["Button", "Label", "LineEdit"]: set_color("font_color", type, tokens.text_color)
	set_color("font_disabled_color", "Button", tokens.muted_color)
	set_constant("separation", "VBoxContainer", tokens.space_medium)
	set_constant("separation", "HBoxContainer", tokens.space_small)
	set_constant("h_separation", "GridContainer", tokens.space_small)
	set_constant("v_separation", "GridContainer", tokens.space_small)
	_build_artwork_variations()
	_build_close_variation()
	_build_icon_variations()
	_build_detail_variations()
	_build_unavailable_variations()
	_build_card_variations()

## 共用卡面以浅字、细黑边和深色底板保持小字号对比度，不承载战斗状态。
func _build_card_variations() -> void:
	set_color("unavailable_frame_tint", "CardArtwork", tokens.card_unavailable_frame_tint)
	set_color("unavailable_surface_tint", "CardStatsBadge", tokens.card_unavailable_surface_tint)
	set_type_variation("CardStatValue", "Label")
	set_color("font_color", "CardStatValue", tokens.card_value_color)
	set_color("font_outline_color", "CardStatValue", Color(0, 0, 0, 0.8))
	set_constant("outline_size", "CardStatValue", 2)
	set_constant("embolden_percent", "CardStatValue", 65)
	set_font_size("font_size", "CardStatValue", tokens.body_font_size - 8)
	set_color("health_surface", "CardStatsBadge", tokens.health_color.darkened(0.20))
	set_color("rim_color", "CardStatsBadge", tokens.card_badge_rim_color)
	set_constant("corner_radius", "CardStatsBadge", 3)

## 内容浮层共用黑金标题、暖纸正文及墨色排版，不改变目录和战斗卡面的基础主题。
func _build_detail_variations() -> void:
	var title := _detail_texture(preload("res://ui/design_system/themes/detail_title.png"))
	title.content_margin_left = 48
	title.content_margin_right = 48
	title.content_margin_top = 18
	title.content_margin_bottom = 18
	var paper := _detail_texture(preload("res://ui/design_system/themes/detail_surface.png"))
	set_type_variation("DetailPaper", "Panel")
	set_stylebox("panel", "DetailPaper", paper)
	set_type_variation("DetailSupplement", "PanelContainer")
	var supplement := _detail_texture(preload("res://ui/design_system/themes/detail_supplement.png"))
	supplement.content_margin_left = 26
	supplement.content_margin_right = 26
	supplement.content_margin_top = 18
	supplement.content_margin_bottom = 18
	set_stylebox("panel", "DetailSupplement", supplement)
	for type in ["DetailPopup", "DetailSection", "DetailMetric", "DetailTag", "DetailHint"]:
		set_type_variation(type, "PanelContainer")
		var box := _box(Color.TRANSPARENT, tokens.detail_rule_color, 0, 0)
		box.set_content_margin_all(0)
		if type == "DetailPopup":
			box.content_margin_left = 26
			box.content_margin_right = 26
			box.content_margin_bottom = 24
		elif type == "DetailSection":
			box.border_width_bottom = 1
			box.content_margin_bottom = 14
		elif type in ["DetailTag", "DetailHint"]:
			box.bg_color = Color("e2d3b9") if type == "DetailHint" else Color(0.45, 0.33, 0.15, 0.06)
			box.set_border_width_all(1)
			box.content_margin_left = 8
			box.content_margin_right = 8
			box.content_margin_top = 4
			box.content_margin_bottom = 4
		set_stylebox("panel", type, box)
	for type in ["DetailTitle", "DetailHeading", "DetailValue", "DetailCaption", "DetailBody", "DetailTagText"]:
		set_type_variation(type, "Label")
		var sizes: Dictionary = {"DetailTitle": 32, "DetailHeading": 20, "DetailValue": 22, "DetailCaption": 17, "DetailBody": 20, "DetailTagText": 17}
		set_font_size("font_size", type, sizes[type])
		var color: Color = tokens.detail_ink_color
		if type in ["DetailCaption", "DetailHeading", "DetailTagText"]: color = tokens.detail_caption_color
		elif type == "DetailTitle": color = tokens.detail_gold_color
		set_color("font_color", type, color)
		set_constant("line_spacing", type, 5)
		if type in ["DetailTitle", "DetailHeading"]:
			set_constant("embolden_percent", type, 65)
	set_stylebox("normal", "DetailTitle", title)
	for type: String in ["DetailRichBody", "DetailRichCaption", "DetailRichValue"]:
		set_type_variation(type, "RichTextLabel")
		set_font_size("normal_font_size", type, {"DetailRichBody": 20, "DetailRichCaption": 17, "DetailRichValue": 22}[type])
		set_color("default_color", type, tokens.detail_caption_color if type == "DetailRichCaption" else tokens.detail_ink_color)
		set_constant("line_separation", type, 5)
	for type in ["GrowthLabel", "GrowthValue"]:
		set_type_variation(type, "Label")
		set_font_size("font_size", type, 20)
		set_color("font_color", type, tokens.detail_gold_color)
		set_constant("line_spacing", type, 3)
	set_type_variation("DetailProgress", "ProgressBar")
	var track := _box(Color("111312"), Color(tokens.detail_gold_color, 0.28), 1, 1)
	track.set_content_margin_all(0)
	set_stylebox("background", "DetailProgress", track)
	var fill := _box(tokens.detail_gold_color.darkened(0.12), Color.TRANSPARENT, 0, 1)
	fill.set_content_margin_all(0)
	set_stylebox("fill", "DetailProgress", fill)
	set_type_variation("DetailActionButton", "Button")
	set_font_size("font_size", "DetailActionButton", 22)
	set_constant("embolden_percent", "DetailActionButton", 65)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var button := _detail_texture(preload("res://ui/design_system/themes/detail_paper.png"))
		button.set_content_margin_all(14)
		var brightness: float = 1.05 if state == "hover" else 0.88 if state == "pressed" else 0.96 if state == "disabled" else 1.0
		button.modulate_color = Color(brightness, brightness, brightness)
		set_stylebox(state, "DetailActionButton", button)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		set_color(state, "DetailActionButton", tokens.detail_ink_color)
	set_color("font_disabled_color", "DetailActionButton", tokens.detail_caption_color)
	set_stylebox("focus", "DetailActionButton", _box(Color.TRANSPARENT, tokens.detail_caption_color, 2, 0))
	set_type_variation("DetailCloseButton", "Button")
	set_font_size("font_size", "DetailCloseButton", 28)
	for state in ["normal", "hover", "pressed", "disabled"]:
		set_stylebox(state, "DetailCloseButton", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		set_color(state, "DetailCloseButton", tokens.detail_gold_color.lightened(0.2) if state == "font_hover_color" else tokens.detail_gold_color)
	set_stylebox("focus", "DetailCloseButton", _box(Color.TRANSPARENT, tokens.detail_gold_color, 1, 0))

## 未开放提示沿用黑金牌，文字继承当前语言字体，不创建第二份完整字库。
func _build_unavailable_variations() -> void:
	var panel := _detail_texture(preload("res://ui/design_system/themes/detail_title.png"))
	panel.texture_margin_left = 21
	panel.texture_margin_right = 21
	panel.texture_margin_top = 17
	panel.texture_margin_bottom = 17
	panel.set_content_margin_all(21)
	set_type_variation("UnavailablePanel", "PanelContainer")
	set_stylebox("panel", "UnavailablePanel", panel)
	for type in ["UnavailableTitle", "UnavailableBody"]:
		set_type_variation(type, "Label")
		set_font_size("font_size", type, 19 if type == "UnavailableTitle" else 15)
		set_color("font_color", type, Color("efefec"))
		set_constant("line_spacing", type, 3)

## 九宫格以同一比例绘制金属切角，不随长正文拉扁边框或角部。
func _detail_texture(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 20)
	return style

## 插画界面的入口使用透明、纸片和黑条材质，不给原始图标套圆角面板。
func _build_artwork_variations() -> void:
	for type in ["ArtworkButton", "PaperButton", "LightBlockButton", "BlackButton"]:
		set_type_variation(type, "Button")
		var focus = _box(Color.TRANSPARENT, tokens.focus_color, 2, 0)
		set_stylebox("focus", type, focus)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBox
			if type == "PaperButton":
				style = _texture_box(preload("res://ui/design_system/icons/common/com_btn/btn_big_box_1.png"))
				style.modulate_color = Color(0.82, 0.82, 0.82) if state == "pressed" else Color.WHITE
			else:
				var fill = Color.TRANSPARENT
				if type == "LightBlockButton": fill = Color(0.82, 0.82, 0.82) if state == "pressed" else Color.WHITE
				elif type == "BlackButton": fill = Color.BLACK
				elif state == "hover": fill = Color(1, 1, 1, 0.08)
				elif state == "pressed": fill = Color(0, 0, 0, 0.2)
				style = _box(fill, Color.TRANSPARENT, 0, 0)
			for side in ["left", "top", "right", "bottom"]: style.set("content_margin_" + side, 0)
			set_stylebox(state, type, style)
		var ink = type in ["PaperButton", "LightBlockButton"]
		for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			set_color(color, type, Color.BLACK if ink else tokens.text_color)
		set_color("font_outline_color", type, Color.BLACK)
		set_constant("outline_size", type, 1 if ink else 3)
	set_type_variation("ResourcePanel", "PanelContainer")
	set_stylebox("panel", "ResourcePanel", _texture_box(preload("res://ui/design_system/icons/common/small_bg.png")))
	set_type_variation("ArtworkPanel", "PanelContainer")
	set_stylebox("panel", "ArtworkPanel", _box(tokens.panel_color.lightened(0.03), Color.TRANSPARENT, 0, 0))
	for type in ["FooterTabButton"]:
		set_type_variation(type, "Button")
		var normal = _box(tokens.panel_color.lightened(0.03), Color.TRANSPARENT, 0, 0)
		var selected = _box(tokens.selected_color, tokens.accent_color, 0, 0)
		if type == "FooterTabButton": selected.border_width_bottom = 3
		for style in [normal, selected]:
			for side in ["left", "top", "right", "bottom"]: style.set("content_margin_" + side, 0)
		for state in ["normal", "disabled"]: set_stylebox(state, type, normal)
		for state in ["pressed", "hover"]: set_stylebox(state, type, selected)
		set_stylebox("focus", type, _box(Color.TRANSPARENT, tokens.focus_color, 2, 0))
		set_font_size("font_size", type, tokens.body_font_size)

## 返回旗牌直接绘制透明素材，各交互状态只改变材质明度。
func _build_close_variation() -> void:
	set_type_variation("CloseButton", "Button")
	var texture: Texture2D = preload("res://ui/design_system/icons/common/com_btn/btn_page_return.png")
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := _texture_box(texture)
		var brightness: float = tokens.entry_normal_brightness
		if state == "hover": brightness = tokens.entry_hover_brightness
		elif state in ["pressed", "hover_pressed"]: brightness = tokens.entry_pressed_brightness
		style.modulate_color = Color(brightness, brightness, brightness, 0.45 if state == "disabled" else 1.0)
		set_stylebox(state, "CloseButton", style)
	set_stylebox("focus", "CloseButton", _box(Color.TRANSPARENT, tokens.focus_color, 2, tokens.corner_radius))

## 图标操作共用无底色反馈，Home 入口继承同一组明度令牌。
func _build_icon_variations() -> void:
	set_type_variation("IconButton", "ArtworkButton")
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		set_stylebox(state, "IconButton", StyleBoxEmpty.new())
	for state in ["normal", "hover", "pressed"]:
		var brightness: float = tokens.get("entry_" + state + "_brightness")
		set_color(state + "_tint", "IconButton", Color(brightness, brightness, brightness, 1))
	for state in ["hover", "pressed", "hover_pressed", "focus"]:
		set_color("font_" + state + "_color", "IconButton", tokens.text_color)
		set_color("icon_" + state + "_color", "IconButton", Color.WHITE)

	set_type_variation("HomeEntryButton", "IconButton")

## 按控件尺寸呈现原始材质，不叠加描边或放大素材自带黑边。
func _texture_box(texture: Texture2D) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = texture
	for side in ["left", "top", "right", "bottom"]: style.set("content_margin_" + side, 0)
	return style

## 单个可复用样式只包含通用表面，不承载 Feature 状态。
func _box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = tokens.space_small * 1.5
	style.content_margin_right = tokens.space_small * 1.5
	style.content_margin_top = tokens.space_small
	style.content_margin_bottom = tokens.space_small
	return style
