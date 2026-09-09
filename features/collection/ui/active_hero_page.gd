extends VBoxContainer
## 独立出战英雄页：浏览候选只更新预览，明确确认后才更换账号与章节英雄。

const Preview = preload("res://ui/components/content/content_preview.gd")
const Card = preload("res://features/collection/ui/hero_candidate.tscn")
var session: PlayerSessionState
var progression: AdventureProgression
var overlays: CanvasLayer
var selected_id: String = ""
var _roster_ids: Array = []
var _revision: int = 0

## Home 注入切换用例，页面不自己重置路线或保存第二份英雄选择。
func bind_player(player: PlayerSessionState, flow: AdventureProgression, overlay: CanvasLayer) -> void:
	session = player
	progression = flow
	overlays = overlay

## 场景拥有当前详情、候选横向目录和唯一确认按钮。
func _ready() -> void:
	$Confirm.pressed.connect(_request_change)
	visibility_changed.connect(func(): _revision += 1)
	if session == null:
		$Confirm.disabled = true
		return
	selected_id = session.collection.selected_hero
	session.changed.connect(refresh)
	refresh()

## 事务回滚后重新读取会话；候选身份仍合法时保持浏览位置。
func refresh() -> void:
	if not is_node_ready() or session == null: return
	_apply_reading_theme()
	var ids: Array = []
	for row: Dictionary in session.content.data.cards:
		if row.card_kind == CardTypes.Kind.CoreHero and session.collection.owns(row.id): ids.append(row.id)
	if not selected_id in ids: selected_id = session.collection.selected_hero
	if ids != _roster_ids:
		_roster_ids = ids
		GameUI.clear($Roster/Cards)
		for id: String in ids:
			var card: Button = Card.instantiate()
			card.name = id
			card.custom_minimum_size = Vector2(142, 188)
			card.toggle_mode = true
			card.pressed.connect(_preview.bind(id))
			$Roster/Cards.add_child(card)
	for card: Button in $Roster/Cards.get_children():
		var id: String = str(card.name)
		var entry: Dictionary = Preview.entry(session.content, "cards", session.content.get_record("cards", id))
		entry.face = Preview.card_face(session.collection.definition(id))
		entry.owned = true
		card.get_node("Picture").present(entry)
		card.set_pressed_no_signal(id == selected_id)
		card.get_node("Selection").visible = id == selected_id
		card.tooltip_text = entry.name
	var current: Dictionary = session.content.get_record("cards", session.collection.selected_hero)
	$Current.text = ContentText.format_key("ui.hero.current", {"name": ContentText.field(current)})
	_present()

## 全页正文采用可读字号，独立卡面仍使用原有组件的字体与标准尺寸。
func _apply_reading_theme() -> void:
	var reading := Theme.new()
	reading.merge_with(preload("res://ui/design_system/themes/game_theme.tres"))
	for type: String in ["DetailBody", "DetailValue", "DetailHeading", "DetailCaption", "DetailTagText"]:
		reading.set_font_size("font_size", type, 22 if type in ["DetailCaption", "DetailTagText"] else 26)
	for type: String in ["DetailRichBody", "DetailRichValue", "DetailRichCaption"]:
		reading.set_font_size("normal_font_size", type, 22 if type == "DetailRichCaption" else 26)
	$Paper/Scroll/Detail.theme = reading

## 轻点候选只更换只读详情，不调用切换用例，不弹出交易确认。
func _preview(id: String) -> void:
	if not is_visible_in_tree() or not id in _roster_ids: return
	selected_id = id
	_revision += 1
	for card: Button in $Roster/Cards.get_children():
		card.set_pressed_no_signal(str(card.name) == id)
		card.get_node("Selection").visible = str(card.name) == id
	$Paper/Scroll.scroll_vertical = 0
	_present()

## 共用标准卡面与永久属性详情，不展示培养或专属碎片进度。
func _present() -> void:
	var row: Dictionary = session.content.get_record("cards", selected_id)
	if row.is_empty(): return
	$Name.text = ContentText.field(row)
	$Paper/Scroll/Detail.present(Preview.entry(session.content, "cards", row), Preview.permanent_detail(session.collection.definition(selected_id)))
	var selected: bool = selected_id == session.collection.selected_hero
	$Confirm.text = "ui.collection.current_hero" if selected else "ui.hero.change"
	$Confirm.disabled = selected or session.busy or session.collection.cards[selected_id].health_ratio <= 0 or session.current_route().phase == RouteState.Phase.NodeInProgress

## 确认捕获原英雄和候选；页面关闭、切换候选或外部状态变化会使请求失效。
func _request_change() -> void:
	if not is_visible_in_tree() or $Confirm.disabled: return
	_confirm_change.call_deferred(selected_id, session.collection.selected_hero, _revision)

## 只有存在路线进度或临时构筑时提示重置风险，新账号使用普通更换确认。
func _confirm_change(candidate: String, original: String, revision: int) -> void:
	if not _can_commit(candidate, original, revision): return
	var route: RouteState = session.current_route()
	var has_progress: bool = route.current >= 0 or route.completed or (session.build.started and (session.build.cards.size() > 1 or not session.build.relics.is_empty() or session.build.pending_reward or session.build.cards.any(func(card): return card.copies > 1)))
	var message: Callable = func(): return ContentText.text("ui.collection.change_warning") if has_progress else ContentText.format_key("ui.hero.confirm", {"name": ContentText.field(session.content.get_record("cards", candidate))})
	overlays.confirm(message, func():
		if not is_instance_valid(self) or not _can_commit(candidate, original, revision): return
		var failure: String = progression.change_hero(candidate)
		overlays.toast("ui.collection.changed" if failure.is_empty() else failure), "ui.hero.change")

## 延迟回调只允许当前可见页面提交当时确认的候选。
func _can_commit(candidate: String, original: String, revision: int) -> bool:
	return is_inside_tree() and is_visible_in_tree() and _revision == revision and selected_id == candidate and session.collection.selected_hero == original and candidate != original and session.collection.owns(candidate)

## 动态标题与属性随语言重绑，不更换账号英雄。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): refresh.call_deferred()
