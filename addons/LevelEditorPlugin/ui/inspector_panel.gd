@tool
extends PanelContainer
class_name InspectorPanel

const SceneDropLineEdit = preload("res://addons/LevelEditorPlugin/ui/scene_drop_line_edit.gd")
const BoardLayoutManager = preload("res://Game/Scripts/board_layout_manager.gd")

signal object_changed(object: LaserObjectData)
signal stage_settings_changed(stage: LaserStageData)
signal level_settings_changed(level: LaserLevelData)
signal request_delete_selected
signal request_duplicate_selected
signal custom_name_renamed(index: int, new_name: String)
signal request_snap_stage_position()
signal tile_paint_selected(tile_coord: Vector2i)
signal tile_tool_mode_requested(tool_mode: int)

const CUSTOM_TYPE_ID_BASE: int = 100

var current_level: LaserLevelData = null
var current_stage: LaserStageData = null
var selected_object: LaserObjectData = null

var obj_section: VBoxContainer
var obj_id_lbl: Label
var obj_type_option: OptionButton
var obj_pos_x: SpinBox
var obj_pos_y: SpinBox
var obj_rot_spin: SpinBox
var obj_color_btn: ColorPickerButton
var obj_movable_chk: CheckBox
var obj_rotatable_chk: CheckBox
var obj_enabled_chk: CheckBox
var obj_target_edit: LineEdit

var tab_bar: HBoxContainer
var tab_obj_btn: Button
var tab_stage_btn: Button
var tab_lvl_btn: Button

var stage_section: VBoxContainer
var lvl_section: VBoxContainer

var stage_w_spin: SpinBox
var stage_h_spin: SpinBox
var stage_entry_x: SpinBox
var stage_entry_y: SpinBox
var stage_entry_dir: OptionButton
var stage_exit_x: SpinBox
var stage_exit_y: SpinBox
var stage_exit_dir: OptionButton
var stage_time_limit: SpinBox
var stage_time_bonus: SpinBox

var stage_pos_x_spin: SpinBox
var stage_pos_y_spin: SpinBox
var stage_pos_status_lbl: Label

var stage_transition_dir_option: OptionButton
var stage_board_img_edit: LineEdit
var stage_slice_cols_spin: SpinBox
var stage_slice_rows_spin: SpinBox
var stage_img_file_dialog: FileDialog
var stage_margin_l_spin: SpinBox
var stage_margin_t_spin: SpinBox
var stage_margin_r_spin: SpinBox
var stage_margin_b_spin: SpinBox
var stage_autodetect_btn: Button
var stage_tile_borders_chk: CheckBox
var stage_frame_pieces_lbl: Label

var tab_tile_btn: Button
var tile_section: VBoxContainer
var tile_preview_size: int = 54
var big_tile_dialog: AcceptDialog = null
var big_dialog_grid: GridContainer = null
var big_dialog_status: Label = null
var big_dialog_buttons: Dictionary = {}
var tile_status_lbl: Label
var tile_preview_scroll: ScrollContainer
var tile_grid_container: GridContainer
var tile_buttons: Dictionary = {}
var selected_tile_coord: Vector2i = Vector2i(0, 0)
var tile_paint_btn: Button
var tile_erase_btn: Button

var lvl_id_spin: SpinBox
var lvl_name_edit: LineEdit
var lvl_univ_timer: SpinBox
var star_3_spin: SpinBox
var star_2_spin: SpinBox
var star_1_spin: SpinBox
var coin_3_spin: SpinBox
var coin_2_spin: SpinBox
var coin_1_spin: SpinBox

