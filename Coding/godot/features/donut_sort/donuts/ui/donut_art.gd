class_name DonutArt
extends RefCounted
## 集中提供餐盒、拖拽和动效共用的立体甜甜圈纹理与原始显示尺寸。

const FOOD: Array[Texture2D] = [
	preload("res://game_content/donuts/art/donut_pink_plain.tres"),
	preload("res://game_content/donuts/art/donut_brown_plain.tres"),
	preload("res://game_content/donuts/art/donut_green_plain.tres"),
	preload("res://game_content/donuts/art/donut_blue_plain.tres"),
	preload("res://game_content/donuts/art/donut_orange_plain.tres"),
	preload("res://game_content/donuts/art/donut_ivory_sprinkles.tres"),
	preload("res://game_content/donuts/art/donut_purple_plain.tres"),
	preload("res://game_content/donuts/art/donut_magenta_sprinkles.tres"),
	preload("res://game_content/donuts/art/donut_red_drizzle.tres"),
	preload("res://game_content/donuts/art/donut_russet_sprinkles.tres"),
	preload("res://game_content/donuts/art/donut_teal_sprinkles.tres"),
	preload("res://game_content/donuts/art/donut_charcoal_sprinkles.tres"),
	preload("res://game_content/donuts/art/donut_pistachio_sprinkles.tres"),
	preload("res://game_content/donuts/art/donut_lavender_drizzle.tres"),
	preload("res://game_content/donuts/art/donut_mocha_drizzle.tres")]
const HIDDEN: Texture2D = preload("res://features/donut_sort/board/ui/art/mechanics/donut_hidden_neutral.tres")
const FOOD_SIZE: Vector2 = Vector2(160, 114) # 设计单位；在 200×126 纸托内露出两侧与前沿褶边。
