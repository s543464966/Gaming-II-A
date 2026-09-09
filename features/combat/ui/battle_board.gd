class_name BattleBoard
extends Control
## 可配置矩形棋盘、受控拖拽和战报表现；权威站位由外层事务提交。

signal move_requested(id: String, position: int)
signal swap_requested(first_id: String, second_id: String)
signal card_clicked(id: String)
const DRAG_DISTANCE = 8.0
const SWAP_HOVER_SECONDS = 0.35
const CELL_PROPORTIONS = Vector2(100, 118)
const CELL_FILL = 0.94
const SLOT_TEXTURE = preload("res://features/combat/ui/art/board_slot_recess.png")
const BOARD_THEME = preload("res://features/combat/ui/battle_theme.tres")
const T = preload("res://features/mechanics/contracts/combat_types.gd")
const CardView = preload("res://features/combat/ui/combat_card.tscn")
const Playback = preload("res://features/combat/ui/battle_playback.gd")
const Vfx = preload("res://features/combat/ui/battle_vfx_renderer.gd")
const IMPACT_SECONDS = 0.58
const FEEDBACK_SECONDS = 0.82
const LINK_SECONDS = 0.38
const MAX_BURSTS = 24
const IMPACT_EFFECT_KEYS = {
	T.Output.Physical: "effect.combat.impact.physical.v1",
	T.Output.Witchcraft: "effect.combat.impact.witchcraft.v1",
	T.Output.Burn: "effect.combat.impact.burn.v1",
	T.Output.Poison: "effect.combat.impact.poison.v1",
	T.Output.Healing: "effect.combat.impact.healing.v1",
	T.Output.Shield: "effect.combat.impact.shield.v1",
}
var columns: int = BattleGrid.COLUMNS
var rows: int = BattleGrid.ROWS
var view_team: int = 0
var content: RefCounted
var audio: AudioService
var snapshots: Array = []
var cards: Dictionary = {}
var selected: String = ""
var interactive: bool = false
## 宿主提供只读的完整交换校验；棋盘不依赖模式或持有构筑规则。
var can_swap: Callable
var clock_time: float = 0
var projectiles: Array = []
var feedback: Array = []
var impacts: Array = []
var passive_links: Array = []
var _impact_sequences: Dictionary = {}
var _projectile_sequences: Dictionary = {}
var _pending_defeats: Dictionary = {}
var _board_tween: Tween
## 按下候选也用于区分轻点；敌方卡只能查看，不能拖动。
var _drag: String = ""
var _drag_origin: Vector2
var _drag_point: Vector2
var _drag_moved: bool = false
var _swap_target: String = ""
var _swap_elapsed: float = 0.0

## 只在按住卡牌期间处理停留时间，静置棋盘不逐帧轮询。
func _ready() -> void:
	set_process(false)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): cancel_drag())

## 停留使用场景时间，暂停、隐藏或停用后不继续积累。
func _process(delta: float) -> void:
	if not interactive or _drag.is_empty() or not is_visible_in_tree() or get_tree().paused:
		cancel_drag()
		return
	if _drag_moved: _update_swap_hover(_drag_point, delta)

## 离树撤销停留与拖拽，迟到松手不能发起交换。
func _exit_tree() -> void:
	cancel_drag()

## 显式刷新已提交快照；不缓存可变章节对象。
func configure(catalog: RefCounted, values: Array, configuration: Dictionary = {}) -> void:
	content = catalog
	columns = int(configuration.get("columns", BattleGrid.COLUMNS))
	rows = int(configuration.get("rows", BattleGrid.ROWS))
	view_team = int(configuration.get("view_team", 0))
	snapshots = values.duplicate(true)
	clear_effects()
	_load_impact_sequences()
	_projectile_sequences.clear()
	cancel_drag()
	for card in cards.values():
		remove_child(card)
		card.queue_free()
	cards.clear()
	_pending_defeats.clear()
	for snapshot in snapshots:
		var card = CardView.instantiate()
		card.configure(snapshot, content, view_team, columns)
		card.pressed.connect(_card_pressed)
		card.defeat_finished.connect(_card_defeat_finished)
		cards[snapshot.id] = card
		add_child(card)
	apply_frame(BattleAssembly.preview_frames(snapshots, columns, configuration.get("resources", {}), configuration.get("ability_hosts", [])))
	_layout()
	if not resized.is_connected(_layout): resized.connect(_layout)

