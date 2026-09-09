class_name AdventureEventPage
extends VBoxContainer
## 展示并提交流动黑市与旅途奇遇，随机内容只读取已保存事件状态。

const UI = preload("res://ui/components/ui.gd")
const C = preload("res://game_content/runtime/content_types.gd")
const Artwork = preload("res://features/game_modes_pve_adventure/ui/event_artwork.gd")
const MarketOffer = preload("res://features/game_modes_pve_adventure/ui/market_offer.tscn")
signal finished
signal settings_requested
var session: PlayerSessionState
var progression: AdventureProgression
var audio: AudioService
var _view_revision: int = 0
var _message: String = ""
var _confirming_leave: bool = false
var _choosing_replacement: bool = false

## 固定标题和插画留白由场景提供，窄高变化只调整非交互留白。
func _ready() -> void:
	$Header.settings_requested.connect(func(): settings_requested.emit())
	resized.connect(_layout_hero)

## 横屏及短屏缩小插画留白，正文和底部按钮仍保留标准触摸尺寸。
func _layout_hero() -> void:
	if session == null: return
	var market: bool = session.build.events.node_type == C.NodeType.BlackMarket
	$Scroll/Body/Hero.custom_minimum_size.y = clampf(size.y * (0.05 if market else 0.27), 0.0, 360.0) if size.y > 800.0 else 0.0

## 页面接收已恢复事件，不在配置或刷新时重新抽取内容。
func configure(player: PlayerSessionState, flow: AdventureProgression, sound: AudioService = null) -> void:
	session = player
	progression = flow
	audio = sound
	_message = ""
	_confirming_leave = false
	_choosing_replacement = false
	refresh()

## 根据当前活动节点重建动态项目，离开页面后旧按钮无法继续提交。
func refresh() -> void:
	if session == null or progression == null or not is_node_ready(): return
	_view_revision += 1
	for group: String in ["Fragments", "Exchange", "Stamina"]:
		UI.clear(get_node("Scroll/Body/Market/" + group))
	UI.clear($Scroll/Body/Replacement)
	UI.clear($Footer)
	$Feedback.text = _message
	$Feedback.visible = not _message.is_empty()
	if not progression.has_active_event(): return
	$Header.configure(session, _event_title())
	var market: bool = session.build.events.node_type == C.NodeType.BlackMarket
	$Scroll/Body/Market.visible = market
	$Scroll/Body/Contract.visible = not market
	$Scroll/Body/Replacement.visible = not market and _choosing_replacement
	$Scroll/Body/Hero.visible = not _choosing_replacement
	_layout_hero()
	if market: _show_market()
	else: _show_encounter()