func _init() -> void:
	custom_minimum_size = Vector2(240, 0)
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

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(main_vbox)

	var header := Label.new()
	header.text = "⚙️ PROPERTIES INSPECTOR"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 13)
	main_vbox.add_child(header)

	tab_bar = HBoxContainer.new()
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.add_theme_constant_override("separation", 4)
	main_vbox.add_child(tab_bar)

	var tab_group := ButtonGroup.new()

	tab_obj_btn = Button.new()
	tab_obj_btn.text = "📦 Object"
	tab_obj_btn.toggle_mode = true
	tab_obj_btn.button_group = tab_group
	tab_obj_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_obj_btn.add_theme_font_size_override("font_size", 11)
	tab_obj_btn.pressed.connect(func(): _switch_tab(0))
	tab_bar.add_child(tab_obj_btn)

	tab_stage_btn = Button.new()
	tab_stage_btn.text = "📐 Stage"
	tab_stage_btn.toggle_mode = true
	tab_stage_btn.button_group = tab_group
	tab_stage_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_stage_btn.add_theme_font_size_override("font_size", 11)
	tab_stage_btn.pressed.connect(func(): _switch_tab(1))
	tab_bar.add_child(tab_stage_btn)

	tab_lvl_btn = Button.new()
	tab_lvl_btn.text = "🏆 Level"
	tab_lvl_btn.toggle_mode = true
	tab_lvl_btn.button_group = tab_group
	tab_lvl_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_lvl_btn.add_theme_font_size_override("font_size", 11)
	tab_lvl_btn.pressed.connect(func(): _switch_tab(2))
	tab_bar.add_child(tab_lvl_btn)

	tab_tile_btn = Button.new()
	tab_tile_btn.text = "🧩 Tiles"
	tab_tile_btn.toggle_mode = true
	tab_tile_btn.button_group = tab_group
	tab_tile_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_tile_btn.add_theme_font_size_override("font_size", 11)
	tab_tile_btn.pressed.connect(func(): _switch_tab(3))
	tab_bar.add_child(tab_tile_btn)

	obj_section = _create_section(main_vbox, "SELECTED OBJECT")

	obj_id_lbl = Label.new()
	obj_id_lbl.text = "ID: (none)"
	obj_id_lbl.modulate = Color(0.7, 0.7, 0.7)
	obj_section.add_child(obj_id_lbl)

	var type_row := HBoxContainer.new()
	var t_lbl := Label.new()
	t_lbl.text = "Type:"
	type_row.add_child(t_lbl)
	obj_type_option = OptionButton.new()
	obj_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	obj_type_option.item_selected.connect(_on_obj_type_selected)
	type_row.add_child(obj_type_option)
	obj_section.add_child(type_row)
	rebuild_type_dropdown()

	var pos_row := HBoxContainer.new()
	var p_lbl := Label.new()
	p_lbl.text = "Pos (X,Y):"
	pos_row.add_child(p_lbl)
	obj_pos_x = SpinBox.new()
	obj_pos_x.min_value = 0
	obj_pos_x.max_value = 50
	obj_pos_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	obj_pos_x.value_changed.connect(_on_obj_pos_changed)
	pos_row.add_child(obj_pos_x)
	obj_pos_y = SpinBox.new()
	obj_pos_y.min_value = 0
	obj_pos_y.max_value = 50
	obj_pos_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	obj_pos_y.value_changed.connect(_on_obj_pos_changed)
	pos_row.add_child(obj_pos_y)
	obj_section.add_child(pos_row)

	var rot_row := HBoxContainer.new()
	var r_lbl := Label.new()
	r_lbl.text = "Rot°:"
	rot_row.add_child(r_lbl)
	obj_rot_spin = SpinBox.new()
	obj_rot_spin.min_value = 0
	obj_rot_spin.max_value = 315
	obj_rot_spin.step = 45
	obj_rot_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	obj_rot_spin.value_changed.connect(_on_obj_rot_changed)
	rot_row.add_child(obj_rot_spin)

	var c_lbl := Label.new()
	c_lbl.text = "Color:"
	rot_row.add_child(c_lbl)
	obj_color_btn = ColorPickerButton.new()
	obj_color_btn.custom_minimum_size = Vector2(40, 24)
	obj_color_btn.color_changed.connect(_on_obj_color_changed)
	rot_row.add_child(obj_color_btn)
	obj_section.add_child(rot_row)

	obj_movable_chk = CheckBox.new()
	obj_movable_chk.text = "Movable in Gameplay"
	obj_movable_chk.toggled.connect(_on_obj_movable_toggled)
	obj_section.add_child(obj_movable_chk)

	obj_rotatable_chk = CheckBox.new()
	obj_rotatable_chk.text = "Rotatable in Gameplay"
	obj_rotatable_chk.toggled.connect(_on_obj_rotatable_toggled)
	obj_section.add_child(obj_rotatable_chk)

	obj_enabled_chk = CheckBox.new()
	obj_enabled_chk.text = "Enabled"
	obj_enabled_chk.toggled.connect(_on_obj_enabled_toggled)
	obj_section.add_child(obj_enabled_chk)

	var conn_row := HBoxContainer.new()
	var conn_lbl := Label.new()
	conn_lbl.text = "Target ID:"
	conn_row.add_child(conn_lbl)
	obj_target_edit = LineEdit.new()
	obj_target_edit.placeholder_text = "Entry Gate ID (e.g. gate_0001)"
	obj_target_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	obj_target_edit.text_changed.connect(_on_obj_target_changed)
	conn_row.add_child(obj_target_edit)
	obj_section.add_child(conn_row)

	var obj_btn_row := HBoxContainer.new()
	var dup_btn := Button.new()
	dup_btn.text = "Duplicate (Ctrl+D)"
	dup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dup_btn.pressed.connect(func(): request_duplicate_selected.emit())
	obj_btn_row.add_child(dup_btn)

	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.modulate = Color(1.2, 0.7, 0.7)
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.pressed.connect(func(): request_delete_selected.emit())
	obj_btn_row.add_child(del_btn)
	obj_section.add_child(obj_btn_row)

	stage_section = _create_section(main_vbox, "CURRENT STAGE")

	var grid_row := HBoxContainer.new()
	var g_lbl := Label.new()
	g_lbl.text = "Grid (W,H):"
	grid_row.add_child(g_lbl)
	stage_w_spin = SpinBox.new()
	stage_w_spin.min_value = 3
	stage_w_spin.max_value = 20
	stage_w_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_w_spin.value_changed.connect(_on_stage_dimensions_changed)
	grid_row.add_child(stage_w_spin)
	stage_h_spin = SpinBox.new()
	stage_h_spin.min_value = 3
	stage_h_spin.max_value = 25
	stage_h_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_h_spin.value_changed.connect(_on_stage_dimensions_changed)
	grid_row.add_child(stage_h_spin)
	stage_section.add_child(grid_row)

	var timer_row := HBoxContainer.new()
	var tlim_lbl := Label.new()
	tlim_lbl.text = "Limit (s):"
	timer_row.add_child(tlim_lbl)
	stage_time_limit = SpinBox.new()
	stage_time_limit.min_value = 1
	stage_time_limit.max_value = 300
	stage_time_limit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_time_limit.value_changed.connect(_on_stage_timer_changed)
	timer_row.add_child(stage_time_limit)

	var tbon_lbl := Label.new()
	tbon_lbl.text = "Bonus:"
	timer_row.add_child(tbon_lbl)
	stage_time_bonus = SpinBox.new()
	stage_time_bonus.min_value = 0
	stage_time_bonus.max_value = 60
	stage_time_bonus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_time_bonus.value_changed.connect(_on_stage_timer_changed)
	timer_row.add_child(stage_time_bonus)
	stage_section.add_child(timer_row)

	var ssp_lbl := Label.new()
	ssp_lbl.text = "📍 GamePlay Screen Position"
	ssp_lbl.add_theme_font_size_override("font_size", 11)
	ssp_lbl.modulate = Color(0.85, 1.0, 0.65)
	stage_section.add_child(ssp_lbl)

	stage_pos_status_lbl = Label.new()
	stage_pos_status_lbl.text = "Mode: Auto-Center"
	stage_pos_status_lbl.add_theme_font_size_override("font_size", 10)
	stage_pos_status_lbl.modulate = Color(0.6, 0.8, 1.0)
	stage_section.add_child(stage_pos_status_lbl)

	var ssp_xy_row := HBoxContainer.new()
	var ssp_xlbl := Label.new()
	ssp_xlbl.text = "X:"
	ssp_xy_row.add_child(ssp_xlbl)
	stage_pos_x_spin = SpinBox.new()
	stage_pos_x_spin.min_value = -3000
	stage_pos_x_spin.max_value = 3000
	stage_pos_x_spin.step = 1
	stage_pos_x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_pos_x_spin.value_changed.connect(_on_stage_screen_pos_changed)
	ssp_xy_row.add_child(stage_pos_x_spin)
	var ssp_ylbl := Label.new()
	ssp_ylbl.text = "Y:"
	ssp_xy_row.add_child(ssp_ylbl)
	stage_pos_y_spin = SpinBox.new()
	stage_pos_y_spin.min_value = -3000
	stage_pos_y_spin.max_value = 3000
	stage_pos_y_spin.step = 1
	stage_pos_y_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_pos_y_spin.value_changed.connect(_on_stage_screen_pos_changed)
	ssp_xy_row.add_child(stage_pos_y_spin)
	stage_section.add_child(ssp_xy_row)

	var ssp_btn_row := HBoxContainer.new()
	var snap_btn := Button.new()
	snap_btn.text = "📌 Snap from View"
	snap_btn.tooltip_text = "Snap the current editor view position to this stage"
	snap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snap_btn.add_theme_font_size_override("font_size", 11)
	snap_btn.pressed.connect(func(): request_snap_stage_position.emit())
	ssp_btn_row.add_child(snap_btn)
	var reset_btn := Button.new()
	reset_btn.text = "🔄 Auto"
	reset_btn.tooltip_text = "Reset to auto-center mode (center of screen)"
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.add_theme_font_size_override("font_size", 11)
	reset_btn.modulate = Color(1.0, 0.85, 0.5)
	reset_btn.pressed.connect(_on_stage_screen_pos_reset)
	ssp_btn_row.add_child(reset_btn)
	stage_section.add_child(ssp_btn_row)

	var trans_lbl := Label.new()
	trans_lbl.text = "🎬 Stage Transition Direction"
	trans_lbl.add_theme_font_size_override("font_size", 11)
	trans_lbl.modulate = Color(0.7, 0.85, 1.0)
	stage_section.add_child(trans_lbl)

	var trans_row := HBoxContainer.new()
	var trans_dir_lbl := Label.new()
	trans_dir_lbl.text = "Slide from:"
	trans_row.add_child(trans_dir_lbl)
	stage_transition_dir_option = OptionButton.new()
	for k in LaserStageData.TRANSITION_DIR_NAMES.keys():
		stage_transition_dir_option.add_item(LaserStageData.TRANSITION_DIR_NAMES[k], int(k))
	stage_transition_dir_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_transition_dir_option.item_selected.connect(_on_stage_transition_dir_changed)
	trans_row.add_child(stage_transition_dir_option)
	stage_section.add_child(trans_row)

	# --- DEDICATED TILES SECTION (Only shown in '🧩 Tiles' Tab) ---
	tile_section = _create_section(main_vbox, "BOARD TILEMAP STUDIO")

	var board_hdr := Label.new()
	board_hdr.text = "🧩 Board Image & Sliced Tilemap"
	board_hdr.add_theme_font_size_override("font_size", 12)
	board_hdr.modulate = Color(1.0, 0.85, 0.35)
	tile_section.add_child(board_hdr)

	var b_row := HBoxContainer.new()
	stage_board_img_edit = LineEdit.new()
	stage_board_img_edit.placeholder_text = "res://... or file path"
	stage_board_img_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_board_img_edit.text_submitted.connect(_on_stage_board_img_changed)
	b_row.add_child(stage_board_img_edit)

	var b_browse := Button.new()
	b_browse.text = "📂"
	b_browse.tooltip_text = "Browse board image..."
	b_browse.pressed.connect(func():
		if stage_img_file_dialog != null:
			stage_img_file_dialog.popup_centered_ratio(0.7)
	)
	b_row.add_child(b_browse)
	tile_section.add_child(b_row)

	stage_img_file_dialog = FileDialog.new()
	stage_img_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	stage_img_file_dialog.access = FileDialog.ACCESS_RESOURCES
	stage_img_file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Image Files", "* ; All Files"])
	stage_img_file_dialog.file_selected.connect(func(path: String):
		stage_board_img_edit.text = path
		_on_stage_board_img_changed(path)
	)
	add_child(stage_img_file_dialog)

	var b_slice_row := HBoxContainer.new()
	var b_clbl := Label.new()
	b_clbl.text = "Slice (Cols, Rows):"
	b_slice_row.add_child(b_clbl)
	stage_slice_cols_spin = SpinBox.new()
	stage_slice_cols_spin.min_value = 1
	stage_slice_cols_spin.max_value = 32
	stage_slice_cols_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_slice_cols_spin.value_changed.connect(_on_stage_board_slice_changed)
	b_slice_row.add_child(stage_slice_cols_spin)
	stage_slice_rows_spin = SpinBox.new()
	stage_slice_rows_spin.min_value = 1
	stage_slice_rows_spin.max_value = 32
	stage_slice_rows_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_slice_rows_spin.value_changed.connect(_on_stage_board_slice_changed)
	b_slice_row.add_child(stage_slice_rows_spin)
	tile_section.add_child(b_slice_row)

	var m_hdr := Label.new()
	m_hdr.text = "Frame Margins (L, T, R, B):"
	m_hdr.add_theme_font_size_override("font_size", 11)
	m_hdr.modulate = Color(0.8, 0.85, 0.95)
	tile_section.add_child(m_hdr)

	var m_row := HBoxContainer.new()
	stage_margin_l_spin = SpinBox.new()
	stage_margin_l_spin.min_value = 0
	stage_margin_l_spin.max_value = 512
	stage_margin_l_spin.prefix = "L:"
	stage_margin_l_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_margin_l_spin.value_changed.connect(_on_stage_board_margins_changed)
	m_row.add_child(stage_margin_l_spin)

	stage_margin_t_spin = SpinBox.new()
	stage_margin_t_spin.min_value = 0
	stage_margin_t_spin.max_value = 512
	stage_margin_t_spin.prefix = "T:"
	stage_margin_t_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_margin_t_spin.value_changed.connect(_on_stage_board_margins_changed)
	m_row.add_child(stage_margin_t_spin)

	stage_margin_r_spin = SpinBox.new()
	stage_margin_r_spin.min_value = 0
	stage_margin_r_spin.max_value = 512
	stage_margin_r_spin.prefix = "R:"
	stage_margin_r_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_margin_r_spin.value_changed.connect(_on_stage_board_margins_changed)
	m_row.add_child(stage_margin_r_spin)

	stage_margin_b_spin = SpinBox.new()
	stage_margin_b_spin.min_value = 0
	stage_margin_b_spin.max_value = 512
	stage_margin_b_spin.prefix = "B:"
	stage_margin_b_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_margin_b_spin.value_changed.connect(_on_stage_board_margins_changed)
	m_row.add_child(stage_margin_b_spin)
	tile_section.add_child(m_row)

	var m_actions := HBoxContainer.new()
	stage_autodetect_btn = Button.new()
	stage_autodetect_btn.text = "🎯 Auto-Detect Frame Margins"
	stage_autodetect_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_autodetect_btn.tooltip_text = "Automatically scan image borders and set frame margins"
	stage_autodetect_btn.pressed.connect(_on_autodetect_margins_pressed)
	m_actions.add_child(stage_autodetect_btn)

	var m_reset_btn := Button.new()
	m_reset_btn.text = "Reset (0)"
	m_reset_btn.tooltip_text = "Reset margins to 0 (full texture)"
	m_reset_btn.pressed.connect(func():
		if current_stage != null:
			current_stage.set_board_margins(0, 0, 0, 0)
			_update_margin_spinboxes()
			stage_settings_changed.emit(current_stage)
			_rebuild_inspector_tile_preview()
			_rebuild_big_dialog_tiles()
	)
	m_actions.add_child(m_reset_btn)
	tile_section.add_child(m_actions)

	var p_hdr := Label.new()
	p_hdr.text = "Frame Piece Controls:"
	p_hdr.add_theme_font_size_override("font_size", 11)
	p_hdr.modulate = Color(0.8, 0.85, 0.95)
	tile_section.add_child(p_hdr)

	var p_row := HBoxContainer.new()
	var toggle_t_btn := Button.new()
	toggle_t_btn.text = "Top"
	toggle_t_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_t_btn.tooltip_text = "Toggle all top border pieces"
	toggle_t_btn.pressed.connect(func():
		if current_stage != null:
			current_stage.toggle_side_frame_pieces("T")
			stage_settings_changed.emit(current_stage)
			_update_frame_pieces_display()
	)
	p_row.add_child(toggle_t_btn)

	var toggle_b_btn := Button.new()
	toggle_b_btn.text = "Bottom"
	toggle_b_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_b_btn.tooltip_text = "Toggle all bottom border pieces"
	toggle_b_btn.pressed.connect(func():
		if current_stage != null:
			current_stage.toggle_side_frame_pieces("B")
			stage_settings_changed.emit(current_stage)
			_update_frame_pieces_display()
	)
	p_row.add_child(toggle_b_btn)

	var toggle_l_btn := Button.new()
	toggle_l_btn.text = "Left"
	toggle_l_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_l_btn.tooltip_text = "Toggle all left border pieces"
	toggle_l_btn.pressed.connect(func():
		if current_stage != null:
			current_stage.toggle_side_frame_pieces("L")
			stage_settings_changed.emit(current_stage)
			_update_frame_pieces_display()
	)
	p_row.add_child(toggle_l_btn)

	var toggle_r_btn := Button.new()
	toggle_r_btn.text = "Right"
	toggle_r_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_r_btn.tooltip_text = "Toggle all right border pieces"
	toggle_r_btn.pressed.connect(func():
		if current_stage != null:
			current_stage.toggle_side_frame_pieces("R")
			stage_settings_changed.emit(current_stage)
			_update_frame_pieces_display()
	)
	p_row.add_child(toggle_r_btn)

	var restore_p_btn := Button.new()
	restore_p_btn.text = "🔄 Restore"
	restore_p_btn.tooltip_text = "Restore all hidden/deleted frame pieces"
	restore_p_btn.pressed.connect(func():
		if current_stage != null:
			current_stage.clear_hidden_frame_pieces()
			stage_settings_changed.emit(current_stage)
			_update_frame_pieces_display()
	)
	p_row.add_child(restore_p_btn)
	tile_section.add_child(p_row)

	stage_frame_pieces_lbl = Label.new()
	stage_frame_pieces_lbl.add_theme_font_size_override("font_size", 10)
	stage_frame_pieces_lbl.modulate = Color(0.6, 0.8, 1.0)
	stage_frame_pieces_lbl.text = "Tip: Click any border piece on canvas to delete or restore it!"
	tile_section.add_child(stage_frame_pieces_lbl)

	var b_actions := HBoxContainer.new()
	var b_match_btn := Button.new()
	b_match_btn.text = "🔄 Match Grid"
	b_match_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_match_btn.pressed.connect(func():
		if current_stage != null:
			stage_slice_cols_spin.value = current_stage.grid_width
			stage_slice_rows_spin.value = current_stage.grid_height
			_on_stage_board_slice_changed(0)
	)
	b_actions.add_child(b_match_btn)

	var b_fill_btn := Button.new()
	b_fill_btn.text = "⚡ Auto-Fill 1:1"
	b_fill_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_fill_btn.pressed.connect(func():
		if current_stage != null:
			current_stage.auto_fill_board_tiles()
			stage_settings_changed.emit(current_stage)
	)
	b_actions.add_child(b_fill_btn)

	var b_clr_btn := Button.new()
	b_clr_btn.text = "❌ Clear Tiles"
	b_clr_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_clr_btn.pressed.connect(func():
		if current_stage != null:
			current_stage.clear_all_board_tiles()
			stage_settings_changed.emit(current_stage)
			_rebuild_inspector_tile_preview()
	)
	b_actions.add_child(b_clr_btn)
	tile_section.add_child(b_actions)

	stage_tile_borders_chk = CheckBox.new()
	stage_tile_borders_chk.text = "Show Tile Border Lines"
	stage_tile_borders_chk.tooltip_text = "Toggle the grid border lines drawn on tiles"
	stage_tile_borders_chk.button_pressed = true
	stage_tile_borders_chk.toggled.connect(func(pressed: bool):
		if current_stage != null:
			current_stage.show_tile_borders = pressed
			stage_settings_changed.emit(current_stage)
	)
	tile_section.add_child(stage_tile_borders_chk)

	var b_tools := HBoxContainer.new()
	tile_paint_btn = Button.new()
	tile_paint_btn.text = "🖌️ Paint Tile"
	tile_paint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_paint_btn.tooltip_text = "Activate tile paint mode"
	tile_paint_btn.pressed.connect(func():
		tile_paint_btn.modulate = Color(0.4, 1.2, 0.5)
		tile_erase_btn.modulate = Color(1.0, 1.0, 1.0)
		tile_paint_selected.emit(selected_tile_coord)
		tile_tool_mode_requested.emit(5)
	)
	b_tools.add_child(tile_paint_btn)

	tile_erase_btn = Button.new()
	tile_erase_btn.text = "🧽 Erase Tile"
	tile_erase_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_erase_btn.tooltip_text = "Activate tile erase mode"
	tile_erase_btn.pressed.connect(func():
		tile_erase_btn.modulate = Color(1.2, 0.4, 0.4)
		tile_paint_btn.modulate = Color(1.0, 1.0, 1.0)
		tile_tool_mode_requested.emit(6)
	)
	b_tools.add_child(tile_erase_btn)
	tile_section.add_child(b_tools)

	var big_btn_row := HBoxContainer.new()
	var open_big_btn := Button.new()
	open_big_btn.text = "🔍 Open Big View"
	open_big_btn.custom_minimum_size = Vector2(0, 36)
	open_big_btn.modulate = Color(1.0, 0.9, 0.25)
	open_big_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_big_btn.pressed.connect(_open_big_tile_dialog)
	big_btn_row.add_child(open_big_btn)
	tile_section.add_child(big_btn_row)

	var sz_row := HBoxContainer.new()
	var sz_lbl := Label.new()
	sz_lbl.text = "Tile Size:"
	sz_lbl.add_theme_font_size_override("font_size", 10)
	sz_row.add_child(sz_lbl)
	for sz in [36, 54, 72, 96]:
		var sb := Button.new()
		sb.text = "%dpx" % sz
		sb.add_theme_font_size_override("font_size", 10)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.pressed.connect(func():
			tile_preview_size = sz
			_rebuild_inspector_tile_preview()
		)
		sz_row.add_child(sb)
	tile_section.add_child(sz_row)

	tile_preview_scroll = ScrollContainer.new()
	tile_preview_scroll.custom_minimum_size = Vector2(0, 240)
	tile_preview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile_section.add_child(tile_preview_scroll)

	tile_grid_container = GridContainer.new()
	tile_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_grid_container.add_theme_constant_override("h_separation", 4)
	tile_grid_container.add_theme_constant_override("v_separation", 4)
	tile_preview_scroll.add_child(tile_grid_container)

	lvl_section = _create_section(main_vbox, "LEVEL & TIMERS")

	var lvl_id_row := HBoxContainer.new()
	var lid_lbl := Label.new()
	lid_lbl.text = "Level ID:"
	lvl_id_row.add_child(lid_lbl)
	lvl_id_spin = SpinBox.new()
	lvl_id_spin.min_value = 1
	lvl_id_spin.max_value = 999
	lvl_id_spin.value_changed.connect(_on_level_data_changed)
	lvl_id_row.add_child(lvl_id_spin)

	var u_lbl := Label.new()
	u_lbl.text = "Timer:"
	lvl_id_row.add_child(u_lbl)
	lvl_univ_timer = SpinBox.new()
	lvl_univ_timer.min_value = 5
	lvl_univ_timer.max_value = 600
	lvl_univ_timer.suffix = "s"
	lvl_univ_timer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lvl_univ_timer.value_changed.connect(_on_level_data_changed)
	lvl_id_row.add_child(lvl_univ_timer)
	lvl_section.add_child(lvl_id_row)

	var name_row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = "Name:"
	name_row.add_child(name_lbl)
	lvl_name_edit = LineEdit.new()
	lvl_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lvl_name_edit.text_changed.connect(func(_t): _on_level_data_changed(0))
	name_row.add_child(lvl_name_edit)
	lvl_section.add_child(name_row)

	var star_lbl := Label.new()
	star_lbl.text = "⭐ Star Time Thresholds (s):"
	lvl_section.add_child(star_lbl)

	var star_row := HBoxContainer.new()
	star_3_spin = _make_star_spin(star_row, "⭐⭐⭐")
	star_2_spin = _make_star_spin(star_row, "⭐⭐")
	star_1_spin = _make_star_spin(star_row, "⭐")
	lvl_section.add_child(star_row)

	var coin_lbl := Label.new()
	coin_lbl.text = "🪙 Coin Rewards:"
	lvl_section.add_child(coin_lbl)

	var coin_row := HBoxContainer.new()
	coin_3_spin = _make_star_spin(coin_row, "3 Stars")
	coin_3_spin.max_value = 10000
	coin_2_spin = _make_star_spin(coin_row, "2 Stars")
	coin_2_spin.max_value = 10000
	coin_1_spin = _make_star_spin(coin_row, "1 Star")
	coin_1_spin.max_value = 10000
	lvl_section.add_child(coin_row)

	_update_object_display()
	_switch_tab(1)

