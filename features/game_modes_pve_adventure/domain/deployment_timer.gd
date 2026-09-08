class_name DeploymentTimer
extends RefCounted
## 部署计时不依赖场景；冲突保留剩余时间，归零仍需最终占位校验。

signal second_changed(second: int)
signal completed
var remaining: float = 0.0
var running: bool = false
var _announced: int = -1

## 开启一次十五秒准备阶段。
func begin(duration: float = 15.0) -> void:
	assert(duration > 0 and is_finite(duration))
	remaining = duration
	running = true
	_announced = -1
	_publish()

## 只有完成最终校验才发出一次开战信号。
func tick(delta: float, blocked: bool = false, can_complete: Callable = Callable()) -> void:
	if not running or blocked or delta <= 0: return
	remaining = maxf(0, remaining - delta)
	_publish()
	if remaining > 0: return
	if can_complete.is_valid() and not can_complete.call(): return
	running = false
	completed.emit()

## 取消不触发自动开战。
func cancel() -> void:
	running = false
	remaining = 0
	_announced = -1

## 显示秒数向上取整且仅在变化时通知界面。
func _publish() -> void:
	var value = ceili(remaining)
	if value != _announced:
		_announced = value
		second_changed.emit(value)