## 七项交易按碎片、兑换和体力分组，两种支付共用同一已购状态。
func _show_market() -> void:
	for action: Dictionary in session.build.events.market.actions:
		var offer: Control = MarketOffer.instantiate()
		var fragment: bool = action.kind == AdventureEvents.MarketKind.Fragment
		var exchange: bool = action.kind == AdventureEvents.MarketKind.Exchange
		var group: String = "Fragments" if fragment else ("Exchange" if exchange else "Stamina")
		get_node("Scroll/Body/Market/" + group).add_child(offer)
		offer.set_meta("action_id", action.id)
		var content: VBoxContainer = offer.get_node("Margin/Content")
		content.get_node("Title").text = _market_title(action)
		content.get_node("Art").texture = Artwork.content(session.content, "items", action.content_id) if fragment else Artwork.STAMINA
		content.get_node("Art").custom_minimum_size.y = 100 if fragment else 58
		content.get_node("Payments/Gold").visible = not exchange
		content.get_node("Payments/StarStone").visible = not exchange
		content.get_node("Payments/Or").visible = not exchange
		content.get_node("Exchange").visible = exchange
		content.get_node("Flow").visible = exchange
		content.get_node("Flow").tooltip_text = _market_title(action)
		if not fragment:
			content.get_node("Payments").columns = 2
			content.get_node("Payments/Or").hide()
			for side: String in ["left", "top", "right", "bottom"]: offer.get_node("Margin").add_theme_constant_override("margin_" + side, 0)
			offer.get_node("Paper").hide()
			offer.remove_theme_stylebox_override("panel")
			offer.theme_type_variation = &"DetailSupplement"
			content.get_node("Title").theme_type_variation = &"GrowthLabel"
			content.get_node("Title").custom_minimum_size.y = 0
			content.get_node("Payments/Or").theme_type_variation = &"GrowthLabel"
		if exchange:
			content.get_node("Art").hide()
			content.get_node("Title").hide()
			content.get_node("Flow/CostIcon").texture = Artwork.currency(action.cost_currency)
			content.get_node("Flow/Cost").text = str(action.cost_amount)
			content.get_node("Flow/RewardIcon").texture = Artwork.currency(action.reward_currency)
			content.get_node("Flow/Reward").text = str(action.reward_amount)
			var button: Button = content.get_node("Exchange")
			button.disabled = action.purchased or _balance(action.cost_currency) < action.cost_amount
			_bind(button, _purchase.bind(action.id, -1))
		else:
			for payment: int in [C.Currency.Gold, C.Currency.StarStone]:
				var button: Button = content.get_node("Payments/Gold" if payment == C.Currency.Gold else "Payments/StarStone")
				var price: int = action.gold_price if payment == C.Currency.Gold else action.stone_price
				button.get_node("Price/Value").text = str(price)
				button.get_node("Price").modulate.a = 0.4 if action.purchased or _balance(payment) < price else 1.0
				button.disabled = action.purchased or _balance(payment) < price
				button.tooltip_text = ContentText.format_key("ui.event.market.pay", {"amount": price, "currency": _currency_name(payment)})
				_bind(button, _purchase.bind(action.id, payment))
		if action.purchased:
			content.get_node("Art").modulate.a = 0.55
			# 已售状态占据原有动作区，其他商品的位置保持稳定。
			if exchange: content.get_node("Exchange").text = "ui.event.market.completed"
			elif fragment: content.get_node("Payments/Or").text = "ui.event.market.completed"
			else: content.get_node("Title").text = tr("ui.event.market.completed")
	if _confirming_leave:
		$Footer.add_child(UI.label("ui.event.market.leave_warning", 20))
		var choices := HBoxContainer.new()
		$Footer.add_child(choices)
		choices.add_child(_button("ui.event.market.continue", _cancel_leave, true))
		choices.add_child(_button("ui.event.market.confirm_leave", _leave))
	else:
		var stock: Label = UI.label("ui.event.market.once", 18)
		stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		$Footer.add_child(stock)
		$Footer.add_child(_button("ui.event.market.leave", _request_leave))

## 余额只读，禁用提示与真实事务使用相同的货币身份。
func _balance(currency: int) -> int:
	return session.assets.gold if currency == C.Currency.Gold else session.assets.star_stone

## 商品名称读取真实卡牌或物品，兑换方向与体力数量读取锁定条款。
func _market_title(action: Dictionary) -> String:
	if action.kind == AdventureEvents.MarketKind.Fragment:
		var source: Dictionary = session.content.data.shop_offers.filter(func(offer): return offer.reward_id == action.reward_id)[0]
		var table: String = "cards" if source.shop_tab != C.ShopTab.Relic else "relics"
		return ContentText.format_key("ui.event.market.fragment", {"name": ContentText.field(session.content.get_record(table, source.reward_id)), "amount": action.amount})
	if action.kind == AdventureEvents.MarketKind.Stamina: return ContentText.format_key("ui.event.market.stamina", {"amount": action.amount})
	return ContentText.format_key("ui.event.market.exchange", {"cost": action.cost_amount, "cost_currency": _currency_name(action.cost_currency), "reward": action.reward_amount, "reward_currency": _currency_name(action.reward_currency)})

## 货币身份只用于事件短标签，不改变账号资产的统一枚举。
func _currency_name(currency: int) -> String:
	return tr("ui.currency.gold" if currency == C.Currency.Gold else "ui.currency.star_stone")

## 页面标题读取当前节点的正式多语言内容，不复制黑市或奇遇名称。
func _event_title() -> String:
	var route: RouteState = session.current_route()
	return ContentText.field(session.content.node_definition(route.nodes[route.current]), "title")

