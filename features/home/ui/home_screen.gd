extends Control
## Home 导航宿主；功能页面按需缓存，账号设置以局部小弹窗覆盖主页。

const UI = preload("res://ui/components/ui.gd")
const ActiveHeroPage = "res://features/collection/ui/active_hero_page.tscn"
const CollectionPage = "res://features/collection/ui/collection_page.tscn"
const EncyclopediaPage = "res://features/encyclopedia/ui/encyclopedia_page.tscn"
const ShopPage = "res://features/shop/ui/shop_page.tscn"
const ShopResources = "res://features/shop/ui/shop_resources.tscn"
const AssetsPage = "res://features/backpack/ui/assets_page.tscn"
const TalentPage = "res://features/talents/ui/talent_page.tscn"
const ModesPage = "res://features/game_modes/ui/game_modes_page.tscn"
const ActivityPage = "res://features/activities/ui/activity_page.tscn"
const Activities = preload("res://features/activities/ui/activity_page.gd")
const SettingsPopup = "res://features/account/ui/settings_popup.tscn"
const Unavailable = "res://ui/components/unavailable_view.tscn"
const PageFrame = "res://ui/components/page_frame.tscn"
signal navigation_requested(id: String)
var session: RefCounted
var progression: RefCounted
var persist: Callable
var overlays: CanvasLayer
var platform: Node
var ranking: Callable
var localization: LocalizationService
var audio: AudioService

## 宿主接收当前会话及用例；导航交回应用主场景。
func configure(player: RefCounted, flow: RefCounted, save: Callable, overlay: CanvasLayer, host: Node, sound: AudioService = null) -> void:
	session = player
	progression = flow
	persist = save
	overlays = overlay
	platform = host
	audio = sound

const PAGES = {
	"GameModes": "ui.page.modes",
	"Collection": "ui.page.collection",
	"ActiveHero": "ui.hero.title",
	"Talents": "ui.page.talents",
	"Encyclopedia": "ui.page.encyclopedia",
	"PlayerAssets": "ui.page.assets",
	"Mall": "ui.page.shop",
	"Activity": Activities.TITLES.Activity,
	"ActivityContractSummon": Activities.TITLES.ActivityContractSummon,
	"ActivityLegendRoad": Activities.TITLES.ActivityLegendRoad,
	"ActivityDailyTask": Activities.TITLES.ActivityDailyTask,
	"ActivitySevenSign": Activities.TITLES.ActivitySevenSign,
	"Social": "ui.page.social",
	"SocialRank": "ui.page.ranking",
	"AccountNotice": "ui.page.notices",
	"Achievements": "ui.page.achievements",
}
var _home: Control
var _safe: Control
var _player_name: Label
var _gold_value: Label
var _star_stone_value: Label
var _stamina_value: Label
var _hero_image: TextureRect
var _mode_summary: Label
var _chapter_caption: Label
var _chapter_progress: Label
var _pages: Dictionary = {}
var _active: String = ""
var _clock: float = 0
var _mode_frame_transition: Tween
var _settings_popup: AccountSettingsPopup
var _preparing_assets: bool = false

## 稳定布局来自可编辑场景；运行时只绑定动作和会话数据。
func _ready() -> void:
	_safe = $SafeArea/Content
	_home = $SafeArea/Content/Home
	_player_name = _home.get_node("TopBar/Player/Name")
	_gold_value = _home.get_node("TopBar/Gold/Row/Value")
	_star_stone_value = _home.get_node("TopBar/StarStone/Row/Value")
	_stamina_value = _home.get_node("TopBar/Stamina/Value")
	_hero_image = _home.get_node("Actions/Hero/Portrait")
	_mode_summary = _home.get_node("Actions/Modes/ModeSummary")
	_chapter_caption = _home.get_node("Actions/Start/Caption")
	_chapter_progress = _home.get_node("Actions/ChapterProgress")
	for dynamic_text in [_player_name, _gold_value, _star_stone_value, _stamina_value, _mode_summary, _chapter_caption, _chapter_progress]:
		dynamic_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	$SafeArea.configure(platform)
	if session == null: return
	if audio != null: audio.play_music("music.home")
	for button in _home.find_children("*", "Button", true, false):
		if button.has_meta("page_id"): button.pressed.connect(_open_entry.bind(button))
	_home.get_node("Actions/Start").pressed.connect(_enter_adventure)
	_refresh_header()