func _switch_tab(idx: int) -> void:
	if tab_obj_btn == null:
		return
	tab_obj_btn.set_pressed_no_signal(idx == 0)
	tab_stage_btn.set_pressed_no_signal(idx == 1)
	tab_lvl_btn.set_pressed_no_signal(idx == 2)
	if tab_tile_btn != null:
		tab_tile_btn.set_pressed_no_signal(idx == 3)
	if obj_section != null:
		obj_section.visible = (idx == 0)
	if stage_section != null:
		stage_section.visible = (idx == 1)
	if lvl_section != null:
		lvl_section.visible = (idx == 2)
	if tile_section != null:
		tile_section.visible = (idx == 3)

func _make_star_spin(parent: Control, label_text: String) -> SpinBox:
	var vbox := VBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 10)
	vbox.add_child(l)
	var sb := SpinBox.new()
	sb.min_value = 1
	sb.max_value = 600
	sb.custom_minimum_size = Vector2(60, 0)
	sb.value_changed.connect(_on_level_data_changed)
	vbox.add_child(sb)
	parent.add_child(vbox)
	return sb

func _create_section(parent: Control, _title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)
	return box

func set_level(level: LaserLevelData) -> void:
	current_level = level
	if level != null:
		lvl_id_spin.set_value_no_signal(level.level_id)
		lvl_name_edit.text = level.level_name
		lvl_univ_timer.set_value_no_signal(level.universal_timer)
		star_3_spin.set_value_no_signal(level.star_threshold_3)
		star_2_spin.set_value_no_signal(level.star_threshold_2)
		star_1_spin.set_value_no_signal(level.star_threshold_1)
		coin_3_spin.set_value_no_signal(level.coin_reward_3)
		coin_2_spin.set_value_no_signal(level.coin_reward_2)
		coin_1_spin.set_value_no_signal(level.coin_reward_1)

