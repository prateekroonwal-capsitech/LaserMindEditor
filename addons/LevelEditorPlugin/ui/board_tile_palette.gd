@tool
extends PanelContainer
class_name BoardTilePalette

const BoardLayoutManager = preload("res://Game/Scripts/board_layout_manager.gd")

signal tile_selected(tile_coord: Vector2i)
signal tool_mode_requested(tool_mode: int)
signal board_settings_changed
signal request_redraw

var current_stage: LaserStageData = null
var selected_tile_coord: Vector2i = Vector2i(0, 0)
var is_tile_paint_active: bool = false

var stage_label: Label
var img_path_edit: LineEdit
var browse_btn: Button
var file_dialog: FileDialog
var slice_cols_spin: SpinBox
var slice_rows_spin: SpinBox
var match_grid_btn: Button
var autofill_btn: Button
var clear_tiles_btn: Button
var paint_btn: Button
var erase_btn: Button

var tile_container: GridContainer
var tile_scroll: ScrollContainer
var tile_buttons: Dictionary = {}
var info_label: Label

func _init() -> void:
	custom_minimum_size = Vector2(210, 0)
	size_flags_horizontal = Control.SIZE_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_setup_ui()

func _setup_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	var header := Label.new()
	header.text = "🧩 BOARD TILE PALETTE"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 13)
	vbox.add_child(header)

	stage_label = Label.new()
	stage_label.text = "Stage 1 (Grid: 5x5)"
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.add_theme_font_size_override("font_size", 11)
	stage_label.modulate = Color(0.7, 0.85, 1.0)
	vbox.add_child(stage_label)

	# --- Image Reference Section ---
	var img_sec_lbl := Label.new()
	img_sec_lbl.text = "SOURCE BOARD IMAGE"
	img_sec_lbl.add_theme_font_size_override("font_size", 11)
	img_sec_lbl.modulate = Color(1.0, 0.8, 0.3)
	vbox.add_child(img_sec_lbl)

	var img_row := HBoxContainer.new()
	img_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	img_path_edit = LineEdit.new()
	img_path_edit.placeholder_text = "res://... or file path"
	img_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	img_path_edit.text_submitted.connect(_on_image_path_submitted)
	img_row.add_child(img_path_edit)

	browse_btn = Button.new()
	browse_btn.text = "📂"
	browse_btn.tooltip_text = "Browse Board Image File..."
	browse_btn.pressed.connect(_on_browse_pressed)
	img_row.add_child(browse_btn)

	var clear_img_btn := Button.new()
	clear_img_btn.text = "✖"
	clear_img_btn.tooltip_text = "Remove image reference"
	clear_img_btn.pressed.connect(func():
		img_path_edit.text = ""
		_on_image_path_submitted("")
	)
	img_row.add_child(clear_img_btn)
	vbox.add_child(img_row)

	# --- Slicing Grid Controls ---
	var slice_sec_lbl := Label.new()
	slice_sec_lbl.text = "IMAGE SLICE GRID (Cols × Rows)"
	slice_sec_lbl.add_theme_font_size_override("font_size", 11)
	slice_sec_lbl.modulate = Color(1.0, 0.8, 0.3)
	vbox.add_child(slice_sec_lbl)

	var slice_row := HBoxContainer.new()
	slice_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var c_lbl := Label.new()
	c_lbl.text = "Cols:"
	slice_row.add_child(c_lbl)

	slice_cols_spin = SpinBox.new()
	slice_cols_spin.min_value = 1
	slice_cols_spin.max_value = 32
	slice_cols_spin.value = 5
	slice_cols_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slice_cols_spin.value_changed.connect(_on_slice_dimensions_changed)
	slice_row.add_child(slice_cols_spin)

	var r_lbl := Label.new()
	r_lbl.text = "Rows:"
	slice_row.add_child(r_lbl)

	slice_rows_spin = SpinBox.new()
	slice_rows_spin.min_value = 1
	slice_rows_spin.max_value = 32
	slice_rows_spin.value = 5
	slice_rows_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slice_rows_spin.value_changed.connect(_on_slice_dimensions_changed)
	slice_row.add_child(slice_rows_spin)
	vbox.add_child(slice_row)

	match_grid_btn = Button.new()
	match_grid_btn.text = "🔄 Match Stage Grid"
	match_grid_btn.tooltip_text = "Set slice cols and rows to match stage grid size (e.g. 5x5, 6x6)"
	match_grid_btn.pressed.connect(_on_match_grid_pressed)
	vbox.add_child(match_grid_btn)

	# --- Paint / Erase Tools ---
	var tool_row := HBoxContainer.new()
	tool_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	paint_btn = Button.new()
	paint_btn.text = "🖌️ Paint Tile"
	paint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paint_btn.tooltip_text = "Activate Tile Paint mode. Click or drag on grid to place selected tile."
	paint_btn.pressed.connect(_on_paint_tile_pressed)
	tool_row.add_child(paint_btn)

	erase_btn = Button.new()
	erase_btn.text = "🧽 Erase Tile"
	erase_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	erase_btn.tooltip_text = "Activate Tile Erase mode. Click on grid to remove placed tile."
	erase_btn.pressed.connect(_on_erase_tile_pressed)
	tool_row.add_child(erase_btn)
	vbox.add_child(tool_row)

	# --- Auto Fill / Clear Stage Tiles ---
	var action_row := HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	autofill_btn = Button.new()
	autofill_btn.text = "⚡ Auto-Fill 1:1"
	autofill_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	autofill_btn.tooltip_text = "Map the whole sliced image 1-to-1 onto stage cells"
	autofill_btn.pressed.connect(_on_autofill_pressed)
	action_row.add_child(autofill_btn)

	clear_tiles_btn = Button.new()
	clear_tiles_btn.text = "❌ Clear Stage Tiles"
	clear_tiles_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_tiles_btn.tooltip_text = "Clear all placed tiles on this stage"
	clear_tiles_btn.pressed.connect(_on_clear_tiles_pressed)
	action_row.add_child(clear_tiles_btn)
	vbox.add_child(action_row)

	# --- Sliced Tiles Grid Preview ---
	var tiles_lbl := Label.new()
	tiles_lbl.text = "SLICED TILES (CLICK TO SELECT)"
	tiles_lbl.add_theme_font_size_override("font_size", 11)
	tiles_lbl.modulate = Color(1.0, 0.8, 0.3)
	vbox.add_child(tiles_lbl)

	info_label = Label.new()
	info_label.text = "No image loaded. Enter image path above."
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.modulate = Color(0.6, 0.6, 0.6)
	vbox.add_child(info_label)

	tile_scroll = ScrollContainer.new()
	tile_scroll.custom_minimum_size = Vector2(0, 220)
	tile_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tile_scroll)

	tile_container = GridContainer.new()
	tile_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_container.add_theme_constant_override("h_separation", 3)
	tile_container.add_theme_constant_override("v_separation", 3)
	tile_scroll.add_child(tile_container)

	_setup_file_dialog()