## 棋盘整体等比容纳在可用区域，窗口尺寸不改变每格 100:118 的宽高比。
func grid_rect() -> Rect2:
	var natural_size = CELL_PROPORTIONS * Vector2(columns, rows)
	var fitted_size = natural_size * minf(size.x / natural_size.x, size.y / natural_size.y)
	return Rect2((size - fitted_size) / 2, fitted_size)

## 几何换算由棋盘单独拥有，拖拽、卡面与弹道共用居中后的格子边界。
func cell_rect(index: int, width: int = 1, height: int = 1) -> Rect2:
	var grid = grid_rect()
	var cell = grid.size / Vector2(columns, rows)
	return Rect2(grid.position + Vector2(index % columns, index / columns) * cell, Vector2(width, height) * cell)

## 空槽和占位卡面同比例留缝，避免固定像素内缩改变单格卡牌比例。
func slot_rect(index: int, width: int = 1, height: int = 1) -> Rect2:
	var rect = cell_rect(index, width, height)
	var inset = rect.size * (1.0 - CELL_FILL) / 2
	return Rect2(rect.position + inset, rect.size - inset * 2)

## 屏幕外落点无效，卡牌回到已提交位置。
func position_at(point: Vector2) -> int:
	var grid = grid_rect()
	if not grid.has_point(point) or not grid.has_area(): return -1
	var cell = grid.size / Vector2(columns, rows)
	var local = point - grid.position
	return floori(local.y / cell.y) * columns + floori(local.x / cell.x)

## 玩家与固定怪物占位重叠时标红双方，计时判断使用提交快照。
func conflicts() -> Array:
	var ids: Array = []
	for i in range(snapshots.size()):
		var a: Dictionary = snapshots[i]
		for j in range(i + 1, snapshots.size()):
			var b: Dictionary = snapshots[j]
			if BattleGrid.footprint_mask(a.position, a.definition.width, a.definition.height, columns, rows) & BattleGrid.footprint_mask(b.position, b.definition.width, b.definition.height, columns, rows):
				if not a.id in ids: ids.append(a.id)
				if not b.id in ids: ids.append(b.id)
	return ids

## 关闭交互撤销拖拽并停用卡面点击和悬停，迟到的松手不能改站位。
func set_interactive(value: bool) -> void:
	interactive = value
	if not value: cancel_drag()
	else: _layout()

## 阶段由宿主显式注入，不以能否拖拽推断战斗是否开始。
func set_cooldown_enabled(value: bool) -> void:
	for card in cards.values(): card.set_cooldown_enabled(value)

## 选中仅更新卡面焦点，不提交站位或打开详情。
func select_card(id: String) -> void:
	if not cards.has(id): return
	selected = id
	_layout()

## 归零、暂停或场景退出时立即撤销输入，通知期间可延后卡面复位。
func cancel_drag(defer_layout: bool = false) -> void:
	_clear_swap_hover()
	_drag = ""
	_drag_moved = false
	set_process(false)
	if defer_layout: _layout.call_deferred()
	else: _layout()

## 状态投射不改写原始输入，所有卡面消费同一帧。
func apply_frame(frame: Dictionary) -> void:
	for value in frame.cards:
		if not cards.has(value.id): continue
		if not value.defeated:
			cards[value.id].apply_frame(value)
			continue
		if not _pending_defeats.has(value.id):
			_pending_defeats[value.id] = true
			cards[value.id].play_defeat(value)
		if selected == value.id:
			selected = ""

## 死亡动画完成后才移除卡面，原始快照仍负责定位残留飘字。
func _card_defeat_finished(id: String) -> void:
	if not cards.has(id): return
	var view: Control = cards[id]
	remove_child(view)
	view.queue_free()
	cards.erase(id)
	_pending_defeats.erase(id)

## 连续扫描只更新仍在场的卡面材质，逐帧采样不重放伤害或重建卡牌。
func sample_cooldowns(values: Dictionary) -> void:
	for id in values:
		if cards.has(id): cards[id].sample_cooldown(values[id])