func set_stage(stage: LaserStageData) -> void:
	current_stage = stage
	if stage != null:
		stage_w_spin.set_value_no_signal(stage.grid_width)
		stage_h_spin.set_value_no_signal(stage.grid_height)
		stage_time_limit.set_value_no_signal(stage.time_limit)
		stage_time_bonus.set_value_no_signal(stage.time_bonus)
		var has_custom_pos := _stage_has_custom_position(stage)
		if has_custom_pos:
			stage_pos_x_spin.set_value_no_signal(stage.stage_screen_position.x)
			stage_pos_y_spin.set_value_no_signal(stage.stage_screen_position.y)
			stage_pos_status_lbl.text = "Mode: Custom Position (%.0f, %.0f)" % [stage.stage_screen_position.x, stage.stage_screen_position.y]
			stage_pos_status_lbl.modulate = Color(0.4, 1.0, 0.5)
		else:
			stage_pos_x_spin.set_value_no_signal(0)
			stage_pos_y_spin.set_value_no_signal(0)
			stage_pos_status_lbl.text = "Mode: Auto-Center"
			stage_pos_status_lbl.modulate = Color(0.6, 0.8, 1.0)
		var td := int(stage.stage_transition_direction)
		for i in range(stage_transition_dir_option.item_count):
			if stage_transition_dir_option.get_item_id(i) == td:
				stage_transition_dir_option.select(i)
				break
		if stage_board_img_edit != null:
			stage_board_img_edit.text = stage.board_image_path
		if stage_slice_cols_spin != null:
			stage_slice_cols_spin.set_value_no_signal(stage.get_effective_slice_cols())
		if stage_slice_rows_spin != null:
			stage_slice_rows_spin.set_value_no_signal(stage.get_effective_slice_rows())
		_update_margin_spinboxes()
		if stage_tile_borders_chk != null:
			stage_tile_borders_chk.set_pressed_no_signal(stage.show_tile_borders)
		_update_frame_pieces_display()
		_rebuild_inspector_tile_preview()
	if selected_object == null and tab_stage_btn != null and tab_obj_btn != null and tab_obj_btn.button_pressed:
		_switch_tab(1)

