class_name DonutEventPlayer
extends Control
## 依次播放会话已提交的事件快照，统一持有临时精灵和可取消动效。

signal playback_finished

const PARCEL: Texture2D = preload("res://features/donut_sort/board/ui/art/paper_package_closed.tres")
const BOX_SCENE: PackedScene = preload("res://features/donut_sort/board/ui/donut_box.tscn")
const SPARKLE: Texture2D = preload("res://features/donut_sort/ui/art/effects/sparkle.tres")
const DONUT_FLIGHT_DURATION: float = 0.30 # 秒；每颗完成自身的飞行与落下。
const DONUT_FLIGHT_STAGGER: float = 0.10 # 秒；拉开可见先后，同时保持相邻两颗飞行重叠。

var _animation: Tween
var _board: DonutBoardView


## 显式接收页面拥有的棋盘，入场路径从目标盒位与当前视口计算。
func initialize(board: DonutBoardView) -> void:
	_board = board


## 把事务事件串成一条时间线，快照只交给页面渲染，不重新执行规则。
func play(events: Array, drop_origin: Variant, render_state: Callable, toast: Callable) -> void:
	stop()
	_animation = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_animation.tween_interval(0.01)
	var reward_origin: Vector2 = _board.position + _board.size * 0.5
	for event: Dictionary in events:
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
				_animation.tween_callback(_board.boxes[event.index].hide)
				_append_flight(PARCEL, _board.origin(event.index), Vector2(_board.origin(event.index).x, -180),
					_board.boxes[event.index].size * _board.boxes[event.index].scale, 0.18)
			"refill":
				_append_box_flight(event.state.slots[event.index], event.index, 0.28)
			"mechanism", "reveal", "unlock", "demand_unlock", "spare_return":
				_animation.tween_interval(0.06)
			"combo":
				_animation.tween_callback(toast.bind("%d 连单！" % event.count))
				var sparkle_start: Vector2 = reward_origin - Vector2(37.5, 80)
				_append_flight(SPARKLE, sparkle_start, sparkle_start + Vector2(0, -36), Vector2(75, 70), 0.32)
			"undo":
				_animation.tween_callback(toast.bind("已撤回"))
		_animation.tween_callback(render_state.bind(event.state))
	_animation.finished.connect(playback_finished.emit)


## 查询已提交事件是否仍在展示，供新手势决定是否先收敛画面。
func is_playing() -> bool:
	return _animation != null and _animation.is_running()


## 停止旧时间线并清理全部临时精灵，页面随后渲染最终快照。
func stop() -> void:
	if is_playing():
		_animation.kill()
	for effect: Node in get_children():
		if effect is CanvasItem:
			effect.hide()
			effect.queue_free()


## 首颗承接拖放位置，后续食物从原盒逐颗起飞，在目标原堆叠上方依次落下。
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
	for sprite: TextureRect in sprites:
		_animation.tween_callback(sprite.queue_free)


## 加入轻微抬起落下的弧线，让短距离拖放也能看到首颗落定和后颗跟随。
func _position_donut(progress: float, sprite: TextureRect, start: Vector2, finish: Vector2) -> void:
	sprite.position = start.lerp(finish, progress) - Vector2(0, sin(progress * PI) * 42.0 * sprite.scale.y)


## 按目标盒位所在半区从视口外水平移入，保持与落点餐盒一致的尺寸和行高。
func _append_box_flight(slot: Dictionary, index: int, duration: float) -> void:
	var sprite: DonutBox = BOX_SCENE.instantiate()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.box_index = index
	sprite.size = DonutBox.BOX_SIZE
	sprite.scale = _board.boxes[index].scale
	var finish: Vector2 = _board.origin(index)
	var viewport_bounds: Rect2 = get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	var box_width: float = sprite.size.x * sprite.scale.x
	var from_left: bool = finish.x + box_width * 0.5 <= _board.position.x + _board.size.x * 0.5
	var start_x: float = viewport_bounds.position.x - box_width - 24.0 if from_left else viewport_bounds.end.x + 24.0
	sprite.position = Vector2(start_x, finish.y)
	sprite.hide()
	add_child(sprite)
	sprite.present(slot)
	_animation.tween_callback(sprite.show)
	_animation.tween_property(sprite, "position", finish, duration)
	_animation.tween_callback(sprite.queue_free)


## 将包裹或装饰精灵加入同一可取消时间线。
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
