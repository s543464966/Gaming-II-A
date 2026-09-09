class_name CombatCardView
extends "res://ui/components/content/card_face.gd"
## 单张战斗卡的只读表现；不拥有生命、占位和拖拽提交逻辑。

signal pressed(id: String)
signal defeat_finished(id: String)
const Text = preload("res://features/combat/ui/combat_text.gd")
var snapshot: Dictionary = {}
var frame: Dictionary = {}
## 切换观察方只刷新敌我表现，保留原始队伍和已结算生命值。
var view_team: int = 0:
	set(value):
		view_team = value
		if not frame.is_empty(): set_stats(frame, view_team)
		queue_redraw()
var conflicted: bool = false
var selected: bool = false
var _status: Label
var _cooldown_scan: ColorRect
var _scan_material: ShaderMaterial
var _impact_flash: ColorRect
var _flash_material: ShaderMaterial
var _state_outline: Control
var _description: String = ""
var _name_key: String = ""
var _cooldown_enabled: bool = false
var _rest_position: Vector2 = Vector2.ZERO
var _motion_tween: Tween
var _lunge_tween: Tween
var _flash_tween: Tween
var _defeating: bool = false

## 准备与战斗共用卡框、插画与输出生命双区徽章，初值仅消费装配预览帧。
func configure(value: Dictionary, content: RefCounted, perspective: int = 0, columns: int = BattleGrid.COLUMNS) -> void:
	snapshot = value
	view_team = perspective
	var row: Dictionary = content.get_record("cards", value.definition.id)
	set_appearance(content.resource(row.get("texture_key", "")), int(value.definition.get("chapter_level", 0)), int(value.definition.width))
	_state_outline = $StateOutline
	if not _state_outline.draw.is_connected(_draw_state): _state_outline.draw.connect(_draw_state)
	_status = $Status
	_cooldown_scan = $CooldownScan
	_impact_flash = $ImpactFlash
	move_child(_stats_badge, _impact_flash.get_index() + 1)
	_scan_material = _cooldown_scan.material
	_flash_material = _impact_flash.material
	if not _cooldown_scan.resized.is_connected(_sync_scan_size): _cooldown_scan.resized.connect(_sync_scan_size)
	if not resized.is_connected(_sync_pivot): resized.connect(_sync_pivot)
	_sync_scan_size()
	_sync_pivot()
	_name_key = row.name_key
	_refresh_identity()
	apply_frame(BattleAssembly.preview_frame(value, columns))

## 语言刷新不创建战斗单位、不改写状态帧或拖拽位置。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _translate_view.call_deferred()

## 详情与异常状态按当前语言重算，已有帧保持同一数值。
func _translate_view() -> void:
	if snapshot.is_empty() or not is_inside_tree() or is_queued_for_deletion(): return
	_refresh_identity()
	if not frame.is_empty(): apply_frame(frame)

## 名称只用于详情，不在基础卡面显示名字或成长等级。
func _refresh_identity() -> void:
	_description = ContentText.field({"id": snapshot.definition.id, "name_key": _name_key})

## 状态帧覆盖全部易变字段，死亡与冷却不由 UI 推断结算。
func apply_frame(value: Dictionary) -> void:
	frame = value
	visible = not frame.defeated
	if not frame.defeated: _defeating = false
	set_stats(frame, view_team)
	var statuses: Array = Text.status_labels(frame)
	if frame.get("ammo_capacity", 0) > 0 and frame.ammo_remaining == 0: statuses.append(tr("ui.combat.ammo_empty"))
	_status.text = "·".join(statuses)
	_status.visible = not frame.defeated and not statuses.is_empty()
	_update_cooldown_scan()
	tooltip_text = _description + "\n" + Text.battle_card(snapshot.definition, frame)
	queue_redraw()

## 棋盘布局更新静止坐标；在途前冲会从最新位置开始并最终回到这里。
func set_board_position(value: Vector2) -> void:
	_rest_position = value
	if _lunge_tween != null and _lunge_tween.is_valid(): _lunge_tween.kill()
	position = value

## 棋盘只用此状态避免在退场卡牌上继续绘制常驻状态循环。
func is_defeating() -> bool:
	return _defeating