func set_selected_object(obj: LaserObjectData) -> void:
	selected_object = obj
	_update_object_display()
	if obj != null:
		_switch_tab(0)

func _update_object_display() -> void:
	if selected_object == null:
		obj_id_lbl.text = "No object selected"
		obj_type_option.disabled = true
		obj_pos_x.editable = false
		obj_pos_y.editable = false
		obj_rot_spin.editable = false
		obj_color_btn.disabled = true
		obj_movable_chk.disabled = true
		obj_rotatable_chk.disabled = true
		obj_enabled_chk.disabled = true
		obj_target_edit.editable = false
		return

	obj_type_option.disabled = false
	obj_pos_x.editable = true
	obj_pos_y.editable = true
	obj_rot_spin.editable = true
	obj_color_btn.disabled = false
	obj_movable_chk.disabled = false
	obj_rotatable_chk.disabled = false
	obj_enabled_chk.disabled = false
	obj_target_edit.editable = true

	obj_id_lbl.text = "ID: %s" % selected_object.id
	_sync_type_dropdown_selection()
	obj_pos_x.set_value_no_signal(selected_object.grid_pos.x)
	obj_pos_y.set_value_no_signal(selected_object.grid_pos.y)
	obj_rot_spin.set_value_no_signal(selected_object.rotation_deg)
	obj_color_btn.color = selected_object.color
	obj_movable_chk.set_pressed_no_signal(selected_object.movable)
	obj_rotatable_chk.set_pressed_no_signal(selected_object.rotatable)
	obj_enabled_chk.set_pressed_no_signal(selected_object.enabled)
	obj_target_edit.text = selected_object.target_id

