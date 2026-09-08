extends SceneTree
## 对固定版本的未加密 PCK 做无损载荷去重；保留每个资源路径与原始字节。

const Reader = preload("res://tooling/export/pck_reader.gd")
const Report = preload("res://tooling/export/pck_report.gd")

## 只写调用方分配的新候选文件，完成逐项比对后返回统计。
static func optimize(source: String, destination: String) -> Dictionary:
	if FileAccess.file_exists(destination) or source == destination:
		return {"error": "去重目标必须尚不存在。"}
	var original = Reader.new()
	if original.open(source) != OK:
		return {"error": "源 PCK 损坏或不是受支持的 Godot 4.5.1 格式。"}
	var entries: Array[Dictionary] = []
	var payloads: Array[PackedByteArray] = []
	var hashes: Dictionary = {}
	var directory_size: int = 100
	var duplicate_bytes: int = 0
	for path in original.get_files():
		var bytes: PackedByteArray = original.read_file(path)
		var digest: String = _hash(bytes, HashingContext.HASH_SHA256).hex_encode()
		var index: int = int(hashes.get(digest, -1))
		if index >= 0:
			if bytes != payloads[index]:
				original.close()
				return {"error": "不同载荷发生摘要冲突。"}
			duplicate_bytes += bytes.size()
		else:
			index = payloads.size()
			hashes[digest] = index
			payloads.append(bytes)
		var name: PackedByteArray = path.to_utf8_buffer()
		name.resize(_align(name.size() + 1, 4))
		entries.append({"name": name, "index": index, "size": bytes.size(), "md5": _hash(bytes, HashingContext.HASH_MD5)})
		directory_size += 40 + name.size()
	var base: int = _align(directory_size, 16)
	var cursor: int = base
	var offsets: Array[int] = []
	for bytes in payloads:
		offsets.append(cursor - base)
		cursor += _align(bytes.size(), 16)
	var output = FileAccess.open(destination, FileAccess.WRITE)
	if output == null:
		original.close()
		return {"error": "无法创建去重候选 PCK。"}
	# V2 是当前固定引擎仍支持的独立包格式，不复制供应商 SDK 或重写资源。
	for value in [0x43504447, 2, 4, 5, 1, 0]: output.store_32(value)
	output.store_64(base)
	output.store_buffer(_zeros(64))
	output.store_32(entries.size())
	for entry in entries:
		output.store_32(entry.name.size())
		output.store_buffer(entry.name)
		output.store_64(offsets[entry.index])
		output.store_64(entry.size)
		output.store_buffer(entry.md5)
		output.store_32(0)
	output.store_buffer(_zeros(base - output.get_position()))
	for bytes in payloads:
		output.store_buffer(bytes)
		output.store_buffer(_zeros(_align(bytes.size(), 16) - bytes.size()))
	output.flush()
	var write_error: Error = output.get_error()
	output.close()
	var verified = Reader.new()
	var valid: bool = write_error == OK and verified.open(destination) == OK
	if valid:
		valid = original.get_files() == verified.get_files()
		for path in original.get_files():
			if original.read_file(path) != verified.read_file(path): valid = false
	var inventory: Dictionary = Report.summarize(verified) if valid else {}
	original.close()
	verified.close()
	if not valid:
		DirAccess.remove_absolute(destination)
		return {"error": "去重后路径集合或资源字节不一致，已拒绝候选。"}
	return {"entries": entries.size(), "unique_payloads": payloads.size(), "duplicate_bytes": duplicate_bytes,
		"input_bytes": FileAccess.open(source, FileAccess.READ).get_length(), "output_bytes": cursor, "inventory": inventory}

## 标准块对齐只影响容器填充，不影响资源内容。
static func _align(value: int, alignment: int) -> int:
	return value + (alignment - value % alignment) % alignment

## 显式零填充保证相同输入得到可重建的容器字节。
static func _zeros(size: int) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(size)
	bytes.fill(0)
	return bytes

## SHA-256 用于去重，Godot 容器要求的 MD5 仍逐项保存和验证。
static func _hash(bytes: PackedByteArray, kind: HashingContext.HashType) -> PackedByteArray:
	var hashing = HashingContext.new()
	hashing.start(kind)
	hashing.update(bytes)
	return hashing.finish()

## 工作区唯一导出入口调用此格式实现，不在游戏运行时注册服务。
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3 or FileAccess.file_exists(args[2]):
		printerr("Usage: pck_deduplicate.gd -- <source.pck> <new.pck> <new-report.json>")
		quit(2)
		return
	var result: Dictionary = optimize(args[0], args[1])
	if result.has("error"):
		printerr(result.error)
		quit(1)
		return
	var report = FileAccess.open(args[2], FileAccess.WRITE)
	if report == null:
		quit(1)
		return
	report.store_string(JSON.stringify(result, "  ", true) + "\n")
	report.close()
	print("PCK DEDUP PASS: " + JSON.stringify(result))
	quit()
