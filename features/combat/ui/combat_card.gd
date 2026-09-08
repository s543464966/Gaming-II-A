class_name CombatCardView
extends "res://ui/components/content/card_face.gd"
## 单张战斗卡的只读表现；不拥有生命、占位和拖拽提交逻辑。

signal pressed(id: String)
const Text = preload("res://features/combat/ui/combat_text.gd")
var snapshot: Dictionary = {}
var view_team: int = 0
var frame: Dictionary = {}
var conflicted: bool = false
var selected: bool = false
var _status: Label
var _cooldown_scan: ColorRect
var _scan_material: ShaderMaterial
var _state_outline: Control
var _description: String = ""
var _name_key: String = ""
var _cooldown_enabled: bool = false

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
	move_child(_stats_badge, _cooldown_scan.get_index())
	_scan_material = _cooldown_scan.material
	if not _cooldown_scan.resized.is_connected(_sync_scan_size): _cooldown_scan.resized.connect(_sync_scan_size)
	_sync_scan_size()
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
	set_stats(frame)
	var statuses: Array = Text.status_labels(frame)
	if frame.get("ammo_capacity", 0) > 0 and frame.ammo_remaining == 0: statuses.append(tr("ui.combat.ammo_empty"))
	_status.text = "·".join(statuses)
	_status.visible = not frame.defeated and not statuses.is_empty()
	_update_cooldown_scan()
	tooltip_text = _description + "\n" + Text.battle_card(snapshot.definition, frame)
	queue_redraw()

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
