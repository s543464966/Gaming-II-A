@tool
extends VBoxContainer
## 由磁盘 CSV 动态生成表格与文本编辑区，保存后请求独立同步入口。

signal sync_requested
const Document = preload("res://tooling/game_data/csv_editor/csv_document.gd")
const PAGE_SIZE: int = 100
var source_root: String = ""
var documents: Dictionary = {}
var active_path: String = ""
var sync_busy: bool = false
var _row: int = -1
var _column: int = -1
var _page: int = 0
var _sort_column: int = -1
var _ascending: bool = true
var _updating: bool = false
var _confirm_action: Callable
var _file_items: Dictionary = {}
var _widths: Dictionary = {}
var _listed_files: Array[String] = []

@onready var files: Tree = %Files
@onready var grid: Tree = %Grid
@onready var detail: TextEdit = %Detail
@onready var search: LineEdit = %Search

## 一次连接编辑动作，页面显示时再读取调用方指定的 CSV 根。
func _ready() -> void:
	%Refresh.pressed.connect(refresh)
	%Save.pressed.connect(save_documents.bind(false))
	%SaveAll.pressed.connect(save_documents.bind(true))
	%Sync.pressed.connect(_request_sync)
	%Undo.pressed.connect(_history.bind(false))
	%Redo.pressed.connect(_history.bind(true))
	%Add.pressed.connect(_add_row.bind(false))
	%Copy.pressed.connect(_add_row.bind(true))
	%Delete.pressed.connect(_delete_selected)
	%Reload.pressed.connect(_request_reload)
	%Previous.pressed.connect(_change_page.bind(-1))
	%Next.pressed.connect(_change_page.bind(1))
	%ColumnWidth.value_changed.connect(_resize_column)
	%ShowLog.toggled.connect(func(value: bool) -> void: %Log.visible = value)
	%Confirm.confirmed.connect(_confirmed)
	files.item_selected.connect(_file_selected)
	grid.cell_selected.connect(_cell_selected)
	grid.item_edited.connect(_cell_edited)
	grid.column_title_clicked.connect(_sort)
	detail.text_changed.connect(_detail_changed)
	search.text_changed.connect(_search_changed)
	_update_buttons()

## 配置磁盘根；编辑器本身不读取游戏 Schema 或任何游戏定义。
func setup(root: String) -> void:
	source_root = root.simplify_path()
	%Source.text = source_root
	%Source.tooltip_text = source_root
	refresh()

## 返回编辑中的真实文档，当前未选择时为空。
func current() -> RefCounted:
	return documents.get(active_path)

## 汇总未保存文件，用于退出提示和批量保存。
func dirty_paths() -> Array[String]:
	var result: Array[String] = []
	for path: String in documents:
		if documents[path].is_dirty(): result.append(path)
	result.sort()
	return result

## 重新发现文件和表头；外部变化不覆盖本机尚未保存的编辑。
func refresh() -> void:
	if source_root.is_empty() or sync_busy: return
	_listed_files = Document.discover(source_root)
	for path: String in documents.keys():
		var doc: RefCounted = documents[path]
		if doc.check_external_change():
			if doc.is_dirty(): continue
			if path not in _listed_files: documents.erase(path)
			elif not doc.open(path): documents.erase(path)
	if not active_path.is_empty() and not documents.has(active_path): active_path = ""
	_rebuild_files()
	if not active_path.is_empty():
		_render_table()
	elif not _listed_files.is_empty():
		select_file(_listed_files[0])
	else:
		_render_table()
		set_status("未找到 CSV，请检查目录：" + source_root)
	_show_conflict()

## 按完整文件路径打开表，列完全由该 CSV 的表头决定。
func select_file(path: String) -> void:
	if not documents.has(path):
		var doc: RefCounted = Document.new()
		if not doc.open(path):
			set_status(doc.error, true)
			_rebuild_files()
			_render_table()
			return
		documents[path] = doc
	active_path = path
	_row = -1
	_column = -1
	_page = 0
	_sort_column = -1
	_updating = true
	search.text = ""
	if _file_items.has(path): _file_items[path].select(0)
	_updating = false
	_render_table()
	set_status("%s · %d 条记录，%d 列" % [_relative(path), current().rows.size(), current().headers.size()])
	_show_conflict()

