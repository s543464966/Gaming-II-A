extends Node
## 为动态展示文字响应原生语言通知，不重建控件或更改业务状态。

var evaluate: Callable

## 父控件已有布局，只更新文字属性。
func _ready() -> void:
	refresh()

## 切语言仅重算展示值，输入和交互身份保持不变。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): refresh.call_deferred()

## 业务页面离开后不再执行旧的文字回调。
func refresh() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not evaluate.is_valid(): return
	get_parent().text = evaluate.call()
