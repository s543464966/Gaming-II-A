extends "res://platforms/common/minigame_bridge.gd"
## 抖音运行时适配入口；第三方 SDK 保持隔离在 addons。

## 抖音仅绑定 tt 宿主，不访问微信 API。
func bind(platform: Node) -> bool:
	return attach(platform, "tt")