## 弹道采用事件已解析的资源键，保留默认、强化替换与单次覆盖的真实外观。
func launch(event: Dictionary) -> void:
	if not cards.has(event.source) or not cards.has(event.target): return
	if content == null or not content.assets.has(event.projectile): return
	var appearance: Dictionary = content.assets[event.projectile]
	if str(appearance.get("kind", "")) != "Projectile": return
	var output := int(event.get("output_type", T.Output.Physical))
	var duration := ProjectileMotion.flight_duration(output)
	var key := str(event.projectile)
	if not _projectile_sequences.has(key):
		_projectile_sequences[key] = content.resource(key, "Projectile")
	var frames: SpriteFrames = _projectile_sequences[key]
	if frames == null: return
	var animations := frames.get_animation_names()
	if animations.is_empty(): return
	var animation: StringName = &"flight" if frames.has_animation(&"flight") else StringName(animations[0])
	projectiles.append({"source": event.source, "target": event.target, "start": event.time + Playback.FLIGHT_SECONDS - duration, "duration": duration,
		"size": Vector2(appearance.width, appearance.height), "output_type": output, "frames": frames, "animation": animation})
	while projectiles.size() > MAX_BURSTS: projectiles.pop_front()
	queue_redraw()

## 原始事件时刻只启动蓄力、前冲和被动连线，命中仍等待回放延迟。
func cue_event(event: Dictionary) -> void:
	var kind := int(event.get("kind", -1))
	var source := str(event.get("source", ""))
	var target := str(event.get("target", ""))
	var output := int(event.get("output_type", _card_output(source)))
	if kind == T.Event.BeforeMainAbilityCast and cards.has(source):
		cards[source].play_cast(output)
	elif kind == T.Event.ActionReleased and cards.has(source):
		cards[source].play_release(card_center(target) - card_center(source))
		if str(event.get("main_ability_id", "")).is_empty():
			passive_links.append({"source": source, "target": target, "start": float(event.get("time", 0.0)), "duration": LINK_SECONDS, "output_type": output})
	_trim_bursts()
	queue_redraw()

## 只根据语义事件创建局部飘字，不触发任何游戏效果。
func play_event(event: Dictionary, impact_time: float) -> void:
	var target := str(event.get("target", ""))
	if target.is_empty(): return
	var kind := int(event.get("kind", -1))
	var output := int(event.get("output_type", _card_output(target)))
	if kind == T.Event.ActionReleased:
		_append_impact(target, output, impact_time, IMPACT_SECONDS, false)
	elif kind == T.Event.DamageResolved and cards.has(target):
		var source_center := card_center(str(event.get("source", "")))
		var direction_sign := -1.0 if source_center.x > card_center(target).x else 1.0
		cards[target].play_hit(output, event.get("critical", false), direction_sign)
		if event.get("critical", false):
			_append_impact(target, output, impact_time, IMPACT_SECONDS, true)
		_pulse_board(event.get("critical", false))
	elif kind == T.Event.HealingResolved and cards.has(target):
		cards[target].play_restore(T.Output.Healing)
	elif kind in [T.Event.ShieldGained, T.Event.DamageGuarded] and cards.has(target):
		cards[target].play_restore(T.Output.Shield)
		if kind == T.Event.DamageGuarded: _append_impact(target, T.Output.Shield, impact_time, IMPACT_SECONDS, false)
	elif kind in [T.Event.AdjacentMainAbilityCast, T.Event.LinkedMainAbilityCast]:
		passive_links.append({"source": str(event.get("source", "")), "target": target, "start": impact_time, "duration": LINK_SECONDS, "output_type": output})
	var text: String = _feedback_text(event)
	var color = Color.WHITE
	match kind:
		T.Event.DamageResolved:
			color = DesignTokens.output_color(event.get("output_type", T.Output.Physical))
		T.Event.HealingResolved:
			color = DesignTokens.output_color(T.Output.Healing)
		T.Event.ShieldGained:
			color = DesignTokens.output_color(T.Output.Shield)
	if not text.is_empty():
		feedback.append({"target": target, "text": text, "event": event.duplicate(true), "color": color, "start": impact_time,
			"duration": FEEDBACK_SECONDS, "critical": event.get("critical", false)})
	_trim_bursts()
	queue_redraw()

## 飘字仅从语义事件翻译，诊断字符串不当作玩家文案。
func _feedback_text(event: Dictionary) -> String:
	match int(event.kind):
		T.Event.DamageResolved:
			var text = tr("ui.combat.blocked") if event.value <= 0 else "−" + RuleText.number(event.value)
			return text
		T.Event.HealingResolved: return "+" + RuleText.number(event.value)
		T.Event.ShieldGained: return ContentText.format_key("ui.combat.shield_gained", {"amount": RuleText.number(event.value)})
		T.Event.HasteGained: return ContentText.text("rules.trigger.haste_gained")
		T.Event.StatusApplied: return RuleText.enum_label("status", T.Status, T.Status[event.detail]) if T.Status.has(event.detail) else ""
	return ""