func _setup_file_dialog() -> void:
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Image Files", "* ; All Files"])
	file_dialog.file_selected.connect(func(path: String):
		img_path_edit.text = path
		_on_image_path_submitted(path)
	)
	add_child(file_dialog)

func set_stage(stage: LaserStageData) -> void:
	current_stage = stage
	if current_stage == null:
		stage_label.text = "No Stage Selected"
		img_path_edit.text = ""
		_rebuild_tile_palette()
		return

	stage_label.text = "Stage %d (Grid: %dx%d)" % [current_stage.stage_index, current_stage.grid_width, current_stage.grid_height]
	img_path_edit.text = current_stage.board_image_path

	var cols = current_stage.get_effective_slice_cols()
	var rows = current_stage.get_effective_slice_rows()
	slice_cols_spin.set_value_no_signal(cols)
	slice_rows_spin.set_value_no_signal(rows)

	_rebuild_tile_palette()

func _on_browse_pressed() -> void:
	if file_dialog != null:
		file_dialog.popup_centered_ratio(0.7)

func _on_image_path_submitted(new_path: String) -> void:
	if current_stage == null:
		return
	current_stage.board_image_path = new_path.strip_edges()
	_rebuild_tile_palette()
	board_settings_changed.emit()
	request_redraw.emit()

