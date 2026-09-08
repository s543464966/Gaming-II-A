class_name MechanicBuild
extends RefCounted
## 一次玩法运行的构筑事实；不包含路线、市场、奖励阶段或存储 I/O。

var cards: Array = []
## 开始本次构筑时锁定账号成长，期间账号升星不会暗改已进行的章节。
var permanent_growth: Dictionary = {}
## 每份遗物保留独立身份与消耗状态；重复获得不合并为等级。
var relics: Array = []
## 模式提供的账号天赋输入快照；不能在构筑中花点或学习。
var talents: Array = []
var next_sequence: int = 0

## 按稳定实例 ID 找到可变卡牌。
func find_card(id: String) -> Dictionary:
	for card in cards:
		if card.id == id: return card
	return {}

## 生成单调实例标识，不复用已删除职责的存档编号。
func create_card(id: String, kind: int, health: float, position: int, width: int, height: int) -> Dictionary:
	var instance = "run:%s:%s:%d" % [CardTypes.Kind.find_key(kind), id, next_sequence]
	next_sequence += 1
	return {"id": instance, "definition_id": id, "kind": kind, "max_health": maxf(1, health),
		"health": maxf(1, health), "position": position, "width": width, "height": height, "copies": 1}

## 构筑只保存实例事实，不复制静态定义或战斗中的临时状态。
func capture() -> Dictionary:
	return {"next_sequence": next_sequence,
		"permanent_growth": permanent_growth.duplicate(true),
		"cards": cards.map(func(card): return {"id": card.id, "definition_id": card.definition_id, "kind": card.kind,
			"health": card.health, "position": card.position, "copies": card.copies}),
		"relics": relics.duplicate(true), "talents": talents.duplicate()}
