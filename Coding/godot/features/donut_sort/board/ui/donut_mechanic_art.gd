class_name DonutMechanicArt
extends RefCounted
## 提供圆纸托机制图；口味顺序保持既有编号，不按外部包列表重排。

const ROOT: String = "res://features/donut_sort/board/ui/art/mechanics/"
const HOLDER: Texture2D = preload("res://features/donut_sort/board/ui/art/paper_holder_round.tres")
const SINGLE: Texture2D = preload("res://features/donut_sort/board/ui/art/mechanics/holder_single.tres")
const COVER: Texture2D = preload("res://features/donut_sort/board/ui/art/mechanics/cover_opaque_round.tres")
const FROST: Texture2D = preload("res://features/donut_sort/board/ui/art/mechanics/frost_donut_overlay.tres")
const CYCLE: Texture2D = preload("res://features/donut_sort/board/ui/art/mechanics/badge_cycle_front.tres")
const BOMB: Texture2D = preload("res://features/donut_sort/board/ui/art/mechanics/badge_bomb_front.tres")
const FLAVORS: Array[String] = ["pink", "brown", "green", "blue", "orange", "ivory", "purple", "magenta", "red", "russet", "teal", "charcoal", "pistachio", "lavender", "mocha"]


## 固定颜色随实体盒而非当前食物变化，普通盒与单颗盒复用基础底座。
static func holder(slot: Dictionary) -> Texture2D:
	if slot.kind == "single":
		return SINGLE
	if slot.get("box") != null and slot.box.kind == "fixed":
		return load(ROOT + "holder_fixed_%s.tres" % FLAVORS[int(slot.box.fixed_flavor)])
	return HOLDER
