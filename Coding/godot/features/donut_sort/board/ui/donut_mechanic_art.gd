class_name DonutMechanicArt
extends RefCounted
## 提供圆纸托机制图；口味顺序保持既有编号，不按外部包列表重排。

const HOLDER: Texture2D = preload("res://features/donut_sort/board/ui/art/paper_holder_round.tres")
const FRONT: Texture2D = preload("res://features/donut_sort/board/ui/art/paper_holder_round_front.tres")
const SINGLE_FRONT: Texture2D = preload("res://features/donut_sort/board/ui/art/mechanics/holder_single_front.tres")
# 按现有口味 ID 绑定原图；缺图的两个备用口味使用奶白基底染色。
const TINTED_FIXED_FLAVORS: Array[int] = [11, 14]
const FIXED: Array[Texture2D] = [
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_pink.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_brown.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_green.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_blue.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_orange.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_ivory.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_purple.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_magenta.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_red.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_russet.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_teal.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_ivory.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_pistachio.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_lavender.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_ivory.tres")]
const FIXED_FRONTS: Array[Texture2D] = [
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_pink_front.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_brown_front.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_green_front.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_blue_front.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_orange_front.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_ivory_front.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_purple_front.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_magenta_front.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_red_front.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_russet_front.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_teal_front.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_ivory_front.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_pistachio_front.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_lavender_front.tres"),
	preload("res://features/donut_sort/board/ui/art/mechanics/holder_fixed_ivory_front.tres")]
const SINGLE: Texture2D = preload("res://features/donut_sort/board/ui/art/mechanics/holder_single.tres")
const COVER: Texture2D = preload("res://features/donut_sort/board/ui/art/mechanics/cover_opaque_round.tres")
const ICE_SHELL: Texture2D = preload("res://features/donut_sort/board/ui/art/mechanics/ice_stack_shell.tres")
const CYCLE: Texture2D = preload("res://features/donut_sort/board/ui/art/mechanics/badge_cycle_front.tres")
const BOMB: Texture2D = preload("res://features/donut_sort/board/ui/art/mechanics/badge_bomb_front.tres")


## 固定纸托按盒子的指定口味选图，清空或放入其他食物不会改变底色。
static func holder(slot: Dictionary) -> Texture2D:
	if slot.kind == "single":
		return SINGLE
	if slot.get("box") != null and slot.box.kind == "fixed":
		return FIXED[int(slot.box.fixed_flavor)]
	return HOLDER


## 前沿与底图使用同一张原图的坐标片段，保留原色折纹和单格数字牌。
static func front(holder_texture: Texture2D) -> Texture2D:
	if holder_texture == SINGLE:
		return SINGLE_FRONT
	var fixed_index: int = FIXED.find(holder_texture)
	if fixed_index >= 0:
		return FIXED_FRONTS[fixed_index]
	return FRONT
