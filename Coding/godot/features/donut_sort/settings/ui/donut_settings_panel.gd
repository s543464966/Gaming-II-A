class_name DonutSettingsPanel
extends ColorRect
## 管理设置、选关与重开界面，只通过信号请求修改关卡会话。

signal level_selected(index: int)
signal restart_selected
signal sidebar_failed


## 绑定稳定控件并根据关卡目录填充可选关卡。
func _ready() -> void:
	$Card/Resume.pressed.connect(close)
	$Card/Restart.pressed.connect(_on_restart_pressed)
	$Card/Sidebar.pressed.connect(_on_sidebar_pressed)
	var levels: Array = DonutLevel.catalog()
	for index: int in levels.size():
		var button := Button.new()
		button.text = "第 %d 关\n%s" % [index + 1, levels[index].title]
		button.custom_minimum_size = Vector2(218, 130)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 26)
		button.pressed.connect(_on_level_pressed.bind(index))
		$Card/Choices.add_child(button)


## 从关卡标题展示选关面板。
func show_level_selection() -> void:
	_open("选择关卡")


## 从齿轮展示设置面板。
func show_settings() -> void:
	_open("游戏设置")


## 展示设置与选关操作，按宿主能力配置侧边栏入口。
func _open(heading: String) -> void:
	$Card/Heading.text = heading
	$Card/Detail.text = "切关或重开会清空当前进度"
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
