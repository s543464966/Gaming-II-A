class_name AttributeIcons
extends RefCounted
## 属性图标与显示名称的唯一映射；规则占位符只携带稳定属性身份。

const TEXTURES: Dictionary = {
	"physical_damage": preload("res://ui/design_system/icons/attributes/physical_damage.png"),
	"witchcraft_damage": preload("res://ui/design_system/icons/attributes/witchcraft_damage.png"),
	"burn_damage": preload("res://ui/design_system/icons/attributes/burn_damage.png"),
	"poison_damage": preload("res://ui/design_system/icons/attributes/poison_damage.png"),
	"healing_power": preload("res://ui/design_system/icons/attributes/healing_power.png"),
	"shield_power": preload("res://ui/design_system/icons/attributes/shield_power.png"),
	"max_health": preload("res://ui/design_system/icons/attributes/max_health.png"),
	"health": preload("res://ui/design_system/icons/attributes/max_health.png"),
	"crit_chance": preload("res://ui/design_system/icons/attributes/crit_chance.png"),
	"crit_multiplier": preload("res://ui/design_system/icons/attributes/crit_multiplier.png"),
	"lifesteal_ratio": preload("res://ui/design_system/icons/attributes/lifesteal_ratio.png"),
	"haste_ratio": preload("res://ui/design_system/icons/attributes/haste_ratio.png"),
	"cooldown_seconds": preload("res://ui/design_system/icons/attributes/cooldown_seconds.png"),
	"ammo_capacity": preload("res://ui/design_system/icons/attributes/ammo_capacity.png"),
	"multicast_bonus": preload("res://ui/design_system/icons/attributes/multicast_bonus.png"),
}

## 名称继续使用原生翻译，悬停、点按和纯文本共用同一词汇。
static func label(stat: String) -> String:
	if stat == "health": return ContentText.text("rules.resource.health")
	return ContentText.text("rules.stat." + stat)

## 详情只接收受控属性标记；纯文本消费者仍获得完整名称。
static func symbol(stat: String, iconic: bool) -> String:
	return "[stat:%s]" % stat if iconic and TEXTURES.has(stat) else label(stat)

## 作者模板决定图标位置，不在完成翻译的句子中搜索并替换词语。
static func format_rule(key: String, arguments: Dictionary, iconic: bool) -> String:
	var values: Dictionary = arguments.duplicate()
	var template: String = ContentText.text(key)
	if template.contains("{stat_"):
		for stat: String in TEXTURES:
			if template.contains("{stat_" + stat + "}"): values["stat_" + stat] = symbol(stat, iconic)
	return ContentText.format_key(key, values)

## 无障碍与测试文本使用同一图标身份还原，不丢弃数值或单位。
static func plain(text: String) -> String:
	for stat: String in TEXTURES: text = text.replace("[stat:%s]" % stat, label(stat))
	return text
