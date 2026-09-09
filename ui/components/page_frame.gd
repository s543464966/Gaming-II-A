extends Control
## 标准功能页统一拥有全屏底图、左上角页头和安全区内的业务内容。

signal close_requested
@export var title: String = "页面"
@export var background_texture: Texture2D = preload("res://ui/design_system/themes/page_background.tres")
@export var background_shade: Color = Color.TRANSPARENT
var _platform: Node
@onready var content: VBoxContainer = $SafeArea/Bounds/Margin/Column/Content
@onready var header: HBoxContainer = $SafeArea/Bounds/Margin/Column/Header
@onready var close_button: Button = $SafeArea/Bounds/Margin/Column/Header/Back
@onready var background: TextureRect = $Background

## 平台只提供安全区，业务内容不必各自计算屏幕边距。
func configure(platform: Node) -> void:
	_platform = platform

## 框架不判断业务页面类型，也不调用应用导航。
func _ready() -> void:
	$SafeArea.configure(_platform)
	background.texture = background_texture
	$Shade.color = background_shade
	header.get_node("Title").text = title
	close_button.pressed.connect(func(): close_requested.emit())

## 业务页可在标题右侧挂载固定内容，位置与安全区仍由同一个页头负责。
func add_header_content(view: Control) -> void:
	var trailing: HBoxContainer = header.get_node("Trailing")
	trailing.add_child(view)
	trailing.show()
