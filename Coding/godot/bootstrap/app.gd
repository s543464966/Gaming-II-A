extends Node
## 在持续存活的 App 中完成资源准备，再向关卡页面显式注入会话。

const HOME_SCENE: String = "res://features/home/ui/home_screen.tscn"
const DELIVERY: Script = preload("res://services/content_delivery.gd")

var _delivery: Node
@onready var _loading: Control = $Overlay/Loading
@onready var _status: Label = $Overlay/Loading/Panel/Status
@onready var _retry: Button = $Overlay/Loading/Panel/Retry


## 离线包立即进入关卡；带清单的测试包先准备远程贴图。
func _ready() -> void:
	if not FileAccess.file_exists(DELIVERY.MANIFEST_PATH):
		_show_game()
		return
	_delivery = DELIVERY.new()
	$Services.add_child(_delivery)
	_delivery.phase_changed.connect(func(message: String) -> void: _status.text = message)
	_retry.pressed.connect(_retry_download)
	_loading.show()
	_prepare_content.call_deferred()


## 成功挂载后才实例化依赖远程贴图的关卡场景。
func _prepare_content() -> void:
	_status.text = "正在加载游戏资源…"
	_retry.hide()
	var ready: bool = await _delivery.prepare()
	if not is_inside_tree():
		return
	if ready:
		_loading.hide()
		_show_game()
	else:
		_status.text = _delivery.error
		_retry.show()


## 玩家点击后重试同一份随包清单，不改变当前包的资源版本。
func _retry_download() -> void:
	_prepare_content.call_deferred()


## 页面进入树前完成会话注入，服务与 Overlay 不随页面重建。
func _show_game() -> void:
	var scene: PackedScene = load(HOME_SCENE)
	if scene == null:
		_loading.show()
		_status.text = "关卡资源无法加载，请重新打包。"
		_retry.hide()
		return
	var page: Control = scene.instantiate()
	page.initialize(DonutSession.new())
	$SceneContainer.add_child(page)
