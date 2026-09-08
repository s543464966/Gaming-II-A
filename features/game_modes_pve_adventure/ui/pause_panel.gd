class_name AdventurePausePanel
extends PanelContainer
## 设置的原生暂停操作层；暂停所有权和导航仍留在页面协调器。

const UI = preload("res://ui/components/ui.gd")
signal continued
signal reload_requested
signal exit_requested

## 稳定按钮只发送动作，不自行保存、放弃战斗或修改场景树暂停状态。
func _ready() -> void:
	$SafeArea/Margin/Content/Continue.pressed.connect(func(): continued.emit())
	$SafeArea/Margin/Content/Actions/Reload.pressed.connect(func(): reload_requested.emit())
	$SafeArea/Margin/Content/Actions/Exit.pressed.connect(func(): exit_requested.emit())
	UI.tokens.changed.connect(_apply_tokens)
	_apply_tokens()

## 设置只绑定标题和安全区，不再承担卡牌详情排版。
func configure(title: String, platform: Node) -> void:
	$SafeArea.configure(platform)
	$SafeArea/Margin/Content/Title.text = title

## 边距随共享令牌变化，不在运行脚本里重建另一套业务布局。
func _apply_tokens() -> void:
	for side in ["left", "top", "right", "bottom"]:
		$SafeArea/Margin.add_theme_constant_override("margin_" + side, UI.tokens.page_margin)

## 移除页面时立即解绑共享资源，避免排队释放期间继续刷新。
func _exit_tree() -> void:
	if UI.tokens.changed.is_connected(_apply_tokens): UI.tokens.changed.disconnect(_apply_tokens)

## 汇总逐份保留已使用和未使用遗物，不提供状态编辑入口。
func show_relics(content: GameCatalog, records: Array) -> void:
	var list: VBoxContainer = $SafeArea/Margin/Content/Scroll/Body/RelicHistory
	UI.clear(list)
	if records.is_empty(): list.add_child(UI.label("ui.relic.empty", 22))
	for record: Dictionary in records:
		var row: Dictionary = content.get_record("relics", record.content_id)
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"DetailSupplement"
		var box := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = content.resource(row.texture_key)
		box.add_child(icon)
		var status: String = "ui.relic.used" if record.consumed else ("ui.relic.unused" if row.usage == ContentTypes.RelicUsage.Consumable else "ui.relic.persistent")
		box.add_child(UI.bound_label(func(): return ContentText.field(row) + " · " + tr(status) + "\n" + RuleText.relic(row), 22))
		panel.add_child(box)
		list.add_child(panel)