## 首页入口只按页面身份导航，未开放社交不再区分页签。
func _open_entry(button: Button) -> void:
	open_page(str(button.get_meta("page_id")))

## 顶栏读取权威会话，事务回滚后不显示未提交数值。
func _process(delta: float) -> void:
	if session == null or not is_instance_valid(_player_name): return
	_clock += delta
	if _clock >= 1:
		_clock = 0
		_refresh_header()

## 同页再次点击关闭，打开其他页会关闭旧页及未提交模态。
func open_page(id: String) -> void:
	if PAGES.has(id) and not await _prepare_assets(_page_resource_keys(id)): return
	if id == "AccountSettings":
		_open_settings()
		return
	if not PAGES.has(id): return
	if _active == id:
		close_page()
		return
	close_page()
	if not _pages.has(id): _create_page(id)
	_active = id
	_home.hide()
	$Background.visible = id == "GameModes"
	_pages[id].root.show()
	var body: Control = _pages[id].body
	if body.has_method("refresh"): body.refresh()
	elif id == "SocialRank": _populate_static(id, body)

## 页面关闭不维护历史栈，不卸载缓存页面。
func close_page() -> void:
	overlays.close_modal()
	_close_settings()
	if _mode_frame_transition != null and _mode_frame_transition.is_valid(): _mode_frame_transition.kill()
	_mode_frame_transition = null
	$ImmersiveShade.hide()
	$ImmersiveShade.modulate.a = 0
	for page in _pages.values():
		if page.body.has_method("cancel_transition"): page.body.cancel_transition()
		page.root.hide()
	_active = ""
	$Background.show()
	if is_instance_valid(_home): _home.show()
	if is_instance_valid(_player_name): _refresh_header()

## 页面边框与关闭层属于宿主，具体内容仍由 Feature 拥有。
func _create_page(id: String) -> void:
	var root = load(PageFrame).instantiate()
	root.name = id
	root.title = PAGES[id]
	root.configure(platform)
	if id in ["Collection", "Encyclopedia", "ActiveHero"]:
		root.background_texture = load("res://ui/design_system/themes/immersive_background.png")
		root.background_shade = Color(0, 0, 0, 0.14)
	root.close_requested.connect(close_page)
	add_child(root)
	root.hide()
	var column: VBoxContainer = root.content
	var body: Control
	match id:
		"Collection":
			body = load(CollectionPage).instantiate()
			body.bind_player(session, overlays)
		"ActiveHero":
			body = load(ActiveHeroPage).instantiate()
			body.bind_player(session, progression, overlays)
		"Encyclopedia":
			body = load(EncyclopediaPage).instantiate()
			body.catalog = session.content
		"Mall":
			var resources = load(ShopResources).instantiate()
			resources.bind_player(session)
			root.add_header_content(resources)
			body = load(ShopPage).instantiate()
			body.bind_player(session, persist, overlays)
			body.return_requested.connect(close_page)
		"PlayerAssets":
			body = load(AssetsPage).instantiate()
			body.bind_player(session)
		"Talents":
			body = load(TalentPage).instantiate()
			body.bind_player(session, persist, overlays)
		"GameModes":
			body = load(ModesPage).instantiate()
			body.bind_player(session, progression, overlays)
			body.bind_background(root.background)
			body.chapter_confirmed.connect(close_page)
			body.return_requested.connect(close_page)
			body.transition_started.connect(_mode_transition_started.bind(root))
			body.transition_finished.connect(_mode_transition_finished.bind(root))
		"Activity", "ActivityContractSummon", "ActivityLegendRoad", "ActivityDailyTask", "ActivitySevenSign":
			body = load(ActivityPage).instantiate()
			body.page_id = id
			body.navigation_requested.connect(open_page)
		_: body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if body is CatalogPage: body.overlays = overlays
	column.add_child(body)
	if id in ["GameModes", "Mall"]: root.close_requested.disconnect(close_page)
	if id in ["GameModes", "Mall"]: root.close_requested.connect(body.request_return)
	_pages[id] = {"root": root, "body": body}
	if id not in ["Collection", "Encyclopedia", "Mall", "PlayerAssets", "GameModes", "Talents", "ActiveHero"] and not Activities.TITLES.has(id): _populate_static(id, body)

