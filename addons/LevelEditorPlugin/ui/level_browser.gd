@tool
extends PanelContainer
class_name LevelBrowser

signal level_opened(level_id: int)
signal level_created(level: LaserLevelData)
signal level_duplicated(old_id: int, new_id: int)
signal level_deleted(level_id: int)
signal batch_validation_requested
signal batch_solvability_requested
signal export_all_json_requested

var level_list_tree: Tree
var search_edit: LineEdit
var diff_filter: OptionButton
var val_filter: OptionButton

var all_level_ids: Array[int] = []

func _init() -> void:
	custom_minimum_size = Vector2(180, 0)
	_setup_ui()

func _setup_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	var header := Label.new()
	header.text = "📚 LEVEL BROWSER"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	vbox.add_child(header)

	search_edit = LineEdit.new()
	search_edit.placeholder_text = "🔍 Search Level ID / Name..."
	search_edit.text_changed.connect(func(_t): refresh_list())
	vbox.add_child(search_edit)

	var filter_row := HBoxContainer.new()
	diff_filter = OptionButton.new()
	diff_filter.add_item("All Diff", 0)
	diff_filter.add_item("Easy", 1)
	diff_filter.add_item("Medium", 2)
	diff_filter.add_item("Hard", 3)
	diff_filter.add_item("Expert", 4)
	diff_filter.item_selected.connect(func(_i): refresh_list())
	diff_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_row.add_child(diff_filter)

	val_filter = OptionButton.new()
	val_filter.add_item("All Status", 0)
	val_filter.add_item("Valid", 1)
	val_filter.add_item("Invalid", 2)
	val_filter.item_selected.connect(func(_i): refresh_list())
	val_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_row.add_child(val_filter)
	vbox.add_child(filter_row)

	level_list_tree = Tree.new()
	level_list_tree.columns = 3
	level_list_tree.set_column_title(0, "Level")
	level_list_tree.set_column_title(1, "Diff")
	level_list_tree.set_column_title(2, "Status")
	level_list_tree.set_column_titles_visible(true)
	level_list_tree.set_column_expand(0, true)
	level_list_tree.set_column_expand(1, false)
	level_list_tree.set_column_custom_minimum_width(1, 55)
	level_list_tree.set_column_expand(2, false)
	level_list_tree.set_column_custom_minimum_width(2, 60)
	level_list_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_list_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	level_list_tree.item_activated.connect(_on_item_activated)
	vbox.add_child(level_list_tree)

	var act_grid := GridContainer.new()
	act_grid.columns = 2
	act_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var open_btn := Button.new()
	open_btn.text = "📂 Open / Edit"
	open_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_btn.modulate = Color(0.8, 1.1, 1.3)
	open_btn.pressed.connect(_on_open_selected_pressed)
	act_grid.add_child(open_btn)

	var new_btn := Button.new()
	new_btn.text = "＋ New Level"
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_btn.pressed.connect(_on_new_level_pressed)
	act_grid.add_child(new_btn)

	var dup_btn := Button.new()
	dup_btn.text = "📋 Duplicate"
	dup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dup_btn.pressed.connect(_on_duplicate_level_pressed)
	act_grid.add_child(dup_btn)

	var del_btn := Button.new()
	del_btn.text = "🗑 Delete"
	del_btn.modulate = Color(1.2, 0.7, 0.7)
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.pressed.connect(_on_delete_level_pressed)
	act_grid.add_child(del_btn)

	var val_all_btn := Button.new()
	val_all_btn.text = "✓ Validate All"
	val_all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_all_btn.pressed.connect(func(): batch_validation_requested.emit())
	act_grid.add_child(val_all_btn)

	vbox.add_child(act_grid)

	var exp_btn := Button.new()
	exp_btn.text = "📤 Export All to JSON"
	exp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp_btn.pressed.connect(func(): export_all_json_requested.emit())
	vbox.add_child(exp_btn)

func refresh_list() -> void:
	level_list_tree.clear()
	var root = level_list_tree.create_item()

	all_level_ids = LevelMigration.get_all_level_ids()
	var filter_txt = search_edit.text.to_lower().strip_edges()
	var selected_diff_idx = diff_filter.selected
	var selected_val_idx = val_filter.selected

	for id in all_level_ids:
		var lvl_title = "Level %02d" % id
		if not filter_txt.is_empty() and not str(id).contains(filter_txt) and not lvl_title.to_lower().contains(filter_txt):
			continue

		var item = level_list_tree.create_item(root)
		item.set_text(0, lvl_title)
		item.set_text(1, "Med")
		item.set_text(2, "✓ Valid")
		item.set_custom_color(2, Color(0.3, 1.0, 0.4))
		item.set_metadata(0, id)

func _on_item_activated() -> void:
	_on_open_selected_pressed()

func _on_open_selected_pressed() -> void:
	var sel = level_list_tree.get_selected()
	if sel != null:
		var id = sel.get_metadata(0)
		if id is int:
			level_opened.emit(id)

func _on_new_level_pressed() -> void:
	var new_id: int = 1
	while all_level_ids.has(new_id):
		new_id += 1
	var new_lvl := LaserLevelData.new()
	new_lvl.level_id = new_id
	new_lvl.level_number = new_id
	new_lvl.level_name = "Level %02d" % new_id
	level_created.emit(new_lvl)
	refresh_list()

func _on_duplicate_level_pressed() -> void:
	var sel = level_list_tree.get_selected()
	if sel == null:
		return
	var src_id = sel.get_metadata(0)
	if src_id is int:
		var new_id: int = src_id + 1
		while all_level_ids.has(new_id):
			new_id += 1
		level_duplicated.emit(src_id, new_id)
		refresh_list()

func _on_delete_level_pressed() -> void:
	var sel = level_list_tree.get_selected()
	if sel == null:
		return
	var id = sel.get_metadata(0)
	if id is int:
		level_deleted.emit(id)
		refresh_list()
