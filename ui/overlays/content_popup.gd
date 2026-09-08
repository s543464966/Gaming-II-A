class_name ContentPopup
extends Control
## 紧凑内容弹窗只绑定展示数据与业务动作，滚动和关闭不改变底层页面。

signal close_requested
signal closed
var presentation: Callable
var actions: Callable
var platform: Node
var _layout_queued: bool = false
var _language_font: Font
var _reading_fonts: Dictionary = {}
@onready var detail: ContentDetail = $SafeArea/Bounds/Panel/Column/Card/Column/Scroll/Detail
@onready var action_bar: VBoxContainer = $SafeArea/Bounds/Panel/Column/Supplement/Column/Actions
@onready var scroll: ScrollContainer = $SafeArea/Bounds/Panel/Column/Card/Column/Scroll
@onready var panel: PanelContainer = $SafeArea/Bounds/Panel
@onready var card_panel: PanelContainer = $SafeArea/Bounds/Panel/Column/Card
@onready var supplement: PanelContainer = $SafeArea/Bounds/Panel/Column/Supplement
@onready var growth: ContentGrowth = $SafeArea/Bounds/Panel/Column/Supplement/Column/Growth
@onready var title: Label = $SafeArea/Bounds/Panel/Column/Card/Column/Title

## 静态场景负责遮罩、标题、关闭和滚动区，不创建另一份内容状态。
func _ready() -> void:
	$Shade.color = GameUI.tokens.modal_shade
	$SafeArea.configure(platform)
	$SafeArea/Bounds.gui_input.connect(_outside_input)
	$SafeArea/Bounds.resized.connect(_layout)
	get_viewport().size_changed.connect(_queue_layout)
	detail.minimum_size_changed.connect(_queue_layout)
	supplement.minimum_size_changed.connect(_queue_layout)
	card_panel.resized.connect(_queue_layout)
	scroll.resized.connect(_fit_preview)
	title.resized.connect(_queue_layout)
	title.get_node("Close").pressed.connect(close_requested.emit)
	refresh()
	panel.grab_focus()

## 业务方重新查询当前口径；重绑不重置阅读位置或提交交易。
func refresh() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_node_ready() or not presentation.is_valid(): return
	var value: Dictionary = presentation.call()
	if value.is_empty():
		close_requested.emit()
		return
	_sync_reading_fonts()
	title.get_node("Close").accessibility_name = ContentText.text("ui.common.close")
	var offset: int = scroll.scroll_vertical
	title.text = value.entry.name
	detail.present(value.entry, value.detail)
	growth.present(value.detail.get("growth", {}))
	GameUI.clear(action_bar)
	if actions.is_valid(): actions.call(value.entry, action_bar)
	for button in action_bar.get_children():
		if button is Button:
			button.theme = theme
			button.theme_type_variation = &"DetailActionButton"
			if "compact" in button: button.compact = true
			else: button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, GameUI.tokens.detail_action_height)
	action_bar.visible = action_bar.get_child_count() > 0
	supplement.visible = growth.visible or action_bar.visible
	_layout()
	scroll.set_deferred("scroll_vertical", offset)

## 详情及内嵌卡面使用同一清晰字体副本，切语言时替换旧副本，不修改共享资源。
func _sync_reading_fonts() -> void:
	var shared: Theme = preload("res://ui/design_system/themes/game_theme.tres")
	if _language_font == shared.default_font: return
	_language_font = shared.default_font
	_reading_fonts.clear()
	var reading_theme := Theme.new()
	reading_theme.merge_with(shared)
	reading_theme.default_font = _reading_font(shared.default_font)
	for type in [&"DetailTitle", &"DetailHeading", &"DetailActionButton"]:
		reading_theme.set_font(&"font", type, _reading_font(shared.get_font(&"font", type)))
	var previous: Theme = theme
	theme = reading_theme
	for control: Control in find_children("*", "Control", true, false):
		if control.theme == shared or control.theme == previous: control.theme = reading_theme

## 字体按原始身份复用局部副本，额外采样避免手机缩放把低分辨率字形放大。
func _reading_font(source: Font) -> Font:
	if source == null: return null
	if _reading_fonts.has(source): return _reading_fonts[source]
	var font: Font = source.duplicate()
	_reading_fonts[source] = font
	if font is FontFile: font.oversampling = 2.0
	elif font is FontVariation: font.base_font = _reading_font(source.base_font)
	var fallbacks: Array[Font] = []
	for fallback: Font in source.fallbacks: fallbacks.append(_reading_font(fallback))
	font.fallbacks = fallbacks
	return font

## 两个独立面板整体居中限高；卡牌正文滚动，成长与操作位于其下方的可选面板。
func _layout() -> void:
	_layout_queued = false
	if not is_inside_tree() or is_queued_for_deletion() or not is_node_ready(): return
	var available: Vector2 = $SafeArea/Bounds.size
	var tokens: DesignTokens = GameUI.tokens
	# 手机窗口缩小了全局逻辑画布，在安全区内补偿详情字号，保持实际阅读尺寸。
	var viewport_scale: float = get_viewport().get_final_transform().get_scale().x
	var reading_scale: float = clampf(0.72 / maxf(viewport_scale, 0.01), 1, 1.6)
	panel.scale = Vector2.ONE * reading_scale
	var width: float = minf(tokens.detail_popup_width, available.x * 0.84 / reading_scale)
	panel.size.x = width
	var chrome: float = panel.get_combined_minimum_size().y
	var height: float = minf(chrome + detail.get_combined_minimum_size().y, minf(tokens.detail_popup_height, available.y * 0.76 / reading_scale))
	panel.size = Vector2(width, height)
	panel.position = (available - panel.size * reading_scale) * 0.5
	var paper: Control = $SafeArea/Bounds/Paper
	var paper_top: float = title.size.y - 14
	paper.scale = panel.scale
	paper.position = panel.position + (card_panel.position + Vector2(0, paper_top)) * reading_scale
	paper.size = Vector2(card_panel.size.x, maxf(0, card_panel.size.y - paper_top))

## 正文视口改变时保持整张卡面可见，不改变卡牌定义或能力排版内容。
func _fit_preview() -> void:
	detail.fit_preview(scroll.size.y)

## 容器完成文字换行后再重新限高，不依赖逐帧轮询。
func _queue_layout() -> void:
	if _layout_queued or not is_inside_tree() or is_queued_for_deletion(): return
	_layout_queued = true
	_layout.call_deferred()

## 点按遮罩仅关闭弹窗，事件不得穿透为卡牌移动或底层按钮操作。
func _outside_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		close_requested.emit()

## 返回键与点按遮罩等价，不改变收藏选择或战斗状态。
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()

## 切语言重绑同一弹窗，长译文仍在原滚动容器中排版。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): refresh.call_deferred()
