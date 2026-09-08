extends Control
## 非阻塞轻提示；生命周期与安全区随自身节点清理，不留下全局计时回调。

var message: Variant = ""
var platform: Node
var duration: float = 3.5

## 所有子控件忽略输入，暂停游戏时也按真实时间关闭。
func _ready() -> void:
	$SafeArea.configure(platform)
	if message is Callable: GameUI.bind_text($SafeArea/Content/Panel/Message, message)
	else: $SafeArea/Content/Panel/Message.text = str(message)
	$Lifetime.timeout.connect(queue_free)
	$Lifetime.start(maxf(0.1, duration))
