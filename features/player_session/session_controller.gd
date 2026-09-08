class_name PlayerSessionController
extends Node
## 本机唯一默认玩家的创建、恢复和保存；不维护密码或有期限的认证会话。

const Repository = preload("res://services/save/json_repository.gd")
const Account = preload("res://features/player_session/legacy_account_codec.gd")
const Session = preload("res://features/player_session/player_session.gd")
const Progression = preload("res://features/game_modes_pve_adventure/application/adventure_progression.gd")
const PROFILE_FILE = "local_player.json"
var content: GameCatalog
var repository: JsonRepository
var session: PlayerSessionState
var progression: AdventureProgression
## 只在无法确定旧玩家时提供一次性选择，不作为账号切换入口。
var legacy_profiles: Array = []
## 页面只读取展示键；路径和校验细节只进入技术诊断。
var startup_error: String = ""
var startup_diagnostic: String = ""
## 备份恢复成功后保留提示，直到就绪 Home 实际展示；失败重试不提前消费。
var recovery_notice: String = ""
var _second: float = 0

## App 注入内容和本机存储后直接恢复或创建默认玩家。
func initialize(catalog: GameCatalog, storage: JsonRepository) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	content = catalog
	repository = storage
	load_player()

## 体力时钟独立于战斗暂停，不每秒写盘。
func _process(delta: float) -> void:
	if session == null: return
	_second += delta
	if _second >= 1:
		_second = 0
		session.user.settle(int(Time.get_unix_time_from_system()))

## 先保存完整玩家再绑定默认身份；中途失败时重试复用已落盘玩家，绝不重复发放。
func load_player(selected_identity: String = "") -> bool:
	if content == null or repository == null: return _fail("ui.session.not_ready")
	legacy_profiles.clear()
	if repository.exists("account_deletion.json"):
		return _fail("ui.session.legacy_deletion", "旧目录存在未完成删除意图，已阻止自动恢复且未修改原件。")
	var identity: String = ""
	var indexed: bool = repository.exists(PROFILE_FILE)
	if indexed:
		var profile = repository.read(PROFILE_FILE, func(value):
			return value.get("schema") == 1 and value.get("user_id") is String and not value.user_id.is_empty())
		if profile.is_empty(): return _fail("ui.session.profile_unreadable", repository.error)
		_remember_recovery()
		identity = profile.user_id
	else:
		if not _find_existing_players(): return false
		if not selected_identity.is_empty():
			for profile in legacy_profiles:
				if profile.user_id == selected_identity: identity = selected_identity
			if identity.is_empty(): return _fail("ui.session.choose_existing")
		elif legacy_profiles.size() == 1:
			identity = legacy_profiles[0].user_id
		elif legacy_profiles.size() > 1:
			var previous = repository.read("session.json") if repository.exists("session.json") else {}
			for profile in legacy_profiles:
				if profile.user_id == previous.get("user_id"): identity = profile.user_id
			if identity.is_empty(): return _fail("ui.session.choose_existing")
	var fresh: bool = identity.is_empty()
	if fresh: identity = Crypto.new().generate_random_bytes(16).hex_encode()
	var candidate = Session.new(content, identity)
	var filename = Repository.player_file(identity)
	var unfinished_initialization = not indexed and legacy_profiles.any(func(profile):
		return profile.user_id == identity and profile.get("can_initialize", false))
	if fresh or (unfinished_initialization and not repository.exists(filename)):
		candidate.initialize_new(int(Time.get_unix_time_from_system()))
		if not repository.write(filename, candidate.capture()): return _fail("ui.save.failed", repository.error)
	elif not repository.exists(filename):
		return _fail("ui.session.save_missing")
	else:
		if repository.read(filename, candidate.restore).is_empty():
			return _fail("ui.session.load_failed", candidate.error + "\n" + repository.error)
		_remember_recovery()
	var previous_session = session
	var previous_progression = progression
	session = candidate
	progression = Progression.new(session, save_player)
	if session.current_route().phase == 0:
		var recovery = progression.abandon()
		if not recovery.is_empty():
			session = previous_session
			progression = previous_progression
			return _fail("ui.session.recovery_failed", recovery + "\n" + repository.error)
	if not indexed and not repository.write(PROFILE_FILE, {"schema": 1, "user_id": identity}):
		session = previous_session
		progression = previous_progression
		return _fail("ui.session.profile_write_failed", repository.error)
	legacy_profiles.clear()
	startup_error = ""
	startup_diagnostic = ""
	return true

## 只读取旧身份目录或未绑定玩家文件；任何损坏来源都不能被当成新用户。
func _find_existing_players() -> bool:
	if repository.exists("accounts.json"):
		var source = repository.read("accounts.json", func(value): return Account.decode(value).error.is_empty())
		if source.is_empty(): return _fail("ui.session.profile_unreadable", repository.error)
		_remember_recovery()
		for record in Account.decode(source).records:
			legacy_profiles.append({"user_id": record.user_id, "label": record.account, "can_initialize": not record.initialized})
		if not legacy_profiles.is_empty(): return true
	var files: Array[String] = []
	if DirAccess.dir_exists_absolute(repository.root):
		var directory = DirAccess.open(repository.root)
		if directory == null: return _fail("ui.session.profile_unreadable", "无法读取玩家目录。")
		for filename in directory.get_files():
			var name: String = filename.trim_suffix(".bak")
			if name.begins_with("player_") and name.ends_with(".json") and not name in files: files.append(name)
	for name in files:
		var saved = repository.read(name, func(value):
			if not value.get("user_id") is String or value.user_id.is_empty(): return false
			return Repository.player_file(value.user_id) == name and Session.new(content, value.user_id).restore(value))
		if saved.is_empty(): return _fail("ui.session.load_failed", repository.error)
		legacy_profiles.append({"user_id": saved.user_id, "label": "%s (%s)" % [saved.user.get("name", ""), saved.user_id.left(8)]})
	return true

## 所有业务保存都从各 Owner 捕获当前事实，不使用界面缓存。
func save_player() -> bool:
	if session == null: return _fail("ui.session.not_ready")
	session.user.settle(int(Time.get_unix_time_from_system()))
	if not repository.write(Repository.player_file(session.user_id), session.capture()): return _fail("ui.save.failed", repository.error)
	startup_error = ""
	startup_diagnostic = ""
	return true

## 撤销未就绪内存状态，不删除本机默认身份和已有存档。
func clear_player() -> void:
	session = null
	progression = null

## 就绪页面消费一次恢复提示，不将可恢复备份降级为启动错误。
func take_recovery_notice() -> String:
	if session == null or not startup_error.is_empty(): return ""
	var notice: String = recovery_notice
	recovery_notice = ""
	return notice

## 立即记录本次读取来源，后续身份或玩家读取不能冲掉恢复事实。
func _remember_recovery() -> void:
	if repository.recovered_from_backup:
		recovery_notice = "ui.session.backup_recovered"

## 失败保留可翻译反馈和开发诊断，不泄露底层文件内容。
func _fail(message_key: String, diagnostic: String = "") -> bool:
	startup_error = message_key
	startup_diagnostic = diagnostic.strip_edges()
	return false
