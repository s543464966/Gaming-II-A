class_name DonutAudio
extends Node
## 持有局内循环配乐与单次音效，跟随页面暂停并限制密集落位声。

const MOVE_INTERVAL_MS: int = 70

var ticks_msec: Callable = Time.get_ticks_msec
var _active: bool = false
var _last_move_ms: int = -MOVE_INTERVAL_MS
@onready var music: AudioStreamPlayer = $Music
@onready var move_sound: AudioStreamPlayer = $Move
@onready var clear_sound: AudioStreamPlayer = $Clear
@onready var pack_sound: AudioStreamPlayer = $Pack


## 离开页面即停止所有播放实例，避免已移出场景树的配乐仍占用音频服务。
func _exit_tree() -> void:
	_active = false
	music.stop()
	stop_effects()


## 页面恢复时续播配乐，隐藏或后台时清除短音效而不补播。
func set_active(value: bool) -> void:
	_active = value
	if _active and not music.has_stream_playback():
		music.play()
	music.stream_paused = not _active
	if not _active:
		stop_effects()


## 只响应动画实际到达的落位、归纳与入盒节点，不监听规则提交。
func play_cue(cue: StringName) -> void:
	if not _active or not can_process():
		return
	match cue:
		&"move":
			var now: int = ticks_msec.call()
			if now - _last_move_ms < MOVE_INTERVAL_MS:
				return
			_last_move_ms = now
			move_sound.play()
		&"clear":
			clear_sound.play()
		&"pack":
			pack_sound.play()


## 动画中断时结束全部短音效，配乐不随搬运、撤回或切关重启。
func stop_effects() -> void:
	move_sound.stop()
	clear_sound.stop()
	pack_sound.stop()
