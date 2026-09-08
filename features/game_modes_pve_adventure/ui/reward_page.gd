class_name AdventureRewardPage
extends VBoxContainer
## 战后奖励界面，只通过冒险事务提交选择和账号奖励。

signal finished
const UI = preload("res://ui/components/ui.gd")
const C = preload("res://game_content/runtime/content_types.gd")
const Dice = preload("res://features/game_modes_pve_adventure/domain/reward_dice.gd")
const Receipt = preload("res://features/game_modes_pve_adventure/ui/reward_receipt.tscn")
const RewardCard = preload("res://features/game_modes_pve_adventure/ui/reward_card.tscn")
var session: PlayerSessionState
var progression: AdventureProgression
var _aurora_upgrade_id: String = ""
var _feedback_renderer: Callable
var _timeout_pending: bool = false
var _retry_after: float = 0.0
var _choice_revision: int = 0
var _victory_seconds: float = -1.0
var _command_failed: bool = false
## 页面生命周期内仅成功重投推进表现代次，候选抽取的随机计数不参与。
var _roll_revision: int = 0
@onready var _choice_cards: HBoxContainer = $ChoiceCards
@onready var _feedback: Label = $Feedback
@onready var _timer: Label = $ChoiceHeader/Timer/Value
@onready var _body: VBoxContainer = $Scroll/Body

## 无会话时只预览场景骨架，不创建账号或章节状态。
func _ready() -> void:
	_timer.theme_type_variation = &"GrowthLabel"
	# 缩小纸面视觉高度，同时保留标准触摸区域；不修改共享 Theme。
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		if not $Footer/Completion/Complete.get_theme_stylebox(state) is StyleBoxTexture: continue
		var skin: StyleBoxTexture = $Footer/Completion/Complete.get_theme_stylebox(state).duplicate()
		skin.expand_margin_top = -18.0
		skin.expand_margin_bottom = -18.0
		$Footer/Completion/Complete.add_theme_stylebox_override(state, skin)
	$DiceTray.die_requested.connect(func(id: int): _command("open", id))
	$Retry.pressed.connect(_prepare)
	$Footer/Actions/Reroll.pressed.connect(_command.bind("reroll"))
	$Footer/Completion/Complete.pressed.connect(_complete)
	UI.bind_text(_feedback, _feedback_text)

## 页面只持有会话入口，回滚后重新查询其最新 Owner。
func configure(player: PlayerSessionState, commands: AdventureProgression, victory_seconds: float = -1.0) -> void:
	session = player
	progression = commands
	_roll_revision += 1
	_aurora_upgrade_id = ""
	_retry_after = 0.0
	_timeout_pending = false
	_victory_seconds = victory_seconds
	$VictoryHeader/Victory.visible = not progression.is_aurora_node()
	$VictoryHeader/Duration.visible = victory_seconds >= 0.0
	$VictoryHeader/Duration.text = "%ss" % RuleText.number(snappedf(victory_seconds, 0.1))
	_prepare()

## 新奖励自动投出；旧存档或保存失败恢复只处理未投骰子。
func _prepare() -> void:
	var error: String = progression.prepare_rewards()
	_command_failed = not error.is_empty()
	_set_feedback(func(): return error)
	refresh()

