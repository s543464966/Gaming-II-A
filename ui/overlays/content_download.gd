extends Control
## 阻断当前内容入口的下载反馈，取消不提交业务操作，失败由玩家决定是否重试。

signal finished(success: bool)
var delivery: Node
var keys: Array = []
var platform: Node
var _finished: bool = false

## 布局保持在场景中，只绑定资源准备状态与动作。
func _ready() -> void:
	$SafeArea.configure(platform)
	delivery.progress.connect(_progress)
	$SafeArea/Center/Panel/Column/Actions/Cancel.pressed.connect(_cancel)
	$SafeArea/Center/Panel/Column/Actions/Retry.pressed.connect(_start)
	_start.call_deferred()

## 重试复用已经校验的包，不重新下载完成部分。
func _start() -> void:
	$SafeArea/Center/Panel/Column/Error.hide()
	$SafeArea/Center/Panel/Column/Actions/Retry.hide()
	var ready: bool = await delivery.prepare(keys)
	if _finished or not is_inside_tree(): return
	if ready:
		_finished = true
		finished.emit(true)
	else:
		$SafeArea/Center/Panel/Column/Error.show()
		$SafeArea/Center/Panel/Column/Actions/Retry.show()

## 百分比按已经校验并挂载的字节更新，不把响应开始误报为完成。
func _progress(done: int, total: int) -> void:
	$SafeArea/Center/Panel/Column/Progress.value = 100.0 * done / maxi(1, total)

## 取消和导航关闭都只结束本次等待。
func _cancel() -> void:
	if _finished: return
	_finished = true
	delivery.cancel()
	finished.emit(false)

## 全局层被释放时取消仍在运行的下载并解除信号。
func _exit_tree() -> void:
	_cancel()
	if is_instance_valid(delivery) and delivery.progress.is_connected(_progress): delivery.progress.disconnect(_progress)
