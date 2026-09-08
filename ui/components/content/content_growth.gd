class_name ContentGrowth
extends VBoxContainer
## 独立展示升星碎片和进度，不读取账号或持有升星事务。

## 宽度稳定后测量译文，紧凑数值不挤碎片名称。
func _ready() -> void:
	resized.connect(_layout_header)

## 数量沿用真实升星门槛，无成长数据时整体收起，满星显示状态并隐藏进度条。
func present(status: Dictionary) -> void:
	visible = not status.is_empty()
	if status.is_empty(): return
	$Header/Fragments.visible = status.cost > 0
	$Header/Count.text = ContentText.text("ui.collection.star_max") if status.cost == 0 else "%s / %s" % [status.quantity, status.cost]
	$Progress.visible = status.cost > 0
	$Progress.max_value = maxi(status.cost, 1)
	$Progress.value = status.quantity
	_layout_header.call_deferred()

## 一行放得下时左右对齐，长译文与大数值各占一行，满星状态独占整行。
func _layout_header() -> void:
	if not is_node_ready() or is_queued_for_deletion(): return
	var fragments: Label = $Header/Fragments
	var count: Label = $Header/Count
	var caption_width: float = fragments.get_theme_font("font").get_string_size(fragments.tr(fragments.text), HORIZONTAL_ALIGNMENT_LEFT, -1, fragments.get_theme_font_size("font_size")).x
	var count_width: float = count.get_theme_font("font").get_string_size(count.text, HORIZONTAL_ALIGNMENT_LEFT, -1, count.get_theme_font_size("font_size")).x
	var inline: bool = fragments.visible and caption_width + count_width + $Header.get_theme_constant("h_separation") <= size.x
	$Header.columns = 2 if inline else 1
	count.size_flags_horizontal = Control.SIZE_FILL if inline else Control.SIZE_EXPAND_FILL
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if fragments.visible else HORIZONTAL_ALIGNMENT_CENTER

## 语言与字体变化后重新测量，不复用前一种语言的断行位置。
func _notification(what: int) -> void:
	if what in [NOTIFICATION_THEME_CHANGED, NOTIFICATION_TRANSLATION_CHANGED] and is_node_ready(): _layout_header.call_deferred()