## 保存当前或全部修改；只在文件保存均成功后请求一次现有同步。
func save_documents(all_documents: bool = false) -> void:
	if sync_busy: return
	var targets: Array[String] = dirty_paths() if all_documents else ([active_path] as Array[String])
	var failures: PackedStringArray = []
	var saved: int = 0
	for path: String in targets:
		if not documents.has(path): continue
		var doc: RefCounted = documents[path]
		var dirty: bool = doc.is_dirty()
		if not doc.save(): failures.append(doc.error)
		elif dirty: saved += 1
	_rebuild_files()
	_update_buttons()
	if not failures.is_empty():
		set_status("已保存 %d 份；其余文件保存失败，未启动同步。\n%s" % [saved, "\n".join(failures)], true)
		return
	if targets.is_empty() or (not all_documents and active_path.is_empty()): return
	set_status("CSV 已保存；正在启动游戏数据同步…")
	sync_requested.emit()

## 同步状态与 CSV 保存状态分开，错误日志保持可查看。
func set_status(message: String, failed: bool = false) -> void:
	%Status.text = message
	%Status.modulate = Color(1.0, 0.65, 0.55) if failed else Color.WHITE

## 同步期间暂停保存与编辑，避免同一界面重复提交。
func set_sync_state(busy: bool, message: String, log_text: String = "", failed: bool = false) -> void:
	sync_busy = busy
	set_status(message, failed)
	if not log_text.is_empty(): %Log.text = log_text
	if failed:
		%ShowLog.button_pressed = true
		%Log.visible = true
	_update_buttons()
	_render_table()

## 返回编辑器时检查实际文件，不持续扫描隐藏页面。
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready() and is_visible_in_tree(): refresh.call_deferred()

## 编辑器标签内的保存快捷键与按钮使用同一入口。
func _shortcut_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	if event.is_command_or_control_pressed() and event.keycode == KEY_S:
		get_viewport().set_input_as_handled()
		save_documents(event.shift_pressed)

## 文件树只按真实相对目录分组，保留已在外部删除的未保存文件。
func _rebuild_files() -> void:
	_updating = true
	files.clear()
	_file_items.clear()
	var root: TreeItem = files.create_item()
	var groups: Dictionary = {"": root}
	var paths: Array[String] = _listed_files.duplicate()
	for path: String in dirty_paths():
		if path not in paths: paths.append(path)
	paths.sort()
	for path: String in paths:
		var relative: String = _relative(path)
		var parent: String = ""
		var parts: PackedStringArray = relative.split("/")
		for index in range(parts.size() - 1):
			var next: String = parent.path_join(parts[index]) if not parent.is_empty() else parts[index]
			if not groups.has(next):
				var group: TreeItem = files.create_item(groups[parent])
				group.set_text(0, parts[index])
				group.set_selectable(0, false)
				groups[next] = group
			parent = next
		var item: TreeItem = files.create_item(groups[parent])
		var doc: RefCounted = documents.get(path)
		var marker: String = " !" if doc != null and doc.conflict else (" *" if doc != null and doc.is_dirty() else "")
		item.set_text(0, path.get_file() + marker)
		item.set_tooltip_text(0, path)
		item.set_metadata(0, path)
		_file_items[path] = item
		if path == active_path: item.select(0)
	_updating = false