## 动态条目全部来自本章状态和正式内容目录。
func refresh() -> void:
	if session == null or not is_node_ready(): return
	_style_reward_content.call_deferred(self)
	_refresh_completion.call_deferred()
	UI.clear(_body)
	UI.clear(_choice_cards)
	_choice_revision += 1
	var build: RunBuild = session.build
	var rewards: RewardDice = build.rewards
	var aurora_only: bool = progression.is_aurora_node()
	var choosing: bool = not rewards.choice.is_empty()
	$ChoiceHeader.visible = choosing
	$ChoiceGap.visible = choosing
	_choice_cards.visible = choosing
	$VictoryHeader.visible = not aurora_only and not choosing
	$VictoryHeader/Duration.visible = _victory_seconds >= 0.0 and not choosing
	_feedback.visible = not _feedback_text().is_empty() and (not choosing or _command_failed)
	# 用完骰子后保留骰盘的弹性空间，核心按钮仍在底部。
	$DiceTray.visible = not aurora_only and not choosing
	$Scroll.visible = not choosing and (aurora_only or build.aurora_rewards.remaining() > 0)
	$Footer/Actions.visible = not choosing
	$Footer/Completion/Complete.visible = false
	$CarryNotice.visible = not choosing and not aurora_only
	_translate_header()
	var unrolled = rewards.dice.any(func(die): return die.status == Dice.Status.Unrolled)
	$Retry.visible = unrolled and rewards.choice.is_empty()
	$Footer/Actions/Reroll.disabled = not rewards.choice.is_empty() or rewards.rerolls <= 0 or rewards.remaining() == 0
	$Footer/Completion/Complete.text = "ui.reward.complete_build"
	$Footer/Completion/Complete.disabled = build.aurora_rewards.remaining() > 0 or not rewards.choice.is_empty() or unrolled
	$ChoiceHeader/Timer.visible = not rewards.choice.is_empty()
	$Resources.visible = not choosing and $Resources/Items.get_child_count() > 0
	if aurora_only:
		$Footer/Actions.hide()
		$Footer/Actions/Reroll.hide()
		$ChoiceHeader/Timer.hide()
		$Footer/Completion/Complete.disabled = build.aurora_rewards.remaining() > 0
		_aurora_rewards()
		return
	if not rewards.choice.is_empty():
		_choices()
		return
	_configure_dice()
	if not build.aurora_rewards.offers.is_empty(): _aurora_rewards()
	if not build.migration_receipt.is_empty():
		_body.add_child(UI.bound_label(func(): return ContentText.format_key("ui.reward.migration_receipt", build.migration_receipt), 18))

## 标题与奖励回执只读取已保存状态，不影响时限或正在进行的操作。
func _translate_header() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or session == null: return
	var build: RunBuild = session.build
	var rewards: RewardDice = build.rewards
	if not rewards.choice.is_empty():
		for die in rewards.dice:
			if die.id == rewards.choice.die_id:
				$ChoiceHeader/Heading/SubtitleRow/Subtitle.text = ContentText.field(session.adventure.die_definition(die.kind))
	_refresh_receipts()
	$Footer/Actions/Reroll/Content/Caption.text = tr("ui.reward.reroll")

	$Footer/Actions/Reroll/Content/Icon/Remaining.text = str(rewards.rerolls)
	$Footer/Actions/Reroll.tooltip_text = $Footer/Actions/Reroll/Content/Caption.text

## 同类奖励合并到一行，超宽时横向滚动；不展示账号余额或空奖励占位。
func _refresh_receipts() -> void:
	UI.clear($Resources/Items)
	for row: Dictionary in _receipt_rows():
		var item: Control = Receipt.instantiate()
		$Resources/Items.add_child(item)
		item.get_node("Icon").texture = row.texture
		if not row.get("card_id", "").is_empty():
			var definition: Dictionary = session.adventure.assembly.base_definition(row.card_id)
			var copies: Array = session.build.cards.filter(func(card): return card.definition_id == row.card_id)
			var level: int = 0 if copies.is_empty() else DuplicateGrowth.level(copies[0].copies)
			var art: CardArtwork = item.get_node("Icon/Card")
			var height: float = item.get_node("Icon").custom_minimum_size.y
			item.get_node("Icon").texture = null
			item.get_node("Icon").custom_minimum_size = Vector2(height * definition.width * 100.0 / (definition.height * 118.0), height)
			art.show()
			art.set_appearance(row.texture, level, definition.width)
		item.get_node("Amount").text = ("+%d" if row.currency else "×%d") % row.amount
		item.get_node("Icon/Marker").text = row.marker
		item.get_node("Icon/Marker").visible = not row.marker.is_empty()
		item.tooltip_text = row.title
	$Resources.visible = session.build.rewards.choice.is_empty() and $Resources/Items.get_child_count() > 0

