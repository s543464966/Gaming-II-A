class_name AudioService
extends Node
## 应用级音频生命周期：管理音乐切换、一次性音效、总线音量与设备偏好。

signal settings_changed
const PREFERENCE := "audio_preferences.json"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const SFX_POOL_SIZE := 12
const UI_CUE_REPLACEMENT_WINDOW_MSEC := 24
const BUTTON_FEEDBACK_GAP_MSEC := 110
const DEFAULT_LEVELS: Dictionary[String, float] = {"music": 1.0, "effects": 1.0}
var error: String = ""
## 损坏偏好保持原文件，只允许本次会话调整音量。
var preference_warning: String = ""
var current_music_key: String = ""
var _levels: Dictionary[String, float] = DEFAULT_LEVELS.duplicate()
var _saved_levels: Dictionary[String, float] = DEFAULT_LEVELS.duplicate()
var _catalog: GameCatalog
var _repository: RefCounted
var _preference_can_save: bool = true
var _music_players: Array[AudioStreamPlayer] = []
var _sfx_players: Array[AudioStreamPlayer] = []
var _active_music: int = -1
var _sfx_cursor: int = 0
var _music_fade: Tween
var _save_timer: Timer
var _suspended: bool = false
var _last_ui_cue_msec: int = -UI_CUE_REPLACEMENT_WINDOW_MSEC
var _last_button_feedback_msec: int = -BUTTON_FEEDBACK_GAP_MSEC
var _last_ui_key: String = ""

## 建立最小音频总线和固定播放池；服务跟随 App 持续存活。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	for index: int in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % (index + 1)
		player.bus = MUSIC_BUS
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_music_players.append(player)
	for index: int in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%02d" % (index + 1)
		player.bus = SFX_BUS
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_players.append(player)
	_save_timer = Timer.new()
	_save_timer.name = "PreferenceSave"
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.25
	_save_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.timeout.connect(_save_preferences)
	add_child(_save_timer)
	_apply_levels()

## 内容加载成功后恢复设备音量；音频偏好不属于玩家进度。
func initialize(catalog: GameCatalog, repository: RefCounted) -> void:
	stop_music(0.0)
	_catalog = catalog
	_repository = repository
	error = ""
	preference_warning = ""
	_preference_can_save = true
	_levels = DEFAULT_LEVELS.duplicate()
	_saved_levels = DEFAULT_LEVELS.duplicate()
	if _repository != null and _repository.exists(PREFERENCE):
		var preference: Dictionary = _repository.read(PREFERENCE, _valid_preference)
		if not _repository.error.is_empty():
			_preference_can_save = false
			preference_warning = "ui.audio.preference_unreadable"
		else:
			for channel: String in DEFAULT_LEVELS: _levels[channel] = float(preference[channel])
			_saved_levels = _levels.duplicate()
			if _repository.recovered_from_backup: preference_warning = "ui.audio.preference_recovered"
	_apply_levels()
	settings_changed.emit()

## 返回设置控件需要的线性音量，范围固定为 0～1。
func level(channel: String) -> float:
	return _levels.get(channel, DEFAULT_LEVELS.get(channel, 1.0))

## 音量立即作用于总线，并短暂防抖后写入独立设备偏好。
func set_level(channel: String, value: float) -> void:
	if not DEFAULT_LEVELS.has(channel): return
	var normalized := clampf(value, 0.0, 1.0)
	if is_equal_approx(_levels[channel], normalized): return
	_levels[channel] = normalized
	_apply_levels()
	settings_changed.emit()
	if _repository != null and _preference_can_save: _save_timer.start()

## 相同音乐不重启；两路播放器只负责无缝淡入切换，不持有场景规则。
func play_music(key: String, fade_seconds: float = 0.8) -> void:
	if _catalog == null or key.is_empty() or _suspended: return
	if key == current_music_key and _active_music >= 0 and _music_players[_active_music].playing: return
	var stream: Resource = _catalog.resource(key, "Audio")
	if not stream is AudioStream:
		push_error("音乐资源不可播放: " + key)
		return
	if not _configure_music_loop(stream): return
	_settle_music_fade()
	var previous := _active_music
	var next := 0 if previous != 0 else 1
	var player := _music_players[next]
	player.stream = stream
	player.volume_linear = 0.0 if fade_seconds > 0.0 else 1.0
	player.play()
	_active_music = next
	current_music_key = key
	if fade_seconds <= 0.0:
		if previous >= 0: _music_players[previous].stop()
		return
	var previous_gain := _music_players[previous].volume_linear if previous >= 0 else 0.0
	_music_fade = create_tween()
	_music_fade.tween_method(_crossfade_music.bind(next, previous, previous_gain), 0.0, 1.0, fade_seconds)
	_music_fade.finished.connect(_music_fade_finished.bind(previous))

