@tool
extends EditorPlugin
## 注册小游戏平台与语言、配乐导出插件，不创建游戏 Autoload 或网络后台服务。

var _wechat: EditorExportPlatform
var _douyin: EditorExportPlatform
var _languages: EditorExportPlugin
var _audio: EditorExportPlugin

## 注册两个平台的制作入口，不发起导出或下载。
func _enter_tree() -> void:
	_languages = preload("res://tooling/export/language_export_plugin.gd").new()
	add_export_plugin(_languages)
	_audio = preload("res://tooling/export/minigame_audio_export_plugin.gd").new()
	add_export_plugin(_audio)
	_wechat = preload("res://tooling/export/wechat_export_platform.gd").new()
	add_export_platform(_wechat)
	_douyin = preload("res://tooling/export/douyin_export_platform.gd").new()
	add_export_platform(_douyin)

## 编辑器禁用插件时成对释放平台引用。
func _exit_tree() -> void:
	if _languages != null: remove_export_plugin(_languages)
	if _audio != null: remove_export_plugin(_audio)
	if _wechat != null: remove_export_platform(_wechat)
	if _douyin != null: remove_export_platform(_douyin)
	_wechat = null
	_douyin = null
	_languages = null
	_audio = null
