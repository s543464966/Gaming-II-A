class_name AttributeText
extends RichTextLabel
## 原生行内图标排版；普通文本逐段写入，名称和译文不能注入 BBCode。

signal symbol_pressed(stat: String)
var content: String = ""

## 字体和图标共同响应主题，页面语言切换由详情重新绑定文本。
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	fit_content = true
	scroll_active = false
	bbcode_enabled = false
	selection_enabled = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	meta_clicked.connect(_symbol_clicked)
	theme_changed.connect(_render)
	_render()

## 更新当前语义内容，不计算属性或查找玩家状态。
func present(value: String) -> void:
	content = value
	if is_node_ready(): _render()

## 图标与文字使用相同行高，悬停提示只标注该图标的真实名称。
func _render() -> void:
	if not is_node_ready(): return
	clear()
	var pattern := RegEx.new()
	pattern.compile("\\[stat:([a-z_]+)\\]")
	var offset: int = 0
	var icon_size: int = get_theme_font_size("normal_font_size") + 4
	for token: RegExMatch in pattern.search_all(content):
		add_text(content.substr(offset, token.get_start() - offset))
		var stat: String = token.get_string(1)
		if AttributeIcons.TEXTURES.has(stat):
			var description: String = AttributeIcons.label(stat)
			push_meta(stat, RichTextLabel.META_UNDERLINE_NEVER, description)
			add_image(AttributeIcons.TEXTURES[stat], icon_size, icon_size, Color.WHITE, INLINE_ALIGNMENT_CENTER, Rect2(), stat, false, description, false, false, description)
			pop()
		else: add_text(token.get_string())
		offset = token.get_end()
	add_text(content.substr(offset))
	accessibility_name = AttributeIcons.plain(content)

## 点击只发送已登记属性，外部字符串不能触发其他动作。
func _symbol_clicked(value: Variant) -> void:
	if value is String and AttributeIcons.TEXTURES.has(value): symbol_pressed.emit(value)