func rebuild_type_dropdown() -> void:
	if obj_type_option == null:
		return
	var prev_selected_id: int = -1
	if obj_type_option.selected >= 0 and obj_type_option.selected < obj_type_option.item_count:
		prev_selected_id = obj_type_option.get_selected_id()

	obj_type_option.clear()

	for k in LaserObjectData.TYPE_NAMES.keys():
		if k != LaserObjectData.ObjectType.CUSTOM:
			obj_type_option.add_item(LaserObjectData.TYPE_NAMES[k], k)

	var custom_elems := CustomElementsManager.load_elements()
	if custom_elems.is_empty():
		obj_type_option.add_item("Custom", int(LaserObjectData.ObjectType.CUSTOM))
	else:
		for i in range(custom_elems.size()):
			var elem = custom_elems[i]
			var c_name := str(elem.get("name", "Custom %d" % (i + 1))).strip_edges()
			if c_name.is_empty():
				c_name = "Custom %d" % (i + 1)
			var item_id := CUSTOM_TYPE_ID_BASE + i
			obj_type_option.add_item(c_name, item_id)
			obj_type_option.set_item_metadata(obj_type_option.item_count - 1, elem)

	if selected_object != null:
		_sync_type_dropdown_selection()
	elif prev_selected_id >= 0:
		for i in range(obj_type_option.item_count):
			if obj_type_option.get_item_id(i) == prev_selected_id:
				obj_type_option.select(i)
				break

func _sync_type_dropdown_selection() -> void:
	if selected_object == null or obj_type_option == null:
		return
	if selected_object.type != LaserObjectData.ObjectType.CUSTOM:
		for i in range(obj_type_option.item_count):
			if obj_type_option.get_item_id(i) == int(selected_object.type):
				obj_type_option.select(i)
				return
	else:
		var c_id := str(selected_object.properties.get("custom_id", ""))
		var c_name := str(selected_object.properties.get("custom_name", "")).strip_edges()
		var c_idx := int(selected_object.properties.get("custom_index", -1))

		var first_custom_idx := -1
		for i in range(obj_type_option.item_count):
			var id_val := obj_type_option.get_item_id(i)
			if id_val >= CUSTOM_TYPE_ID_BASE or id_val == int(LaserObjectData.ObjectType.CUSTOM):
				if first_custom_idx == -1:
					first_custom_idx = i
				var meta = obj_type_option.get_item_metadata(i)
				if meta is Dictionary:
					if not c_id.is_empty() and str(meta.get("id", "")) == c_id:
						obj_type_option.select(i)
						if not c_name.is_empty():
							obj_type_option.set_item_text(i, c_name)
						return
					if not c_name.is_empty() and str(meta.get("name", "")).strip_edges() == c_name:
						obj_type_option.select(i)
						return
					if c_idx >= 0 and int(meta.get("index", -1)) == c_idx:
						obj_type_option.select(i)
						if not c_name.is_empty():
							obj_type_option.set_item_text(i, c_name)
						return
				elif obj_type_option.get_item_text(i) == c_name:
					obj_type_option.select(i)
					return

		if first_custom_idx != -1:
			obj_type_option.select(first_custom_idx)
			if not c_name.is_empty():
				obj_type_option.set_item_text(first_custom_idx, c_name)

func _on_obj_type_selected(idx: int) -> void:
	if selected_object != null:
		var chosen_id := obj_type_option.get_item_id(idx)
		if chosen_id < CUSTOM_TYPE_ID_BASE and chosen_id != int(LaserObjectData.ObjectType.CUSTOM):
			selected_object.type = chosen_id as LaserObjectData.ObjectType
		else:
			selected_object.type = LaserObjectData.ObjectType.CUSTOM
			var meta = obj_type_option.get_item_metadata(idx)
			if meta is Dictionary:
				selected_object.properties["custom_id"] = meta.get("id", "custom_1")
				selected_object.properties["custom_name"] = meta.get("name", "Custom")
				selected_object.properties["custom_index"] = meta.get("index", chosen_id - CUSTOM_TYPE_ID_BASE)
				selected_object.properties["scene_path"] = meta.get("scene_path", "")
				if meta.has("color"):
					selected_object.color = meta["color"]
			else:
				var txt := obj_type_option.get_item_text(idx)
				selected_object.properties["custom_name"] = txt
		_update_object_display()
		object_changed.emit(selected_object)

func _on_obj_pos_changed(_v: float) -> void:
	if selected_object != null:
		selected_object.grid_pos = Vector2i(int(obj_pos_x.value), int(obj_pos_y.value))
		object_changed.emit(selected_object)

func _on_obj_rot_changed(v: float) -> void:
	if selected_object != null:
		selected_object.rotation_deg = int(v)
		object_changed.emit(selected_object)

func _on_obj_color_changed(c: Color) -> void:
	if selected_object != null:
		selected_object.color = c
		object_changed.emit(selected_object)

func _on_obj_movable_toggled(t: bool) -> void:
	if selected_object != null:
		selected_object.movable = t
		object_changed.emit(selected_object)

func _on_obj_rotatable_toggled(t: bool) -> void:
	if selected_object != null:
		selected_object.rotatable = t
		object_changed.emit(selected_object)

func _on_obj_enabled_toggled(t: bool) -> void:
	if selected_object != null:
		selected_object.enabled = t
		object_changed.emit(selected_object)

func _on_obj_target_changed(txt: String) -> void:
	if selected_object != null:
		selected_object.target_id = txt.strip_edges()
		object_changed.emit(selected_object)

func _on_stage_dimensions_changed(_v: float) -> void:
	if current_stage != null:
		current_stage.grid_width = int(stage_w_spin.value)
		current_stage.grid_height = int(stage_h_spin.value)
		stage_settings_changed.emit(current_stage)

func _on_stage_timer_changed(_v: float) -> void:
	if current_stage != null:
		current_stage.time_limit = float(stage_time_limit.value)
		current_stage.time_bonus = float(stage_time_bonus.value)
		stage_settings_changed.emit(current_stage)

