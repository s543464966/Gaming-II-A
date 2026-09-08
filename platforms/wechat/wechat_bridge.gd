extends "res://platforms/common/minigame_bridge.gd"
## 微信运行时适配入口；平台发布配置不属于此模块。

## 微信仅绑定 wx 宿主，不访问抖音 SDK。
func bind(platform: Node) -> bool:
	return attach(platform, "wx")
