extends VBoxContainer
## 遗迹与事件共用紧凑资源栏，只读账号余额并向宿主请求设置。

signal settings_requested
var _session: PlayerSessionState
var _elapsed: float = 0.0

## 原生设置按钮沿用触摸取消，页面标题由当前节点提供。
func _ready() -> void:
	$Resources/Settings.pressed.connect(func(): settings_requested.emit())

## 配置只更换只读会话引用，不推进章节或体力事务。
func configure(player: PlayerSessionState, title: String) -> void:
	_session = player
	$Title.text = title
	_refresh()

## 可见时跟随体力自然恢复，购买与奖励页面重建时立即刷新。
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_elapsed += delta
	if _elapsed < 1.0: return
	_elapsed = 0.0
	_refresh()

## 数值每次读取最终 Owner，事务失败后的回滚不留下临时余额。
func _refresh() -> void:
	if _session == null or _session.busy: return
	$Resources/Gold/Value.text = str(_session.assets.gold)
	$Resources/StarStone/Value.text = str(_session.assets.star_stone)
	$Resources/Stamina/Value.text = "%d/%d" % [_session.user.stamina, _session.user.STAMINA_MAX]