## 单项购买完成后读取事务最终状态，保存失败时保留原商品供重试。
func _purchase(id: String, payment: int) -> void:
	var error: String = progression.market_purchase(id, payment)
	_message = error
	if audio != null: audio.play_ui_cue("sfx.ui.error" if not error.is_empty() else "sfx.adventure.reward", -3.0)
	refresh()

## 有剩余项目时先显示具体离开后果，全部购完可直接离开。
func _request_leave() -> void:
	if progression.market_has_unpurchased():
		_confirming_leave = true
		refresh()
	else: _leave()

## 取消离开只恢复项目列表，不修改任何商品状态。
func _cancel_leave() -> void:
	_confirming_leave = false
	refresh()

## 明确离开完成节点；已购内容保留，未购项目随事件清除。
func _leave() -> void:
	var error: String = progression.leave_event()
	if not error.is_empty():
		_message = error
		refresh()
		return
	finished.emit()

## 奇遇一次展示一个收获和代价，刷新与离开始终保持可用。
func _show_encounter() -> void:
	var pair: Dictionary = session.build.events.encounter
	var terms: VBoxContainer = $Scroll/Body/Contract/Terms
	$Scroll/Body/Contract.add_theme_stylebox_override("panel", get_theme_stylebox("panel", "DetailPaper"))
	terms.get_node("Reward/Text").text = _reward_text(pair.reward)
	terms.get_node("Cost/Text").text = _cost_text(pair.cost)
	terms.get_node("Reward/Icon").texture = _reward_icon(pair.reward)
	terms.get_node("Cost/Icon").texture = _cost_icon(pair.cost)
	terms.get_node("Cost/Icon").visible = terms.get_node("Cost/Icon").texture != null
	for path: String in ["RewardHeading", "CostHeading", "Reward/Text", "Cost/Text"]:
		terms.get_node(path).theme_type_variation = &"DetailBody"
	if _choosing_replacement:
		$Scroll/Body/Replacement.add_child(UI.label("ui.event.encounter.replacement_prompt", 22))
		for card: Dictionary in progression.encounter_replacement_candidates():
			var row: Dictionary = session.content.get_record("cards", card.definition_id)
			$Scroll/Body/Replacement.add_child(_button(ContentText.format_key("ui.event.encounter.replace", {"name": ContentText.field(row)}), _accept.bind(card.id)))
		$Footer.add_child(_button("ui.common.cancel", _cancel_replacement, true))
		$Scroll.ensure_control_visible.call_deferred($Scroll/Body/Replacement)
		return
	var accept: Button = _button("ui.event.encounter.accept", _accept.bind(""))
	accept.disabled = pair.cost.kind == C.EncounterCost.Stamina and session.user.stamina < pair.cost.amount
	$Footer.add_child(accept)
	var alternatives := HBoxContainer.new()
	alternatives.add_theme_constant_override("separation", 12)
	$Footer.add_child(alternatives)
	var rule: Dictionary = session.content.data.adventure_encounter_rules[0]
	var remaining: int = maxi(0, rule.refresh_count - pair.refreshes)
	var refresh_button: Button = _button(tr("ui.event.encounter.refresh") + "  ·  " + str(remaining), _refresh_encounter, true)
	refresh_button.disabled = remaining == 0
	alternatives.add_child(refresh_button)
	alternatives.add_child(_button("ui.event.encounter.leave", _leave, true))

## 收获插画只读取这次已经保存的内容身份。
func _reward_icon(reward: Dictionary) -> Texture2D:
	match int(reward.kind):
		C.EncounterReward.Dice: return Artwork.DICE
		C.EncounterReward.StarStone: return Artwork.STAR
		C.EncounterReward.Relic: return Artwork.content(session.content, "relics", reward.content_id)
		C.EncounterReward.Card: return Artwork.content(session.content, "cards", reward.content_id)
	return null

## 代价使用相同属性图标，空目标不伪造被扣除的卡牌。
func _cost_icon(cost: Dictionary) -> Texture2D:
	match int(cost.kind):
		C.EncounterCost.Stamina: return Artwork.STAMINA
		C.EncounterCost.TeamDebuff: return AttributeIcons.TEXTURES.get(cost.stat)
		C.EncounterCost.Dice: return Artwork.DICE
		C.EncounterCost.Card:
			var card: Dictionary = session.build.find_card(cost.target_id)
			return null if card.is_empty() else Artwork.content(session.content, "cards", card.definition_id)
	return null

