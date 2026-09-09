class_name CardFaceView
extends CardArtwork
## 部署／战斗、目录与内容预览共用的只读卡面，在同一位图框上增加数值徽章。

const STANDARD_SIZE: Vector2 = Vector2(100, 118)

var _stats_badge: Control

## 卡面几何只响应尺寸，不绑定输入、动画或战斗执行器。
func _ready() -> void:
	super._ready()
	_bind_nodes()
	resized.connect(_layout_card)
	_layout_card()

## 插画和框由底层统一维护，多格卡只扩展卡身。
func set_appearance(texture: Texture2D, chapter_level: int, columns: int) -> void:
	super.set_appearance(texture, chapter_level, columns)
	_bind_nodes()
	_layout_card()

## 数字与队伍由装配帧提供；按观察方区分生命底色，不按卡牌类型判断敌我。
func set_stats(state: Dictionary, perspective: int = 0) -> void:
	_bind_nodes()
	var output: int = state.output_type
	var enemy: bool = int(state.get("team_id", perspective)) != perspective
	_stats_badge.set_values(output, state.stats.get(CombatTypes.output_stat(output), 0), state.health, state.maximum_health, enemy)
	_layout_card()

## 缩略图宿主按完整可见范围适配，避免突出卡身的徽章被裁掉。
func get_visual_rect() -> Rect2:
	_bind_nodes()
	return Rect2(Vector2.ZERO, size).merge(_stats_badge.get_rect())

## 入树前绑定稳定节点，保持战斗卡面与只读预览使用相同入口。
func _bind_nodes() -> void:
	_bind_art_nodes()
	if _stats_badge == null: _stats_badge = $StatsBadge

## 框与徽章共用同一不可用状态，只压暗数值底板，不改变文字、几何和生命比例。
func _refresh_availability() -> void:
	super._refresh_availability()
	_bind_nodes()
	_stats_badge.set_unavailable(_unavailable)

## 徽章宽度由数字与生命条余量决定；多格卡仍按单格基准排版。
func _layout_card() -> void:
	var cell_width: float = size.x / _columns
	_stats_badge.fit_to_card(cell_width, size.x)
	_stats_badge.position = Vector2((size.x - _stats_badge.size.x) / 2, -_stats_badge.size.y * 0.23)
