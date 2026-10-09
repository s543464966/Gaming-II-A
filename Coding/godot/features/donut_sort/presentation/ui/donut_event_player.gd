class_name DonutEventPlayer
extends Control
## 依次播放会话已提交的事件快照，统一持有临时精灵和可取消动效。

signal playback_finished
signal playback_stopped
signal audio_cue(cue: StringName)

const BOX_SCENE: PackedScene = preload("res://features/donut_sort/board/ui/donut_box.tscn")
const SPARKLE: Texture2D = preload("res://features/donut_sort/ui/art/effects/sparkle.tres")
const DONUT_FLIGHT_DURATION: float = 0.30 # 秒；每颗完成自身的飞行与落下。
const DONUT_FLIGHT_STAGGER: float = 0.10 # 秒；拉开可见先后，同时保持相邻两颗飞行重叠。
const REFILL_FLIGHT_DURATION: float = 0.45 # 秒；补货整盒从侧边清楚进入原位。
const DISPATCH_FLIGHT_DURATION: float = 0.36 # 秒；收餐先飞至订单盒口上方。
const DISPATCH_DROP_DURATION: float = 0.22 # 秒；保持横坐标，向下收入盒内。
const DISPATCH_STAGGER: float = 0.12 # 秒；逐颗起飞，后颗与前颗的落盒交错。

var _animation: Tween
var _board: DonutBoardView
var _orders: DonutOrdersView
var clock_blocked: bool = false # 入场与系统收餐暂停炸弹，普通搬运仍计时。
var refill_pending: bool = false # 含补货的事务展示完成前不接受新棋盘手势，避免跳过补货画面。
var dispatch_pending: bool = false # 收餐结束前保留逐颗入盒过程，避免点击跳过。
var entry_bounds: Rect2 = Rect2(0, 0, 1024, 1536) # 页面可见边界，使用动效层坐标；整盒从边界外进入。


## 显式接收棋盘与订单视图，所有飞行目标均由当前页面坐标换算。
func initialize(board: DonutBoardView, orders: DonutOrdersView) -> void:
	_board = board
	_orders = orders


## 把事务事件串成一条时间线，快照只交给页面渲染，不重新执行规则。
func play(events: Array, drop_origin: Variant, render_state: Callable, toast: Callable) -> void:
	stop()
	refill_pending = events.any(func(event: Dictionary) -> bool: return event.kind == "refill")
	dispatch_pending = events.any(func(event: Dictionary) -> bool: return event.kind == "dispatch")
	clock_blocked = not events.is_empty() and events[0].kind in ["begin", "dispatch", "refill", "mechanism", "combo"]
	_animation = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_animation.tween_interval(0.01)
	var reward_origin: Vector2 = _board.position + _board.size * 0.5
	for event: Dictionary in events:
		_animation.tween_callback(func() -> void: clock_blocked = event.kind in ["begin", "dispatch", "refill", "mechanism", "combo"])
		match event.kind:
			"begin":
				render_state.call(event.state)
				for index: int in _board.boxes.size():
					if event.state.slots[index].open and event.state.slots[index].box != null:
						_board.boxes[index].hide()
						_append_box_flight(event.state.slots[index], index, 0.10)
						_animation.tween_callback(_board.boxes[index].show)
			"move":
				_append_donut_flight(event, drop_origin)
			"dispatch":
				reward_origin = _board.origin(event.index) + _board.boxes[event.index].size * _board.boxes[event.index].scale * 0.5
				_append_dispatch(event)
			"refill":
				_append_box_flight(event.state.slots[event.index], event.index, REFILL_FLIGHT_DURATION)
			"mechanism", "reveal", "unlock", "demand_unlock", "spare_return", "cycle":
				_animation.tween_interval(0.06)
			"group":
				_animation.tween_callback(audio_cue.emit.bind(&"clear"))
				_animation.tween_callback(toast.bind("已归纳"))
			"combo":
				_animation.tween_callback(toast.bind("%d 连单！" % event.count))
				var sparkle_start: Vector2 = reward_origin - Vector2(37.5, 80)
				_append_flight(SPARKLE, sparkle_start, sparkle_start + Vector2(0, -36), Vector2(75, 70), 0.32)
			"undo":
				_animation.tween_callback(toast.bind("已撤回"))
		_animation.tween_callback(render_state.bind(event.state))
	_animation.finished.connect(func() -> void: clock_blocked = false; refill_pending = false; dispatch_pending = false; playback_finished.emit())