## 收获文案显示锁定数量与具体内容，不根据当前资格替换结果。
func _reward_text(reward: Dictionary) -> String:
	match int(reward.kind):
		C.EncounterReward.Dice: return tr("ui.event.encounter.reward_dice")
		C.EncounterReward.StarStone: return ContentText.format_key("ui.event.encounter.reward_stone", {"amount": reward.amount})
		C.EncounterReward.Relic: return ContentText.format_key("ui.event.encounter.reward_relic", {"name": ContentText.field(session.content.get_record("relics", reward.content_id))})
		C.EncounterReward.Card: return ContentText.format_key("ui.event.encounter.reward_card", {"name": ContentText.field(session.content.get_record("cards", reward.content_id))})
	return tr("ui.event.encounter.unknown_reward")

## 空目标明确显示不发生额外扣除，英雄永远不作为卡牌代价候选。
func _cost_text(cost: Dictionary) -> String:
	match int(cost.kind):
		C.EncounterCost.Stamina: return ContentText.format_key("ui.event.encounter.cost_stamina", {"amount": cost.amount})
		C.EncounterCost.TeamDebuff: return ContentText.format_key("ui.event.encounter.cost_debuff", {"stat": _stat_name(cost.stat), "amount": cost.amount})
		C.EncounterCost.Card:
			var card: Dictionary = session.build.find_card(cost.target_id)
			return tr("ui.event.encounter.cost_no_card") if card.is_empty() else ContentText.format_key("ui.event.encounter.cost_card", {"name": ContentText.field(session.content.get_record("cards", card.definition_id))})
		C.EncounterCost.Dice: return tr("ui.event.encounter.cost_no_die") if cost.target_id.is_empty() else tr("ui.event.encounter.cost_die")
	return tr("ui.event.encounter.unknown_cost")

## 输出属性采用卡牌详情中的玩家名称。
func _stat_name(stat: String) -> String:
	return tr("rules.stat." + stat)

## 接受前若需要腾位则先展示目标选择，最终事务按代价后收获提交。
func _accept(replacement_id: String) -> void:
	if replacement_id.is_empty() and not progression.encounter_replacement_candidates().is_empty():
		_choosing_replacement = true
		refresh()
		return
	var error: String = progression.accept_encounter(replacement_id)
	_message = error
	if not error.is_empty():
		if audio != null: audio.play_ui_cue("sfx.ui.error", -3.0)
		refresh()
		return
	if audio != null: audio.play_ui_cue("sfx.adventure.reward", -3.0)
	finished.emit()

## 取消替换不接受奇遇，原组合与刷新机会保持不变。
func _cancel_replacement() -> void:
	_choosing_replacement = false
	refresh()

## 刷新成功后显示新锁定组合，失败仍保留原组合。
func _refresh_encounter() -> void:
	var error: String = progression.refresh_encounter()
	_message = error
	if audio != null: audio.play_ui_cue("sfx.ui.error" if not error.is_empty() else "sfx.adventure.route_select", -3.0)
	refresh()

## 页面动作使用原生按钮，次要动作保持同尺寸并采用暗色纸面。
func _button(text: String, action: Callable, secondary: bool = false) -> Button:
	var button: Button = UI.button(text)
	button.theme_type_variation = &"DetailDarkActionButton" if secondary else &"DetailActionButton"
	_bind(button, action)
	return button

## 重建推迟到输入结束，视图代次防止连点提交刷新后的新组合。
func _bind(button: Button, action: Callable) -> void:
	button.pressed.connect(_apply_action.bind(action, _view_revision), CONNECT_DEFERRED)

## 旧按钮、隐藏页面和暂停中的迟到回调都不能提交事务。
func _apply_action(action: Callable, revision: int) -> void:
	if revision != _view_revision or not is_inside_tree() or is_queued_for_deletion() or not is_visible_in_tree() or not can_process() or not progression.has_active_event(): return
	action.call()

## 切换语言时重建当前短文案，不提交购买、刷新或接受操作。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and session != null: refresh.call_deferred()