## 已出现的反馈切语言不重放事件、不重置动画计时。
func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT] and is_node_ready(): cancel_drag(true)
	if what != NOTIFICATION_TRANSLATION_CHANGED or not is_node_ready(): return
	for item in feedback: item.text = _feedback_text(item.event)
	queue_redraw()

## 所有局部表现跟随唯一回放时钟，暂停不推进动画。
func advance(time: float) -> void:
	clock_time = time
	projectiles = projectiles.filter(func(item): return time < item.start + item.duration)
	feedback = feedback.filter(func(item): return time < item.start + item.duration)
	impacts = impacts.filter(func(item): return time < item.start + item.duration)
	passive_links = passive_links.filter(func(item): return time < item.start + item.duration)
	queue_redraw()

## 重开或离开战斗清理所有单场表现。
func clear_effects() -> void:
	projectiles.clear()
	feedback.clear()
	impacts.clear()
	passive_links.clear()
	if _board_tween != null and _board_tween.is_valid(): _board_tween.kill()
	scale = Vector2.ONE
	rotation = 0.0
	for card in cards.values(): card.reset_presentation()
	for id in _pending_defeats.keys(): _card_defeat_finished(id)
	_pending_defeats.clear()
	clock_time = 0
	queue_redraw()

## 已移除卡面仍用原战斗占位定位在途弹道和击杀飘字，不保留可交互尸体。
func card_center(id: String) -> Vector2:
	if cards.has(id): return cards[id].position + cards[id].size / 2
	for snapshot in snapshots:
		if snapshot.id == id: return cell_rect(snapshot.position, snapshot.definition.width, snapshot.definition.height).get_center()
	return Vector2.ZERO

## 按下先记录卡牌候选，轻点和拖拽在释放时互斥处理。
func _card_pressed(id: String) -> void:
	if not interactive or not cards.has(id): return
	if audio != null: audio.play_ui_cue("sfx.adventure.card_pickup", -6.0)
	cancel_drag()
	select_card(id)
	_drag = id
	_drag_origin = get_local_mouse_position()
	_drag_point = _drag_origin
	_drag_moved = false
	set_process(true)
	if cards[id].snapshot.definition.team_id == view_team: cards[id].z_index = 2

## 小幅抖动按点击处理；拖拽只允许我方落位，取消或越界松手不弹详情。
func _input(event: InputEvent) -> void:
	if _drag.is_empty() or not interactive or not event is InputEventMouse: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.canceled:
		cancel_drag()
		return
	var movable: bool = cards[_drag].snapshot.definition.team_id == view_team
	var point: Vector2 = make_input_local(event).position
	_drag_point = point
	if event is InputEventMouseMotion:
		_drag_moved = _drag_moved or point.distance_to(_drag_origin) > DRAG_DISTANCE
		if _drag_moved and movable:
			cards[_drag].position = point - cards[_drag].size / 2
			_update_swap_hover(point, 0.0)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var id = _drag
		var moved = _drag_moved or point.distance_to(_drag_origin) > DRAG_DISTANCE
		var clicked = not moved and cards[id].get_rect().has_point(point)
		var index = position_at(point)
		_update_swap_hover(point, 0.0)
		var target: String = _hovered_ally(point)
		var swap_ready: bool = not _swap_target.is_empty() and _swap_elapsed >= SWAP_HOVER_SECONDS
		cancel_drag()
		get_viewport().set_input_as_handled()
		if moved and movable and not target.is_empty():
			if swap_ready: swap_requested.emit(id, target)
		elif moved and movable and index >= 0: move_requested.emit(id, index)
		elif clicked: card_clicked.emit(id)

## 使用目标的已提交占位命中，拖动卡面的临时坐标不影响候选身份。
func _hovered_ally(point: Vector2) -> String:
	if _drag.is_empty() or not cards.has(_drag) or cards[_drag].snapshot.definition.team_id != view_team: return ""
	for item in snapshots:
		if item.id == _drag or not cards.has(item.id) or item.definition.team_id != view_team: continue
		if cell_rect(item.position, item.definition.width, item.definition.height).has_point(point): return item.id
	return ""

## 同一合法目标连续停留到阈值才高亮；移开或空间不足立即撤销。
func _update_swap_hover(point: Vector2, delta: float) -> void:
	var target: String = _hovered_ally(point)
	if not target.is_empty() and (not can_swap.is_valid() or not can_swap.call(_drag, target)): target = ""
	if target != _swap_target:
		_clear_swap_hover()
		_swap_target = target
	if _swap_target.is_empty(): return
	_swap_elapsed += delta
	if _swap_elapsed >= SWAP_HOVER_SECONDS:
		cards[_swap_target].selected = true
		cards[_swap_target].queue_redraw()

