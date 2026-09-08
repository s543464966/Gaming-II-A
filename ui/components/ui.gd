class_name GameUI
extends RefCounted
## 原生 Control 组件工厂；只管理样式和布局，不含 Feature 业务。

const THEME = preload("res://ui/design_system/themes/game_theme.tres")
static var tokens: DesignTokens = preload("res://ui/design_system/tokens/default_tokens.tres")
const BUTTON = preload("res://ui/components/button.tscn")
const SafeArea = preload("res://ui/components/safe_area.gd")

## 创建覆盖视口的安全内容根，不缩放或裁剪背景。
static func safe_area(parent: Node, platform: Node = null) -> Control:
	var wrapper = SafeArea.new()
	wrapper.configure(platform)
	parent.add_child(wrapper)
	var content = Control.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.add_child(content)
	return content

## 默认文字可折行，长规则通过父级滚动区域查看。
static func label(text: String, size: int = -1) -> Label:
	var node = Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if size > 0: node.add_theme_font_size_override("font_size", size)
	return node

## 动态文本通过只读回调重算，插入的账号名或内容 ID 不再参与自动翻译。
static func bind_text(node: Control, evaluate: Callable) -> void:
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var binding = preload("res://ui/components/localized_text_binding.gd").new()
	binding.evaluate = evaluate
	node.add_child(binding)

## 创建保留布局和身份的动态本地化标签。
static func bound_label(evaluate: Callable, size: int = -1) -> Label:
	var node = label("", size)
	bind_text(node, evaluate)
	return node

## 标准按钮保持触摸高度、键盘焦点和可读文字。
static func button(text: String, action: Callable = Callable()) -> Button:
	var node = BUTTON.instantiate()
	node.text = text
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if action.is_valid(): node.pressed.connect(action)
	return node

## 图片保留透明边缘和比例，不强行拉伸角色。
static func texture(value: Texture2D, minimum: Vector2 = Vector2(120, 160)) -> TextureRect:
	var node = TextureRect.new()
	node.texture = value
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = minimum
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

## 清空动态内容前移出树，避免排队释放残留占布局。
static func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

## 输入回调关闭面板时立即停止显示和交互，保留到帧末释放以免悬空触摸焦点。
static func dismiss(control: Control) -> void:
	if not is_instance_valid(control) or control.is_queued_for_deletion(): return
	control.hide()
	control.process_mode = Node.PROCESS_MODE_DISABLED
	control.queue_free()

## 为任意 Control 建立一致边距的竖直内容容器。
static func column(parent: Node, margin: int = -1) -> VBoxContainer:
	var wrapper = MarginContainer.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]: wrapper.add_theme_constant_override("margin_" + side, tokens.page_margin if margin < 0 else margin)
	parent.add_child(wrapper)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.add_child(box)
	return box

## 长内容使用原生滚动容器，禁用横向溢出。
static func scroll(parent: Node) -> VBoxContainer:
	var scroll = TouchScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return content
