class_name DonutSettingsButton
extends Button
## 使用独立图标表达打开游戏设置的玩家意图。

signal settings_requested


## 将点击转成页面可连接的设置请求。
func _ready() -> void:
	pressed.connect(_on_pressed)


## 页面负责显示设置入口，不由按钮查找场景根节点。
func _on_pressed() -> void:
	settings_requested.emit()