## 模式推拉时统一页头与内容一起淡入淡出，页头布局始终由框架维护。
func _mode_transition_started(expanded: bool, duration: float, root: Control) -> void:
	if _mode_frame_transition != null and _mode_frame_transition.is_valid(): _mode_frame_transition.kill()
	var close: Button = root.close_button
	if not expanded:
		root.header.modulate.a = 0
		$ImmersiveShade.modulate.a = 0
	$ImmersiveShade.show()
	close.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_frame_transition = root.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_mode_frame_transition.tween_property(root.header, "modulate:a", 0.0 if expanded else 1.0, duration * 0.72)
	_mode_frame_transition.tween_property($ImmersiveShade, "modulate:a", 0.0 if expanded else 1.0, duration)

## 模式页完成内缩后恢复页头与返回交互；外扩完成由页面信号关闭。
func _mode_transition_finished(expanded: bool, root: Control) -> void:
	if expanded:
		$ImmersiveShade.hide()
		return
	var close: Button = root.close_button
	root.header.modulate.a = 1
	close.mouse_filter = Control.MOUSE_FILTER_STOP

## 本机排行保留真实记录；未开放页面共用模式选择的黑金提示。
func _populate_static(id: String, body: Control) -> void:
	UI.clear(body)
	if id == "SocialRank":
		var content = UI.scroll(body)
		content.add_child(UI.label("ui.home.ranking_info", 22))
		var rows = ranking.call() if ranking.is_valid() else []
		for i in range(rows.size()):
			var label = UI.label("%d.  %s (%s)    %d" % [i + 1, rows[i].name, rows[i].account, rows[i].value])
			label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			content.add_child(label)
		return
	var unavailable: UnavailableView = load(Unavailable).instantiate()
	unavailable.name = "Unavailable"
	unavailable.title = PAGES[id]
	body.add_child(unavailable)

## 设置入口保留 Home 作为背景，并在加入场景树前注入语言与平台依赖。
func _open_settings() -> void:
	if is_instance_valid(_settings_popup): return
	close_page()
	var popup: AccountSettingsPopup = load(SettingsPopup).instantiate()
	popup.localization = localization
	popup.platform = platform
	popup.audio = audio
	popup.close_requested.connect(_close_settings.bind(popup))
	_settings_popup = popup
	add_child(popup)
	if audio != null: audio.play_ui_cue("sfx.ui.open", -6.0)

## 关闭设置只释放当前弹窗，并把键盘焦点归还给原设置入口。
func _close_settings(popup: AccountSettingsPopup = _settings_popup) -> void:
	if not is_instance_valid(popup) or _settings_popup != popup: return
	_settings_popup = null
	if audio != null: audio.play_ui_cue("sfx.ui.close", -6.0)
	UI.dismiss(popup)
	var entry: Button = _home.get_node("TopBar/Settings")
	if is_instance_valid(entry) and entry.is_visible_in_tree(): entry.grab_focus()

