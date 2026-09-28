class_name DonutUndoHistory
extends RefCounted
## 只保存玩家操作前的完整会话快照，恢复与道具扣费仍由会话执行。

var _states: Array[Dictionary] = []


## 切关或重开时丢弃旧关卡历史。
func clear() -> void:
	_states.clear()


## 保存一次玩家操作前的独立快照。
func remember(state: Dictionary) -> void:
	_states.append(state)


## 查询是否有可恢复的玩家操作。
func has_entry() -> bool:
	return not _states.is_empty()


## 取出最近一次操作前的快照，调用方负责原子恢复。
func take() -> Dictionary:
	return _states.pop_back()