func _on_stage_screen_pos_changed(_v: float) -> void:
	if current_stage == null:
		return
	current_stage.stage_screen_position = Vector2(stage_pos_x_spin.value, stage_pos_y_spin.value)
	stage_pos_status_lbl.text = "Mode: Custom Position (%.0f, %.0f)" % [stage_pos_x_spin.value, stage_pos_y_spin.value]
	stage_pos_status_lbl.modulate = Color(0.4, 1.0, 0.5)
	stage_settings_changed.emit(current_stage)

func _on_stage_screen_pos_reset() -> void:
	if current_stage == null:
		return
	current_stage.stage_screen_position = Vector2(-9999.0, -9999.0)
	stage_pos_x_spin.set_value_no_signal(0)
	stage_pos_y_spin.set_value_no_signal(0)
	stage_pos_status_lbl.text = "Mode: Auto-Center"
	stage_pos_status_lbl.modulate = Color(0.6, 0.8, 1.0)
	stage_settings_changed.emit(current_stage)

func snap_stage_position_from_canvas(origin: Vector2) -> void:
	if current_stage == null:
		return
	current_stage.stage_screen_position = origin
	stage_pos_x_spin.set_value_no_signal(origin.x)
	stage_pos_y_spin.set_value_no_signal(origin.y)
	stage_pos_status_lbl.text = "Mode: Custom Position (%.0f, %.0f)" % [origin.x, origin.y]
	stage_pos_status_lbl.modulate = Color(0.4, 1.0, 0.5)
	stage_settings_changed.emit(current_stage)

func _stage_has_custom_position(stage: LaserStageData) -> bool:
	if stage == null:
		return false
	return stage.stage_screen_position.x > -9000.0 and stage.stage_screen_position.y > -9000.0

func _on_stage_transition_dir_changed(idx: int) -> void:
	if current_stage == null:
		return
	var dir_id := stage_transition_dir_option.get_item_id(idx)
	current_stage.stage_transition_direction = dir_id as LaserStageData.TransitionDir
	stage_settings_changed.emit(current_stage)

func _on_level_data_changed(_v: float) -> void:
	if current_level != null:
		current_level.level_id = int(lvl_id_spin.value)
		current_level.level_number = int(lvl_id_spin.value)
		current_level.level_name = lvl_name_edit.text
		current_level.universal_timer = float(lvl_univ_timer.value)
		current_level.star_threshold_3 = float(star_3_spin.value)
		current_level.star_threshold_2 = float(star_2_spin.value)
		current_level.star_threshold_1 = float(star_1_spin.value)
		current_level.coin_reward_3 = int(coin_3_spin.value)
		current_level.coin_reward_2 = int(coin_2_spin.value)
		current_level.coin_reward_1 = int(coin_1_spin.value)
		level_settings_changed.emit(current_level)

func _on_stage_board_img_changed(txt: String) -> void:
	if current_stage != null:
		current_stage.board_image_path = txt.strip_edges()
		stage_settings_changed.emit(current_stage)
		_rebuild_inspector_tile_preview()

func _on_stage_board_slice_changed(_v: float = 0) -> void:
	if current_stage != null:
		current_stage.board_slice_cols = int(stage_slice_cols_spin.value)
		current_stage.board_slice_rows = int(stage_slice_rows_spin.value)
		stage_settings_changed.emit(current_stage)
		_rebuild_inspector_tile_preview()

func _on_stage_board_margins_changed(_v: float = 0) -> void:
	if current_stage != null and stage_margin_l_spin != null:
		current_stage.set_board_margins(
			int(stage_margin_l_spin.value),
			int(stage_margin_t_spin.value),
			int(stage_margin_r_spin.value),
			int(stage_margin_b_spin.value)
		)
		stage_settings_changed.emit(current_stage)
		_rebuild_inspector_tile_preview()
		_rebuild_big_dialog_tiles()

func _update_margin_spinboxes() -> void:
	if current_stage != null:
		if stage_margin_l_spin != null:
			stage_margin_l_spin.set_value_no_signal(current_stage.board_margin_left)
		if stage_margin_t_spin != null:
			stage_margin_t_spin.set_value_no_signal(current_stage.board_margin_top)
		if stage_margin_r_spin != null:
			stage_margin_r_spin.set_value_no_signal(current_stage.board_margin_right)
		if stage_margin_b_spin != null:
			stage_margin_b_spin.set_value_no_signal(current_stage.board_margin_bottom)

func _update_frame_pieces_display() -> void:
	if stage_frame_pieces_lbl == null:
		return
	if current_stage == null or current_stage.hidden_frame_pieces.is_empty():
		stage_frame_pieces_lbl.text = "Tip: Click any border piece on canvas to delete or restore it!"
		stage_frame_pieces_lbl.modulate = Color(0.6, 0.8, 1.0)
	else:
		var preview_keys = current_stage.hidden_frame_pieces.slice(0, 4)
		var joined = ", ".join(preview_keys)
		if current_stage.hidden_frame_pieces.size() > 4:
			joined += "..."
		stage_frame_pieces_lbl.text = "Deleted Pieces: %d (%s) • Click canvas piece to toggle" % [
			current_stage.hidden_frame_pieces.size(),
			joined
		]
		stage_frame_pieces_lbl.modulate = Color(1.0, 0.7, 0.3)

func _on_autodetect_margins_pressed() -> void:
	if current_stage == null or current_stage.board_image_path.is_empty():
		return
	var tex := BoardLayoutManager.get_board_texture(current_stage.board_image_path)
	if tex == null:
		return
	var det := BoardLayoutManager.auto_detect_board_margins(tex)
	if det != Vector4i.ZERO:
		current_stage.set_board_margins(det.x, det.y, det.z, det.w)
		_update_margin_spinboxes()
		stage_settings_changed.emit(current_stage)
		_rebuild_inspector_tile_preview()
		_rebuild_big_dialog_tiles()

