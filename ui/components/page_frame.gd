extends Control
## 标准功能页框架：底图铺满视口，标题、关闭入口和业务内容仍位于安全区。

signal close_requested
enum Layout { TITLED, IMMERSIVE }
@export var layout_style: Layout = Layout.TITLED
@export var title: String = "页面"
@export var background_texture: Texture2D = preload("res://ui/design_system/themes/page_background.tres")
@export var background_shade: Color = Color.TRANSPARENT
var _platform: Node
@onready var content: VBoxContainer = $SafeArea/Bounds/Margin/Column/Content
@onready var close_button: Button = $SafeArea/Bounds/Close
@onready var background: TextureRect = $Background

## 平台只提供安全区，业务内容不必各自计算屏幕边距。
func configure(platform: Node) -> void:
	_platform = platform

## 框架不判断业务页面类型，也不调用应用导航。
func _ready() -> void:
	$SafeArea.configure(_platform)
	background.texture = background_texture
	$Shade.color = background_shade
	$SafeArea/Bounds/Margin/Column/Header/Title.text = title
	close_button.pressed.connect(func(): close_requested.emit())
	if layout_style == Layout.IMMERSIVE:
		$SafeArea/Bounds/Margin/Column/Header.hide()
		for side in ["left", "top", "right", "bottom"]: $SafeArea/Bounds/Margin.add_theme_constant_override("margin_" + side, 0)