## 渲染分页视图，记录原始行号，防止排序后改错数据。
func _render_table() -> void:
	_updating = true
	grid.clear()
	var doc: RefCounted = current()
	if doc == null:
		grid.columns = 1
		grid.set_column_title(0, "CSV")
		%Page.text = ""
		_updating = false
		_update_detail()
		_update_buttons()
		return
	grid.columns = doc.headers.size() + 1
	grid.set_column_title(0, "记录")
	grid.set_column_expand(0, false)
	grid.set_column_custom_minimum_width(0, 65)
	for column in range(doc.headers.size()):
		grid.set_column_title(column + 1, str(doc.headers[column]) + ((" ↑" if _ascending else " ↓") if _sort_column == column else ""))
		grid.set_column_expand(column + 1, false)
		grid.set_column_clip_content(column + 1, true)
		grid.set_column_custom_minimum_width(column + 1, _widths.get(active_path + ":" + str(column), 160))
	var indices: Array[int] = doc.visible_rows(search.text, _sort_column, _ascending)
	var pages: int = maxi(1, ceili(float(indices.size()) / PAGE_SIZE))
	_page = clampi(_page, 0, pages - 1)
	var root: TreeItem = grid.create_item()
	for offset in range(_page * PAGE_SIZE, mini((_page + 1) * PAGE_SIZE, indices.size())):
		var index: int = indices[offset]
		var item: TreeItem = grid.create_item(root)
		item.set_metadata(0, index)
		item.set_text(0, str(index + 1))
		for column in range(doc.headers.size()):
			item.set_text(column + 1, doc.rows[index][column])
			item.set_tooltip_text(column + 1, doc.rows[index][column])
			# 多行内容在全文编辑区编辑，避免单行编辑器截断换行。
			item.set_editable(column + 1, not sync_busy and not (str(doc.rows[index][column]).contains("\n") or str(doc.rows[index][column]).contains("\r")))
			if _row == index and _column == column: item.select(column + 1)
	%Page.text = "%d / %d 页 · %d / %d 条" % [_page + 1, pages, indices.size(), doc.rows.size()]
	%Previous.disabled = _page == 0
	%Next.disabled = _page >= pages - 1
	_updating = false
	_update_detail()
	_update_buttons()

## 切换单元格时同步全文，保留字段中的全部字符。
func _update_detail() -> void:
	_updating = true
	var doc: RefCounted = current()
	var valid: bool = doc != null and _row >= 0 and _row < doc.rows.size() and _column >= 0 and _column < doc.headers.size()
	detail.editable = valid and not sync_busy
	detail.text = doc.rows[_row][_column] if valid else ""
	%CellLabel.text = "%s\n记录 %d · %s" % [active_path.get_file(), _row + 1, doc.headers[_column]] if valid else "单元格全文"
	%ColumnWidth.editable = valid
	if valid: %ColumnWidth.value = _widths.get(active_path + ":" + str(_column), 160)
	_updating = false

## 根据选中记录和同步状态更新可执行动作。
func _update_buttons() -> void:
	var doc: RefCounted = current()
	var valid_row: bool = doc != null and _row >= 0 and _row < doc.rows.size()
	%Save.disabled = sync_busy or doc == null
	%SaveAll.disabled = sync_busy or dirty_paths().is_empty()
	%Sync.disabled = sync_busy
	%Refresh.disabled = sync_busy
	%Reload.disabled = sync_busy or doc == null
	%Add.disabled = sync_busy or doc == null
	%Copy.disabled = sync_busy or not valid_row
	%Delete.disabled = sync_busy or not valid_row
	%Undo.disabled = sync_busy or doc == null or not doc.can_undo()
	%Redo.disabled = sync_busy or doc == null or not doc.can_redo()

## 从文件树读取完整路径，不靠文件名推断表类型。
func _file_selected() -> void:
	if _updating: return
	var item: TreeItem = files.get_selected()
	if item != null and item.get_metadata(0) is String: select_file(item.get_metadata(0))

## 将当前视图单元格定位到原始数据行列。
func _cell_selected() -> void:
	if _updating: return
	var item: TreeItem = grid.get_selected()
	if item == null: return
	_row = item.get_metadata(0)
	_column = grid.get_selected_column() - 1
	_update_detail()
	_update_buttons()

## 单行直接编辑后更新原始数据及全文面板。
func _cell_edited() -> void:
	if _updating or sync_busy: return
	var item: TreeItem = grid.get_edited()
	var column: int = grid.get_edited_column() - 1
	if item == null or column < 0: return
	current().set_cell(item.get_metadata(0), column, item.get_text(column + 1))
	_row = item.get_metadata(0)
	_column = column
	_rebuild_files()
	_update_detail()
	_update_buttons()

