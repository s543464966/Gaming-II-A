class_name DonutArt
extends RefCounted
## 集中提供餐盒、拖拽和动效共用的立体甜甜圈纹理与原始显示尺寸。

const FOOD: Array[Texture2D] = [
	preload("res://game_content/donuts/art/soft_glaze_pink.tres"),
	preload("res://game_content/donuts/art/soft_glaze_cocoa.tres"),
	preload("res://game_content/donuts/art/soft_glaze_forest_green.tres"),
	preload("res://game_content/donuts/art/soft_glaze_sky_blue.tres"),
	preload("res://game_content/donuts/art/soft_glaze_orange.tres"),
	preload("res://game_content/donuts/art/soft_glaze_ivory.tres"),
	preload("res://game_content/donuts/art/soft_glaze_purple.tres"),
	preload("res://game_content/donuts/art/soft_glaze_raspberry.tres"),
	preload("res://game_content/donuts/art/soft_glaze_red.tres"),
	preload("res://game_content/donuts/art/soft_glaze_caramel.tres"),
	preload("res://game_content/donuts/art/soft_glaze_teal.tres"),
	preload("res://game_content/donuts/art/soft_glaze_royal_blue.tres"),
	preload("res://game_content/donuts/art/soft_glaze_lime.tres"),
	preload("res://game_content/donuts/art/soft_glaze_lavender.tres"),
	preload("res://game_content/donuts/art/soft_glaze_yellow.tres")]
const HIDDEN: Texture2D = preload("res://game_content/donuts/art/soft_glaze_hidden_gray.tres")
const FOOD_SIZE: Vector2 = Vector2(160, 136) # 设计单位；在 200×126 纸托内露出两侧与前沿褶边。
# 包内缺少的宝蓝、柠檬黄纸托沿用此色板；其余固定纸托直接使用彩色原图。
const FLAVOR_COLORS: Array[Color] = [Color("f660aa"), Color("74351d"), Color("278449"), Color("00abe9"),
	Color("ff6810"), Color("ead6af"), Color("821dde"), Color("c71c5c"), Color("f02737"),
	Color("c98a50"), Color("00a8a4"), Color("255bc5"), Color("a5c937"), Color("b584f4"), Color("ffbb00")]
