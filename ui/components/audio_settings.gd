class_name AudioSettingsControl
extends VBoxContainer
## 复用的音量设置控件；只编辑应用音频偏好，不持有玩家状态。

var service: AudioService
var _syncing: bool = false
@onready var _music: HSlider = $Music/Slider
@onready var _effects: HSlider = $Effects/Slider
@onready var _feedback: Label = $Feedback

## 连接音乐与音效滑杆，并投射服务中的当前设备偏好。
func _ready() -> void:
	_music.value_changed.connect(_level_changed.bind("music"))
	_effects.value_changed.connect(_level_changed.bind("effects"))
	_connect_service()
	_refresh()
	_refresh_accessibility()

## 后加入的暂停面板可在就绪后注入同一个应用服务。
func configure(audio: AudioService) -> void:
	if service == audio: return
	_disconnect_service()
	service = audio
	_connect_service()
	_refresh()

## 玩家拖动时立即试听，持久化防抖由服务统一管理。
func _level_changed(value: float, channel: String) -> void:
	if _syncing or service == null: return
	service.set_level(channel, value)
	_refresh_values()

## 服务变更同时更新滑杆、百分比与可恢复的存储警告。
func _refresh() -> void:
	if not is_node_ready(): return
	_syncing = true
	for slider: HSlider in [_music, _effects]: slider.editable = service != null
	if service != null:
		_music.value = service.level("music")
		_effects.value = service.level("effects")
	_syncing = false
	_refresh_values()
	_feedback.text = ContentText.text(service.preference_warning) if service != null and not service.preference_warning.is_empty() else ""
	_feedback.visible = not _feedback.text.is_empty()

## 百分比标签跟随滑杆，不把显示取整写回实际音量。
func _refresh_values() -> void:
	if not is_node_ready(): return
	$Music/Value.text = "%d%%" % roundi(_music.value * 100.0)
	$Effects/Value.text = "%d%%" % roundi(_effects.value * 100.0)

## 当前服务存在时只连接一次设备设置事件。
func _connect_service() -> void:
	if service != null and not service.settings_changed.is_connected(_refresh): service.settings_changed.connect(_refresh)

## 控件释放或改绑时停止接收长生命周期服务的更新。
func _disconnect_service() -> void:
	if service != null and service.settings_changed.is_connected(_refresh): service.settings_changed.disconnect(_refresh)

## 切换语言只更新无障碍名称，实际音量不变。
func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or not is_node_ready(): return
	_refresh_accessibility()

## 两个滑杆使用当前语言提供明确名称，键盘与读屏均不依赖相邻标签推断。
func _refresh_accessibility() -> void:
	_music.accessibility_name = ContentText.text("ui.audio.music")
	_effects.accessibility_name = ContentText.text("ui.audio.effects")

## 离树时解除应用服务连接，避免设置面板排队释放期间继续刷新。
func _exit_tree() -> void:
	_disconnect_service()
