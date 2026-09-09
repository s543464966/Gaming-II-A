extends Node
## 唯一主场景装配根：持有服务与内容容器，通过显式依赖和导航信号连接页面。

const Catalog = preload("res://game_content/runtime/game_catalog.gd")
const Repository = preload("res://services/save/json_repository.gd")
const Ranking = preload("res://features/social/local_ranking.gd")
const UI = preload("res://ui/components/ui.gd")
## 只登记路径，启动根不提前解析所有页面及其贴图、三维奖励依赖。
const SCENES: Dictionary[String, String] = {
	"startup": "res://features/player_session/ui/startup_screen.tscn",
	"home": "res://features/home/ui/home_screen.tscn",
	"adventure": "res://features/game_modes_pve_adventure/ui/adventure_screen.tscn"
}
signal screen_changed(id: String)
var content: GameCatalog = Catalog.new()
@onready var accounts: PlayerSessionController = $Services/PlayerSession
@onready var platform: GamePlatform = $Services/PlatformService
@onready var localization: LocalizationService = $Services/Localization
@onready var audio: AudioService = $Services/Audio
@onready var delivery: Node = $Services/ContentDelivery
@onready var overlays: CanvasLayer = $Overlay
@onready var scene_container: Control = $SceneContainer
var current_screen: Control
var current_screen_id: String = ""
var _transitioning: bool = false
var _paused_before_block: bool = false
var _environment_blocked: bool = false
var _previous_font: Font
var _applied_font: Font
var _starting: bool = false
var _delivery_directory: String

## 服务只装配一次，后续只更换 SceneContainer 中的内容。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	platform.suspended_changed.connect(_platform_suspended)
	get_viewport().size_changed.connect(_refresh_environment)
	overlays.configure(platform, audio)
	audio.bind_ui(scene_container)
	audio.bind_ui(overlays)
	var directory = OS.get_environment("MAGICA_DATA_DIR")
	var repository = Repository.new(directory if not directory.is_empty() else "user://MagicA")
	_delivery_directory = directory if not directory.is_empty() else "user://MagicA"
	content.delivery = delivery
	var theme: Theme = UI.THEME
	_previous_font = theme.default_font
	localization.locale_changed.connect(_apply_language_font)
	accounts.repository = repository
	_retry_startup()
	_refresh_environment.call_deferred()

## 启动成功直接进入 Home；仅在失败或旧存档歧义时显示恢复页。
func _retry_startup(identity: String = "") -> void:
	if _starting: return
	_starting = true
	var repository = accounts.repository
	if localization.available.is_empty() and not localization.initialize(repository):
		accounts.startup_error = "ui.startup.language_failed"
		accounts.startup_diagnostic = localization.error
	elif not delivery.initialize(_delivery_directory):
		accounts.startup_error = "ui.startup.content_failed"
		accounts.startup_diagnostic = delivery.error
	elif content.load_content():
		audio.initialize(content, repository)
		if accounts.content == null: accounts.initialize(content, repository)
		else: accounts.load_player(identity)
	else:
		accounts.startup_error = "ui.startup.content_failed"
		accounts.startup_diagnostic = "\n".join(content.errors)
	_apply_language_font()
	if accounts.session != null and accounts.startup_error.is_empty():
		var hero: Dictionary = content.get_record("cards", accounts.session.collection.selected_hero)
		var chapter: Dictionary = content.get_record("chapters", accounts.session.selected_chapter)
		if not await overlays.prepare_content(delivery, [hero.get("texture_key", ""), chapter.get("unlocked_background_key", "")]):
			accounts.startup_error = "ui.startup.content_failed"
			accounts.startup_diagnostic = delivery.error
	if not is_inside_tree(): return
	_starting = false
	navigate("home" if accounts.session != null and accounts.startup_error.is_empty() else "startup")

## 语言服务提供已打包字体，所有页面与浮层继续共用同一 Theme。
func _apply_language_font(_locale: String = "") -> void:
	if localization.current_font == null: return
	_applied_font = localization.current_font
	var theme: Theme = UI.THEME
	theme.default_font = _applied_font

## App 释放其字体绑定，编辑器单页预览恢复原设计系统默认值。
func _exit_tree() -> void:
	var theme: Theme = UI.THEME
	if theme.default_font == _applied_font: theme.default_font = _previous_font
	_applied_font = null
	_previous_font = null

## 导航排队至帧边界，重复请求不会在信号回调中销毁当前页面。
func navigate(id: String) -> void:
	if _transitioning or not SCENES.has(id): return
	_transitioning = true
	_replace_screen.call_deferred(id)

## 新页面在入树前得到所需依赖；旧页面的局部状态随场景释放。
func _replace_screen(id: String) -> void:
	if not is_inside_tree(): return
	if id == "adventure" and accounts.session != null and not await overlays.prepare_content(delivery, accounts.progression.required_resource_keys()):
		_transitioning = false
		return
	if id != "startup" and accounts.session == null: id = "startup"
	if id == "startup": audio.stop_music(0.0)
	if not is_inside_tree(): return
	var scene: PackedScene = load(SCENES[id])
	if scene == null or not scene.can_instantiate():
		_transitioning = false
		overlays.toast("ui.startup.content_failed")
		return
	overlays.close_modal()
	if is_instance_valid(current_screen):
		scene_container.remove_child(current_screen)
		current_screen.queue_free()
	_paused_before_block = false
	get_tree().paused = _environment_blocked
	var candidate: Control = scene.instantiate()
	if id in ["startup", "home"]: candidate.localization = localization
	if id == "startup":
		candidate.configure(accounts, platform)
		candidate.content_diagnostic = delivery.diagnostic
		candidate.retry_requested.connect(_retry_startup)
		candidate.player_selected.connect(_retry_startup)
	else:
		candidate.configure(accounts.session, accounts.progression, accounts.save_player, overlays, platform, audio)
		if id == "home": candidate.ranking = _ranking_rows
	candidate.navigation_requested.connect(navigate)
	current_screen = candidate
	current_screen_id = id
	scene_container.add_child(candidate)
	if id == "home":
		var recovery_notice: String = accounts.take_recovery_notice()
		if not recovery_notice.is_empty(): overlays.toast(recovery_notice, 10.0)
	_transitioning = false
	screen_changed.emit(id)

## 排行只向 Home 提供只读结果，不暴露账号仓储。
func _ranking_rows() -> Array:
	return Ranking.rows(accounts.session)

## 平台隐藏保存当前进度，是否恢复时钟由组合环境状态决定。
func _platform_suspended(value: bool) -> void:
	_refresh_environment()
	if value:
		if accounts.session != null: accounts.save_player()
	else:
		if accounts.session != null: accounts.session.user.settle(int(Time.get_unix_time_from_system()))

## 后台和横屏共用一次暂停快照，任一仍有效时都不恢复玩家原有的暂停层。
func _refresh_environment() -> void:
	if not is_node_ready(): return
	var extent = get_viewport().get_visible_rect().size
	var landscape = extent.x > extent.y
	overlays.get_node("OrientationGuard").visible = landscape
	var blocked = platform.suspended or landscape
	audio.set_suspended(blocked)
	if blocked == _environment_blocked: return
	_environment_blocked = blocked
	if blocked:
		_paused_before_block = get_tree().paused
		get_tree().paused = true
		if is_instance_valid(current_screen) and current_screen.has_method("suspend_presentation"):
			current_screen.suspend_presentation()
	else:
		get_tree().paused = _paused_before_block

## 窗口退出只保存一次；不让内容页面自行持有应用级退出逻辑。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(accounts):
		if accounts.session != null: accounts.save_player()