## 骰子回执按本场身份取已用结果，星能按本次已领选项取锁定金额与内容。
func _receipt_rows() -> Array[Dictionary]:
	var rows: Dictionary = {}
	var gold: int = 0
	var stones: int = 0
	for reward: Dictionary in session.build.rewards.settled_rewards():
		if reward.kind == C.DiceReward.StarStone:
			stones += int(reward.amount)
		else:
			_append_receipt(rows, reward)
	var aurora: AuroraRewards = session.build.aurora_rewards
	for offer: Dictionary in aurora.offers:
		if not offer.id in aurora.selected: continue
		var definition: Dictionary = session.content.get_record("aurora_rewards", offer.id)
		match int(definition.aurora_reward_kind):
			C.AuroraReward.Gold: gold += int(offer.amount)
			C.AuroraReward.StarStone: stones += int(offer.amount)
			C.AuroraReward.Relic, C.AuroraReward.MinionFragments, C.AuroraReward.RelicFragments, C.AuroraReward.HeroFragment:
				for id: String in offer.content_ids:
					_append_receipt(rows, {"kind": C.DiceReward.Relic if definition.aurora_reward_kind == C.AuroraReward.Relic else C.DiceReward.Fragment, "content_id": id, "amount": offer.amount})
			C.AuroraReward.Stamina, C.AuroraReward.CardUpgrade:
				rows[offer.id] = {"texture": preload("res://ui/design_system/icons/common/player_stamina.png") if definition.aurora_reward_kind == C.AuroraReward.Stamina else preload("res://ui/design_system/icons/star.png"),
					"amount": offer.amount, "title": ContentText.field(definition), "currency": false, "marker": ""}
	var result: Array[Dictionary] = []
	if gold > 0:
		result.append({"texture": preload("res://ui/design_system/icons/common/player_gold.png"), "amount": gold, "title": "", "currency": true, "marker": ""})
	if stones > 0:
		result.append({"texture": preload("res://ui/design_system/icons/common/player_star_stone.png"), "amount": stones, "title": "", "currency": true, "marker": ""})
	for row: Dictionary in rows.values(): result.append(row)
	return result

## 图标使用对应内容原图，碎片和英雄强化保留小标记，避免与整卡混淆。
func _append_receipt(rows: Dictionary, reward: Dictionary) -> void:
	var key: String = "%d:%s" % [reward.kind, reward.content_id]
	if rows.has(key):
		rows[key].amount += int(reward.amount)
		var total: Dictionary = reward.duplicate()
		total.amount = rows[key].amount
		rows[key].title = _reward_title(total)
		return
	var record: Dictionary = session.adventure.reward_record(reward)
	rows[key] = {"texture": _candidate_texture(reward, record), "amount": int(reward.amount), "title": _reward_title(reward), "currency": false,
		"card_id": reward.content_id if reward.kind in [C.DiceReward.Minion, C.DiceReward.ItemCard, C.DiceReward.HeroGrowth] else "",
		"marker": "◇" if reward.kind == C.DiceReward.Fragment else ("↑" if reward.kind == C.DiceReward.HeroGrowth else "")}

## 倒计时只展示同一截止时间，到期请求一次事务，保存失败后有界重试。
func _process(_delta: float) -> void:
	if session == null or progression == null or not is_visible_in_tree(): return
	_refresh_completion()
	var choice: Dictionary = session.build.rewards.choice
	if choice.is_empty(): return
	var now: float = progression.current_time()
	_timer.text = ContentText.format_key("ui.reward.countdown", {"seconds": maxi(0, ceili(choice.deadline - now))})
	if now < choice.deadline or _timeout_pending or now < _retry_after: return
	_timeout_pending = true
	var error = _command("timeout")
	_retry_after = progression.current_time() + 1.0 if not error.is_empty() else 0.0
	_timeout_pending = false

