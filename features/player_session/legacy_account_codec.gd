class_name LegacyAccountCodec
extends RefCounted
## 仅为既有账号存档提供格式校验与迁移映射；不执行认证或写盘。

## 完整校验后返回规范账号及旧存档文件映射；损坏记录不得静默跳过。
static func decode(document: Dictionary) -> Dictionary:
	var rows: Variant = document.get("accounts", document.get("accountList"))
	if not rows is Array: return {"records": [], "files": {}, "error": "账号表缺少有效列表。"}
	var records: Array = []
	var files: Dictionary = {}
	var accounts: Array = []
	for row in rows:
		if not row is Dictionary: return _invalid()
		var id: Variant = row.get("user_id", row.get("userId"))
		var account: Variant = row.get("account", row.get("accountId"))
		var hash_value: Variant = row.get("password_hash", row.get("passwordHash"))
		var salt: Variant = row.get("salt", row.get("passwordSalt"))
		var initialized: Variant = row.get("initialized", true)
		if not initialized is bool: return _invalid()
		if not id is String or id.is_empty() or id in files or not account is String or not valid_account(account) or account in accounts: return _invalid()
		if not _base64_size(hash_value, 32) or not _base64_size(salt, 16): return _invalid()
		var filename: Variant = row.get("saveFileName", "save_" + id + ".json")
		if not filename is String or filename.is_empty() or filename != filename.get_file() or filename in [".", ".."]: return _invalid()
		files[id] = filename
		accounts.append(account)
		records.append({"user_id": id, "account": account, "password_hash": hash_value, "salt": salt,
			"created": timestamp(row.get("created", row.get("createdAt", 0))), "last_login": timestamp(row.get("last_login", row.get("lastLoginAt", 0))), "initialized": initialized})
	return {"records": records, "files": files, "error": ""}

## 保留既有账号约束：一至九位 ASCII 字母或数字，大小写敏感。
static func valid_account(account: String) -> bool:
	if account.is_empty() or account.length() >= 10: return false
	for character in account:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789": return false
	return true

## 旧 UTC ISO 日期与当前 Unix 秒均归一为秒，保留明确时区偏移。
static func timestamp(value: Variant) -> int:
	if value is int or value is float: return maxi(0, int(value)) if is_finite(float(value)) else 0
	if not value is String or value.length() < 19: return 0
	var pattern = RegEx.new()
	pattern.compile("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}")
	if pattern.search(value) == null: return 0
	var month = int(value.substr(5, 2))
	var day = int(value.substr(8, 2))
	if month < 1 or month > 12 or day < 1 or day > 31 or int(value.substr(11, 2)) > 23 or int(value.substr(14, 2)) > 59 or int(value.substr(17, 2)) > 59: return 0
	var seconds = Time.get_unix_time_from_datetime_string(value.left(19))
	var suffix: String = value.substr(19)
	var offset_start = maxi(suffix.find("+"), suffix.find("-"))
	if offset_start >= 0:
		var zone = suffix.substr(offset_start)
		if zone.length() != 6 or zone[3] != ":" or not zone.substr(1, 2).is_valid_int() or not zone.substr(4, 2).is_valid_int(): return 0
		var offset = (int(zone.substr(1, 2)) * 60 + int(zone.substr(4, 2))) * 60
		seconds -= offset if zone[0] == "+" else -offset
	return maxi(0, seconds)

## 先检查编码字符再解码，不让无效输入触发引擎错误日志。
static func _base64_size(value: Variant, size: int) -> bool:
	if not value is String or value.is_empty() or value.length() % 4 != 0: return false
	var pattern = RegEx.new()
	pattern.compile("^[A-Za-z0-9+/]+={0,2}$")
	return pattern.search(value) != null and Marshalls.base64_to_raw(value).size() == size

## 错误不包含账号秘密或散列内容。
static func _invalid() -> Dictionary:
	return {"records": [], "files": {}, "error": "账号表包含重复、缺失或损坏记录。"}
