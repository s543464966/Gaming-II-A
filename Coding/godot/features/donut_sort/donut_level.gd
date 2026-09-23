class_name DonutLevel
extends RefCounted
## 加载并校验甜甜圈关卡的唯一 JSON 定义，不持有运行中的关卡状态。

const CATALOG_PATH: String = "res://game_content/donuts/levels/catalog.json"
const FLAVOR_COUNT: int = 4


## 读取可游玩的关卡列表，供会话切换与页面选关共用。
static func catalog() -> Array:
	return _read(CATALOG_PATH).get("levels", [])


## 加载指定关卡，发现非法配置时提供定位信息并拒绝使用。
static func load_definition(path: String) -> Dictionary:
	var definition: Dictionary = _read(path)
	var errors: PackedStringArray = validate(definition)
	if not errors.is_empty():
		push_error("Invalid donut level %s: %s" % [path, "; ".join(errors)])
		return {}
	return definition


## 校验盒位、需求、逐盒备货及各口味数量，避免关卡静默进入不可完成状态。
static func validate(definition: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not definition.get("slots") is Array or definition.slots.size() != 16:
		errors.append("slots must contain 16 positions")
	if not definition.get("demands") is Array or definition.demands.size() != 4:
		errors.append("demands must contain 4 positions")
	if not definition.get("stock") is Array:
		errors.append("stock must be a finite array")
	if not errors.is_empty():
		return errors
	var supply: Array[int] = [0, 0, 0, 0]
	var demand: Array[int] = [0, 0, 0, 0]
	var turnover_count: int = 0
	for index: int in definition.slots.size():
		var slot: Variant = definition.slots[index]
		if not slot is Dictionary or not slot.get("kind", "") in ["regular", "turnover", "single"]:
			errors.append("invalid slot %d" % index)
			continue
		if slot.kind == "turnover":
			turnover_count += 1
			if int(slot.get("unlock_after", -1)) != -1 or slot.get("box") != null:
				errors.append("turnover slots must begin locked without a box")
		elif int(slot.get("unlock_after", 0)) < 0:
			errors.append("ordinary slot requires a nonnegative unlock threshold")
		if slot.get("box") != null:
			_check_box(slot.box, 1 if slot.kind == "single" else 4, supply, errors)
	if turnover_count != 2:
		errors.append("exactly two turnover slots required")
	for box: Variant in definition.stock:
		_check_box(box, 4, supply, errors)
	for position: Variant in definition.demands:
		if not position is Dictionary or not position.get("sequence") is Array or int(position.get("unlock_after", 0)) < 0:
			errors.append("invalid demand position")
			continue
		for flavor: Variant in position.sequence:
			if not _valid_flavor(flavor):
				errors.append("invalid demand flavor")
			else:
				demand[int(flavor)] += 4
	if supply != demand:
		errors.append("flavor supply %s does not match demand %s" % [supply, demand])
	if not definition.get("tools") is Dictionary:
		errors.append("tools must be defined")
	else:
		for key: String in ["undo", "add_box", "top"]:
			if int(definition.tools.get(key, -1)) < 0:
				errors.append("invalid tool count: " + key)
	if not definition.get("combo_rewards") is Array:
		errors.append("combo_rewards must be defined")
	else:
		var previous: int = 1
		for tier: Variant in definition.combo_rewards:
			if not tier is Dictionary or int(tier.get("count", 0)) <= previous or int(tier.get("coins", -1)) < 0 or int(tier.get("diamonds", -1)) < 0:
				errors.append("invalid or unordered combo reward")
			else:
				previous = int(tier.count)
	return errors


## 校验单盒限制与食物明暗信息，并累积实际口味数量。
static func _check_box(value: Variant, capacity: int, supply: Array[int], errors: PackedStringArray) -> void:
	if not value is Dictionary or not value.get("items") is Array or value.items.size() > capacity:
		errors.append("invalid box capacity or items")
		return
	if not value.get("kind", "normal") in ["normal", "lid", "frozen"] or int(value.get("lid", 0)) < 0:
		errors.append("invalid box mechanism")
	for item: Variant in value.items:
		if not item is Dictionary or not _valid_flavor(item.get("flavor")) or not item.get("revealed") is bool:
			errors.append("invalid donut flavor or visibility")
		else:
			supply[int(item.flavor)] += 1


## 仅接受内容目录支持的整数口味编号。
static func _valid_flavor(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == float(int(value)) and int(value) >= 0 and int(value) < FLAVOR_COUNT


## 读取 JSON 对象，失败时保留原路径用于诊断。
static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing donut content: " + path)
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary:
		push_error("Invalid JSON object: " + path)
		return {}
	return value