## 骰盘只绑定可用骰和最近入账星石，不追加章节奖励清单。
func _configure_dice() -> void:
	var rewards: RewardDice = session.build.rewards
	var ready: Array = []
	var stones: Array = rewards.dice.filter(func(die): return die.kind == C.DiceKind.StarStone and die.status == Dice.Status.Used and die.id in rewards.settlement_ids)
	var latest_stone: int = -1 if stones.is_empty() else int(stones.back().id)
	for die in rewards.dice:
		if die.status != Dice.Status.Ready and die.id != latest_stone: continue
		var row: Dictionary = session.adventure.die_definition(die.kind)
		ready.append({"id": die.id, "kind": die.kind, "title": func(): return ContentText.field(row), "paid": die.status == Dice.Status.Used, "amount": die.reward.get("amount", 0)})
	$DiceTray.configure(ready, _roll_revision, session.content.resource("dice.reward_surface"))

## 三张候选并排，点击直接领取，过期视图的事件不能影响刷新后或下一颗骰子。
func _choices() -> void:
	var choice: Dictionary = session.build.rewards.choice
	for index in range(choice.candidates.size()):
		var card: Control = RewardCard.instantiate()
		_choice_cards.add_child(card)
		card.configure(_candidate_view.bind(choice.candidates[index]), maxi(0, choice.refresh_limit - choice.refreshes[index]))
		card.selected.connect(_candidate_action.bind("choose", index, _choice_revision), CONNECT_DEFERRED)
		card.refresh_requested.connect(_candidate_action.bind("refresh", index, _choice_revision), CONNECT_DEFERRED)

## 保存失败重绑同一事实供重试，旧节点和重复信号不能提交第二份奖励。
func _candidate_action(action: String, index: int, revision: int) -> void:
	if revision != _choice_revision or session.build.rewards.choice.is_empty(): return
	_apply_view_action(_command.bind(action, index), revision)

## 动态正文按钮在输入结束后执行；版本随重建递增，迟到操作不能影响新列表。
func _reward_button(text: String, action: Callable) -> Button:
	var button: Button = UI.button(text)
	button.pressed.connect(_apply_view_action.bind(action, _choice_revision), CONNECT_DEFERRED)
	return button

## 隐藏、暂停、离场或换过内容后不再接受旧视图的延迟操作。
func _apply_view_action(action: Callable, revision: int) -> void:
	if revision != _choice_revision or not is_inside_tree() or is_queued_for_deletion() or not is_visible_in_tree() or not can_process(): return
	action.call()

## 卡牌详情复用成长后装配投影，遗物和碎片复用实际详情内容。
func _candidate_view(reward: Dictionary) -> Dictionary:
	if reward.kind == C.DiceReward.StarStone:
		return {"title": _reward_title(reward), "texture": preload("res://game_content/items/art/coin_mana_stone.png"), "detail": {"sections": []}}
	var row: Dictionary = session.adventure.reward_record(reward)
	var detail: Dictionary
	if reward.kind in [C.DiceReward.Minion, C.DiceReward.ItemCard, C.DiceReward.HeroGrowth]:
		var cards: Array = session.build.cards.filter(func(card): return card.definition_id == row.id)
		var copies: int = 1 if cards.is_empty() else int(cards[0].copies) + 1
		var definition: Dictionary = CardGrowth.project(BattleAssembly.new(session.content).base_definition(row.id), session.build.permanent_growth.get(row.id, {"star_level": 1, "fragment_steps": 0}), copies, session.content.data.growth_rules[0])
		detail = ContentPreview.card_detail(definition)
		detail.scope = ""
	else:
		var table: String = "relics" if reward.kind == C.DiceReward.Relic else "items"
		detail = ContentPreview.describe(session.content, ContentPreview.entry(session.content, table, row))
		if reward.kind == C.DiceReward.Relic:
			detail.scope = detail.tags[0]
			detail.sections = detail.sections.filter(func(section): return section.get("title") == "ui.detail.actions")
	return {"title": ContentText.field(row) + (" ×%d" % reward.amount if reward.amount > 1 else ""),
		"texture": _candidate_texture(reward, row), "detail": detail}

