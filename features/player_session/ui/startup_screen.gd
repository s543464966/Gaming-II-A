extends Control
## 仅在启动故障或旧存档选择时显示；不提供认证、注册或创建第二个玩家。

const UI = preload("res://ui/components/ui.gd")
signal navigation_requested(id: String)
signal retry_requested
signal player_selected(identity: String)
var accounts: PlayerSessionController
var platform: Node
var localization: LocalizationService
@onready var _body: VBoxContainer = $SafeArea/Margin/Column/Scroll/Body

## 注入只读启动状态和安全区服务，恢复操作通过信号交还 App。
func configure(controller: PlayerSessionController, host: Node) -> void:
	accounts = controller
	platform = host

## 正常启动不经过本页；F6 只呈现布局，不创建玩家数据。
func _ready() -> void:
	$SafeArea.configure(platform)
	UI.bind_text($SafeArea/Margin/Column/Subtitle, func():
		var title = ContentText.text("ui.startup.title")
		return "Game unavailable" if title == "ui.startup.title" else title)
	UI.bind_text($SafeArea/Margin/Column/Footnote, func():
		var notice = ContentText.text("ui.startup.local_player")
		return "Local saves are stored on this device." if notice == "ui.startup.local_player" else notice)
	var selector = preload("res://ui/components/language_selector.tscn").instantiate()
	selector.service = localization
	$SafeArea/Margin/Column.add_child(selector)
	if accounts == null:
		_body.add_child(UI.label("此页面仅预览启动异常布局；请运行 bootstrap/app.tscn。"))
		return
	refresh()

## 旧目录存在多个玩家时只允许选择已有存档，不显示注册或密码输入。
func refresh() -> void:
	UI.clear(_body)
	_body.add_child(UI.bound_label(_startup_text))
	for profile in accounts.legacy_profiles:
		var button = UI.button(profile.label, func(): player_selected.emit(profile.user_id))
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_body.add_child(button)
	var retry = UI.button("ui.startup.retry", func(): retry_requested.emit())
	if ContentText.text("ui.startup.retry") == "ui.startup.retry": retry.text = "Retry"
	_body.add_child(retry)

## 翻译资源自身不可用时保留最小可读提示，不显示内部路径和诊断。
func _startup_text() -> String:
	var text = ContentText.text(accounts.startup_error)
	if text == accounts.startup_error:
		return "Unable to load game data. Your saved files have not been replaced. Please retry or repair the game."
	return text