## 音乐停止也使用同一淡出路径，离开应用时可立即清理。
func stop_music(fade_seconds: float = 0.35) -> void:
	_settle_music_fade()
	current_music_key = ""
	if _active_music < 0: return
	var stopping := _active_music
	_active_music = -1
	if fade_seconds <= 0.0:
		_music_players[stopping].stop()
		return
	_music_fade = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_music_fade.tween_property(_music_players[stopping], "volume_linear", 0.0, fade_seconds)
	_music_fade.finished.connect(_music_fade_finished.bind(stopping))

## 固定池限制同类叠响；重复声部达到两条后替换最旧播放头。
func play_sfx(key: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if _catalog == null or key.is_empty() or _suspended: return
	var stream: Resource = _catalog.resource(key, "Audio")
	if not stream is AudioStream:
		push_error("音效资源不可播放: " + key)
		return
	var selected := -1
	var matching: Array[int] = []
	for index: int in range(_sfx_players.size()):
		if _sfx_players[index].playing and _sfx_players[index].get_meta("audio_key", "") == key:
			matching.append(index)
	if matching.size() >= 2:
		selected = matching[0]
		for index: int in matching:
			if int(_sfx_players[index].get_meta("audio_started", 0)) < int(_sfx_players[selected].get_meta("audio_started", 0)):
				selected = index
	for offset: int in range(_sfx_players.size()):
		if selected >= 0: break
		var index := (_sfx_cursor + offset) % _sfx_players.size()
		if not _sfx_players[index].playing:
			selected = index
			break
	if selected < 0: selected = _sfx_cursor
	_sfx_cursor = (selected + 1) % _sfx_players.size()
	var player := _sfx_players[selected]
	player.stop()
	player.stream = stream
	player.volume_db = clampf(volume_db, -36.0, 6.0)
	player.pitch_scale = clampf(pitch_scale, 0.75, 1.30)
	player.set_meta("audio_key", key)
	player.set_meta("audio_started", Time.get_ticks_usec())
	player.play()

## 页面离开或表现重置时仅停止所属音效，不触碰其他页面和全局音乐。
func stop_sfx(prefix: String = "") -> void:
	for player: AudioStreamPlayer in _sfx_players:
		if not str(player.get_meta("audio_key", "")).begins_with(prefix): continue
		player.stop()
		player.stream = null

## 玩家输入触发的语义音效替代同次按钮兜底声，避免一个动作叠响两次。
func play_ui_cue(key: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var now := Time.get_ticks_msec()
	var repeated := key == _last_ui_key and now - _last_ui_cue_msec < 95
	_last_ui_cue_msec = now
	_last_ui_key = key
	if repeated: return
	if key in ["sfx.ui.open", "sfx.ui.close"]:
		stop_sfx("sfx.ui.open")
		stop_sfx("sfx.ui.close")
	play_sfx(key, volume_db, pitch_scale)

## 页面根显式登记后，现有与后加入的普通按钮获得低强度材质触感。
func bind_ui(root: Node) -> void:
	if root == null: return
	_bind_ui_node(root)

## 后台或横屏阻断暂停音乐并丢弃短音效；恢复时不补播过期反馈。
func set_suspended(value: bool) -> void:
	if value == _suspended: return
	_suspended = value
	for player: AudioStreamPlayer in _music_players: player.stream_paused = value
	for player: AudioStreamPlayer in _sfx_players:
		if value: player.stop()

## 测试和退出可显式冲刷仍在防抖窗口中的偏好。
func flush_preferences() -> void:
	if _save_timer != null and not _save_timer.is_stopped():
		_save_timer.stop()
		_save_preferences()

## 第一次使用时补齐项目总线，正式工程仍由 default_bus_layout 保存名称。
func _ensure_bus(name: StringName) -> void:
	if AudioServer.get_bus_index(name) >= 0: return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, name)
	AudioServer.set_bus_send(index, &"Master")

## 分类音量只衰减游戏内 Music 与 SFX；Master 保持原始增益并继续服从系统音量。
func _apply_levels() -> void:
	_set_bus_level(&"Master", 1.0)
	_set_bus_level(MUSIC_BUS, _levels.music)
	_set_bus_level(SFX_BUS, _levels.effects)

## 零音量使用静音标记，非零值转换为 Godot 分贝。
func _set_bus_level(bus: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0: return
	AudioServer.set_bus_mute(index, value <= 0.0001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))

## 设备偏好写入失败时保留上次成功文件，并继续使用本次会话音量。
func _save_preferences() -> void:
	if _repository == null or not _preference_can_save or _levels == _saved_levels: return
	error = ""
	if not _repository.write(PREFERENCE, {"version": 1, "music": _levels.music, "effects": _levels.effects}):
		error = "ui.audio.save_failed"
		preference_warning = error
	else:
		_saved_levels = _levels.duplicate()
		preference_warning = ""
	settings_changed.emit()

## 偏好只接受完整有限范围，损坏数据不能被强转成默认值覆盖。
static func _valid_preference(value: Dictionary) -> bool:
	if value.get("version") != 1 or not value.has("music") or not value.has("effects"): return false
	if value.keys().any(func(key: Variant): return key not in ["version", "master", "music", "effects"]): return false
	for channel: String in DEFAULT_LEVELS:
		var level_value: Variant = value.get(channel)
		if not (level_value is int or level_value is float) or not is_finite(float(level_value)) or float(level_value) < 0.0 or float(level_value) > 1.0: return false
	if value.has("master"):
		var legacy_master: Variant = value.master
		if not (legacy_master is int or legacy_master is float) or not is_finite(float(legacy_master)) or float(legacy_master) < 0.0 or float(legacy_master) > 1.0: return false
	return true

## 音乐在创建播放头前补齐整段循环边界，避免零长度循环立即结束。
func _configure_music_loop(stream: Resource) -> bool:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		var end_sample := roundi(wav.get_length() * wav.mix_rate)
		if end_sample <= 0:
			push_error("音乐资源没有可循环的采样: " + wav.resource_path)
			return false
		wav.loop_begin = 0
		wav.loop_end = end_sample
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return true
	if stream is AudioStreamOggVorbis:
		stream.loop = true
		return true
	if stream is AudioStreamMP3:
		stream.loop = true
		return true
	push_error("音乐资源不支持循环: " + stream.resource_path)
	return false

## 等功率交叉淡化避免两首曲目在切换中点同时接近静音。
func _crossfade_music(progress: float, incoming: int, outgoing: int, outgoing_gain: float) -> void:
	var angle := progress * PI * 0.5
	_music_players[incoming].volume_linear = sin(angle)
	if outgoing >= 0: _music_players[outgoing].volume_linear = outgoing_gain * cos(angle)

## 中断淡化时保留较响的一路及当前增益，快速切页不会把微弱的新曲突然推满。
func _settle_music_fade() -> void:
	if _music_fade != null and _music_fade.is_valid(): _music_fade.kill()
	_music_fade = null
	var loudest := -1
	for index: int in range(_music_players.size()):
		if not _music_players[index].playing: continue
		if loudest < 0 or _music_players[index].volume_linear > _music_players[loudest].volume_linear:
			loudest = index
	_active_music = loudest
	for index: int in range(_music_players.size()):
		if index != _active_music: _music_players[index].stop()

## 淡化完成后停止旧播放器，活动播放器继续维持零分贝素材增益。
func _music_fade_finished(stopping: int) -> void:
	if stopping >= 0 and stopping < _music_players.size() and stopping != _active_music: _music_players[stopping].stop()
	_music_fade = null

## 新加入的节点递归接入按钮反馈，同一运行节点只连接一次。
func _bind_ui_node(node: Node) -> void:
	if not node.has_meta("audio_children_bound"):
		node.child_entered_tree.connect(_bind_ui_node)
		node.set_meta("audio_children_bound", true)
	if node is BaseButton and not node.has_meta("audio_button_bound"):
		node.pressed.connect(_button_pressed.bind(node))
		node.set_meta("audio_button_bound", true)
	for child: Node in node.get_children(): _bind_ui_node(child)

## 下拉框保持安静；普通按钮延后到业务回调完成后再决定是否播放兜底声。
func _button_pressed(button: BaseButton) -> void:
	if button is OptionButton or button.get_meta("audio_silent", false): return
	_play_button_fallback.call_deferred(button, Time.get_ticks_msec())

## 同次输入已有打开、关闭、奖励或错误声时保持静默，并限制快速连点的密度。
func _play_button_fallback(button: BaseButton, pressed_at_msec: int) -> void:
	if not is_instance_valid(button) or button.get_meta("audio_silent", false): return
	if abs(_last_ui_cue_msec - pressed_at_msec) <= UI_CUE_REPLACEMENT_WINDOW_MSEC: return
	var now := Time.get_ticks_msec()
	if now - _last_button_feedback_msec < BUTTON_FEEDBACK_GAP_MSEC: return
	_last_button_feedback_msec = now
	play_sfx(str(button.get_meta("audio_cue", "sfx.ui.confirm")), -7.0)

## 退出前保存最后一次滑杆调整并停止全部播放器。
func _exit_tree() -> void:
	flush_preferences()
	stop_music(0.0)
	for player: AudioStreamPlayer in _music_players: player.stream = null
	for player: AudioStreamPlayer in _sfx_players:
		player.stop()
		player.stream = null
	_catalog = null
	_repository = null