## 专属碎片没有独立原图时，按唯一兑换关系显示对应内容插画，名称仍明确标注碎片。
func _candidate_texture(reward: Dictionary, row: Dictionary) -> Texture2D:
	var texture: Texture2D = session.content.resource(row.get("texture_key", ""))
	if texture != null or reward.kind != C.DiceReward.Fragment: return texture
	for offer: Dictionary in session.content.data.shop_offers:
		if offer.fragment_item_id != row.id: continue
		var table: String = "relics" if offer.shop_tab == C.ShopTab.Relic else "cards"
		return session.content.resource(session.content.get_record(table, offer.reward_id).get("texture_key", ""))
	return null

## 明确区分账号奖励、卡牌成长与遗物强化，不把碎片和星石拼成一项。
func _reward_title(reward: Dictionary) -> String:
	if reward.kind == C.DiceReward.StarStone: return ContentText.format_key("ui.reward.stones", {"count": reward.amount})
	var row: Dictionary = session.adventure.reward_record(reward)
	return ContentText.format_key("ui.reward.named", {"kind": tr("ui.reward.kind." + String(C.DiceReward.find_key(reward.kind)).to_snake_case()), "name": ContentText.field(row), "count": reward.amount})

## 八项奖励只展示已保存结果，强化目标选择不提前消费领取额度。
func _aurora_rewards() -> void:
	var rewards: AuroraRewards = session.build.aurora_rewards
	_body.add_child(UI.bound_label(func(): return ContentText.format_key("ui.aurora.progress", {"count": rewards.trigger_count, "max": session.content.data.aurora_reward_rules[0].max_triggers, "remaining": rewards.remaining()}), 26))
	if rewards.offers.is_empty():
		_body.add_child(UI.label("ui.aurora.limit", 22))
		return
	if not _aurora_upgrade_id.is_empty() and rewards.available(_aurora_upgrade_id).is_empty(): _aurora_upgrade_id = ""
	if not _aurora_upgrade_id.is_empty():
		_body.add_child(UI.label("ui.aurora.choose_card", 24))
		for card: Dictionary in session.build.cards:
			var row: Dictionary = session.content.get_record("cards", card.definition_id)
			var target: Button = _reward_button("ui.aurora.upgrade", _command.bind("aurora", -1, _aurora_upgrade_id, card.id))
			UI.bind_text(target, func(): return ContentText.format_key("ui.aurora.upgrade_target", {"name": ContentText.field(row), "level": DuplicateGrowth.level(card.copies), "next": DuplicateGrowth.level(card.copies) + 1}))
			_body.add_child(target)
		_body.add_child(_reward_button("ui.common.cancel", _cancel_aurora_upgrade))
		return
	for offer: Dictionary in rewards.offers:
		var row: Dictionary = session.content.get_record("aurora_rewards", offer.id)
		var box: VBoxContainer = _section()
		box.add_child(UI.bound_label(func(): return ContentText.field(row), 25))
		box.add_child(UI.bound_label(_aurora_detail.bind(row, offer), 20))
		var chosen: bool = offer.id in rewards.selected
		var button: Button = _reward_button("ui.aurora.claimed" if chosen else "ui.reward.choose_aurora", _choose_aurora.bind(offer.id))
		button.disabled = chosen or rewards.remaining() <= 0
		box.add_child(button)

## 货币显示锁定数额，碎片与遗物显示具体内容，卡牌强化保留目标选择。
func _aurora_detail(row: Dictionary, offer: Dictionary) -> String:
	if row.aurora_reward_kind in [C.AuroraReward.StarStone, C.AuroraReward.Gold, C.AuroraReward.Stamina]:
		return ContentText.format_key("ui.aurora.amount", {"name": ContentText.field(row), "amount": offer.amount})
	if row.aurora_reward_kind == C.AuroraReward.CardUpgrade: return ContentText.field(row, "description")
	var lines: PackedStringArray = []
	for id: String in offer.content_ids:
		var content: Dictionary = session.content.get_record("relics" if row.aurora_reward_kind == C.AuroraReward.Relic else "items", id)
		lines.append(ContentText.format_key("ui.aurora.amount", {"name": ContentText.field(content), "amount": offer.amount}))
	return "\n".join(lines)