func _on_slice_dimensions_changed(_val: float = 0) -> void:
	if current_stage == null:
		return
	current_stage.board_slice_cols = int(slice_cols_spin.value)
	current_stage.board_slice_rows = int(slice_rows_spin.value)
	_rebuild_tile_palette()
	board_settings_changed.emit()
	request_redraw.emit()

func _on_match_grid_pressed() -> void:
	if current_stage == null:
		return
	slice_cols_spin.value = current_stage.grid_width
	slice_rows_spin.value = current_stage.grid_height
	_on_slice_dimensions_changed()

func _on_paint_tile_pressed() -> void:
	is_tile_paint_active = true
	paint_btn.modulate = Color(0.4, 1.2, 0.5)
	erase_btn.modulate = Color(1.0, 1.0, 1.0)
	# 5 corresponds to GridCanvas.ToolMode.TILE_PAINT
	tool_mode_requested.emit(5)
	tile_selected.emit(selected_tile_coord)

func _on_erase_tile_pressed() -> void:
	is_tile_paint_active = false
	erase_btn.modulate = Color(1.2, 0.4, 0.4)
	paint_btn.modulate = Color(1.0, 1.0, 1.0)
	# 6 corresponds to GridCanvas.ToolMode.TILE_ERASE
	tool_mode_requested.emit(6)

func _on_autofill_pressed() -> void:
	if current_stage == null:
		return
	current_stage.auto_fill_board_tiles()
	board_settings_changed.emit()
	request_redraw.emit()

func _on_clear_tiles_pressed() -> void:
	if current_stage == null:
		return
	current_stage.clear_all_board_tiles()
	board_settings_changed.emit()
	request_redraw.emit()

func select_tile(tx: int, ty: int) -> void:
	selected_tile_coord = Vector2i(tx, ty)
	_update_tile_button_highlights()
	tile_selected.emit(selected_tile_coord)

func _rebuild_tile_palette() -> void:
	for c in tile_container.get_children():
		c.queue_free()
	tile_buttons.clear()

	if current_stage == null or current_stage.board_image_path.is_empty():
		info_label.text = "No image loaded. Enter image path above or click 📂 to browse."
		info_label.visible = true
		return

	var tex := BoardLayoutManager.get_board_texture(current_stage.board_image_path)
	if tex == null:
		info_label.text = "Could not load image at path:\n%s" % current_stage.board_image_path
		info_label.visible = true
		return

	info_label.visible = false
	var cols := current_stage.get_effective_slice_cols()
	var rows := current_stage.get_effective_slice_rows()
	tile_container.columns = cols

	for y in range(rows):
		for x in range(cols):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(36, 36)
			btn.tooltip_text = "Tile (%d, %d)" % [x, y]

			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = BoardLayoutManager.get_tile_src_rect(tex, x, y, cols, rows, current_stage.get_board_margins())
			btn.icon = atlas
			btn.expand_icon = true

			var cur_c := Vector2i(x, y)
			btn.pressed.connect(func():
				select_tile(cur_c.x, cur_c.y)
				_on_paint_tile_pressed()
			)

			tile_container.add_child(btn)
			tile_buttons[cur_c] = btn

	_update_tile_button_highlights()

func _update_tile_button_highlights() -> void:
	for c in tile_buttons.keys():
		var btn: Button = tile_buttons[c]
		if is_instance_valid(btn):
			if c == selected_tile_coord:
				btn.modulate = Color(1.5, 1.4, 0.4)
			else:
				btn.modulate = Color(1.0, 1.0, 1.0)
