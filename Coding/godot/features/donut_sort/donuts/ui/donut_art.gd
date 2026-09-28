class_name DonutArt
extends RefCounted
## 集中提供订单、餐盒、拖拽和动效共用的甜甜圈纹理与原始显示尺寸。

const FOOD: Array[Texture2D] = [
	preload("res://game_content/donuts/art/donut_pink_sprinkles.tres"),
	preload("res://game_content/donuts/art/donut_chocolate_nuts.tres"),
	preload("res://game_content/donuts/art/donut_matcha_drizzle.tres"),
	preload("res://game_content/donuts/art/donut_blueberry.tres"),
	preload("res://game_content/donuts/art/donut_lemon_drizzle.tres"),
	preload("res://game_content/donuts/art/donut_vanilla_sprinkles.tres"),
	preload("res://game_content/donuts/art/donut_purple_sprinkles.tres")]
const HIDDEN: Texture2D = preload("res://game_content/donuts/art/donut_concealed_gray.tres")
const FOOD_SIZE: Vector2 = Vector2(142, 131)
