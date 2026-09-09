@tool
extends EditorExportPlugin
## 小游戏导出时派生紧凑配乐，原始 OGG、资源键及桌面播放配置保持不变。

const MUSIC_ROOT = "res://game_content/audio/music/"
const LOCK = "res://tooling/export/dependencies.json"
const SCRIPT = "res://tooling/export/minigame_audio_export_plugin.gd"
const BITRATE = "64k"
const SAMPLE_RATE = "32000"
var _temporary: String = ""
var _encoder: String = ""
var _variants: Dictionary[String, AudioStreamOggVorbis] = {}

## 使用独立名称区分语言筛选和音频制作职责。
func _get_name() -> String:
	return "MagicAMinigameAudio"

## 只处理两个小游戏平台，普通 Web 和原生平台继续使用原始音频。
func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformExtension and platform._get_name() in ["MagicA Douyin", "MagicA WeChat"]

## 每次导出拥有独立临时目录，不复用来源不明的转码缓存。
func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	_variants.clear()
	_encoder = verified_encoder()
	if _encoder.is_empty():
		_fail("配乐编码器缺失或校验失败，请先运行 Tooling/environment/prepare_dependencies.mjs。")
		return
	_temporary = "res://tooling/.runtime/minigame-audio-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(_temporary) != OK:
		_temporary = ""
		_fail("无法创建配乐制作临时目录。")

## 原生资源定制负责更新包内重映射，不手工拼装或覆盖引擎缓存。
func _begin_customize_resources(platform: EditorExportPlatform, _features: PackedStringArray) -> bool:
	return _supports_platform(platform)

## 同一首曲目只转码一次；失败报错交给导出门禁，不伪装成优化成功。
func _customize_resource(resource: Resource, path: String) -> Resource:
	if not path.begins_with(MUSIC_ROOT) or not path.ends_with(".ogg") or not resource is AudioStreamOggVorbis: return null
	if _temporary.is_empty() or _encoder.is_empty():
		_fail("配乐制作环境未准备好: " + path)
		return null
	if not _variants.has(path):
		var variant := encode(resource, path, _encoder, _temporary)
		if variant == null:
			_fail("配乐转码或时长校验失败: " + path)
			return null
		_variants[path] = variant
	return _variants[path]

## 配置、编码器和实现共同决定定制缓存，素材变化由引擎依赖检测处理。
func _get_customization_configuration_hash() -> int:
	return (FileAccess.get_sha256(LOCK) + FileAccess.get_sha256(SCRIPT)).hash()

## 只清理本次创建的配乐文件，临时制品不进入产品资源或下一次导出。
func _export_end() -> void:
	_variants.clear()
	if not _temporary.is_empty():
		for file: String in DirAccess.get_files_at(_temporary): DirAccess.remove_absolute(_temporary.path_join(file))
		DirAccess.remove_absolute(_temporary)
	_temporary = ""
	_encoder = ""

## 制作机器目前固定为 macOS ARM64；二进制必须与产品依赖锁完全一致。
static func verified_encoder() -> String:
	var lock: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LOCK))
	var encoder: Dictionary = lock.get("audio_encoder", {})
	if OS.get_name() != "macOS" or Engine.get_architecture_name() != "arm64" or encoder.get("host") != "darwin-arm64": return ""
	var path: String = "res://tooling/.runtime/export-dependencies/" + str(encoder.get("binary", ""))
	if FileAccess.get_sha256(path) != encoder.get("binary_sha256", "invalid"): return ""
	return ProjectSettings.globalize_path(path)

## 保留完整立体声曲目及循环边界；固定参数去除可变元数据，使重复导出可复现。
static func encode(source: AudioStreamOggVorbis, path: String, encoder: String, directory: String) -> AudioStreamOggVorbis:
	var output: String = directory.path_join(path.sha256_text() + ".ogg")
	var diagnostics: Array = []
	var args := PackedStringArray(["-nostdin", "-v", "error", "-i", ProjectSettings.globalize_path(path), "-map", "0:a:0", "-vn",
		"-c:a", "libvorbis", "-b:a", BITRATE, "-ar", SAMPLE_RATE, "-ac", "2", "-fflags", "+bitexact", "-flags:a", "+bitexact",
		"-map_metadata", "-1", ProjectSettings.globalize_path(output)])
	if OS.execute(encoder, args, diagnostics, true) != 0: return null
	var result := AudioStreamOggVorbis.load_from_file(output)
	if result == null or absf(result.get_length() - source.get_length()) > 0.01: return null
	result.loop = source.loop
	result.loop_offset = source.loop_offset
	result.bpm = source.bpm
	result.beat_count = source.beat_count
	result.bar_beats = source.bar_beats
	return result

## 同时记录引擎导出错误和标准错误，退出码为零也不能通过工作区门禁。
func _fail(message: String) -> void:
	get_export_platform().add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR, "Minigame audio", message)
	push_error(message)