func _rebuild_inspector_tile_preview() -> void:
	if tile_grid_container == null:
		return
	for c in tile_grid_container.get_children():
		c.queue_free()
	tile_buttons.clear()

	if current_stage == null or current_stage.board_image_path.is_empty():
		if tile_status_lbl != null:
			tile_status_lbl.text = "No image selected. Enter image path above."
			tile_status_lbl.modulate = Color(0.6, 0.6, 0.6)
		return

	var tex := BoardLayoutManager.get_board_texture(current_stage.board_image_path)
	if tex == null:
		if tile_status_lbl != null:
			tile_status_lbl.text = "Could not load image at path:\n%s" % current_stage.board_image_path
			tile_status_lbl.modulate = Color(1.0, 0.4, 0.4)
		return

	var cols := current_stage.get_effective_slice_cols()
	var rows := current_stage.get_effective_slice_rows()
	tile_grid_container.columns = cols
	if tile_status_lbl != null:
		tile_status_lbl.text = "Sliced %dx%d (%d tiles). Click tile to select & paint:" % [cols, rows, cols * rows]
		tile_status_lbl.modulate = Color(0.4, 1.0, 0.5)

	for y in range(rows):
		for x in range(cols):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(tile_preview_size, tile_preview_size)
			btn.tooltip_text = "Tile (%d, %d)" % [x, y]

			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = BoardLayoutManager.get_tile_src_rect(tex, x, y, cols, rows, current_stage.get_board_margins())
			btn.icon = atlas
			btn.expand_icon = true

			var cur_c := Vector2i(x, y)
			btn.pressed.connect(func():
				selected_tile_coord = cur_c
				_update_inspector_tile_highlights()
				_update_big_dialog_highlights()
				if tile_status_lbl != null:
					tile_status_lbl.text = "Selected Tile (%d, %d) • Click stage grid cells to place!" % [cur_c.x, cur_c.y]
					tile_status_lbl.modulate = Color(1.0, 0.9, 0.2)
				tile_paint_selected.emit(cur_c)
				tile_tool_mode_requested.emit(5)
			)

			tile_grid_container.add_child(btn)
			tile_buttons[cur_c] = btn

	_update_inspector_tile_highlights()

func _update_inspector_tile_highlights() -> void:
	for c in tile_buttons.keys():
		var btn: Button = tile_buttons[c]
		if is_instance_valid(btn):
			if c == selected_tile_coord:
				btn.modulate = Color(1.6, 1.5, 0.3)
			else:
				btn.modulate = Color(1.0, 1.0, 1.0)

func _open_big_tile_dialog() -> void:
	if big_tile_dialog == null:
		_setup_big_tile_dialog()
	_rebuild_big_dialog_tiles()
	if big_tile_dialog.is_inside_tree():
		big_tile_dialog.popup_centered(Vector2(700, 560))
	else:
		big_tile_dialog.visible = true

func _setup_big_tile_dialog() -> void:
	big_tile_dialog = AcceptDialog.new()
	big_tile_dialog.title = "🧩 Sliced Tilemap Studio - Big View"
	big_tile_dialog.ok_button_text = "Close"

	var d_vbox := VBoxContainer.new()
	d_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	d_vbox.add_theme_constant_override("separation", 8)

	big_dialog_status = Label.new()
	big_dialog_status.text = "Click any tile piece below to select, then click stage grid cells to place:"
	big_dialog_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_dialog_status.add_theme_font_size_override("font_size", 13)
	big_dialog_status.modulate = Color(1.0, 0.9, 0.3)
	d_vbox.add_child(big_dialog_status)

	var d_actions := HBoxContainer.new()
	d_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	d_actions.add_theme_constant_override("separation", 8)

	var d_paint := Button.new()
	d_paint.text = "🖌️ Paint Mode"
	d_paint.pressed.connect(func():
		tile_paint_selected.emit(selected_tile_coord)
		tile_tool_mode_requested.emit(5)
		big_dialog_status.text = "Tile (%d, %d) selected! Click stage grid cells to place." % [selected_tile_coord.x, selected_tile_coord.y]
	)
	d_actions.add_child(d_paint)

	var d_erase := Button.new()
	d_erase.text = "🧽 Erase Mode"
	d_erase.pressed.connect(func():
		tile_tool_mode_requested.emit(6)
		big_dialog_status.text = "Erase Mode active! Click stage grid cells to remove tiles."
	)
	d_actions.add_child(d_erase)

	var af_btn := Button.new()
	af_btn.text = "⚡ Auto-Fill 1:1"
	af_btn.pressed.connect(func():
		if current_stage != null:
			current_stage.auto_fill_board_tiles()
			stage_settings_changed.emit(current_stage)
			_rebuild_inspector_tile_preview()
			_rebuild_big_dialog_tiles()
	)
	d_actions.add_child(af_btn)

	var clr_btn := Button.new()
	clr_btn.text = "❌ Clear Tiles"
	clr_btn.pressed.connect(func():
		if current_stage != null:
			current_stage.clear_all_board_tiles()
			stage_settings_changed.emit(current_stage)
			_rebuild_inspector_tile_preview()
			_rebuild_big_dialog_tiles()
	)
	d_actions.add_child(clr_btn)
	d_vbox.add_child(d_actions)

	var d_scroll := ScrollContainer.new()
	d_scroll.custom_minimum_size = Vector2(660, 420)
	d_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d_vbox.add_child(d_scroll)

	var center_box := CenterContainer.new()
	center_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d_scroll.add_child(center_box)

	big_dialog_grid = GridContainer.new()
	big_dialog_grid.add_theme_constant_override("h_separation", 8)
	big_dialog_grid.add_theme_constant_override("v_separation", 8)
	center_box.add_child(big_dialog_grid)

	big_tile_dialog.add_child(d_vbox)
	add_child(big_tile_dialog)

func _rebuild_big_dialog_tiles() -> void:
	if big_dialog_grid == null:
		return
	for c in big_dialog_grid.get_children():
		c.queue_free()
	big_dialog_buttons.clear()

	if current_stage == null or current_stage.board_image_path.is_empty():
		big_dialog_status.text = "No image loaded. Please set board image path first."
		return

	var tex := BoardLayoutManager.get_board_texture(current_stage.board_image_path)
	if tex == null:
		big_dialog_status.text = "Could not load image at path: %s" % current_stage.board_image_path
		return

	var cols := current_stage.get_effective_slice_cols()
	var rows := current_stage.get_effective_slice_rows()
	big_dialog_grid.columns = cols
	big_dialog_status.text = "Sliced %dx%d (%d tiles) • Click any piece to select & paint:" % [cols, rows, cols * rows]

	var big_size := 76.0

	for y in range(rows):
		for x in range(cols):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(big_size, big_size)
			btn.tooltip_text = "Tile (%d, %d)" % [x, y]

			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = BoardLayoutManager.get_tile_src_rect(tex, x, y, cols, rows, current_stage.get_board_margins())
			btn.icon = atlas
			btn.expand_icon = true

			var cur_c := Vector2i(x, y)
			btn.pressed.connect(func():
				selected_tile_coord = cur_c
				_update_inspector_tile_highlights()
				_update_big_dialog_highlights()
				big_dialog_status.text = "Selected Tile (%d, %d) • Click stage grid cells to place!" % [cur_c.x, cur_c.y]
				tile_paint_selected.emit(cur_c)
				tile_tool_mode_requested.emit(5)
			)

			big_dialog_grid.add_child(btn)
			big_dialog_buttons[cur_c] = btn

	_update_big_dialog_highlights()

func _update_big_dialog_highlights() -> void:
	for c in big_dialog_buttons.keys():
		var btn: Button = big_dialog_buttons[c]
		if is_instance_valid(btn):
			if c == selected_tile_coord:
				btn.modulate = Color(1.8, 1.6, 0.2)
			else:
				btn.modulate = Color(1.0, 1.0, 1.0)



