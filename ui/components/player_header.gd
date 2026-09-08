extends Control
## Home 与章节路线共用的账号顶栏；只呈现宿主传入的数据，不导航或持有会话。

## 原生文字独立于装饰切图，玩家名称与资源数字不参与自动翻译。
func _ready() -> void:
	for path: String in ["Player/Name", "Gold/Row/Value", "StarStone/Row/Value", "Stamina/Value"]:
		get_node(path).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED

## 金币和星石保留完整数值；沿用 Home 的单行适配与字体尺寸。
func present(player_name: String, gold: int, star_stone: int, stamina: int, maximum_stamina: int) -> void:
	var values: Dictionary = {
		"Player/Name": player_name,
		"Gold/Row/Value": str(gold),
		"StarStone/Row/Value": str(star_stone),
		"Stamina/Value": "%d/%d" % [stamina, maximum_stamina],
	}
	for path: String in values:
		var label: Label = get_node(path)
		label.text = values[path]
		label.fit_content()