## 全文输入直接修改同一单元格，JSON 不经过反序列化或格式化。
func _detail_changed() -> void:
	if _updating or sync_busy or not detail.editable: return
	current().set_cell(_row, _column, detail.text, true)
	var item: TreeItem = grid.get_root().get_first_child() if grid.get_root() != null else null
	while item != null:
		if item.get_metadata(0) == _row:
			item.set_text(_column + 1, detail.text)
			item.set_editable(_column + 1, not (detail.text.contains("\n") or detail.text.contains("\r")))
			break
		item = item.get_next()
	_rebuild_files()
	_update_buttons()

## 搜索只筛选行，不修改文档或保存顺序。
func _search_changed(_text: String) -> void:
	if _updating: return
	_page = 0
	_render_table()

## 标题点击切换显示排序，记录列恢复原始顺序。
func _sort(column: int, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT: return
	_ascending = not _ascending if _sort_column == column - 1 else true
	_sort_column = column - 1
	_render_table()

## 调整当前列宽，不改变文件内容。
func _resize_column(value: float) -> void:
	if _updating or _column < 0: return
	_widths[active_path + ":" + str(_column)] = int(value)
	grid.set_column_custom_minimum_width(_column + 1, int(value))

## 翻页后重新显示当前筛选结果。
func _change_page(delta: int) -> void:
	_page += delta
	_render_table()

## 新增与复制保留当前原始插入位置，搜索清空以显示新行。
func _add_row(copy: bool) -> void:
	var doc: RefCounted = current()
	if doc == null or sync_busy: return
	var index: int = _row + 1 if _row >= 0 else doc.rows.size()
	doc.insert_row(index, doc.rows[_row] if copy else [])
	_row = index
	_column = 0
	_sort_column = -1
	_updating = true
	search.text = ""
	_updating = false
	_page = index / PAGE_SIZE
	_rebuild_files()
	_render_table()

## 删除确认绑定原始行号，避免排序改变删除目标。
func _delete_selected() -> void:
	var doc: RefCounted = current()
	if doc == null or _row < 0 or sync_busy: return
	var index: int = _row
	_confirm_action = func() -> void:
		doc.remove_row(index)
		_row = -1
		_rebuild_files()
		_render_table()
	%Confirm.dialog_text = "删除 %s 的第 %d 条记录？保存前可以撤销。" % [active_path.get_file(), index + 1]
	%Confirm.popup_centered()

## 放弃本地编辑前明确确认，再从实际 CSV 重建列和记录。
func _request_reload() -> void:
	if current() == null or sync_busy: return
	if not current().is_dirty():
		_reload_current()
		return
	_confirm_action = _reload_current
	%Confirm.dialog_text = "放弃当前表尚未保存的修改，并重新读取磁盘文件？"
	%Confirm.popup_centered()

## 重新载入不覆盖损坏或缺失文件，也不自动恢复已删除文件。
func _reload_current() -> void:
	if not FileAccess.file_exists(active_path):
		documents.erase(active_path)
		active_path = ""
		_row = -1
		_column = -1
		refresh()
		set_status("文件已在外部删除；本地编辑已放弃，不重建文件。")
		return
	if not current().open(active_path):
		set_status(current().error, true)
		return
	_row = -1
	_column = -1
	_sort_column = -1
	_rebuild_files()
	_render_table()
	set_status("已重新读取磁盘 CSV。")

## 确认对话框仅执行最近一次明确的文件或行操作。
func _confirmed() -> void:
	if _confirm_action.is_valid(): _confirm_action.call()
	_confirm_action = Callable()

## 编辑历史保持在所属文档，切换文件不会混用撤销记录。
func _history(forward: bool) -> void:
	if current() == null or sync_busy: return
	if forward: current().redo()
	else: current().undo()
	_rebuild_files()
	_render_table()

## 手动重试只同步磁盘数据，未保存内容仍留在编辑器中。
func _request_sync() -> void:
	if not sync_busy: sync_requested.emit()

## 用明确冲突状态提示外部修改，保存入口会再次检查指纹。
func _show_conflict() -> void:
	if current() != null and current().conflict:
		set_status("当前 CSV 在外部发生变化；本机修改已保留。请复制需要保留的内容后重新载入。", true)

## 将完整路径转换为仅用于显示的相对目录。
func _relative(path: String) -> String:
	return path.trim_prefix(source_root + "/")