## 强化奖励先打开目标列表，其余奖励通过唯一命令入口领取。
func _choose_aurora(id: String) -> void:
	if session.content.get_record("aurora_rewards", id).aurora_reward_kind == C.AuroraReward.CardUpgrade:
		_aurora_upgrade_id = id
		refresh()
	else:
		_command("aurora", -1, id)

## 取消目标选择不领取奖励，已锁定随机结果保持不变。
func _cancel_aurora_upgrade() -> void:
	_aurora_upgrade_id = ""
	refresh()

## 分区只承载动态内容，稳定布局由奖励场景保存。
func _section() -> VBoxContainer:
	var panel = PanelContainer.new()
	_body.add_child(panel)
	var box = VBoxContainer.new()
	panel.add_child(box)
	return box

## 失败刷新回滚后的事实，不把局部动画或按钮状态当成已领取。
func _command(action: String, index: int = -1, id: String = "", target: String = "") -> String:
	var offset: int = $Scroll.scroll_vertical
	var error: String = progression.reward_command(action, index, id, target)
	_command_failed = not error.is_empty()
	if not error.is_empty():
		_set_feedback(func(): return error)
	else:
		if action == "reroll": _roll_revision += 1
		_set_feedback(func(): return "")
	refresh()
	$Scroll.set_deferred("scroll_vertical", 0 if action in ["open", "choose", "timeout"] else offset)
	return error

## 保存结果和当前选择各自持有展示来源，切换语言不重新发起操作。
func _set_feedback(renderer: Callable) -> void:
	_feedback_renderer = renderer
	_feedback.text = _feedback_text()
	_feedback.visible = not _feedback.text.is_empty()

## 只重译实际操作结果或错误，不提供常驻玩法说明。
func _feedback_text() -> String:
	return _feedback_renderer.call() if _feedback_renderer.is_valid() else ""

## 必选项和保存均完成才离开，不能借过期操作跳过仍待处理的奖励阶段。
func _complete() -> void:
	if $DiceTray.visible and (not $DiceTray.is_settled() or $DiceTray.is_dragging()): return
	var error = _command("complete")
	if error.is_empty() and not session.build.pending_reward: finished.emit()

## 投掷和重投停稳后才显示完成动作，保留同一行操作区高度避免骰子跳位。
func _refresh_completion() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	var rolling: bool = $DiceTray.visible and not $DiceTray.is_settled()
	if session != null: rolling = rolling or session.build.rewards.dice.any(func(die): return die.status == Dice.Status.Unrolled)
	$Footer/Completion/Complete.visible = not $ChoiceHeader/Timer.visible and not rolling
	if session != null:
		$Footer/Completion/Complete.disabled = $DiceTray.is_dragging() or session.build.aurora_rewards.remaining() > 0 or not session.build.rewards.choice.is_empty() or rolling
		$Footer/Actions/Reroll.disabled = $DiceTray.is_dragging() or rolling or session.build.rewards.rerolls <= 0 or session.build.rewards.remaining() == 0 or not session.build.rewards.choice.is_empty()
	$Footer/Actions/Reroll/Content.modulate = Color(1, 1, 1, 0.4) if $Footer/Actions/Reroll.disabled else Color.WHITE
	$Footer.visible = not $ChoiceHeader/Timer.visible

## 动态条目自行重绑文字，页面不重建列表、撤销拖拽或改变倒计时。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _translate_header.call_deferred()

## 奖励页动态内容统一使用现有黑金标题和纸面控件，不改变共享主题或交互。
func _style_reward_content(parent: Node) -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	for child in parent.get_children():
		if child.is_queued_for_deletion() or child in [$DiceTray, $ChoiceHeader, _choice_cards]: continue
		if child is PanelContainer:
			child.theme_type_variation = &"DetailSupplement"
		elif child is Button:
			child.theme_type_variation = &"DetailActionButton"
		elif child is Label:
			child.theme_type_variation = &"GrowthLabel"
		_style_reward_content(child)
