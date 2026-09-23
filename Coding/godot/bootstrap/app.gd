extends Node
## 在持续存活的 App 中装配关卡会话并显式交给当前页面。


## 子场景进入树前完成会话注入，避免页面依赖全局查找。
func _enter_tree() -> void:
	$SceneContainer/HomeScreen.initialize(DonutSession.new())
