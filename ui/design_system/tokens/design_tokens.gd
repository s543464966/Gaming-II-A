@tool
class_name DesignTokens
extends Resource
## 通用 UI 的颜色、字号、间距和触摸尺寸事实源；游戏数值不进入设计令牌。

@export var text_color: Color = Color(0.96, 0.97, 1, 1):
	set(value):
		text_color = value
		emit_changed()
@export var muted_color: Color = Color(0.50, 0.54, 0.64, 1):
	set(value):
		muted_color = value
		emit_changed()
@export var surface_color: Color = Color(0.12, 0.14, 0.21, 1):
	set(value):
		surface_color = value
		emit_changed()
@export var panel_color: Color = Color(0.075, 0.09, 0.14, 0.98):
	set(value):
		panel_color = value
		emit_changed()
@export var selected_color: Color = Color(0.20, 0.34, 0.52, 1):
	set(value):
		selected_color = value
		emit_changed()
@export var border_color: Color = Color(0.30, 0.36, 0.48, 1):
	set(value):
		border_color = value
		emit_changed()
@export var accent_color: Color = Color(0.36, 0.67, 1, 1):
	set(value):
		accent_color = value
		emit_changed()
@export var focus_color: Color = Color(0.65, 0.83, 1, 1):
	set(value):
		focus_color = value
		emit_changed()
@export var health_color: Color = Color(0.18, 0.52, 0.25, 1):
	set(value):
		health_color = value
		emit_changed()
@export var card_value_color: Color = Color("f7edcf"):
	set(value):
		card_value_color = value
		emit_changed()
@export var card_badge_rim_color: Color = Color("75684c"):
	set(value):
		card_badge_rim_color = value
		emit_changed()
## 未获得／不可用框复用银白 PNG，只压低 RGB，保留原始透明轮廓与笔触。
@export var card_unavailable_frame_tint: Color = Color(0.36, 0.36, 0.36, 1):
	set(value):
		card_unavailable_frame_tint = value
		emit_changed()
## 不可用数值底板比正常版本柔暗，独立于框倍率，避免血条变黑或数字随之变暗。
@export var card_unavailable_surface_tint: Color = Color(0.60, 0.60, 0.60, 1):
	set(value):
		card_unavailable_surface_tint = value
		emit_changed()
@export var modal_shade: Color = Color(0, 0, 0, 0.78):
	set(value):
		modal_shade = value
		emit_changed()
## 无底色入口的 RGB 明度倍率，1 为原始颜色；不改变透明度或点击区域。
@export_range(0.5, 1.5, 0.01) var entry_normal_brightness: float = 0.90:
	set(value):
		entry_normal_brightness = value
		emit_changed()
@export_range(0.5, 1.5, 0.01) var entry_hover_brightness: float = 1.02:
	set(value):
		entry_hover_brightness = value
		emit_changed()
@export_range(0.5, 1.5, 0.01) var entry_pressed_brightness: float = 1.16:
	set(value):
		entry_pressed_brightness = value
		emit_changed()
@export_range(12, 40) var body_font_size: int = 30:
	set(value):
		body_font_size = value
		emit_changed()
@export_range(0, 64) var page_margin: int = 24:
	set(value):
		page_margin = value
		emit_changed()
@export_range(0, 64) var space_small: int = 12:
	set(value):
		space_small = value
		emit_changed()
@export_range(0, 64) var space_medium: int = 16:
	set(value):
		space_medium = value
		emit_changed()
@export_range(44, 144) var button_height: int = 108:
	set(value):
		button_height = value
		emit_changed()
@export_range(44, 144) var input_height: int = 108:
	set(value):
		input_height = value
		emit_changed()
## 内容浮层采用逻辑像素上限，实际尺寸还受当前安全视口比例约束。
@export var detail_popup_width: float = 500.0
@export var detail_popup_height: float = 820.0
@export_range(44, 108) var detail_action_height: int = 60
## 通用详情沿用石雕黑金与暖纸配色，避免改变其他界面的基础主题。
@export var detail_ink_color: Color = Color("30291d"):
	set(value):
		detail_ink_color = value
		emit_changed()
@export var detail_caption_color: Color = Color("62543f"):
	set(value):
		detail_caption_color = value
		emit_changed()
@export var detail_gold_color: Color = Color("dcc992"):
	set(value):
		detail_gold_color = value
		emit_changed()
@export var detail_rule_color: Color = Color(0.52, 0.40, 0.23, 0.26):
	set(value):
		detail_rule_color = value
		emit_changed()
@export_range(0, 32) var corner_radius: int = 12:
	set(value):
		corner_radius = value
		emit_changed()
@export_range(0, 32) var panel_radius: int = 18:
	set(value):
		panel_radius = value
		emit_changed()

## 六类输出的语义原色供弹道与特效使用；徽章单独压暗，特殊类没有数值色。
static func output_color(kind: int) -> Color:
	match kind:
		CombatTypes.Output.Physical: return Color("d84d3f")
		CombatTypes.Output.Witchcraft: return Color("9b59d0")
		CombatTypes.Output.Burn: return Color("ea7438")
		CombatTypes.Output.Poison: return Color("299e91")
		CombatTypes.Output.Healing: return Color("30b96e")
		CombatTypes.Output.Shield: return Color("dea344")
	return Color.TRANSPARENT
