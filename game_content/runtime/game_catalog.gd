class_name GameCatalog
extends RefCounted
## 唯一运行时静态内容目录；只读取校验后的生成快照，不读取策划 CSV。

const Format = preload("res://game_content/runtime/snapshot_format.gd")
const Validator = preload("res://game_content/runtime/data_validator.gd")
var data: Dictionary = {}
var assets: Dictionary = {}
var indices: Dictionary = {}
var errors: Array[String] = []
var delivery: Node
var _resources: Dictionary = {}

## 快照失败时不发布任何部分目录。
func load_content() -> bool:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(Format.PATH))
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string(Format.ASSETS))
	if not document is Dictionary or not registry is Dictionary:
		errors = ["静态快照或资源注册表无法读取。"]
		return false
	Format.normalize_numbers(document)
	Format.normalize_numbers(registry)
	var language_manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://game_content/generated/localization/manifest.json"))
	if not language_manifest is Dictionary or language_manifest.get("content_hash") != document.get("metadata", {}).get("content_hash"):
		errors = ["静态内容与语言包不是同一批生成物，请重新同步。"]
		return false
	var validator = Validator.new()
	errors = validator.validate(document, registry, true, delivery.deferred_assets() if delivery != null else {})
	if not errors.is_empty(): return false
	data = document
	assets = registry
	indices = validator.indices
	Format.freeze(data)
	Format.freeze(assets)
	Format.freeze(indices)
	return true

## 缺失 ID 返回空定义，不猜测其他类别的替代项。
func get_record(table: String, id: String) -> Dictionary:
	return indices.get(table, {}).get(id, {})

## 非战斗节点按显式节点类型查规则，不从内容 ID 推断类别。
func node_rule(type: int) -> Dictionary:
	for row in data.adventure_node_rules:
		if row.node_type == type: return row
	return {}

## 路线生成时锁定节点报价和奖励，不冻结名称及美术。
func node_terms(type: int) -> Dictionary:
	var rule = node_rule(type)
	var result: Dictionary = {}
	if rule.is_empty(): return result
	for key in ["effect_type", "cost_currency", "cost_amount", "reward_currency", "reward_amount"]: result[key] = rule[key]
	return result

## 界面与结算合并同一份已生成节点条款。
func node_definition(node: Dictionary) -> Dictionary:
	var rule = node_rule(node.type).duplicate(true)
	if not rule.is_empty(): rule.merge(node.event_terms, true)
	return rule

## 按声明类别加载纹理、特效或弹道，资源只缓存一份。
func resource(key: String, kind: String = "Texture") -> Resource:
	if key.is_empty(): return null
	var entry: Dictionary = assets.get(key, {})
	if entry.is_empty() or entry.kind != kind:
		push_error("资源类型不匹配: %s (%s)" % [key, kind])
		return null
	if not _resources.has(key): _resources[key] = load(entry.path)
	return _resources[key]
