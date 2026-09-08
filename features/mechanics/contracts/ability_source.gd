class_name AbilitySource
extends RefCounted
## 内容来源、局部能力与运行宿主的稳定身份，不拥有执行状态。

## 创建内容贡献来源；实例可以是卡牌、附着关系或模式授予项。
static func create(kind: String, content_id: String, instance_id: String) -> Dictionary:
	return {"content_id": content_id, "instance_id": instance_id, "source_kind": kind}

## 局部能力身份属于内容贡献，不能以效果目标替代。
static func for_part(source: Dictionary, part_id: String) -> Dictionary:
	var result = source.duplicate(true)
	result.part_id = part_id
	return result

## 同一静态来源可挂到不同宿主，每次返回独立身份副本。
static func for_host(source: Dictionary, host_id: String) -> Dictionary:
	var result = source.duplicate(true)
	result.host_id = host_id
	return result

## 预算和修正账本按宿主、来源实例与局部能力隔离。
static func key(host_id: String, instance_id: String, part_id: String) -> String:
	return host_id + "|" + instance_id + "|" + part_id

## 显式来源必须具备内容、实例和局部能力身份，避免运行时追踪崩溃。
static func validation_errors(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Dictionary: return ["能力来源必须是对象。"]
	for key in ["content_id", "instance_id", "source_kind", "part_id"]:
		if not value.get(key) is String or str(value.get(key, "")).is_empty(): result.append("能力来源缺少身份: " + key)
	return result
