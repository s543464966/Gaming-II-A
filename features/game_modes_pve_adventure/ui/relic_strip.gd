class_name AdventureRelicStrip
extends "res://ui/components/touch_scroll_container.gd"
## 棋盘下方逐份显示未消耗遗物，战斗中只读取回放宿主帧。

signal inspected(content_id: String)
const UI = preload("res://ui/components/ui.gd")
var records: Array = []
var _content: GameCatalog

## 保留独立展示快照，开战存盘不提前改变回放画面。
func configure(content: GameCatalog, values: Array) -> void:
	_content = content
	records = values.duplicate(true)
	_refresh()

## 消耗由战报决定，移除一份图标时不合并或隐藏同名剩余份数。
func apply_frame(frame: Dictionary) -> void:
	var changed: bool = false
	for host: Dictionary in frame.get("host_states", []):
		if not host.get("consumed", false): continue
		for record: Dictionary in records:
			if record.id == host.id and not record.consumed:
				record.consumed = true
				changed = true
	if changed: _refresh()

## 横向小图标保持棋盘空间，详情与状态文字使用正式内容来源。
func _refresh() -> void:
	if not is_node_ready() or _content == null: return
	UI.clear($Items)
	visible = records.any(func(record): return not record.consumed)
	for record: Dictionary in records:
		if record.consumed: continue
		var row: Dictionary = _content.get_record("relics", record.content_id)
		var button: Button = preload("res://ui/components/touch_button.gd").new()
		button.custom_minimum_size = Vector2(68, 68)
		button.theme_type_variation = &"DetailActionButton"
		button.icon = _content.resource(row.texture_key)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 54)
		var usage: String = ContentText.text("ui.relic.consumable" if row.usage == ContentTypes.RelicUsage.Consumable else "ui.relic.persistent")
		button.tooltip_text = ContentText.field(row) + " · " + usage + "\n" + RuleText.relic(row)
		button.set_meta("relic_id", record.id)
		button.pressed.connect(func(): inspected.emit(row.id))
		$Items.add_child(button)

## 切换语言只更新当前图标说明，不重取持有状态。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _refresh.call_deferred()
