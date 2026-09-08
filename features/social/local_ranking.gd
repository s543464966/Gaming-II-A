extends RefCounted
## 当前本机玩家的价值记录；不是联网竞技积分或服务器排行榜。

## 默认玩家模式只展示当前会话，不读取其他旧账号或凭据。
static func rows(current: RefCounted) -> Array:
	var result: Array = []
	if current == null: return result
	var player = current
	var heroes: int = 0
	for id in player.collection.cards:
		if player.content.get_record("cards", id).card_kind == CardTypes.Kind.CoreHero: heroes += 1
	var quantity: int = 0
	for value in player.assets.items.values(): quantity += value
	var chapters: int = 0
	for route in player.routes.values():
		if route.completed: chapters += 1
	var score: int = player.assets.gold + player.assets.star_stone * 100 + heroes * 500 + chapters * 2000 + maxi(0, player.current_route().current) * 200 + quantity * 20
	result.append({"account": current.user_id.left(8), "name": player.user.name, "value": score})
	return result
