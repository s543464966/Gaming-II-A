class_name UnavailableView
extends Control
## 未开放功能共用居中的黑金提示；标题和可选类别由页面提供，不创建业务动作。

@export var title: String = ""
@export var kind: String = ""

## 场景保留半尺寸原图边角，按安全区域等比排版，不拉伸材质或文字。
func _ready() -> void:
	resized.connect(_layout)
	$Panel.minimum_size_changed.connect(_layout)
	present(title, kind)
	_layout()

## 普通页面只显示标题与状态；模式可额外显示 PVP 等已有类别。
func present(caption: String, category: String = "") -> void:
	title = caption
	kind = category
	if not is_node_ready(): return
	$Panel/Column/Title.text = title
	$Panel/Column/Kind.text = kind
	$Panel/Column/Kind.visible = not kind.is_empty()
	_layout.call_deferred()

## 同一设计比例适配整个页面或内容区，长译文只增高卡片，不越出可用区域。
func _layout() -> void:
	if not is_node_ready() or is_queued_for_deletion() or size.x <= 0 or size.y <= 0: return
	var factor: float = minf(size.x / 941.0, size.y / 1672.0) * 2.0
	var panel: PanelContainer = $Panel
	panel.size = Vector2(306.5, maxf(220, panel.get_combined_minimum_size().y))
	factor = minf(factor, size.y * 0.8 / panel.size.y)
	panel.scale = Vector2.ONE * factor
	panel.position = (size - panel.size * factor) * 0.5