## 目标角标复用选中表现，清除后恢复原选中状态。
func _clear_swap_hover() -> void:
	if cards.has(_swap_target):
		cards[_swap_target].selected = _swap_target == selected
		cards[_swap_target].queue_redraw()
	_swap_target = ""
	_swap_elapsed = 0.0

## 多格位置、冲突与选中仅由已提交输入投射。
func _layout() -> void:
	var blocked = conflicts()
	for id in cards:
		var view = cards[id]
		var item: Dictionary = view.snapshot
		var rect = slot_rect(item.position, item.definition.width, item.definition.height)
		view.set_board_position(rect.position)
		view.size = rect.size
		view.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
		view.z_index = 1 if item.definition.team_id == view_team else 0
		view.conflicted = id in blocked
		view.selected = id == selected
		view.queue_redraw()
	# Control 命中按子节点顺序而非 z_index；冲突时可见在前的我方卡也必须先接收输入。
	for view in cards.values():
		if view.snapshot.definition.team_id == view_team: move_child(view, get_child_count() - 1)
	pivot_offset = size * 0.5
	queue_redraw()

## 统一细框与低对比凹槽仅绘在卡面下方；部署和战斗共用相同几何。
func _draw() -> void:
	var grid = grid_rect()
	var rim = minf(grid.size.x / columns * 0.055, 7.0)
	draw_style_box(BOARD_THEME.get_stylebox("frame", "BattleBoard"), grid.grow(rim))
	for i in range(columns * rows):
		draw_texture_rect(SLOT_TEXTURE, slot_rect(i), false, BOARD_THEME.get_color("slot_tint", "BattleBoard"))

## 前景分成透明特效与清晰文字两层，不创建碰撞或模拟对象。
func draw_effects(layer: Control, feedback_only: bool = false) -> void:
	if feedback_only:
		# 就绪框放在卡面上方的格子外缘，拖动卡覆盖目标时仍能辨识交换反馈。
		if cards.has(_swap_target) and _swap_elapsed >= SWAP_HOVER_SECONDS:
			var target: Dictionary = cards[_swap_target].snapshot
			layer.draw_rect(cell_rect(target.position, target.definition.width, target.definition.height).grow(-1), Color("fff0c4"), false, 1.5, true)
		var font := get_theme_default_font()
		for item in feedback:
			var progress := clampf((clock_time - item.start) / item.duration, 0.0, 1.0)
			Vfx.draw_feedback(layer, font, card_center(item.target), item.text, item.color, progress, item.critical)
		return
	Vfx.draw_ambient(layer, grid_rect(), clock_time)
	for view in cards.values():
		if view.frame.is_empty() or view.is_defeating(): continue
		Vfx.draw_statuses(layer, Rect2(view.position, view.size), view.frame.get("statuses", []), clock_time, _impact_sequences)
	for item in passive_links:
		var progress := clampf((clock_time - item.start) / item.duration, 0.0, 1.0)
		Vfx.draw_link(layer, card_center(item.source), card_center(item.target), progress, item.output_type)
	for item in projectiles:
		var elapsed: float = clock_time - item.start
		if elapsed < 0.0: continue
		var origin := _card_anchor(item.source)
		var target := _card_anchor(item.target)
		var progress := clampf(elapsed / item.duration, 0.0, 1.0)
		var frames: SpriteFrames = item.frames
		var texture := frames.get_frame_texture(item.animation, _frame_at(frames, item.animation, elapsed))
		ProjectileMotion.draw_flight(layer, item.output_type, origin, target, progress, item.size, DesignTokens.output_color(item.output_type), texture, float(frames.get_meta(&"tip_ratio", 0.67)))
	layer.draw_set_transform(Vector2.ZERO)
	for item in impacts:
		var progress := clampf((clock_time - item.start) / item.duration, 0.0, 1.0)
		_draw_impact_sequence(layer, item, progress)
	layer.draw_set_transform(Vector2.ZERO)

## 卡面当前输出为缺省表现类型，事件显式类型始终优先。
func _card_output(id: String) -> int:
	if cards.has(id) and not cards[id].frame.is_empty(): return int(cards[id].frame.get("output_type", T.Output.Special))
	return T.Output.Special

