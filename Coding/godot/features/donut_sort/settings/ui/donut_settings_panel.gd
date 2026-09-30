class_name DonutSettingsPanel
extends ColorRect
## 管理设置、选关与重开界面，只通过信号请求修改关卡会话。

signal level_selected(index: int)
signal restart_selected
signal sidebar_failed
signal lessons_requested

var page_index: int = 0
var current_level: int = 0


## 绑定稳定控件并根据关卡目录填充可选关卡。
func _ready() -> void:
	$Card/Resume.pressed.connect(close)
	$Card/Restart.pressed.connect(_on_restart_pressed)
	$Card/Sidebar.pressed.connect(_on_sidebar_pressed)
	$Card/Previous.pressed.connect(_change_page.bind(-1))
	$Card/Next.pressed.connect(_change_page.bind(1))
	$Card/Lessons.pressed.connect(func() -> void: close(); lessons_requested.emit())
	_show_page()


## 每页十关保留可点击尺寸，不把百个按钮塞入同一面板。
func _show_page() -> void:
	for child: Node in $Card/Choices.get_children():
		$Card/Choices.remove_child(child)
		child.queue_free()
	var levels: Array = DonutLevel.catalog()
	for index: int in range(page_index * 10, mini(levels.size(), page_index * 10 + 10)):
		var button := Button.new()
		button.text = "第 %d 关\n%s" % [index + 1, levels[index].title]
		button.custom_minimum_size = Vector2(218, 130)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 26)
		button.pressed.connect(_on_level_pressed.bind(index))
		$Card/Choices.add_child(button)
	$Card/Page.text = "%d / %d" % [page_index + 1, ceili(levels.size() / 10.0)]
	$Card/Previous.disabled = page_index == 0
	$Card/Next.disabled = (page_index + 1) * 10 >= levels.size()


## 翻页只改变选关展示，不触碰当前局面。
func _change_page(direction: int) -> void:
	page_index = clampi(page_index + direction, 0, (DonutLevel.catalog().size() - 1) / 10)
	_show_page()


## 从关卡标题展示选关面板。
func show_level_selection() -> void:
	_open("选择关卡")


## 从齿轮展示设置面板。
func show_settings() -> void:
	_open("游戏设置")


## 展示设置与选关操作，按宿主能力配置侧边栏入口。
func _open(heading: String) -> void:
	page_index = current_level / 10
	_show_page()
	$Card/Heading.text = heading
	$Card/Detail.text = "切关或重开将重置本局，包括已解锁的周转盒"
	var sidebar: Button = $Card/Sidebar
	sidebar.visible = _sidebar_available()
	if sidebar.visible:
		$Card/Resume.offset_right = 270.0
		$Card/Restart.offset_left = 290.0
		$Card/Restart.offset_right = 508.0
	else:
		$Card/Resume.offset_right = 379.0
		$Card/Restart.offset_left = 419.0
		$Card/Restart.offset_right = 746.0
	show()


## 关闭面板，不修改当前关卡和道具。
func close() -> void:
	hide()


## 玩家选关后关闭面板，交由页面提交关卡请求。
func _on_level_pressed(index: int) -> void:
	close()
	level_selected.emit(index)


## 玩家重开后关闭面板，交由页面提交关卡请求。
func _on_restart_pressed() -> void:
	close()
	restart_selected.emit()


## 仅在抖音宿主确认支持侧边栏时提供复访入口。
func _sidebar_available() -> bool:
	if not OS.has_feature("douyin") or not OS.has_feature("web"):
		return false
	var bridge: JavaScriptObject = JavaScriptBridge.get_interface("__donutDouyinSidebar")
	return bridge != null and bridge.available == true


## 侧边栏请求失败时告知页面显示反馈。
func _on_sidebar_pressed() -> void:
	close()
	var bridge: JavaScriptObject = JavaScriptBridge.get_interface("__donutDouyinSidebar")
	if bridge == null or bridge.open() != true:
		sidebar_failed.emit()
