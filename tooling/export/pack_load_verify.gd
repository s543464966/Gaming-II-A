extends SceneTree
## 在空目录的真实包虚拟文件系统中加载启动依赖，防止源码掩盖漏包。

## 只解析场景与导入资源，不创建玩家会话或进入玩法。
func _initialize() -> void:
	if FileAccess.file_exists("res://tooling/export/pck_reader.gd") or FileAccess.file_exists("res://project.godot"):
		printerr("Pack verification requires the exported VFS without product tooling.")
		quit(2)
		return
	# 懒加载不应隐藏漏包；在空 VFS 中同时解析三类页面和按需浮层。
	for path: String in ["res://bootstrap/app.tscn", "res://features/player_session/ui/startup_screen.tscn",
		"res://features/home/ui/home_screen.tscn", "res://features/game_modes_pve_adventure/ui/adventure_screen.tscn",
		"res://ui/overlays/content_popup.tscn", "res://ui/overlays/content_download.tscn"]:
		var scene: PackedScene = load(path)
		if scene == null or not scene.can_instantiate():
			printerr("Pack scene dependency missing: " + path)
			quit(1)
			return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game_content/generated/localization/manifest.json"))
	var font := FontFile.new()
	for row: Dictionary in manifest.locales:
		if row.id != manifest.default_locale: continue
		if font.load_dynamic_font(row.font.path) != OK or not font.has_char("0".unicode_at(0)):
			printerr("Pack default language font is missing.")
			quit(1)
			return
	var theme: Theme = load("res://ui/design_system/themes/game_theme.tres")
	if theme == null or not theme.get_stylebox("panel", "DetailPaper") is StyleBoxTexture or theme.has_font("font", "UnavailableTitle"):
		printerr("Pack theme did not rebuild styles or still owns a separate title font.")
		quit(1)
		return
	print("PACK LOAD PASS: lazy scenes, shared language font and theme")
	quit()
