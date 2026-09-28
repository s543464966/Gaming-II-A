class_name DonutCompletionView
extends Control
## 在餐台底部显示自动切关反馈，末关提供重玩入口，不遮挡棋盘。

signal continue_requested


## 将末关重玩操作交给页面。
func _ready() -> void:
	$Continue.pressed.connect(continue_requested.emit)


## 根据关卡目录更新末关文案，导航数据仍由会话持有。
func present(level_index: int) -> void:
	var has_next: bool = level_index + 1 < DonutLevel.catalog().size()
	$Heading.text = "本关完成" if has_next else "全部关卡完成"
	$Detail.text = "即将进入下一关" if has_next else ""
	$Continue.visible = not has_next