## 查询已提交事件是否仍在展示，供新手势决定是否先收敛画面。
func is_playing() -> bool:
	return _animation != null and _animation.is_running()


## 停止旧时间线并清理全部临时精灵，页面随后渲染最终快照。
func stop() -> void:
	clock_blocked = false
	refill_pending = false
	dispatch_pending = false
	if _animation != null and _animation.is_valid():
		_animation.kill()
	playback_stopped.emit()
	for effect: Node in get_children():
		if effect is CanvasItem:
			effect.hide()
			effect.queue_free()


## 首颗承接选中或拖放位置，后续食物从原盒逐颗起飞，在目标原堆叠上方依次落下。
func _append_donut_flight(event: Dictionary, drop_origin: Variant) -> void:
	var sprites: Array[TextureRect] = []
	var count: int = int(event.count)
	var source_count: int = event.state.slots[event.source].box.items.size() + count
	var target_count: int = event.state.slots[event.target].box.items.size()
	if drop_origin != null:
		_board.boxes[event.source].hide_moving_food(1)
	_animation.tween_interval(0.0)
	for index: int in count:
		var sprite := TextureRect.new()
		sprite.texture = DonutArt.FOOD[int(event.items[index].flavor)]
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.size = DonutArt.FOOD_SIZE
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.scale = _board.boxes[event.source].scale
		sprite.position = drop_origin if drop_origin != null and index == 0 else \
			_board.origin(event.source) + _board.boxes[event.source].food_position(index,
				event.state.slots[event.source].kind == "single", source_count) * sprite.scale
		sprite.z_index = count - index
		sprite.visible = drop_origin != null and index == 0
		add_child(sprite)
		sprites.append(sprite)
		var delay: float = index * DONUT_FLIGHT_STAGGER
		var finish: Vector2 = _board.origin(event.target) + _board.boxes[event.target].food_position(count - 1 - index,
			event.state.slots[event.target].kind == "single", target_count) * _board.boxes[event.target].scale
		_animation.parallel().tween_callback(_board.boxes[event.source].hide_moving_food.bind(index + 1)).set_delay(delay)
		_animation.parallel().tween_callback(sprite.show).set_delay(delay)
		_animation.parallel().tween_callback(sprite.set_z_index.bind(count + index)).set_delay(delay)
		_animation.parallel().tween_method(_position_donut.bind(sprite, sprite.position, finish), 0.0, 1.0,
			DONUT_FLIGHT_DURATION).set_delay(delay).set_ease(Tween.EASE_OUT)
		_animation.parallel().tween_property(sprite, "scale", _board.boxes[event.target].scale, DONUT_FLIGHT_DURATION).set_delay(delay)
		_animation.parallel().tween_callback(audio_cue.emit.bind(&"move")).set_delay(delay + DONUT_FLIGHT_DURATION)
	for sprite: TextureRect in sprites:
		_animation.tween_callback(sprite.queue_free)


## 加入轻微抬起落下的弧线，让短距离拖放也能看到首颗落定和后颗跟随。
func _position_donut(progress: float, sprite: TextureRect, start: Vector2, finish: Vector2) -> void:
	sprite.position = start.lerp(finish, progress) - Vector2(0, sin(progress * PI) * 42.0 * sprite.scale.y)


