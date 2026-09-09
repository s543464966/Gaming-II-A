extends HBoxContainer
## 商城固定页头只读显示账号资源，总览与详情共用同一实例。

var _session: PlayerSessionState
var _clock: float = 0.0

## 只保留权威会话引用，不复制余额，也不推进体力结算。
func bind_player(player: PlayerSessionState) -> void:
	_session = player

## 事务结束后读取最终余额；可见性恢复时立即更新缓存页面。
func _ready() -> void:
	visibility_changed.connect(refresh)
	if _session != null: _session.changed.connect(refresh)
	refresh()

## 体力自然恢复及非交易更新沿用每秒刷新，只处理当前可见的商城页头。
func _process(delta: float) -> void:
	if _session == null or not is_visible_in_tree(): return
	_clock += delta
	if _clock < 1.0: return
	_clock = 0.0
	refresh()

## 保存失败后的事务通知同样读取回滚余额，不展示尚未提交的变化。
func refresh() -> void:
	if not is_node_ready() or _session == null or _session.busy: return
	$Gold/Value.text = str(_session.assets.gold)
	$StarStone/Value.text = str(_session.assets.star_stone)
	$Stamina/Value.text = "%d/%d" % [_session.user.stamina, _session.user.STAMINA_MAX]

## 离开场景立即停止接收长生命周期会话通知。
func _exit_tree() -> void:
	if _session != null and _session.changed.is_connected(refresh): _session.changed.disconnect(refresh)
