class_name UserState
extends RefCounted
## 账号资料与体力恢复；时间使用 UTC 秒，不受场景暂停影响。

signal changed
const STAMINA_MAX = 100
const RECOVERY_SECONDS = 300
var name: String = "勇者"
var stamina: int = 50
var settled_at: int = 0
var tutorial_completed: bool = false
var dice_capacity: int = 2
var auto_play: bool = false

## 先验证完整资料再替换字段；损坏存档不转换类型或静默修正数值。
func restore(state: Dictionary) -> String:
	if not state.get("name") is String:
		return "账号名称格式损坏。"
	for field: String in ["tutorial_completed", "auto_play"]:
		if not state.get(field) is bool:
			return "账号资料布尔字段损坏: " + field
	for field: String in ["stamina", "settled_at", "dice_capacity"]:
		if not state.get(field) is int or state[field] < 0:
			return "账号资料数值损坏: " + field
	name = state.name
	stamina = state.stamina
	settled_at = state.settled_at
	tutorial_completed = state.tutorial_completed
	dice_capacity = state.dice_capacity
	auto_play = state.auto_play
	return ""

## 保留不足一周期的秒数；系统时间回拨时重置基准。
func settle(now: int) -> void:
	var before = stamina
	if settled_at <= 0 or now < settled_at or stamina >= STAMINA_MAX:
		settled_at = now
	else:
		var recovered = mini((now - settled_at) / RECOVERY_SECONDS, STAMINA_MAX - stamina)
		stamina += recovered
		settled_at = now if stamina >= STAMINA_MAX else settled_at + recovered * RECOVERY_SECONDS
	if before != stamina: changed.emit()

## 扣体力先结算自然恢复，不足时保持扣款状态不变。
func spend(amount: int, now: int) -> bool:
	settle(now)
	if amount < 0 or stamina < amount: return false
	if stamina >= STAMINA_MAX: settled_at = now
	stamina -= amount
	changed.emit()
	return true

## 奖励体力完整入账，允许超过自然恢复上限；溢出期间暂停自然恢复。
func grant_stamina(amount: int, now: int) -> bool:
	if amount <= 0 or stamina > 9223372036854775807 - amount: return false
	settle(now)
	if stamina > 9223372036854775807 - amount: return false
	stamina += amount
	if stamina >= STAMINA_MAX: settled_at = now
	changed.emit()
	return true

## 体力说明中的下一点和回满剩余秒数。
func recovery_times(now: int) -> Vector2i:
	if stamina >= STAMINA_MAX: return Vector2i.ZERO
	var next = RECOVERY_SECONDS - maxi(0, now - settled_at) % RECOVERY_SECONDS
	return Vector2i(next, next + (STAMINA_MAX - stamina - 1) * RECOVERY_SECONDS)

## 捕获账号资料，不在捕获动作中推进时间。
func capture() -> Dictionary:
	return {"name": name, "stamina": stamina, "settled_at": settled_at, "tutorial_completed": tutorial_completed,
		"dice_capacity": dice_capacity, "auto_play": auto_play}
