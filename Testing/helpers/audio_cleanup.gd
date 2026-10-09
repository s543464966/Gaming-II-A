extends RefCounted
## 测试退出前等待音频线程消费停止请求，保留真实的资源泄漏检查。


## Godot 异步混音先淡出再释放实例；等待两次实际混音及主线程清理，最多一秒。
static func wait_for_mix(tree: SceneTree) -> void:
	var deadline: int = Time.get_ticks_msec() + 1000
	for cycle: int in 2:
		var started: float = Time.get_ticks_usec() / 1000000.0
		while Time.get_ticks_usec() / 1000000.0 - AudioServer.get_time_since_last_mix() <= started:
			if Time.get_ticks_msec() >= deadline:
				push_error("Audio mixer did not consume pending stop requests")
				return
			await tree.process_frame
	await tree.process_frame
