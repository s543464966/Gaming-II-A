extends MarginContainer
## 天赋中的分类培养视图，只提交星石培养与免费晋升，不持有另一份成长状态。

const LABELS = {"Hero": "ui.category.hero", "Minion": "ui.category.minion", "Item": "ui.category.item_card"}
const ICONS = {"Hero": 0, "Minion": 600, "Item": 200}
var session: PlayerSessionState
var persist: Callable
var overlays: CanvasLayer
var _panels: Dictionary = {}
var _revision: int = 0

## 借用当前会话及统一保存入口，卡牌专属碎片不进入此页。
func bind_player(player: PlayerSessionState, save: Callable, overlay: CanvasLayer) -> void:
	session = player
	persist = save
	overlays = overlay
	if is_node_ready(): _initialize_view()

## 注入先于入树或晚于入树均沿用同一初始化路径。
func _ready() -> void:
	_initialize_view()

## 固定三类使用同一个场景条目，文字、进度与费用只绑定正式规则。
func _initialize_view() -> void:
	if session == null or not _panels.is_empty(): return
	visibility_changed.connect(func(): _revision += 1)
	for category: String in CollectionState.CATEGORIES:
		var panel: Control = $Scroll/Column.get_node(category)
		_panels[category] = panel
		var icon := AtlasTexture.new()
		icon.atlas = preload("res://ui/design_system/icons/common/catalog_categories.svg")
		icon.region = Rect2(ICONS[category], 0, 100, 100)
		panel.get_node("Column/Header/Icon").texture = icon
		panel.get_node("Column/Header/Title").text = LABELS[category]
		panel.get_node("Column/Action").pressed.connect(_request.bind(category))
	session.changed.connect(refresh)
	refresh()

## 刷新保留滚动位置，余额变化不推导培养档位。
func refresh() -> void:
	if not is_node_ready() or session == null: return
	$Scroll/Column/Balance.text = ContentText.format_key("ui.growth.balance", {"amount": session.assets.star_stone})
	for category: String in _panels:
		var panel: Control = _panels[category]
		var status: Dictionary = session.collection.training_status(category, session.assets)
		panel.get_node("Column/Header/Stars").text = "★".repeat(status.star) + "☆".repeat(5 - status.star)
		panel.get_node("Column/Strength").text = ContentText.format_key("ui.growth.strength", {"value": RuleText.number(status.multiplier * 100)})
		panel.get_node("Column/Progress").max_value = status.step_count
		panel.get_node("Column/Progress").value = status.steps
		panel.get_node("Column/Progress").visible = not status.maxed
		panel.get_node("Column/Status").text = ContentText.text("ui.growth.maxed") if status.maxed else ContentText.format_key("ui.growth.progress", {"current": status.steps, "total": status.step_count})
		var button: Button = panel.get_node("Column/Action")
		button.text = ContentText.text("ui.growth.maxed") if status.maxed else ContentText.text("ui.growth.promote") if status.can_promote else ContentText.format_key("ui.growth.train", {"cost": status.cost})
		button.disabled = session.busy or not persist.is_valid() or not (status.can_train or status.can_promote)

## 捕获当前分类状态后延后打开确认，切页或重复消息不能提交旧进度。
func _request(category: String) -> void:
	if not is_visible_in_tree(): return
	var expected: Dictionary = session.collection.category_growth[category].duplicate(true)
	_confirm.call_deferred(category, expected, _revision)

## 培养确认说明本次费用；晋升确认不重复收费，页面隐藏后取消提交。
func _confirm(category: String, expected: Dictionary, revision: int) -> void:
	if not is_inside_tree() or not is_visible_in_tree() or revision != _revision or session.collection.category_growth[category] != expected: return
	var status: Dictionary = session.collection.training_status(category, session.assets)
	if not status.can_train and not status.can_promote: return
	var promote: bool = status.can_promote
	var message: Callable = func(): return ContentText.format_key("ui.growth.promote_confirm" if promote else "ui.growth.train_confirm",
		{"category": ContentText.text(LABELS[category]), "cost": status.cost, "star": status.star + 1})
	overlays.confirm(message, func():
		if not is_instance_valid(self) or not is_visible_in_tree() or revision != _revision: return
		var failure: String = session.promote_category(category, expected, persist) if promote else session.train_category(category, expected, persist)
		overlays.toast("ui.growth.success" if failure.is_empty() else failure), "ui.growth.promote" if promote else "ui.growth.title")

## 原生译文变化后重绑动态格式，既有选择与培养事实不变。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): refresh.call_deferred()