## 配置阶段预热逐帧命中图集，战斗首次爆发不在回放中同步读取磁盘。
func _load_impact_sequences() -> void:
	_impact_sequences.clear()
	if content == null: return
	for output in IMPACT_EFFECT_KEYS:
		var frames: SpriteFrames = content.resource(IMPACT_EFFECT_KEYS[output], "Effect")
		if frames == null or not frames.has_animation(&"impact") or frames.get_frame_count(&"impact") == 0: continue
		_impact_sequences[output] = frames

## 命中记录只绑定事件语义，逐帧资源由已预热的分类图集统一采样。
func _append_impact(target: String, output: int, start: float, duration: float, critical: bool) -> void:
	# 同一次释放和暴击结算共用一个落点爆发，避免两套图集叠成白块。
	for item in impacts:
		if item.target == target and item.output_type == output and is_equal_approx(item.start, start):
			item.critical = item.critical or critical
			return
	impacts.append({"target": target, "output_type": output, "start": start, "duration": duration, "critical": critical})

## 逐帧图集保持原画比例；正面斩痕与腐蚀以卡面中心为支点，不套用地面偏移。
func _draw_impact_sequence(layer: Control, item: Dictionary, progress: float) -> bool:
	var frames: SpriteFrames = _impact_sequences.get(int(item.output_type))
	if frames == null: return false
	var frame_index := _frame_at(frames, &"impact", progress * float(item.duration))
	var texture := frames.get_frame_texture(&"impact", frame_index)
	if texture == null: return false
	var center := _card_anchor(item.target)
	var card_size: Vector2 = cards[item.target].size if cards.has(item.target) else Vector2(100, 118)
	var target_extent := clampf(minf(card_size.x, card_size.y) * 1.38, 72.0, 148.0)
	if int(item.output_type) in [T.Output.Physical, T.Output.Poison]:
		target_extent = minf(card_size.x, card_size.y) * 1.02
	if item.critical: target_extent *= 1.12
	if int(item.output_type) == T.Output.Burn: center.y -= target_extent * 0.26
	var natural := texture.get_size()
	var display_scale := target_extent / maxf(natural.x, natural.y)
	var display_size := natural * display_scale
	layer.draw_set_transform(center)
	var alpha := 1.0 - smoothstep(0.72, 1.0, progress)
	layer.draw_texture_rect(texture, Rect2(-display_size * 0.5, display_size), false, Color(1, 1, 1, alpha))
	layer.draw_set_transform(Vector2.ZERO)
	return true

## 弹道和命中固定在卡牌静止占位中心，受击回弹不会拖动落点或弯折在途轨迹。
func _card_anchor(id: String) -> Vector2:
	for snapshot in snapshots:
		if snapshot.id == id: return cell_rect(snapshot.position, snapshot.definition.width, snapshot.definition.height).get_center()
	return card_center(id)

## 并发爆发保留最新高价值反馈，限制极端连锁造成的分配与遮挡。
func _trim_bursts() -> void:
	while impacts.size() > MAX_BURSTS: impacts.pop_front()
	while passive_links.size() > MAX_BURSTS: passive_links.pop_front()
	while feedback.size() > MAX_BURSTS: feedback.pop_front()

## 棋盘只做轻微整体脉冲，常规伤害克制、暴击增强，避免连续镜头晃动眩晕。
func _pulse_board(critical: bool) -> void:
	if not critical: return
	if _board_tween != null and _board_tween.is_valid(): _board_tween.kill()
	scale = Vector2.ONE
	rotation = 0.0
	var strength := 0.006
	var angle := strength * (1.0 if int(clock_time * 1000.0) % 2 == 0 else -1.0)
	_board_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_board_tween.tween_property(self, "scale", Vector2.ONE * (1.0 + strength), 0.035).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_board_tween.parallel().tween_property(self, "rotation", angle, 0.035)
	_board_tween.tween_property(self, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_board_tween.parallel().tween_property(self, "rotation", 0.0, 0.11)

## 按逐帧权重采样，循环弹道可重复播放，单次命中到末帧停止。
static func _frame_at(frames: SpriteFrames, animation: StringName, elapsed: float) -> int:
	var total := 0.0
	var count := frames.get_frame_count(animation)
	if count == 0: return -1
	for index in range(count): total += frames.get_frame_duration(animation, index)
	var position := elapsed * frames.get_animation_speed(animation)
	position = fmod(position, total) if frames.get_animation_loop(animation) else minf(position, total)
	for index in range(count):
		position -= frames.get_frame_duration(animation, index)
		if position < 0: return index
	return count - 1