## 主页开始沿用当前已确认章节，不重新抽取现有路线。
func _enter_adventure() -> void:
	if session == null: return
	var mode: String = _pages.GameModes.body.tabs.selected_id if _pages.has("GameModes") else "PveAdventure"
	if mode != "PveAdventure":
		open_page("GameModes")
		overlays.toast("ui.mode.unavailable" if not mode.is_empty() else "ui.mode.empty")
		return
	if not await _prepare_assets(progression.required_resource_keys()): return
	var error: String = progression.ensure_started(int(Time.get_unix_time_from_system()))
	if error.is_empty(): navigation_requested.emit("adventure")
	else: overlays.toast(error)

## 在创建内容页面或提交冒险开始前准备资源，取消下载不改变游戏进度。
func _prepare_assets(keys: Array[String]) -> bool:
	if _preparing_assets: return false
	if session == null: return false
	_preparing_assets = true
	var ready: bool = await overlays.prepare_content(session.content.delivery, keys)
	_preparing_assets = false
	return ready and is_inside_tree()

## 各入口只声明其展示集合，未开放页面没有资源需求，不触发全量下载。
func _page_resource_keys(id: String) -> Array[String]:
	if session == null: return []
	var tables: Array = {
		"GameModes": ["chapters"], "Collection": ["cards", "relics"], "ActiveHero": ["cards"],
		"Encyclopedia": ["cards", "relics", "items", "aurora_rewards"],
		"Mall": ["cards", "relics", "items"], "PlayerAssets": ["items"], "Talents": ["cards", "talents"]
	}.get(id, [])
	var records: Array = []
	for table: String in tables:
		var rows: Array = session.content.data.get(table, [])
		if table == "cards" and id != "Encyclopedia":
			rows = rows.filter(func(row: Dictionary) -> bool:
				return row.card_kind == CardTypes.Kind.CoreHero if id == "ActiveHero" else row.card_kind != CardTypes.Kind.Monster)
		records.append(rows)
	return session.content.resource_keys(records)

## 当前英雄肖像和章节背景随真实选择更新。
func _refresh_header() -> void:
	var player: RefCounted = session
	_home.get_node("TopBar").present(player.user.name, player.assets.gold, player.assets.star_stone, player.user.stamina, player.user.STAMINA_MAX)
	var hero: Dictionary = session.content.get_record("cards", player.collection.selected_hero)
	_hero_image.texture = session.content.resource(hero.get("texture_key", ""))
	var chapter: Dictionary = session.content.get_record("chapters", player.selected_chapter)
	_mode_summary.text = ContentText.text("ui.home.adventure_mode")
	_chapter_caption.text = ContentText.text("ui.home.start_adventure")
	_refresh_chapter_progress(chapter)
	for label in [_mode_summary, _chapter_caption, _chapter_progress]:
		label.fit_content()
	var start: Button = _chapter_caption.get_parent()
	start.disabled = chapter.is_empty()
	$Background.texture = session.content.resource(chapter.get("unlocked_background_key", ""))

## 按路线层级显示当前关卡；分支槽位不计成额外关卡，也不为展示提前生成路线。
func _refresh_chapter_progress(chapter: Dictionary) -> void:
	_chapter_progress.visible = not chapter.is_empty()
	if chapter.is_empty():
		_chapter_progress.text = ""
		return
	var route: RouteState = session.current_route()
	var total: int = chapter.get("layers", []).size()
	var current: int = 1
	if route != null and not route.nodes.is_empty():
		total = int(route.nodes.back().layer) + 1
		if route.current >= 0:
			current = int(route.nodes[route.current].layer) + 1
			if route.phase == RouteState.Phase.RouteSelection and not session.build.pending_reward:
				current += 1
	_chapter_progress.text = ContentText.format_key("ui.home.chapter_progress", {
		"chapter": ContentText.field(chapter), "current": clampi(current, 1, maxi(1, total)), "total": total})

## 语言通知不导航或重建缓存页，只更新主页和只读英雄展示。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and session != null: _translate_view.call_deferred()

## Home 只刷新主页文字，各业务页和浮层处理自身文本绑定。
func _translate_view() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	_refresh_header()