## 主动技能用压缩、抬升和有色光芯衔接既有冷却扫光的完成时刻。
func play_cast(output: int) -> void:
	if _defeating: return
	_reset_motion()
	_flash(DesignTokens.output_color(output), 0.92, 0.28)
	_motion_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_motion_tween.tween_property(self, "scale", Vector2(0.94, 1.04), 0.055).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.parallel().tween_property(self, "rotation", -0.018, 0.055)
	_motion_tween.tween_property(self, "scale", Vector2(1.08, 0.96), 0.085).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", 0.012, 0.085)
	_motion_tween.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", 0.0, 0.14)

## 效果发射只做短距离定向前冲，结算目标仍来自战报而非卡牌坐标。
func play_release(direction: Vector2) -> void:
	if _defeating: return
	if _lunge_tween != null and _lunge_tween.is_valid(): _lunge_tween.kill()
	position = _rest_position
	var offset := direction.normalized() * clampf(minf(size.x, size.y) * 0.10, 5.0, 10.0) if not direction.is_zero_approx() else Vector2(0, -7)
	_lunge_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_lunge_tween.tween_property(self, "position", _rest_position + offset, 0.075).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_lunge_tween.tween_interval(0.035)
	_lunge_tween.tween_property(self, "position", _rest_position, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 受击使用横向压缩、偏转和闪白，暴击增加停留与回弹幅度。
func play_hit(output: int, critical: bool = false, direction_sign: float = 1.0) -> void:
	if _defeating: return
	_reset_motion()
	_flash(Color("fff7dc") if critical else DesignTokens.output_color(output), 1.0, 0.24 if critical else 0.18)
	var squash := Vector2(1.12, 0.88) if critical else Vector2(1.07, 0.93)
	var angle := (0.035 if critical else 0.022) * direction_sign
	_motion_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_motion_tween.tween_property(self, "scale", squash, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", angle, 0.045)
	_motion_tween.tween_interval(0.04 if critical else 0.015)
	_motion_tween.tween_property(self, "scale", Vector2(0.98, 1.03), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", -angle * 0.35, 0.08)
	_motion_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", 0.0, 0.12)

## 恢复与护盾采用向外舒展的回弹，避免沿用伤害的压缩方向。
func play_restore(output: int) -> void:
	if _defeating: return
	_reset_motion()
	_flash(DesignTokens.output_color(output), 0.86, 0.32)
	_motion_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_motion_tween.tween_property(self, "scale", Vector2(1.055, 1.055), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 死亡帧先显示零生命，再经闪白、偏转和缩暗退场后通知棋盘移除。
func play_defeat(value: Dictionary) -> void:
	if _defeating: return
	_defeating = true
	frame = value
	set_stats(frame, view_team)
	_status.hide()
	_cooldown_scan.hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true
	_reset_motion()
	if _lunge_tween != null and _lunge_tween.is_valid(): _lunge_tween.kill()
	position = _rest_position
	_flash(Color("fff1cf"), 1.0, 0.34)
	_motion_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_motion_tween.tween_property(self, "scale", Vector2(1.08, 0.94), 0.065).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_interval(0.045)
	_motion_tween.tween_property(self, "scale", Vector2(0.72, 1.12), 0.27).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.parallel().tween_property(self, "rotation", 0.10 if int(snapshot.get("position", 0)) % 2 == 0 else -0.10, 0.27)
	_motion_tween.parallel().tween_property(self, "modulate", Color(0.42, 0.29, 0.24, 0.0), 0.27)
	_motion_tween.tween_callback(func(): defeat_finished.emit(str(snapshot.get("id", ""))))

## 离开战斗或重建棋盘时停止局部动画并还原卡牌静止外观。
func reset_presentation() -> void:
	_reset_motion()
	if _lunge_tween != null and _lunge_tween.is_valid(): _lunge_tween.kill()
	if _flash_tween != null and _flash_tween.is_valid(): _flash_tween.kill()
	position = _rest_position
	modulate = Color.WHITE
	_defeating = false
	if _flash_material != null: _flash_material.set_shader_parameter("amount", 0.0)
	visible = frame.is_empty() or not frame.get("defeated", false)

## 每次尺寸变化同步变换中心，宽卡仍绕完整卡身蓄力和受击。
func _sync_pivot() -> void:
	pivot_offset = size * 0.5

## 新动作接管缩放与旋转前回到稳定姿态，位置前冲由独立轨道管理。
func _reset_motion() -> void:
	if _motion_tween != null and _motion_tween.is_valid(): _motion_tween.kill()
	scale = Vector2.ONE
	rotation = 0.0
	modulate = Color.WHITE

## 闪光材质独立计时，连续命中只重启本卡强度而不串到其他实例。
func _flash(color: Color, strength: float, duration: float) -> void:
	if _flash_material == null: return
	if _flash_tween != null and _flash_tween.is_valid(): _flash_tween.kill()
	_flash_material.set_shader_parameter("flash_color", color.lerp(Color("fff6dc"), 0.42))
	_flash_material.set_shader_parameter("amount", 0.0)
	_flash_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_flash_tween.tween_property(_flash_material, "shader_parameter/amount", strength, minf(0.055, duration * 0.25)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_flash_material, "shader_parameter/amount", 0.0, maxf(0.01, duration - minf(0.055, duration * 0.25))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## 外层战斗阶段显式开启扫描；预览默认关闭，切换不改变冷却事实。
func set_cooldown_enabled(value: bool) -> void:
	_cooldown_enabled = value
	if not frame.is_empty(): _update_cooldown_scan()

## 扫描只在战斗阶段映射真实冷却；重置、充能及延迟跟随新帧，不自行计时。
func _update_cooldown_scan() -> void:
	var duration: float = float(frame.cooldown) if frame.cooldown != null else 0.0
	var has_cooldown = duration > 0.0 and not frame.defeated
	var exhausted = frame.get("ammo_capacity", 0) > 0 and frame.get("ammo_remaining", 0) == 0
	_cooldown_scan.visible = _cooldown_enabled and has_cooldown and frame.remaining > 0.0 and not exhausted
	var progress = clampf(1.0 - float(frame.remaining) / duration, 0.0, 1.0) if has_cooldown else 0.0
	sample_cooldown(progress)

## 只把回放逐渲染帧采样的比例写入材质，不修改冷却、文字或状态帧。
func sample_cooldown(progress: float) -> void:
	_scan_material.set_shader_parameter("progress", clampf(progress, 0.0, 1.0))

## 线宽和光点按卡面实际尺寸绘制，多格卡横向铺满而不拉粗扫描线。
func _sync_scan_size() -> void:
	_scan_material.set_shader_parameter("card_size", _cooldown_scan.size)

## 卡框颜色只表示强化，交互与敌我状态由独立层标识。
func _draw() -> void:
	if _state_outline != null: _state_outline.queue_redraw()

## 敌方用右上角标；选中用外侧角线，冲突加叉，均不覆盖强化等级色。
func _draw_state() -> void:
	var danger := Color("f07773")
	var mark: float = clampf(size.x / maxi(1, int(snapshot.get("definition", {}).get("width", 1))) * 0.08, 5, 9)
	if snapshot.get("definition", {}).get("team_id") != view_team:
		_state_outline.draw_colored_polygon(PackedVector2Array([Vector2(size.x - mark - 2, 3), Vector2(size.x - 3, 3), Vector2(size.x - 3, mark + 2)]), danger)
	if not selected and not conflicted: return
	var color: Color = danger if conflicted else Color("fff0c4")
	for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		var inward: Vector2 = Vector2(1 if corner.x == 0 else -1, 1 if corner.y == 0 else -1)
		var origin: Vector2 = corner - inward * 1.5
		_state_outline.draw_polyline(PackedVector2Array([origin + Vector2(inward.x * mark, 0), origin, origin + Vector2(0, inward.y * mark)]), color, 1.5, true)
	if conflicted:
		var center: Vector2 = Vector2(size.x / 2, size.y - mark)
		_state_outline.draw_line(center - Vector2(3, 3), center + Vector2(3, 3), danger, 2, true)
		_state_outline.draw_line(center + Vector2(-3, 3), center + Vector2(3, -3), danger, 2, true)

## 鼠标与平台触摸模拟共用一次按下入口。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(snapshot.id)
		accept_event()
