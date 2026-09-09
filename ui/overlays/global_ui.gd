extends CanvasLayer
## 唯一全局对话框与轻提示，由主场景 Overlay 持有。

const DIALOG = "res://ui/overlays/confirmation_dialog.tscn"
const TOAST = "res://ui/overlays/toast.tscn"
const CONTENT = "res://ui/overlays/content_popup.tscn"
const DOWNLOAD = "res://ui/overlays/content_download.tscn"
var modal: Control
var _underlay: ContentPopup
var toast_root: Control
var _platform: Node
var _audio: AudioService
var _preparing_content: bool = false

## 全局层在场景暂停时仍可关闭设置或取消对话框。
func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

## 平台与音频依赖由主场景显式注入，不依赖父节点的脚本字段。
func configure(platform: Node, audio: AudioService = null) -> void:
	_platform = platform
	_audio = audio

## 完整包或已缓存资源立即通过，下载等待只覆盖现有页面，不制造第二个应用入口。
func prepare_content(delivery: Node, keys: Variant = null) -> bool:
	if delivery == null or delivery.pending(keys).is_empty(): return true
	if delivery.busy or _preparing_content: return false
	_preparing_content = true
	close_modal()
	var panel: Control = load(DOWNLOAD).instantiate()
	panel.delivery = delivery
	panel.keys = keys
	panel.platform = _platform
	modal = panel
	add_child(panel)
	if _audio != null: _audio.play_ui_cue("sfx.ui.open", -6.0)
	var ready: bool = await panel.finished
	_preparing_content = false
	if modal == panel: close_modal()
	return ready

## 同时最多存在一个确认；替换或导航后旧对话框不能提交操作。
func confirm(message: Variant, accepted: Callable, title: Variant = "ui.common.confirm_title") -> void:
	if modal is ContentPopup:
		_underlay = modal
		_underlay.process_mode = Node.PROCESS_MODE_DISABLED
	else: close_modal()
	var dialog = load(DIALOG).instantiate()
	dialog.title = title
	dialog.message = message
	dialog.platform = _platform
	dialog.canceled.connect(_close_confirmation)
	dialog.accepted.connect(func():
		if modal != dialog: return
		_close_confirmation()
		if accepted.is_valid(): accepted.call())
	modal = dialog
	add_child(dialog)
	if _audio != null: _audio.play_ui_cue("sfx.ui.open", -6.0)

## 所有内容详情共用小弹窗，Feature 只提供查询与动作，不改变页面路由。
func open_content(presentation: Callable, actions: Callable = Callable()) -> ContentPopup:
	close_modal()
	var popup: ContentPopup = load(CONTENT).instantiate()
	popup.presentation = presentation
	popup.actions = actions
	popup.platform = _platform
	popup.close_requested.connect(close_modal)
	modal = popup
	add_child(popup)
	if _audio != null: _audio.play_ui_cue("sfx.ui.open", -6.0)
	return popup

## 取消或完成确认恢复原详情；导航使用 close_modal 一次撤销整组浮层。
func _close_confirmation() -> void:
	if _audio != null: _audio.play_ui_cue("sfx.ui.close", -6.0)
	if is_instance_valid(modal):
		GameUI.dismiss(modal)
	modal = _underlay
	_underlay = null
	if is_instance_valid(modal):
		modal.process_mode = Node.PROCESS_MODE_ALWAYS
		modal.refresh()

## 关闭模态不会隐式提交业务动作。
func close_modal() -> void:
	var closing: Array = [modal, _underlay]
	var had_open_overlay: bool = closing.any(func(node): return is_instance_valid(node))
	modal = null
	_underlay = null
	for node in closing:
		if not is_instance_valid(node): continue
		GameUI.dismiss(node)
		if node is ContentPopup: node.closed.emit()
	if had_open_overlay and _audio != null: _audio.play_ui_cue("sfx.ui.close", -6.0)

## 错误或成功反馈不接收输入，不阻挡后续业务操作。
func toast(message: Variant, duration: float = 3.5) -> void:
	if message is String and message.is_empty(): return
	if is_instance_valid(toast_root):
		remove_child(toast_root)
		toast_root.queue_free()
	toast_root = load(TOAST).instantiate()
	toast_root.message = message
	toast_root.platform = _platform
	toast_root.duration = duration
	add_child(toast_root)