## 满足需求的四颗食物错峰飞向对应订单盒，最后一颗落入后才推进显示快照。
func _append_dispatch(event: Dictionary) -> void:
	var source: DonutBox = _board.boxes[event.index]
	var card: DonutOrderCard = _orders.cards[event.demand]
	var transform: Transform2D = get_global_transform_with_canvas().affine_inverse() * card.get_global_transform_with_canvas()
	var receiving: Rect2 = transform * card.receiving_rect()
	var fit_scale: float = minf(receiving.size.x / DonutArt.FOOD_SIZE.x, receiving.size.y / DonutArt.FOOD_SIZE.y)
	var target_scale: Vector2 = Vector2.ONE * fit_scale
	var hover: Vector2 = Vector2(receiving.get_center().x - DonutArt.FOOD_SIZE.x * fit_scale * 0.5,
		receiving.position.y - 12.0 * fit_scale)
	var clip := Control.new()
	clip.name = "OrderReceiving%d" % int(event.demand)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_contents = true
	clip.position = receiving.position - Vector2(12, 24) * target_scale
	clip.size = Vector2(receiving.size.x + 24.0 * target_scale.x, receiving.end.y - clip.position.y)
	add_child(clip)
	_animation.tween_callback(func() -> void:
		source.show()
		source.present({"kind": event.state.slots[event.index].kind, "open": true, "box": event.box})
	)
	_animation.tween_interval(0.0)
	for index: int in event.box.items.size():
		var sprite := TextureRect.new()
		sprite.name = "DispatchDonut%d" % index
		sprite.texture = DonutArt.FOOD[int(event.box.items[index].flavor)]
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.size = DonutArt.FOOD_SIZE
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.scale = source.scale
		sprite.position = _board.origin(event.index) + source.food_position(index, false, event.box.items.size()) * source.scale
		sprite.z_index = event.box.items.size() - index
		sprite.hide()
		add_child(sprite)
		var delay: float = index * DISPATCH_STAGGER
		_animation.parallel().tween_callback(source.hide_moving_food.bind(index + 1)).set_delay(delay)
		_animation.parallel().tween_callback(sprite.show).set_delay(delay)
		_animation.parallel().tween_method(_position_dispatch.bind(sprite, sprite.position, hover, source.scale, target_scale, clip),
			0.0, DISPATCH_FLIGHT_DURATION + DISPATCH_DROP_DURATION, DISPATCH_FLIGHT_DURATION + DISPATCH_DROP_DURATION
		).set_delay(delay).set_trans(Tween.TRANS_LINEAR)
	_animation.tween_callback(audio_cue.emit.bind(&"pack"))
	_animation.tween_callback(clip.queue_free)


## 先沿抛物弧线抵达盒口，再垂直下落；切入裁切层后由前沿逐步遮住食物。
func _position_dispatch(seconds: float, sprite: TextureRect, start: Vector2, hover: Vector2,
		source_scale: Vector2, target_scale: Vector2, clip: Control) -> void:
	if seconds < DISPATCH_FLIGHT_DURATION:
		var progress: float = seconds / DISPATCH_FLIGHT_DURATION
		var control: Vector2 = Vector2(hover.x, hover.y - 56.0 * target_scale.y)
		sprite.position = start.bezier_interpolate(control, control, hover, progress)
		sprite.scale = source_scale.lerp(target_scale, progress)
	else:
		if sprite.get_parent() != clip:
			sprite.reparent(clip)
		var progress: float = clampf((seconds - DISPATCH_FLIGHT_DURATION) / DISPATCH_DROP_DURATION, 0.0, 1.0)
		var finish: Vector2 = Vector2(hover.x, clip.position.y + clip.size.y + 2.0 * target_scale.y)
		sprite.scale = target_scale
		sprite.position = hover.lerp(finish, progress * progress) - clip.position


## 首批与补货按目标所在半区从左右边界外水平进入，落定后恢复真实盒体。
func _append_box_flight(slot: Dictionary, index: int, duration: float) -> void:
	var sprite: DonutBox = BOX_SCENE.instantiate()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.box_index = index
	sprite.size = DonutBox.BOX_SIZE
	sprite.scale = _board.boxes[index].scale
	var finish: Vector2 = _board.origin(index)
	var from_left: bool = finish.x + sprite.size.x * sprite.scale.x * 0.5 < entry_bounds.get_center().x
	var start_x: float = entry_bounds.position.x - sprite.size.x * sprite.scale.x - 24.0 if from_left else entry_bounds.end.x + 24.0
	sprite.position = Vector2(start_x, finish.y)
	sprite.hide()
	add_child(sprite)
	sprite.present(slot)
	_animation.tween_callback(sprite.show)
	_animation.tween_property(sprite, "position", finish, duration)
	_animation.tween_callback(sprite.queue_free)


## 将奖励装饰加入同一可取消时间线。
func _append_flight(texture: Texture2D, start: Vector2, finish: Vector2, dimensions: Vector2, duration: float) -> void:
	var sprite := TextureRect.new()
	sprite.texture = texture
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.position = start
	sprite.size = dimensions
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.hide()
	add_child(sprite)
	_animation.tween_callback(sprite.show)
	_animation.tween_property(sprite, "position", finish, duration)
	_animation.tween_callback(sprite.queue_free)
