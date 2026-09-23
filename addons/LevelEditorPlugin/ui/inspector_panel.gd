@tool
extends PanelContainer
class_name InspectorPanel

const SceneDropLineEdit = preload("res://addons/LevelEditorPlugin/ui/scene_drop_line_edit.gd")

signal object_changed(object: LaserObjectData)
signal stage_settings_changed(stage: LaserStageData)
signal level_settings_changed(level: LaserLevelData)
signal request_delete_selected
signal request_duplicate_selected
signal custom_name_renamed(index: int, new_name: String)
signal request_snap_stage_position()
signal tile_paint_selected(tile_coord: Vector2i)
signal tile_tool_mode_requested(tool_mode: int)
signal cell_visual_paint_selected(asset: String, rot_deg: float)
signal cell_visual_modified(stage: LaserStageData, cell: Vector2i, asset: String, rot_deg: float)
signal border_visual_paint_selected(asset: String, rot_deg: float, offset: float, scale_x: float, scale_y: float)
signal border_visual_modified(stage: LaserStageData, side: String, index: int, asset: String, rot_deg: float, offset: float, scale_x: float, scale_y: float)
signal border_erase_selected()
signal corner_visual_paint_selected(asset: String, rot_deg: float, mirror_x: bool, mirror_y: bool, offset: float, scale_x: float, scale_y: float)
signal corner_visual_modified(stage: LaserStageData, corner: String, asset: String, rot_deg: float, mirror_x: bool, mirror_y: bool, offset: float, scale_x: float, scale_y: float)
signal corner_erase_selected()
signal hint_settings_changed(stage: LaserStageData)
signal hint_tool_mode_requested(tool_mode: int)
signal hint_mode_toggled(active: bool)

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
var tab_tile_btn: Button
var tile_section: VBoxContainer
var tile_type_buttons: Dictionary = {}
var tile_rot_buttons: Dictionary = {}
var tile_buttons: Dictionary = {}
var selected_tile_type: int = 0
var selected_tile_rot: int = 0
var selected_tile_coord: Vector2i = Vector2i(0, 0)
var tile_paint_btn: Button
var tile_erase_btn: Button
var tile_status_lbl: Label

# Cell Visuals & Arbitrary Rotation State
var active_cell_asset: String = "cell_1"
var active_cell_rot: float = 0.0
var active_cell_opt: OptionButton
var cell_asset_buttons: Dictionary = {}
var cell_rot_spin: SpinBox

# In-Place Placed Cell Visual Editor
var sel_cell_box: VBoxContainer
var sel_cell_lbl: Label
var sel_cell_asset_opt: OptionButton
var sel_cell_rot_spin: SpinBox
var current_selected_visual_cell: Vector2i = Vector2i(-1, -1)

# --- Border Visuals State ---
var active_border_asset: String = "border_1"
var active_border_rot: float = 0.0
var active_border_offset: float = 0.0
var active_border_scale_x: float = 1.0
var active_border_scale_y: float = 1.0
var active_border_opt: OptionButton
var active_border_rot_spin: SpinBox
var active_border_offset_spin: SpinBox
var active_border_scale_x_spin: SpinBox
var active_border_scale_y_spin: SpinBox
var border_rot_buttons: Dictionary = {}
var border_paint_btn: Button
var border_erase_btn: Button
var border_status_lbl: Label
var border_asset_buttons: Dictionary = {}

var sel_border_box: VBoxContainer
var sel_border_lbl: Label
var sel_border_asset_opt: OptionButton
var sel_border_rot_spin: SpinBox
var sel_border_offset_spin: SpinBox
var sel_border_scale_x_spin: SpinBox
var sel_border_scale_y_spin: SpinBox
var current_selected_border_side: String = ""
var current_selected_border_index: int = -1

# --- Corner Visuals State ---
var active_corner_asset: String = "corner_1"
var active_corner_rot: float = 0.0
var active_corner_offset: float = 0.0
var active_corner_scale_x: float = 1.0
var active_corner_scale_y: float = 1.0
var active_corner_mirror_x: bool = false
var active_corner_mirror_y: bool = false
var active_corner_opt: OptionButton
var active_corner_rot_spin: SpinBox
var active_corner_offset_spin: SpinBox
var active_corner_scale_x_spin: SpinBox
var active_corner_scale_y_spin: SpinBox
var active_corner_mx_chk: CheckBox
var active_corner_my_chk: CheckBox
var corner_rot_buttons: Dictionary = {}
var corner_paint_btn: Button
var corner_erase_btn: Button
var corner_status_lbl: Label
var corner_asset_buttons: Dictionary = {}

var sel_corner_box: VBoxContainer
var sel_corner_lbl: Label
var sel_corner_asset_opt: OptionButton
var sel_corner_rot_spin: SpinBox
var sel_corner_offset_spin: SpinBox
var sel_corner_scale_x_spin: SpinBox
var sel_corner_scale_y_spin: SpinBox
var sel_corner_mx_chk: CheckBox
var sel_corner_my_chk: CheckBox
var current_selected_corner_name: String = ""

# --- Tiles Sub-Tabs (DEFAULT, BORDERS, CORNERS) ---
var tile_subtab_bar: HBoxContainer
var tile_subtab_group: ButtonGroup
var tile_subtab_default_btn: Button
var tile_subtab_borders_btn: Button
var tile_subtab_corners_btn: Button
var tile_default_box: VBoxContainer
var tile_borders_box: VBoxContainer
var tile_corners_box: VBoxContainer
var current_tiles_subtab: int = 0

# --- 3-Library Visual Asset Model Containers ---
var cell_assets_container: VBoxContainer
var border_assets_container: VBoxContainer
var corner_assets_container: VBoxContainer

# Border File Dialog
var border_enable_chk: CheckBox
var border_file_dialog: FileDialog
var border_file_target_prop: String = ""

var lvl_id_spin: SpinBox
var lvl_name_edit: LineEdit
var lvl_univ_timer: SpinBox
var star_3_spin: SpinBox
var star_2_spin: SpinBox
var star_1_spin: SpinBox
var coin_3_spin: SpinBox
var coin_2_spin: SpinBox
var coin_1_spin: SpinBox

# --- Hint Section Controls ---
var tab_hint_btn: Button
var hint_section: VBoxContainer
var hint_enable_chk: CheckBox
var hint_color_btn: ColorPickerButton
var hint_width_spin: SpinBox
var hint_opacity_spin: SpinBox
var hint_draw_btn: Button
var hint_erase_btn: Button
var hint_clear_btn: Button
var hint_points_lbl: Label
var hint_start_lbl: Label
var hint_end_lbl: Label
var hint_status_lbl: Label

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

	tab_hint_btn = Button.new()
	tab_hint_btn.text = "💡 Hint"
	tab_hint_btn.toggle_mode = true
	tab_hint_btn.button_group = tab_group
	tab_hint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_hint_btn.add_theme_font_size_override("font_size", 11)
	tab_hint_btn.pressed.connect(func(): _switch_tab(4))
	tab_bar.add_child(tab_hint_btn)

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
	tile_section = _create_section(main_vbox, "TILES")

	# --- Sub-Tabs Bar: DEFAULT | BORDERS | CORNERS ---
	tile_subtab_bar = HBoxContainer.new()
	tile_subtab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_subtab_bar.add_theme_constant_override("separation", 2)
	tile_section.add_child(tile_subtab_bar)

	tile_subtab_group = ButtonGroup.new()

	tile_subtab_default_btn = Button.new()
	tile_subtab_default_btn.text = "DEFAULT"
	tile_subtab_default_btn.toggle_mode = true
	tile_subtab_default_btn.button_group = tile_subtab_group
	tile_subtab_default_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_subtab_default_btn.add_theme_font_size_override("font_size", 11)
	tile_subtab_default_btn.pressed.connect(func(): _switch_tiles_subtab(0))
	tile_subtab_bar.add_child(tile_subtab_default_btn)

	tile_subtab_borders_btn = Button.new()
	tile_subtab_borders_btn.text = "BORDERS"
	tile_subtab_borders_btn.toggle_mode = true
	tile_subtab_borders_btn.button_group = tile_subtab_group
	tile_subtab_borders_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_subtab_borders_btn.add_theme_font_size_override("font_size", 11)
	tile_subtab_borders_btn.pressed.connect(func(): _switch_tiles_subtab(1))
	tile_subtab_bar.add_child(tile_subtab_borders_btn)

	tile_subtab_corners_btn = Button.new()
	tile_subtab_corners_btn.text = "CORNERS"
	tile_subtab_corners_btn.toggle_mode = true
	tile_subtab_corners_btn.button_group = tile_subtab_group
	tile_subtab_corners_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_subtab_corners_btn.add_theme_font_size_override("font_size", 11)
	tile_subtab_corners_btn.pressed.connect(func(): _switch_tiles_subtab(2))
	tile_subtab_bar.add_child(tile_subtab_corners_btn)

	# =========================================================================
	# TAB 1: DEFAULT (CELL IMAGES)
	# =========================================================================
	tile_default_box = VBoxContainer.new()
	tile_default_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_default_box.add_theme_constant_override("separation", 6)
	tile_section.add_child(tile_default_box)

	var cell_vis_hdr := Label.new()
	cell_vis_hdr.text = "CELL IMAGES"
	cell_vis_hdr.add_theme_font_size_override("font_size", 11)
	cell_vis_hdr.modulate = Color(1.0, 0.85, 0.35)
	tile_default_box.add_child(cell_vis_hdr)

	cell_assets_container = VBoxContainer.new()
	cell_assets_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell_assets_container.add_theme_constant_override("separation", 4)
	tile_default_box.add_child(cell_assets_container)

	var add_cell_btn := Button.new()
	add_cell_btn.text = "➕ Add Cell Image"
	add_cell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_cell_btn.pressed.connect(func():
		_browse_file("add_cell", func(p: String):
			if current_stage != null:
				var new_id = current_stage.add_cell_asset(p)
				_select_cell_asset(new_id)
				stage_settings_changed.emit(current_stage)
				_refresh_tiles_ui()
		)
	)
	tile_default_box.add_child(add_cell_btn)

	tile_default_box.add_child(HSeparator.new())

	var act_cell_lbl := Label.new()
	act_cell_lbl.text = "Active Paint Cell:"
	act_cell_lbl.add_theme_font_size_override("font_size", 11)
	act_cell_lbl.modulate = Color(0.8, 0.9, 1.0)
	tile_default_box.add_child(act_cell_lbl)

	active_cell_opt = OptionButton.new()
	active_cell_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_cell_opt.item_selected.connect(_on_active_cell_opt_changed)
	tile_default_box.add_child(active_cell_opt)

	var rot_hdr := Label.new()
	rot_hdr.text = "Active Paint Rotation:"
	rot_hdr.add_theme_font_size_override("font_size", 11)
	rot_hdr.modulate = Color(0.8, 0.9, 1.0)
	tile_default_box.add_child(rot_hdr)

	var cell_rot_row := HBoxContainer.new()
	cell_rot_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell_rot_row.add_theme_constant_override("separation", 4)

	cell_rot_spin = SpinBox.new()
	cell_rot_spin.min_value = -360.0
	cell_rot_spin.max_value = 360.0
	cell_rot_spin.step = 0.1
	cell_rot_spin.value = 0.0
	cell_rot_spin.suffix = "°"
	cell_rot_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell_rot_spin.value_changed.connect(_on_cell_rot_changed)
	cell_rot_row.add_child(cell_rot_spin)

	tile_rot_buttons.clear()
	for deg in [0, 90, 180, 270]:
		var r_btn := Button.new()
		r_btn.text = "%d°" % deg
		r_btn.custom_minimum_size = Vector2(34, 0)
		r_btn.pressed.connect(func():
			_select_tile_rot(deg)
		)
		cell_rot_row.add_child(r_btn)
		tile_rot_buttons[deg] = r_btn
	tile_default_box.add_child(cell_rot_row)

	var cell_tool_row := HBoxContainer.new()
	cell_tool_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell_tool_row.add_theme_constant_override("separation", 4)

	tile_paint_btn = Button.new()
	tile_paint_btn.text = "🖌️ Paint Cell"
	tile_paint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_paint_btn.tooltip_text = "Activate cell paint mode. Click on grid to place selected visual."
	tile_paint_btn.pressed.connect(_on_paint_tile_pressed)
	cell_tool_row.add_child(tile_paint_btn)

	tile_erase_btn = Button.new()
	tile_erase_btn.text = "🧽 Erase Cell"
	tile_erase_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_erase_btn.tooltip_text = "Activate cell erase mode. Click on grid to remove cell visual."
	tile_erase_btn.pressed.connect(_on_erase_tile_pressed)
	cell_tool_row.add_child(tile_erase_btn)
	tile_default_box.add_child(cell_tool_row)

	var clr_cells_btn := Button.new()
	clr_cells_btn.text = "❌ Clear All Cell Visuals"
	clr_cells_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clr_cells_btn.tooltip_text = "Clear all placed cell visuals on this stage"
	clr_cells_btn.pressed.connect(_on_clear_all_tiles_pressed)
	tile_default_box.add_child(clr_cells_btn)

	tile_default_box.add_child(HSeparator.new())

	# Selected Cell Visual In-Place Editor
	sel_cell_box = VBoxContainer.new()
	sel_cell_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_cell_box.add_theme_constant_override("separation", 4)
	sel_cell_box.visible = false

	var sel_pnl := PanelContainer.new()
	sel_pnl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sel_inner := VBoxContainer.new()
	sel_inner.add_theme_constant_override("separation", 4)

	var sel_cell_hdr := Label.new()
	sel_cell_hdr.text = "SELECTED CELL"
	sel_cell_hdr.add_theme_font_size_override("font_size", 10)
	sel_cell_hdr.modulate = Color(1.0, 0.9, 0.4)
	sel_inner.add_child(sel_cell_hdr)

	sel_cell_lbl = Label.new()
	sel_cell_lbl.text = "Selected Cell: (none)"
	sel_cell_lbl.add_theme_font_size_override("font_size", 11)
	sel_cell_lbl.modulate = Color(1.0, 0.9, 0.3)
	sel_inner.add_child(sel_cell_lbl)

	var sel_edit_row := HBoxContainer.new()
	sel_edit_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var s_a_lbl := Label.new()
	s_a_lbl.text = "Asset:"
	s_a_lbl.add_theme_font_size_override("font_size", 10)
	sel_edit_row.add_child(s_a_lbl)

	sel_cell_asset_opt = OptionButton.new()
	sel_cell_asset_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_cell_asset_opt.item_selected.connect(_on_sel_cell_asset_changed)
	sel_edit_row.add_child(sel_cell_asset_opt)

	var s_r_lbl := Label.new()
	s_r_lbl.text = "Rot:"
	s_r_lbl.add_theme_font_size_override("font_size", 10)
	sel_edit_row.add_child(s_r_lbl)

	sel_cell_rot_spin = SpinBox.new()
	sel_cell_rot_spin.min_value = -360.0
	sel_cell_rot_spin.max_value = 360.0
	sel_cell_rot_spin.step = 0.1
	sel_cell_rot_spin.suffix = "°"
	sel_cell_rot_spin.custom_minimum_size = Vector2(70, 0)
	sel_cell_rot_spin.value_changed.connect(_on_sel_cell_rot_changed)
	sel_edit_row.add_child(sel_cell_rot_spin)

	sel_inner.add_child(sel_edit_row)

	var sel_del_btn := Button.new()
	sel_del_btn.text = "🧽 Remove From This Cell"
	sel_del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_del_btn.pressed.connect(_on_sel_cell_remove_pressed)
	sel_inner.add_child(sel_del_btn)

	sel_pnl.add_child(sel_inner)
	sel_cell_box.add_child(sel_pnl)
	tile_default_box.add_child(sel_cell_box)

	tile_status_lbl = Label.new()
	tile_status_lbl.add_theme_font_size_override("font_size", 11)
	tile_status_lbl.modulate = Color(0.85, 0.9, 0.95)
	tile_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile_default_box.add_child(tile_status_lbl)

	# =========================================================================
	# TAB 2: BORDERS (BORDER IMAGES & PAINTING)
	# =========================================================================
	tile_borders_box = VBoxContainer.new()
	tile_borders_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_borders_box.add_theme_constant_override("separation", 6)
	tile_borders_box.visible = false
	tile_section.add_child(tile_borders_box)

	var border_hdr := Label.new()
	border_hdr.text = "BORDER IMAGES"
	border_hdr.add_theme_font_size_override("font_size", 11)
	border_hdr.modulate = Color(0.4, 0.85, 1.0)
	tile_borders_box.add_child(border_hdr)

	border_assets_container = VBoxContainer.new()
	border_assets_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	border_assets_container.add_theme_constant_override("separation", 4)
	tile_borders_box.add_child(border_assets_container)

	var add_border_btn := Button.new()
	add_border_btn.text = "➕ Add Border Image"
	add_border_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_border_btn.pressed.connect(func():
		_browse_file("add_border", func(p: String):
			if current_stage != null:
				var new_id = current_stage.add_border_asset(p)
				_select_border_asset(new_id)
				stage_settings_changed.emit(current_stage)
				_refresh_tiles_ui()
		)
	)
	tile_borders_box.add_child(add_border_btn)

	tile_borders_box.add_child(HSeparator.new())

	var act_border_sec_lbl := Label.new()
	act_border_sec_lbl.text = "ACTIVE BORDER"
	act_border_sec_lbl.add_theme_font_size_override("font_size", 11)
	act_border_sec_lbl.modulate = Color(0.7, 0.9, 1.0)
	tile_borders_box.add_child(act_border_sec_lbl)

	var act_border_lbl := Label.new()
	act_border_lbl.text = "Active Paint Border:"
	act_border_lbl.add_theme_font_size_override("font_size", 10)
	act_border_lbl.modulate = Color(0.8, 0.9, 1.0)
	tile_borders_box.add_child(act_border_lbl)

	active_border_opt = OptionButton.new()
	active_border_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_border_opt.item_selected.connect(_on_active_border_opt_changed)
	tile_borders_box.add_child(active_border_opt)

	var b_rot_hdr := Label.new()
	b_rot_hdr.text = "Rotation:"
	b_rot_hdr.add_theme_font_size_override("font_size", 10)
	b_rot_hdr.modulate = Color(0.8, 0.9, 1.0)
	tile_borders_box.add_child(b_rot_hdr)

	var border_rot_row := HBoxContainer.new()
	border_rot_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	border_rot_row.add_theme_constant_override("separation", 4)

	active_border_rot_spin = SpinBox.new()
	active_border_rot_spin.min_value = -360.0
	active_border_rot_spin.max_value = 360.0
	active_border_rot_spin.step = 0.1
	active_border_rot_spin.value = 0.0
	active_border_rot_spin.suffix = "°"
	active_border_rot_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_border_rot_spin.value_changed.connect(_on_border_rot_changed)
	border_rot_row.add_child(active_border_rot_spin)

	border_rot_buttons.clear()
	for deg in [0, 90, 180, 270]:
		var r_btn := Button.new()
		r_btn.text = "%d°" % deg
		r_btn.custom_minimum_size = Vector2(34, 0)
		r_btn.pressed.connect(func():
			_select_border_rot(deg)
		)
		border_rot_row.add_child(r_btn)
		border_rot_buttons[deg] = r_btn
	tile_borders_box.add_child(border_rot_row)

	var b_off_row := HBoxContainer.new()
	b_off_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b_off_lbl := Label.new()
	b_off_lbl.text = "Offset From Grid:"
	b_off_lbl.add_theme_font_size_override("font_size", 10)
	b_off_row.add_child(b_off_lbl)

	active_border_offset_spin = SpinBox.new()
	active_border_offset_spin.min_value = -500.0
	active_border_offset_spin.max_value = 500.0
	active_border_offset_spin.step = 0.001
	active_border_offset_spin.value = 0.0
	active_border_offset_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_border_offset_spin.value_changed.connect(_on_border_offset_changed)
	b_off_row.add_child(active_border_offset_spin)
	tile_borders_box.add_child(b_off_row)

	var b_scale_row := HBoxContainer.new()
	b_scale_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var b_sx_lbl := Label.new()
	b_sx_lbl.text = "Scale X:"
	b_sx_lbl.add_theme_font_size_override("font_size", 10)
	b_scale_row.add_child(b_sx_lbl)

	active_border_scale_x_spin = SpinBox.new()
	active_border_scale_x_spin.min_value = 0.001
	active_border_scale_x_spin.max_value = 100.0
	active_border_scale_x_spin.step = 0.001
	active_border_scale_x_spin.value = 1.0
	active_border_scale_x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_border_scale_x_spin.value_changed.connect(_on_border_scale_x_changed)
	b_scale_row.add_child(active_border_scale_x_spin)

	var b_sy_lbl := Label.new()
	b_sy_lbl.text = "Scale Y:"
	b_sy_lbl.add_theme_font_size_override("font_size", 10)
	b_scale_row.add_child(b_sy_lbl)

	active_border_scale_y_spin = SpinBox.new()
	active_border_scale_y_spin.min_value = 0.001
	active_border_scale_y_spin.max_value = 100.0
	active_border_scale_y_spin.step = 0.001
	active_border_scale_y_spin.value = 1.0
	active_border_scale_y_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_border_scale_y_spin.value_changed.connect(_on_border_scale_y_changed)
	b_scale_row.add_child(active_border_scale_y_spin)
	tile_borders_box.add_child(b_scale_row)

	var border_tool_row := HBoxContainer.new()
	border_tool_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	border_tool_row.add_theme_constant_override("separation", 4)

	border_paint_btn = Button.new()
	border_paint_btn.text = "🛡️ Paint Border"
	border_paint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	border_paint_btn.tooltip_text = "Activate border paint mode. Click on cell edges to place selected border visual."
	border_paint_btn.pressed.connect(_on_paint_border_pressed)
	border_tool_row.add_child(border_paint_btn)

	border_erase_btn = Button.new()
	border_erase_btn.text = "🧽 Erase Border"
	border_erase_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	border_erase_btn.tooltip_text = "Activate border erase mode. Click on cell edges to remove border."
	border_erase_btn.pressed.connect(_on_erase_border_pressed)
	border_tool_row.add_child(border_erase_btn)
	tile_borders_box.add_child(border_tool_row)

	var clr_borders_btn := Button.new()
	clr_borders_btn.text = "❌ Clear All Borders"
	clr_borders_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clr_borders_btn.tooltip_text = "Clear all placed borders on this stage"
	clr_borders_btn.pressed.connect(_on_clear_all_borders_pressed)
	tile_borders_box.add_child(clr_borders_btn)

	tile_borders_box.add_child(HSeparator.new())

	# Selected Border Visual In-Place Editor
	sel_border_box = VBoxContainer.new()
	sel_border_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_border_box.add_theme_constant_override("separation", 4)
	sel_border_box.visible = false

	var sel_b_pnl := PanelContainer.new()
	sel_b_pnl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sel_b_inner := VBoxContainer.new()
	sel_b_inner.add_theme_constant_override("separation", 4)

	var sel_b_sec_hdr := Label.new()
	sel_b_sec_hdr.text = "SELECTED BORDER"
	sel_b_sec_hdr.add_theme_font_size_override("font_size", 10)
	sel_b_sec_hdr.modulate = Color(0.4, 0.9, 1.0)
	sel_b_inner.add_child(sel_b_sec_hdr)

	sel_border_lbl = Label.new()
	sel_border_lbl.text = "Selected Border: (none)"
	sel_border_lbl.add_theme_font_size_override("font_size", 11)
	sel_border_lbl.modulate = Color(0.4, 0.9, 1.0)
	sel_b_inner.add_child(sel_border_lbl)

	var sel_b_edit_row := HBoxContainer.new()
	sel_b_edit_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb_a_lbl := Label.new()
	sb_a_lbl.text = "Asset:"
	sb_a_lbl.add_theme_font_size_override("font_size", 10)
	sel_b_edit_row.add_child(sb_a_lbl)

	sel_border_asset_opt = OptionButton.new()
	sel_border_asset_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_border_asset_opt.item_selected.connect(_on_sel_border_asset_changed)
	sel_b_edit_row.add_child(sel_border_asset_opt)

	var sb_r_lbl := Label.new()
	sb_r_lbl.text = "Rot:"
	sb_r_lbl.add_theme_font_size_override("font_size", 10)
	sel_b_edit_row.add_child(sb_r_lbl)

	sel_border_rot_spin = SpinBox.new()
	sel_border_rot_spin.min_value = -360.0
	sel_border_rot_spin.max_value = 360.0
	sel_border_rot_spin.step = 0.1
	sel_border_rot_spin.suffix = "°"
	sel_border_rot_spin.custom_minimum_size = Vector2(70, 0)
	sel_border_rot_spin.value_changed.connect(_on_sel_border_rot_changed)
	sel_b_edit_row.add_child(sel_border_rot_spin)

	sel_b_inner.add_child(sel_b_edit_row)

	var sel_b_off_row := HBoxContainer.new()
	sel_b_off_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb_off_lbl := Label.new()
	sb_off_lbl.text = "Offset From Grid:"
	sb_off_lbl.add_theme_font_size_override("font_size", 10)
	sel_b_off_row.add_child(sb_off_lbl)

	sel_border_offset_spin = SpinBox.new()
	sel_border_offset_spin.min_value = -500.0
	sel_border_offset_spin.max_value = 500.0
	sel_border_offset_spin.step = 0.001
	sel_border_offset_spin.value = 0.0
	sel_border_offset_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_border_offset_spin.value_changed.connect(_on_sel_border_offset_changed)
	sel_b_off_row.add_child(sel_border_offset_spin)
	sel_b_inner.add_child(sel_b_off_row)

	var sel_b_scale_row := HBoxContainer.new()
	sel_b_scale_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb_sx_lbl := Label.new()
	sb_sx_lbl.text = "Scale X:"
	sb_sx_lbl.add_theme_font_size_override("font_size", 10)
	sel_b_scale_row.add_child(sb_sx_lbl)

	sel_border_scale_x_spin = SpinBox.new()
	sel_border_scale_x_spin.min_value = 0.001
	sel_border_scale_x_spin.max_value = 100.0
	sel_border_scale_x_spin.step = 0.001
	sel_border_scale_x_spin.value = 1.0
	sel_border_scale_x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_border_scale_x_spin.value_changed.connect(_on_sel_border_scale_x_changed)
	sel_b_scale_row.add_child(sel_border_scale_x_spin)

	var sb_sy_lbl := Label.new()
	sb_sy_lbl.text = "Scale Y:"
	sb_sy_lbl.add_theme_font_size_override("font_size", 10)
	sel_b_scale_row.add_child(sb_sy_lbl)

	sel_border_scale_y_spin = SpinBox.new()
	sel_border_scale_y_spin.min_value = 0.001
	sel_border_scale_y_spin.max_value = 100.0
	sel_border_scale_y_spin.step = 0.001
	sel_border_scale_y_spin.value = 1.0
	sel_border_scale_y_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_border_scale_y_spin.value_changed.connect(_on_sel_border_scale_y_changed)
	sel_b_scale_row.add_child(sel_border_scale_y_spin)
	sel_b_inner.add_child(sel_b_scale_row)

	var sel_b_del_btn := Button.new()
	sel_b_del_btn.text = "🧽 Remove From This Border"
	sel_b_del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_b_del_btn.pressed.connect(_on_sel_border_remove_pressed)
	sel_b_inner.add_child(sel_b_del_btn)

	sel_b_pnl.add_child(sel_b_inner)
	sel_border_box.add_child(sel_b_pnl)
	tile_borders_box.add_child(sel_border_box)

	border_status_lbl = Label.new()
	border_status_lbl.add_theme_font_size_override("font_size", 11)
	border_status_lbl.modulate = Color(0.85, 0.9, 0.95)
	border_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile_borders_box.add_child(border_status_lbl)

	# =========================================================================
	# TAB 3: CORNERS (CORNER IMAGES & PAINTING)
	# =========================================================================
	tile_corners_box = VBoxContainer.new()
	tile_corners_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_corners_box.add_theme_constant_override("separation", 6)
	tile_corners_box.visible = false
	tile_section.add_child(tile_corners_box)

	var corner_hdr := Label.new()
	corner_hdr.text = "CORNER IMAGES"
	corner_hdr.add_theme_font_size_override("font_size", 11)
	corner_hdr.modulate = Color(0.9, 0.55, 1.0)
	tile_corners_box.add_child(corner_hdr)

	corner_assets_container = VBoxContainer.new()
	corner_assets_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corner_assets_container.add_theme_constant_override("separation", 4)
	tile_corners_box.add_child(corner_assets_container)

	var add_corner_btn := Button.new()
	add_corner_btn.text = "➕ Add Corner Image"
	add_corner_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_corner_btn.pressed.connect(func():
		_browse_file("add_corner", func(p: String):
			if current_stage != null:
				var new_id = current_stage.add_corner_asset(p)
				_select_corner_asset(new_id)
				stage_settings_changed.emit(current_stage)
				_refresh_tiles_ui()
		)
	)
	tile_corners_box.add_child(add_corner_btn)

	tile_corners_box.add_child(HSeparator.new())

	var act_corner_sec_lbl := Label.new()
	act_corner_sec_lbl.text = "ACTIVE CORNER"
	act_corner_sec_lbl.add_theme_font_size_override("font_size", 11)
	act_corner_sec_lbl.modulate = Color(0.95, 0.75, 1.0)
	tile_corners_box.add_child(act_corner_sec_lbl)

	var act_corner_lbl := Label.new()
	act_corner_lbl.text = "Active Paint Corner:"
	act_corner_lbl.add_theme_font_size_override("font_size", 10)
	act_corner_lbl.modulate = Color(0.8, 0.9, 1.0)
	tile_corners_box.add_child(act_corner_lbl)

	active_corner_opt = OptionButton.new()
	active_corner_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_corner_opt.item_selected.connect(_on_active_corner_opt_changed)
	tile_corners_box.add_child(active_corner_opt)

	var c_rot_hdr := Label.new()
	c_rot_hdr.text = "Rotation:"
	c_rot_hdr.add_theme_font_size_override("font_size", 10)
	c_rot_hdr.modulate = Color(0.8, 0.9, 1.0)
	tile_corners_box.add_child(c_rot_hdr)

	var corner_rot_row := HBoxContainer.new()
	corner_rot_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corner_rot_row.add_theme_constant_override("separation", 4)

	active_corner_rot_spin = SpinBox.new()
	active_corner_rot_spin.min_value = -360.0
	active_corner_rot_spin.max_value = 360.0
	active_corner_rot_spin.step = 0.1
	active_corner_rot_spin.value = 0.0
	active_corner_rot_spin.suffix = "°"
	active_corner_rot_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_corner_rot_spin.value_changed.connect(_on_corner_rot_changed)
	corner_rot_row.add_child(active_corner_rot_spin)

	corner_rot_buttons.clear()
	for deg in [0, 90, 180, 270]:
		var r_btn := Button.new()
		r_btn.text = "%d°" % deg
		r_btn.custom_minimum_size = Vector2(34, 0)
		r_btn.pressed.connect(func():
			_select_corner_rot(deg)
		)
		corner_rot_row.add_child(r_btn)
		corner_rot_buttons[deg] = r_btn
	tile_corners_box.add_child(corner_rot_row)

	var c_off_row := HBoxContainer.new()
	c_off_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c_off_lbl := Label.new()
	c_off_lbl.text = "Offset From Grid:"
	c_off_lbl.add_theme_font_size_override("font_size", 10)
	c_off_row.add_child(c_off_lbl)

	active_corner_offset_spin = SpinBox.new()
	active_corner_offset_spin.min_value = -500.0
	active_corner_offset_spin.max_value = 500.0
	active_corner_offset_spin.step = 0.001
	active_corner_offset_spin.value = 0.0
	active_corner_offset_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_corner_offset_spin.value_changed.connect(_on_corner_offset_changed)
	c_off_row.add_child(active_corner_offset_spin)
	tile_corners_box.add_child(c_off_row)

	var c_scale_row := HBoxContainer.new()
	c_scale_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var c_sx_lbl := Label.new()
	c_sx_lbl.text = "Scale X:"
	c_sx_lbl.add_theme_font_size_override("font_size", 10)
	c_scale_row.add_child(c_sx_lbl)

	active_corner_scale_x_spin = SpinBox.new()
	active_corner_scale_x_spin.min_value = 0.001
	active_corner_scale_x_spin.max_value = 100.0
	active_corner_scale_x_spin.step = 0.001
	active_corner_scale_x_spin.value = 1.0
	active_corner_scale_x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_corner_scale_x_spin.value_changed.connect(_on_corner_scale_x_changed)
	c_scale_row.add_child(active_corner_scale_x_spin)

	var c_sy_lbl := Label.new()
	c_sy_lbl.text = "Scale Y:"
	c_sy_lbl.add_theme_font_size_override("font_size", 10)
	c_scale_row.add_child(c_sy_lbl)

	active_corner_scale_y_spin = SpinBox.new()
	active_corner_scale_y_spin.min_value = 0.001
	active_corner_scale_y_spin.max_value = 100.0
	active_corner_scale_y_spin.step = 0.001
	active_corner_scale_y_spin.value = 1.0
	active_corner_scale_y_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_corner_scale_y_spin.value_changed.connect(_on_corner_scale_y_changed)
	c_scale_row.add_child(active_corner_scale_y_spin)
	tile_corners_box.add_child(c_scale_row)

	var corner_mirror_row := HBoxContainer.new()
	corner_mirror_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corner_mirror_row.add_theme_constant_override("separation", 12)

	active_corner_mx_chk = CheckBox.new()
	active_corner_mx_chk.text = "Mirror X"
	active_corner_mx_chk.add_theme_font_size_override("font_size", 10)
	active_corner_mx_chk.toggled.connect(_on_corner_mirror_toggled)
	corner_mirror_row.add_child(active_corner_mx_chk)

	active_corner_my_chk = CheckBox.new()
	active_corner_my_chk.text = "Mirror Y"
	active_corner_my_chk.add_theme_font_size_override("font_size", 10)
	active_corner_my_chk.toggled.connect(_on_corner_mirror_toggled)
	corner_mirror_row.add_child(active_corner_my_chk)
	tile_corners_box.add_child(corner_mirror_row)

	var corner_tool_row := HBoxContainer.new()
	corner_tool_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corner_tool_row.add_theme_constant_override("separation", 4)

	corner_paint_btn = Button.new()
	corner_paint_btn.text = "📐 Paint Corner"
	corner_paint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corner_paint_btn.tooltip_text = "Activate corner paint mode. Click on grid intersections to place selected corner visual."
	corner_paint_btn.pressed.connect(_on_paint_corner_pressed)
	corner_tool_row.add_child(corner_paint_btn)

	corner_erase_btn = Button.new()
	corner_erase_btn.text = "🧽 Erase Corner"
	corner_erase_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corner_erase_btn.tooltip_text = "Activate corner erase mode. Click on grid intersections to remove corner."
	corner_erase_btn.pressed.connect(_on_erase_corner_pressed)
	corner_tool_row.add_child(corner_erase_btn)
	tile_corners_box.add_child(corner_tool_row)

	var clr_corners_btn := Button.new()
	clr_corners_btn.text = "❌ Clear All Corners"
	clr_corners_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clr_corners_btn.tooltip_text = "Clear all placed corners on this stage"
	clr_corners_btn.pressed.connect(_on_clear_all_corners_pressed)
	tile_corners_box.add_child(clr_corners_btn)

	tile_corners_box.add_child(HSeparator.new())

	# Selected Corner Visual In-Place Editor
	sel_corner_box = VBoxContainer.new()
	sel_corner_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_corner_box.add_theme_constant_override("separation", 4)
	sel_corner_box.visible = false

	var sel_c_pnl := PanelContainer.new()
	sel_c_pnl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sel_c_inner := VBoxContainer.new()
	sel_c_inner.add_theme_constant_override("separation", 4)

	var sel_c_sec_hdr := Label.new()
	sel_c_sec_hdr.text = "SELECTED CORNER"
	sel_c_sec_hdr.add_theme_font_size_override("font_size", 10)
	sel_c_sec_hdr.modulate = Color(0.9, 0.55, 1.0)
	sel_c_inner.add_child(sel_c_sec_hdr)

	sel_corner_lbl = Label.new()
	sel_corner_lbl.text = "Selected Corner: (none)"
	sel_corner_lbl.add_theme_font_size_override("font_size", 11)
	sel_corner_lbl.modulate = Color(0.9, 0.55, 1.0)
	sel_c_inner.add_child(sel_corner_lbl)

	var sel_c_edit_row := HBoxContainer.new()
	sel_c_edit_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sc_a_lbl := Label.new()
	sc_a_lbl.text = "Asset:"
	sc_a_lbl.add_theme_font_size_override("font_size", 10)
	sel_c_edit_row.add_child(sc_a_lbl)

	sel_corner_asset_opt = OptionButton.new()
	sel_corner_asset_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_corner_asset_opt.item_selected.connect(_on_sel_corner_asset_changed)
	sel_c_edit_row.add_child(sel_corner_asset_opt)

	var sc_r_lbl := Label.new()
	sc_r_lbl.text = "Rot:"
	sc_r_lbl.add_theme_font_size_override("font_size", 10)
	sel_c_edit_row.add_child(sc_r_lbl)

	sel_corner_rot_spin = SpinBox.new()
	sel_corner_rot_spin.min_value = -360.0
	sel_corner_rot_spin.max_value = 360.0
	sel_corner_rot_spin.step = 0.1
	sel_corner_rot_spin.suffix = "°"
	sel_corner_rot_spin.custom_minimum_size = Vector2(70, 0)
	sel_corner_rot_spin.value_changed.connect(_on_sel_corner_rot_changed)
	sel_c_edit_row.add_child(sel_corner_rot_spin)

	sel_c_inner.add_child(sel_c_edit_row)

	var sel_c_off_row := HBoxContainer.new()
	sel_c_off_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sc_off_lbl := Label.new()
	sc_off_lbl.text = "Offset From Grid:"
	sc_off_lbl.add_theme_font_size_override("font_size", 10)
	sel_c_off_row.add_child(sc_off_lbl)

	sel_corner_offset_spin = SpinBox.new()
	sel_corner_offset_spin.min_value = -500.0
	sel_corner_offset_spin.max_value = 500.0
	sel_corner_offset_spin.step = 0.001
	sel_corner_offset_spin.value = 0.0
	sel_corner_offset_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_corner_offset_spin.value_changed.connect(_on_sel_corner_offset_changed)
	sel_c_off_row.add_child(sel_corner_offset_spin)
	sel_c_inner.add_child(sel_c_off_row)

	var sel_c_scale_row := HBoxContainer.new()
	sel_c_scale_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sc_sx_lbl := Label.new()
	sc_sx_lbl.text = "Scale X:"
	sc_sx_lbl.add_theme_font_size_override("font_size", 10)
	sel_c_scale_row.add_child(sc_sx_lbl)

	sel_corner_scale_x_spin = SpinBox.new()
	sel_corner_scale_x_spin.min_value = 0.001
	sel_corner_scale_x_spin.max_value = 100.0
	sel_corner_scale_x_spin.step = 0.001
	sel_corner_scale_x_spin.value = 1.0
	sel_corner_scale_x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_corner_scale_x_spin.value_changed.connect(_on_sel_corner_scale_x_changed)
	sel_c_scale_row.add_child(sel_corner_scale_x_spin)

	var sc_sy_lbl := Label.new()
	sc_sy_lbl.text = "Scale Y:"
	sc_sy_lbl.add_theme_font_size_override("font_size", 10)
	sel_c_scale_row.add_child(sc_sy_lbl)

	sel_corner_scale_y_spin = SpinBox.new()
	sel_corner_scale_y_spin.min_value = 0.001
	sel_corner_scale_y_spin.max_value = 100.0
	sel_corner_scale_y_spin.step = 0.001
	sel_corner_scale_y_spin.value = 1.0
	sel_corner_scale_y_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_corner_scale_y_spin.value_changed.connect(_on_sel_corner_scale_y_changed)
	sel_c_scale_row.add_child(sel_corner_scale_y_spin)
	sel_c_inner.add_child(sel_c_scale_row)

	var sel_c_mirror_row := HBoxContainer.new()
	sel_c_mirror_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_c_mirror_row.add_theme_constant_override("separation", 12)

	sel_corner_mx_chk = CheckBox.new()
	sel_corner_mx_chk.text = "Mirror X"
	sel_corner_mx_chk.add_theme_font_size_override("font_size", 10)
	sel_corner_mx_chk.toggled.connect(_on_sel_corner_mirror_changed)
	sel_c_mirror_row.add_child(sel_corner_mx_chk)

	sel_corner_my_chk = CheckBox.new()
	sel_corner_my_chk.text = "Mirror Y"
	sel_corner_my_chk.add_theme_font_size_override("font_size", 10)
	sel_corner_my_chk.toggled.connect(_on_sel_corner_mirror_changed)
	sel_c_mirror_row.add_child(sel_corner_my_chk)
	sel_c_inner.add_child(sel_c_mirror_row)

	var sel_c_del_btn := Button.new()
	sel_c_del_btn.text = "🧽 Remove From This Corner"
	sel_c_del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_c_del_btn.pressed.connect(_on_sel_corner_remove_pressed)
	sel_c_inner.add_child(sel_c_del_btn)

	sel_c_pnl.add_child(sel_c_inner)
	sel_corner_box.add_child(sel_c_pnl)
	tile_corners_box.add_child(sel_corner_box)

	corner_status_lbl = Label.new()
	corner_status_lbl.add_theme_font_size_override("font_size", 11)
	corner_status_lbl.modulate = Color(0.85, 0.9, 0.95)
	corner_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile_corners_box.add_child(corner_status_lbl)

	_setup_border_file_dialog()

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

	# =========================================================================
	# TAB 5: HINT (VISUAL-ONLY LASER HINT PATH)
	# =========================================================================
	hint_section = _create_section(main_vbox, "HINT")

	var hint_hdr := Label.new()
	hint_hdr.text = "LASER HINT"
	hint_hdr.add_theme_font_size_override("font_size", 11)
	hint_hdr.modulate = Color(0.4, 0.85, 1.0)
	hint_section.add_child(hint_hdr)

	var hint_info_note := Label.new()
	hint_info_note.text = "Visual-only path configuration for Hint power-up."
	hint_info_note.add_theme_font_size_override("font_size", 10)
	hint_info_note.modulate = Color(0.7, 0.75, 0.8)
	hint_info_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_section.add_child(hint_info_note)

	hint_enable_chk = CheckBox.new()
	hint_enable_chk.text = "Enable Hint Path"
	hint_enable_chk.toggled.connect(_on_hint_enable_toggled)
	hint_section.add_child(hint_enable_chk)

	var hint_color_row := HBoxContainer.new()
	hint_color_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hc_lbl := Label.new()
	hc_lbl.text = "Laser Color:"
	hc_lbl.add_theme_font_size_override("font_size", 11)
	hint_color_row.add_child(hc_lbl)
	hint_color_btn = ColorPickerButton.new()
	hint_color_btn.custom_minimum_size = Vector2(50, 24)
	hint_color_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_color_btn.color = Color(0.31, 0.76, 1.0, 1.0)
	hint_color_btn.color_changed.connect(_on_hint_color_changed)
	hint_color_row.add_child(hint_color_btn)
	hint_section.add_child(hint_color_row)

	var hint_w_row := HBoxContainer.new()
	hint_w_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hw_lbl := Label.new()
	hw_lbl.text = "Laser Width:"
	hw_lbl.add_theme_font_size_override("font_size", 11)
	hint_w_row.add_child(hw_lbl)
	hint_width_spin = SpinBox.new()
	hint_width_spin.min_value = 0.5
	hint_width_spin.max_value = 50.0
	hint_width_spin.step = 0.5
	hint_width_spin.value = 4.0
	hint_width_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_width_spin.value_changed.connect(_on_hint_width_changed)
	hint_w_row.add_child(hint_width_spin)
	hint_section.add_child(hint_w_row)

	var hint_op_row := HBoxContainer.new()
	hint_op_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hop_lbl := Label.new()
	hop_lbl.text = "Laser Opacity:"
	hop_lbl.add_theme_font_size_override("font_size", 11)
	hint_op_row.add_child(hop_lbl)
	hint_opacity_spin = SpinBox.new()
	hint_opacity_spin.min_value = 0.0
	hint_opacity_spin.max_value = 1.0
	hint_opacity_spin.step = 0.05
	hint_opacity_spin.value = 1.0
	hint_opacity_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_opacity_spin.value_changed.connect(_on_hint_opacity_changed)
	hint_op_row.add_child(hint_opacity_spin)
	hint_section.add_child(hint_op_row)

	var hint_tool_row := HBoxContainer.new()
	hint_tool_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_tool_row.add_theme_constant_override("separation", 4)

	var hint_tool_group := ButtonGroup.new()

	hint_draw_btn = Button.new()
	hint_draw_btn.text = "✏️ Draw Hint Path"
	hint_draw_btn.toggle_mode = true
	hint_draw_btn.button_group = hint_tool_group
	hint_draw_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_draw_btn.tooltip_text = "Activate hint drawing mode. Click/drag on grid cells to draw the laser path."
	hint_draw_btn.pressed.connect(_on_hint_draw_pressed)
	hint_tool_row.add_child(hint_draw_btn)

	hint_erase_btn = Button.new()
	hint_erase_btn.text = "🧽 Erase Hint Path"
	hint_erase_btn.toggle_mode = true
	hint_erase_btn.button_group = hint_tool_group
	hint_erase_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_erase_btn.tooltip_text = "Activate hint erase mode. Click on path points to remove them."
	hint_erase_btn.pressed.connect(_on_hint_erase_pressed)
	hint_tool_row.add_child(hint_erase_btn)
	hint_section.add_child(hint_tool_row)

	hint_clear_btn = Button.new()
	hint_clear_btn.text = "❌ Clear Hint Path"
	hint_clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_clear_btn.tooltip_text = "Remove the entire hint path for the current stage."
	hint_clear_btn.pressed.connect(_on_hint_clear_pressed)
	hint_section.add_child(hint_clear_btn)

	hint_section.add_child(HSeparator.new())

	var path_info_hdr := Label.new()
	path_info_hdr.text = "HINT PATH"
	path_info_hdr.add_theme_font_size_override("font_size", 11)
	path_info_hdr.modulate = Color(1.0, 0.85, 0.35)
	hint_section.add_child(path_info_hdr)

	hint_points_lbl = Label.new()
	hint_points_lbl.text = "Points: 0"
	hint_points_lbl.add_theme_font_size_override("font_size", 11)
	hint_section.add_child(hint_points_lbl)

	hint_start_lbl = Label.new()
	hint_start_lbl.text = "Path Start: (none)"
	hint_start_lbl.add_theme_font_size_override("font_size", 11)
	hint_start_lbl.modulate = Color(0.6, 0.9, 0.6)
	hint_section.add_child(hint_start_lbl)

	hint_end_lbl = Label.new()
	hint_end_lbl.text = "Path End: (none)"
	hint_end_lbl.add_theme_font_size_override("font_size", 11)
	hint_end_lbl.modulate = Color(1.0, 0.6, 0.6)
	hint_section.add_child(hint_end_lbl)

	hint_status_lbl = Label.new()
	hint_status_lbl.text = "Click grid cells to draw the laser path."
	hint_status_lbl.add_theme_font_size_override("font_size", 10)
	hint_status_lbl.modulate = Color(0.7, 0.75, 0.8)
	hint_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_section.add_child(hint_status_lbl)

	_update_object_display()
	_switch_tab(1)
	_switch_tiles_subtab(0)

func _switch_tab(idx: int) -> void:
	if tab_obj_btn == null:
		return
	tab_obj_btn.set_pressed_no_signal(idx == 0)
	tab_stage_btn.set_pressed_no_signal(idx == 1)
	tab_lvl_btn.set_pressed_no_signal(idx == 2)
	if tab_tile_btn != null:
		tab_tile_btn.set_pressed_no_signal(idx == 3)
	if tab_hint_btn != null:
		tab_hint_btn.set_pressed_no_signal(idx == 4)
	if obj_section != null:
		obj_section.visible = (idx == 0)
	if stage_section != null:
		stage_section.visible = (idx == 1)
	if lvl_section != null:
		lvl_section.visible = (idx == 2)
	if tile_section != null:
		tile_section.visible = (idx == 3)
	if hint_section != null:
		hint_section.visible = (idx == 4)
	hint_mode_toggled.emit(idx == 4)

func _switch_tiles_subtab(idx: int) -> void:
	current_tiles_subtab = idx
	if tile_subtab_default_btn != null:
		tile_subtab_default_btn.set_pressed_no_signal(idx == 0)
	if tile_subtab_borders_btn != null:
		tile_subtab_borders_btn.set_pressed_no_signal(idx == 1)
	if tile_subtab_corners_btn != null:
		tile_subtab_corners_btn.set_pressed_no_signal(idx == 2)
	if tile_default_box != null:
		tile_default_box.visible = (idx == 0)
	if tile_borders_box != null:
		tile_borders_box.visible = (idx == 1)
	if tile_corners_box != null:
		tile_corners_box.visible = (idx == 2)

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
		if border_enable_chk != null:
			border_enable_chk.set_pressed_no_signal(stage.border_enabled)
		_refresh_tiles_ui()
		update_hint_display()
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

func _refresh_tiles_ui() -> void:
	if current_stage == null:
		return
	current_stage.ensure_default_visual_libraries()

	# 1. Refresh Cell Assets
	if cell_assets_container != null:
		for c in cell_assets_container.get_children():
			c.queue_free()
		cell_asset_buttons.clear()

		for i in range(current_stage.cell_assets.size()):
			var asset = current_stage.cell_assets[i]
			var a_id: String = asset.get("id", "cell_%d" % (i + 1))
			var a_name: String = asset.get("name", a_id)

			var row := HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var btn := Button.new()
			btn.text = "🖼️ " + a_name
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.tooltip_text = asset.get("path", "")
			btn.pressed.connect(func():
				_select_cell_asset(a_id)
			)
			row.add_child(btn)
			cell_asset_buttons[a_id] = btn

			var change_btn := Button.new()
			change_btn.text = "📁"
			change_btn.tooltip_text = "Select/Change Image File for %s" % a_name
			change_btn.pressed.connect(func():
				_browse_file("edit_cell_" + a_id, func(p: String):
					current_stage.update_cell_asset(a_id, p)
					BoardVisualGenerator.clear_texture_cache()
					stage_settings_changed.emit(current_stage)
					_refresh_tiles_ui()
				)
			)
			row.add_child(change_btn)

			if current_stage.cell_assets.size() > 1:
				var del_btn := Button.new()
				del_btn.text = "❌"
				del_btn.tooltip_text = "Remove %s" % a_name
				del_btn.pressed.connect(func():
					current_stage.remove_cell_asset(a_id)
					if active_cell_asset == a_id:
						if not current_stage.cell_assets.is_empty():
							_select_cell_asset(current_stage.cell_assets[0].get("id", "cell_1"))
					BoardVisualGenerator.clear_texture_cache()
					stage_settings_changed.emit(current_stage)
					_refresh_tiles_ui()
				)
				row.add_child(del_btn)

			cell_assets_container.add_child(row)

	# Populate active_cell_opt
	if active_cell_opt != null:
		var prev_cell_id = active_cell_asset
		active_cell_opt.clear()
		var sel_idx := 0
		for i in range(current_stage.cell_assets.size()):
			var a = current_stage.cell_assets[i]
			var a_id: String = a.get("id", "cell_%d" % (i + 1))
			var a_name: String = a.get("name", a_id)
			active_cell_opt.add_item(a_name, i)
			active_cell_opt.set_item_metadata(i, a_id)
			if a_id == prev_cell_id:
				sel_idx = i
		if active_cell_opt.item_count > 0:
			active_cell_opt.select(sel_idx)

	# 2. Refresh Border Assets
	if border_assets_container != null:
		for c in border_assets_container.get_children():
			c.queue_free()
		border_asset_buttons.clear()

		for i in range(current_stage.border_assets.size()):
			var asset = current_stage.border_assets[i]
			var a_id: String = asset.get("id", "border_%d" % (i + 1))
			var a_name: String = asset.get("name", a_id)

			var row := HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var btn := Button.new()
			btn.text = "🛡️ " + a_name
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.tooltip_text = asset.get("path", "")
			btn.pressed.connect(func():
				_select_border_asset(a_id)
			)
			row.add_child(btn)
			border_asset_buttons[a_id] = btn

			var change_b_btn := Button.new()
			change_b_btn.text = "📁"
			change_b_btn.tooltip_text = "Select/Change Border Image File for %s" % a_name
			change_b_btn.pressed.connect(func():
				_browse_file("edit_border_" + a_id, func(p: String):
					current_stage.update_border_asset(a_id, p)
					BoardVisualGenerator.clear_texture_cache()
					stage_settings_changed.emit(current_stage)
					_refresh_tiles_ui()
				)
			)
			row.add_child(change_b_btn)

			if current_stage.border_assets.size() > 1:
				var del_btn := Button.new()
				del_btn.text = "❌"
				del_btn.tooltip_text = "Remove %s" % a_name
				del_btn.pressed.connect(func():
					current_stage.remove_border_asset(a_id)
					if active_border_asset == a_id:
						if not current_stage.border_assets.is_empty():
							_select_border_asset(current_stage.border_assets[0].get("id", "border_1"))
					BoardVisualGenerator.clear_texture_cache()
					stage_settings_changed.emit(current_stage)
					_refresh_tiles_ui()
				)
				row.add_child(del_btn)

			border_assets_container.add_child(row)

	# Populate active_border_opt
	if active_border_opt != null:
		var prev_border_id = active_border_asset
		active_border_opt.clear()
		var sel_b_idx := 0
		for i in range(current_stage.border_assets.size()):
			var a = current_stage.border_assets[i]
			var a_id: String = a.get("id", "border_%d" % (i + 1))
			var a_name: String = a.get("name", a_id)
			active_border_opt.add_item(a_name, i)
			active_border_opt.set_item_metadata(i, a_id)
			if a_id == prev_border_id:
				sel_b_idx = i
		if active_border_opt.item_count > 0:
			active_border_opt.select(sel_b_idx)

	# 3. Refresh Corner Assets
	if corner_assets_container != null:
		for c in corner_assets_container.get_children():
			c.queue_free()
		corner_asset_buttons.clear()

		for i in range(current_stage.corner_assets.size()):
			var asset = current_stage.corner_assets[i]
			var a_id: String = asset.get("id", "corner_%d" % (i + 1))
			var a_name: String = asset.get("name", a_id)

			var row := HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var btn := Button.new()
			btn.text = "📐 " + a_name
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.tooltip_text = asset.get("path", "")
			btn.pressed.connect(func():
				_select_corner_asset(a_id)
			)
			row.add_child(btn)
			corner_asset_buttons[a_id] = btn

			var change_c_btn := Button.new()
			change_c_btn.text = "📁"
			change_c_btn.tooltip_text = "Select/Change Corner Image File for %s" % a_name
			change_c_btn.pressed.connect(func():
				_browse_file("edit_corner_" + a_id, func(p: String):
					current_stage.update_corner_asset(a_id, p)
					BoardVisualGenerator.clear_texture_cache()
					stage_settings_changed.emit(current_stage)
					_refresh_tiles_ui()
				)
			)
			row.add_child(change_c_btn)

			if current_stage.corner_assets.size() > 1:
				var del_btn := Button.new()
				del_btn.text = "❌"
				del_btn.tooltip_text = "Remove %s" % a_name
				del_btn.pressed.connect(func():
					current_stage.remove_corner_asset(a_id)
					if active_corner_asset == a_id:
						if not current_stage.corner_assets.is_empty():
							_select_corner_asset(current_stage.corner_assets[0].get("id", "corner_1"))
					BoardVisualGenerator.clear_texture_cache()
					stage_settings_changed.emit(current_stage)
					_refresh_tiles_ui()
				)
				row.add_child(del_btn)

			corner_assets_container.add_child(row)

	# Populate active_corner_opt
	if active_corner_opt != null:
		var prev_corner_id = active_corner_asset
		active_corner_opt.clear()
		var sel_c_idx := 0
		for i in range(current_stage.corner_assets.size()):
			var a = current_stage.corner_assets[i]
			var a_id: String = a.get("id", "corner_%d" % (i + 1))
			var a_name: String = a.get("name", a_id)
			active_corner_opt.add_item(a_name, i)
			active_corner_opt.set_item_metadata(i, a_id)
			if a_id == prev_corner_id:
				sel_c_idx = i
		if active_corner_opt.item_count > 0:
			active_corner_opt.select(sel_c_idx)

	# Sync in-place selection options
	_sync_inplace_options()

	_update_cell_visual_highlights()
	_update_border_visual_highlights()
	_update_corner_visual_highlights()
	_update_tile_rot_highlights()
	_update_border_rot_highlights()
	_update_corner_rot_highlights()
	_update_tile_status()
	_update_border_status()
	_update_corner_status()

func _sync_inplace_options() -> void:
	if current_stage == null:
		return
	if sel_cell_asset_opt != null:
		var prev_txt = sel_cell_asset_opt.text
		sel_cell_asset_opt.clear()
		for a in current_stage.cell_assets:
			sel_cell_asset_opt.add_item(str(a.get("id", "")))
		for i in range(sel_cell_asset_opt.item_count):
			if sel_cell_asset_opt.get_item_text(i) == prev_txt:
				sel_cell_asset_opt.select(i)
				break

	if sel_border_asset_opt != null:
		var prev_b_txt = sel_border_asset_opt.text
		sel_border_asset_opt.clear()
		for a in current_stage.border_assets:
			sel_border_asset_opt.add_item(str(a.get("id", "")))
		for i in range(sel_border_asset_opt.item_count):
			if sel_border_asset_opt.get_item_text(i) == prev_b_txt:
				sel_border_asset_opt.select(i)
				break

	if sel_corner_asset_opt != null:
		var prev_c_txt = sel_corner_asset_opt.text
		sel_corner_asset_opt.clear()
		for a in current_stage.corner_assets:
			sel_corner_asset_opt.add_item(str(a.get("id", "")))
		for i in range(sel_corner_asset_opt.item_count):
			if sel_corner_asset_opt.get_item_text(i) == prev_c_txt:
				sel_corner_asset_opt.select(i)
				break

var _file_dialog_callback: Callable = Callable()

func _setup_border_file_dialog() -> void:
	if border_file_dialog != null:
		return
	border_file_dialog = FileDialog.new()
	border_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	border_file_dialog.access = FileDialog.ACCESS_RESOURCES
	border_file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp, *.svg ; Image Files", "* ; All Files"])
	border_file_dialog.file_selected.connect(func(path: String):
		if _file_dialog_callback.is_valid():
			_file_dialog_callback.call(path)
	)
	add_child(border_file_dialog)

func _browse_file(target_prop: String, on_selected: Callable = Callable()) -> void:
	border_file_target_prop = target_prop
	_file_dialog_callback = on_selected
	if border_file_dialog != null:
		if border_file_dialog.is_inside_tree():
			border_file_dialog.popup_centered_ratio(0.7)
		else:
			border_file_dialog.visible = true

# =========================================================================
# CELL VISUAL HANDLERS
# =========================================================================
func _select_cell_asset(asset_key: String) -> void:
	active_cell_asset = asset_key
	if active_cell_opt != null and current_stage != null:
		for i in range(active_cell_opt.item_count):
			if str(active_cell_opt.get_item_metadata(i)) == asset_key:
				active_cell_opt.select(i)
				break
	_update_cell_visual_highlights()
	_update_tile_status()
	cell_visual_paint_selected.emit(active_cell_asset, active_cell_rot)
	tile_paint_selected.emit(Vector2i(selected_tile_type, int(round(active_cell_rot))))
	tile_tool_mode_requested.emit(5)

func _on_active_cell_opt_changed(idx: int) -> void:
	if active_cell_opt == null:
		return
	var a_id = str(active_cell_opt.get_item_metadata(idx)) if idx >= 0 else active_cell_opt.get_item_text(idx)
	if not a_id.is_empty():
		_select_cell_asset(a_id)

func _on_cell_rot_changed(new_rot: float) -> void:
	active_cell_rot = new_rot
	selected_tile_rot = int(round(new_rot))
	_update_tile_rot_highlights()
	_update_tile_status()
	cell_visual_paint_selected.emit(active_cell_asset, active_cell_rot)
	tile_paint_selected.emit(Vector2i(selected_tile_type, selected_tile_rot))

func _select_tile_rot(rot_deg: int) -> void:
	selected_tile_rot = rot_deg
	active_cell_rot = float(rot_deg)
	if cell_rot_spin != null:
		cell_rot_spin.set_value_no_signal(active_cell_rot)
	selected_tile_coord = Vector2i(selected_tile_type, selected_tile_rot)
	_update_tile_rot_highlights()
	_update_tile_status()
	cell_visual_paint_selected.emit(active_cell_asset, active_cell_rot)
	tile_paint_selected.emit(selected_tile_coord)
	tile_tool_mode_requested.emit(5)

func _update_cell_visual_highlights() -> void:
	for k in cell_asset_buttons.keys():
		var btn: Button = cell_asset_buttons[k]
		if is_instance_valid(btn):
			if k == active_cell_asset:
				btn.modulate = Color(1.6, 1.5, 0.3)
			else:
				btn.modulate = Color(1.0, 1.0, 1.0)

func _update_tile_rot_highlights() -> void:
	for r in tile_rot_buttons.keys():
		var btn: Button = tile_rot_buttons[r]
		if is_instance_valid(btn):
			if r == int(round(active_cell_rot)):
				btn.modulate = Color(1.6, 1.5, 0.3)
			else:
				btn.modulate = Color(1.0, 1.0, 1.0)

func _update_tile_status() -> void:
	if tile_status_lbl == null:
		return
	var count := 0
	if current_stage != null:
		count = current_stage.get_cell_visuals_count()
	tile_status_lbl.text = "Active Cell: %s (%.0f°)\nPlaced Cells: %d\nClick stage cell to paint or edit." % [active_cell_asset, active_cell_rot, count]

func _on_paint_tile_pressed() -> void:
	selected_tile_coord = Vector2i(selected_tile_type, int(round(active_cell_rot)))
	cell_visual_paint_selected.emit(active_cell_asset, active_cell_rot)
	tile_paint_selected.emit(selected_tile_coord)
	tile_tool_mode_requested.emit(5)
	_update_tile_status()

func _on_erase_tile_pressed() -> void:
	tile_tool_mode_requested.emit(6)
	if tile_status_lbl != null:
		var count := 0
		if current_stage != null:
			count = current_stage.get_cell_visuals_count()
		tile_status_lbl.text = "Erase Cell Mode active!\nPlaced Cells: %d\nClick stage cell to remove visual." % count

func _on_clear_all_tiles_pressed() -> void:
	if current_stage != null:
		current_stage.clear_all_cell_visuals()
		stage_settings_changed.emit(current_stage)
		_update_tile_status()

func inspect_cell_visual(stage: LaserStageData, cell: Vector2i, visual_data: Dictionary) -> void:
	current_selected_visual_cell = cell
	if sel_cell_box == null:
		return
	if visual_data.is_empty():
		sel_cell_box.visible = false
		return
	_switch_tab(3)
	_switch_tiles_subtab(0)
	sel_cell_box.visible = true
	sel_cell_lbl.text = "Selected Cell: (%d, %d)" % [cell.x, cell.y]
	var cur_asset = str(visual_data.get("asset", ""))
	var cur_rot = float(visual_data.get("rotation", 0.0))

	sel_cell_asset_opt.clear()
	var selected_idx := 0
	if stage != null:
		stage.ensure_default_visual_libraries()
		for i in range(stage.cell_assets.size()):
			var a = stage.cell_assets[i]
			var aid: String = str(a.get("id", "cell_%d" % (i + 1)))
			var aname: String = str(a.get("name", aid))
			sel_cell_asset_opt.add_item(aname)
			var cur_idx = sel_cell_asset_opt.item_count - 1
			sel_cell_asset_opt.set_item_metadata(cur_idx, aid)
			if aid == cur_asset or aname == cur_asset or a.get("path", "") == cur_asset or (cur_asset.is_empty() and i == 0):
				selected_idx = cur_idx

	for extra in ["Cell_A", "Cell_B", "Cell_C", "Cell_D", cur_asset]:
		if not extra.is_empty():
			var found := false
			for i in range(sel_cell_asset_opt.item_count):
				if sel_cell_asset_opt.get_item_text(i) == extra or str(sel_cell_asset_opt.get_item_metadata(i)) == extra:
					found = true
					break
			if not found:
				sel_cell_asset_opt.add_item(extra)
				var new_idx = sel_cell_asset_opt.item_count - 1
				sel_cell_asset_opt.set_item_metadata(new_idx, extra)
				if extra == cur_asset:
					selected_idx = new_idx

	sel_cell_asset_opt.select(selected_idx)
	sel_cell_rot_spin.set_value_no_signal(cur_rot)

func _on_sel_cell_rot_changed(new_rot: float) -> void:
	if current_stage == null or current_selected_visual_cell == Vector2i(-1, -1):
		return
	var cur_vis = current_stage.get_cell_visual(current_selected_visual_cell)
	var cur_asset = str(cur_vis.get("asset", active_cell_asset))
	current_stage.set_cell_visual(current_selected_visual_cell, cur_asset, new_rot)
	stage_settings_changed.emit(current_stage)
	cell_visual_modified.emit(current_stage, current_selected_visual_cell, cur_asset, new_rot)

func _on_sel_cell_asset_changed(idx: int) -> void:
	if current_stage == null or current_selected_visual_cell == Vector2i(-1, -1):
		return
	var chosen_asset = str(sel_cell_asset_opt.get_item_metadata(idx)) if idx >= 0 else sel_cell_asset_opt.get_item_text(idx)
	var cur_vis = current_stage.get_cell_visual(current_selected_visual_cell)
	var cur_rot = float(cur_vis.get("rotation", active_cell_rot))
	current_stage.set_cell_visual(current_selected_visual_cell, chosen_asset, cur_rot)
	stage_settings_changed.emit(current_stage)
	cell_visual_modified.emit(current_stage, current_selected_visual_cell, chosen_asset, cur_rot)

func _on_sel_cell_remove_pressed() -> void:
	if current_stage == null or current_selected_visual_cell == Vector2i(-1, -1):
		return
	current_stage.remove_cell_visual(current_selected_visual_cell)
	sel_cell_box.visible = false
	current_selected_visual_cell = Vector2i(-1, -1)
	stage_settings_changed.emit(current_stage)
	_update_tile_status()

# =========================================================================
# BORDER VISUAL HANDLERS
# =========================================================================
func _select_border_asset(asset_key: String) -> void:
	active_border_asset = asset_key
	if active_border_opt != null and current_stage != null:
		for i in range(active_border_opt.item_count):
			if str(active_border_opt.get_item_metadata(i)) == asset_key:
				active_border_opt.select(i)
				break
	_update_border_visual_highlights()
	_update_border_status()
	border_visual_paint_selected.emit(active_border_asset, active_border_rot, active_border_offset, active_border_scale_x, active_border_scale_y)

func _on_active_border_opt_changed(idx: int) -> void:
	if active_border_opt == null:
		return
	var a_id = str(active_border_opt.get_item_metadata(idx)) if idx >= 0 else active_border_opt.get_item_text(idx)
	if not a_id.is_empty():
		_select_border_asset(a_id)

func _on_border_rot_changed(new_rot: float) -> void:
	active_border_rot = new_rot
	_update_border_rot_highlights()
	_update_border_status()
	border_visual_paint_selected.emit(active_border_asset, active_border_rot, active_border_offset, active_border_scale_x, active_border_scale_y)

func _select_border_rot(rot_deg: int) -> void:
	active_border_rot = float(rot_deg)
	if active_border_rot_spin != null:
		active_border_rot_spin.set_value_no_signal(active_border_rot)
	_update_border_rot_highlights()
	_update_border_status()
	border_visual_paint_selected.emit(active_border_asset, active_border_rot, active_border_offset, active_border_scale_x, active_border_scale_y)

func _on_border_offset_changed(new_offset: float) -> void:
	active_border_offset = new_offset
	_update_border_status()
	border_visual_paint_selected.emit(active_border_asset, active_border_rot, active_border_offset, active_border_scale_x, active_border_scale_y)

func _on_border_scale_x_changed(new_sx: float) -> void:
	active_border_scale_x = new_sx
	_update_border_status()
	border_visual_paint_selected.emit(active_border_asset, active_border_rot, active_border_offset, active_border_scale_x, active_border_scale_y)

func _on_border_scale_y_changed(new_sy: float) -> void:
	active_border_scale_y = new_sy
	_update_border_status()
	border_visual_paint_selected.emit(active_border_asset, active_border_rot, active_border_offset, active_border_scale_x, active_border_scale_y)

func _update_border_visual_highlights() -> void:
	for k in border_asset_buttons.keys():
		var btn: Button = border_asset_buttons[k]
		if is_instance_valid(btn):
			if k == active_border_asset:
				btn.modulate = Color(1.6, 1.5, 0.3)
			else:
				btn.modulate = Color(1.0, 1.0, 1.0)

func _update_border_rot_highlights() -> void:
	for r in border_rot_buttons.keys():
		var btn: Button = border_rot_buttons[r]
		if is_instance_valid(btn):
			if r == int(round(active_border_rot)):
				btn.modulate = Color(1.6, 1.5, 0.3)
			else:
				btn.modulate = Color(1.0, 1.0, 1.0)

func _update_border_status() -> void:
	if border_status_lbl == null:
		return
	var count := 0
	if current_stage != null:
		count = current_stage.get_border_visuals_count()
	border_status_lbl.text = "Active Border: %s (%.1f°, off: %.3f, sx: %.3f, sy: %.3f)\nPlaced Borders: %d\nClick outer perimeter to paint or edit." % [active_border_asset, active_border_rot, active_border_offset, active_border_scale_x, active_border_scale_y, count]

func _on_paint_border_pressed() -> void:
	border_visual_paint_selected.emit(active_border_asset, active_border_rot, active_border_offset, active_border_scale_x, active_border_scale_y)
	_update_border_status()

func _on_erase_border_pressed() -> void:
	border_erase_selected.emit()
	if border_status_lbl != null:
		var count := 0
		if current_stage != null:
			count = current_stage.get_border_visuals_count()
		border_status_lbl.text = "Erase Border Mode active!\nPlaced Borders: %d\nClick outer perimeter to remove." % count

func _on_clear_all_borders_pressed() -> void:
	if current_stage != null:
		current_stage.clear_all_border_visuals()
		stage_settings_changed.emit(current_stage)
		_update_border_status()

func inspect_border_visual(stage: LaserStageData, side: String, index: int, visual_data: Dictionary) -> void:
	current_selected_border_side = side
	current_selected_border_index = index
	if sel_border_box == null:
		return
	if visual_data.is_empty():
		sel_border_box.visible = false
		return
	_switch_tab(3)
	_switch_tiles_subtab(1)
	sel_border_box.visible = true
	sel_border_lbl.text = "Selected Border:\n%s Segment %d" % [side.capitalize(), index]
	var cur_asset = str(visual_data.get("asset", ""))
	var cur_rot = float(visual_data.get("rotation", 0.0))
	var cur_offset = float(visual_data.get("offset", 0.0))
	var cur_sx = float(visual_data.get("scale_x", visual_data.get("scale", 1.0)))
	var cur_sy = float(visual_data.get("scale_y", visual_data.get("scale", 1.0)))

	sel_border_asset_opt.clear()
	var selected_idx := 0
	if stage != null:
		stage.ensure_default_visual_libraries()
		for i in range(stage.border_assets.size()):
			var a = stage.border_assets[i]
			var aid: String = str(a.get("id", "border_%d" % (i + 1)))
			var aname: String = str(a.get("name", aid))
			sel_border_asset_opt.add_item(aname)
			var cur_idx = sel_border_asset_opt.item_count - 1
			sel_border_asset_opt.set_item_metadata(cur_idx, aid)
			if aid == cur_asset or aname == cur_asset or a.get("path", "") == cur_asset or (cur_asset.is_empty() and i == 0):
				selected_idx = cur_idx

	sel_border_asset_opt.select(selected_idx)
	sel_border_rot_spin.set_value_no_signal(cur_rot)
	if sel_border_offset_spin != null:
		sel_border_offset_spin.set_value_no_signal(cur_offset)
	if sel_border_scale_x_spin != null:
		sel_border_scale_x_spin.set_value_no_signal(cur_sx)
	if sel_border_scale_y_spin != null:
		sel_border_scale_y_spin.set_value_no_signal(cur_sy)

func _on_sel_border_rot_changed(new_rot: float) -> void:
	if current_stage == null or current_selected_border_side.is_empty() or current_selected_border_index < 0:
		return
	var cur_vis = current_stage.get_border_visual(current_selected_border_side, current_selected_border_index)
	var cur_asset = str(cur_vis.get("asset", active_border_asset))
	var cur_offset = float(cur_vis.get("offset", 0.0))
	var cur_sx = float(cur_vis.get("scale_x", active_border_scale_x))
	var cur_sy = float(cur_vis.get("scale_y", active_border_scale_y))
	current_stage.set_border_visual(current_selected_border_side, current_selected_border_index, cur_asset, new_rot, cur_offset, cur_sx, cur_sy)
	stage_settings_changed.emit(current_stage)
	border_visual_modified.emit(current_stage, current_selected_border_side, current_selected_border_index, cur_asset, new_rot, cur_offset, cur_sx, cur_sy)

func _on_sel_border_asset_changed(idx: int) -> void:
	if current_stage == null or current_selected_border_side.is_empty() or current_selected_border_index < 0:
		return
	var chosen_asset = str(sel_border_asset_opt.get_item_metadata(idx)) if idx >= 0 else sel_border_asset_opt.get_item_text(idx)
	var cur_vis = current_stage.get_border_visual(current_selected_border_side, current_selected_border_index)
	var cur_rot = float(cur_vis.get("rotation", active_border_rot))
	var cur_offset = float(cur_vis.get("offset", 0.0))
	var cur_sx = float(cur_vis.get("scale_x", active_border_scale_x))
	var cur_sy = float(cur_vis.get("scale_y", active_border_scale_y))
	current_stage.set_border_visual(current_selected_border_side, current_selected_border_index, chosen_asset, cur_rot, cur_offset, cur_sx, cur_sy)
	stage_settings_changed.emit(current_stage)
	border_visual_modified.emit(current_stage, current_selected_border_side, current_selected_border_index, chosen_asset, cur_rot, cur_offset, cur_sx, cur_sy)

func _on_sel_border_offset_changed(new_offset: float) -> void:
	if current_stage == null or current_selected_border_side.is_empty() or current_selected_border_index < 0:
		return
	var cur_vis = current_stage.get_border_visual(current_selected_border_side, current_selected_border_index)
	var cur_asset = str(cur_vis.get("asset", active_border_asset))
	var cur_rot = float(cur_vis.get("rotation", active_border_rot))
	var cur_sx = float(cur_vis.get("scale_x", active_border_scale_x))
	var cur_sy = float(cur_vis.get("scale_y", active_border_scale_y))
	current_stage.set_border_visual(current_selected_border_side, current_selected_border_index, cur_asset, cur_rot, new_offset, cur_sx, cur_sy)
	stage_settings_changed.emit(current_stage)
	border_visual_modified.emit(current_stage, current_selected_border_side, current_selected_border_index, cur_asset, cur_rot, new_offset, cur_sx, cur_sy)

func _on_sel_border_scale_x_changed(new_sx: float) -> void:
	if current_stage == null or current_selected_border_side.is_empty() or current_selected_border_index < 0:
		return
	var cur_vis = current_stage.get_border_visual(current_selected_border_side, current_selected_border_index)
	var cur_asset = str(cur_vis.get("asset", active_border_asset))
	var cur_rot = float(cur_vis.get("rotation", active_border_rot))
	var cur_offset = float(cur_vis.get("offset", 0.0))
	var cur_sy = float(cur_vis.get("scale_y", active_border_scale_y))
	current_stage.set_border_visual(current_selected_border_side, current_selected_border_index, cur_asset, cur_rot, cur_offset, new_sx, cur_sy)
	stage_settings_changed.emit(current_stage)
	border_visual_modified.emit(current_stage, current_selected_border_side, current_selected_border_index, cur_asset, cur_rot, cur_offset, new_sx, cur_sy)

func _on_sel_border_scale_y_changed(new_sy: float) -> void:
	if current_stage == null or current_selected_border_side.is_empty() or current_selected_border_index < 0:
		return
	var cur_vis = current_stage.get_border_visual(current_selected_border_side, current_selected_border_index)
	var cur_asset = str(cur_vis.get("asset", active_border_asset))
	var cur_rot = float(cur_vis.get("rotation", active_border_rot))
	var cur_offset = float(cur_vis.get("offset", 0.0))
	var cur_sx = float(cur_vis.get("scale_x", active_border_scale_x))
	current_stage.set_border_visual(current_selected_border_side, current_selected_border_index, cur_asset, cur_rot, cur_offset, cur_sx, new_sy)
	stage_settings_changed.emit(current_stage)
	border_visual_modified.emit(current_stage, current_selected_border_side, current_selected_border_index, cur_asset, cur_rot, cur_offset, cur_sx, new_sy)

func _on_sel_border_remove_pressed() -> void:
	if current_stage == null or current_selected_border_side.is_empty() or current_selected_border_index < 0:
		return
	current_stage.remove_border_visual(current_selected_border_side, current_selected_border_index)
	sel_border_box.visible = false
	current_selected_border_side = ""
	current_selected_border_index = -1
	stage_settings_changed.emit(current_stage)
	_update_border_status()

# =========================================================================
# CORNER VISUAL HANDLERS
# =========================================================================
func _select_corner_asset(asset_key: String) -> void:
	active_corner_asset = asset_key
	if active_corner_opt != null and current_stage != null:
		for i in range(active_corner_opt.item_count):
			if str(active_corner_opt.get_item_metadata(i)) == asset_key:
				active_corner_opt.select(i)
				break
	_update_corner_visual_highlights()
	_update_corner_status()
	corner_visual_paint_selected.emit(active_corner_asset, active_corner_rot, active_corner_mirror_x, active_corner_mirror_y, active_corner_offset, active_corner_scale_x, active_corner_scale_y)

func _on_active_corner_opt_changed(idx: int) -> void:
	if active_corner_opt == null:
		return
	var a_id = str(active_corner_opt.get_item_metadata(idx)) if idx >= 0 else active_corner_opt.get_item_text(idx)
	if not a_id.is_empty():
		_select_corner_asset(a_id)

func _on_corner_rot_changed(new_rot: float) -> void:
	active_corner_rot = new_rot
	_update_corner_rot_highlights()
	_update_corner_status()
	corner_visual_paint_selected.emit(active_corner_asset, active_corner_rot, active_corner_mirror_x, active_corner_mirror_y, active_corner_offset, active_corner_scale_x, active_corner_scale_y)

func _select_corner_rot(rot_deg: int) -> void:
	active_corner_rot = float(rot_deg)
	if active_corner_rot_spin != null:
		active_corner_rot_spin.set_value_no_signal(active_corner_rot)
	_update_corner_rot_highlights()
	_update_corner_status()
	corner_visual_paint_selected.emit(active_corner_asset, active_corner_rot, active_corner_mirror_x, active_corner_mirror_y, active_corner_offset, active_corner_scale_x, active_corner_scale_y)

func _on_corner_offset_changed(new_offset: float) -> void:
	active_corner_offset = new_offset
	_update_corner_status()
	corner_visual_paint_selected.emit(active_corner_asset, active_corner_rot, active_corner_mirror_x, active_corner_mirror_y, active_corner_offset, active_corner_scale_x, active_corner_scale_y)

func _on_corner_scale_x_changed(new_sx: float) -> void:
	active_corner_scale_x = new_sx
	_update_corner_status()
	corner_visual_paint_selected.emit(active_corner_asset, active_corner_rot, active_corner_mirror_x, active_corner_mirror_y, active_corner_offset, active_corner_scale_x, active_corner_scale_y)

func _on_corner_scale_y_changed(new_sy: float) -> void:
	active_corner_scale_y = new_sy
	_update_corner_status()
	corner_visual_paint_selected.emit(active_corner_asset, active_corner_rot, active_corner_mirror_x, active_corner_mirror_y, active_corner_offset, active_corner_scale_x, active_corner_scale_y)

func _on_corner_mirror_toggled(_t: bool) -> void:
	if active_corner_mx_chk != null:
		active_corner_mirror_x = active_corner_mx_chk.button_pressed
	if active_corner_my_chk != null:
		active_corner_mirror_y = active_corner_my_chk.button_pressed
	corner_visual_paint_selected.emit(active_corner_asset, active_corner_rot, active_corner_mirror_x, active_corner_mirror_y, active_corner_offset, active_corner_scale_x, active_corner_scale_y)

func _update_corner_visual_highlights() -> void:
	for k in corner_asset_buttons.keys():
		var btn: Button = corner_asset_buttons[k]
		if is_instance_valid(btn):
			if k == active_corner_asset:
				btn.modulate = Color(1.6, 1.5, 0.3)
			else:
				btn.modulate = Color(1.0, 1.0, 1.0)

func _update_corner_rot_highlights() -> void:
	for r in corner_rot_buttons.keys():
		var btn: Button = corner_rot_buttons[r]
		if is_instance_valid(btn):
			if r == int(round(active_corner_rot)):
				btn.modulate = Color(1.6, 1.5, 0.3)
			else:
				btn.modulate = Color(1.0, 1.0, 1.0)

func _update_corner_status() -> void:
	if corner_status_lbl == null:
		return
	var count := 0
	if current_stage != null:
		count = current_stage.get_corner_visuals_count()
	corner_status_lbl.text = "Active Corner: %s (%.1f°, off: %.3f, sx: %.3f, sy: %.3f)\nPlaced Corners: %d\nClick outer corner to paint or edit." % [active_corner_asset, active_corner_rot, active_corner_offset, active_corner_scale_x, active_corner_scale_y, count]

func _on_paint_corner_pressed() -> void:
	if active_corner_mx_chk != null:
		active_corner_mirror_x = active_corner_mx_chk.button_pressed
	if active_corner_my_chk != null:
		active_corner_mirror_y = active_corner_my_chk.button_pressed
	corner_visual_paint_selected.emit(active_corner_asset, active_corner_rot, active_corner_mirror_x, active_corner_mirror_y, active_corner_offset, active_corner_scale_x, active_corner_scale_y)
	_update_corner_status()

func _on_erase_corner_pressed() -> void:
	corner_erase_selected.emit()
	if corner_status_lbl != null:
		var count := 0
		if current_stage != null:
			count = current_stage.get_corner_visuals_count()
		corner_status_lbl.text = "Erase Corner Mode active!\nPlaced Corners: %d\nClick outer corner to remove." % count

func _on_clear_all_corners_pressed() -> void:
	if current_stage != null:
		current_stage.clear_all_corner_visuals()
		stage_settings_changed.emit(current_stage)
		_update_corner_status()

func inspect_corner_visual(stage: LaserStageData, corner: String, visual_data: Dictionary) -> void:
	current_selected_corner_name = corner
	if sel_corner_box == null:
		return
	if visual_data.is_empty():
		sel_corner_box.visible = false
		return
	_switch_tab(3)
	_switch_tiles_subtab(2)
	sel_corner_box.visible = true
	sel_corner_lbl.text = "Selected Corner:\n%s" % corner.replace("_", " ").capitalize()
	var cur_asset = str(visual_data.get("asset", ""))
	var cur_rot = float(visual_data.get("rotation", 0.0))
	var cur_mx = bool(visual_data.get("mirror_x", false))
	var cur_my = bool(visual_data.get("mirror_y", false))
	var cur_offset = float(visual_data.get("offset", 0.0))
	var cur_sx = float(visual_data.get("scale_x", visual_data.get("scale", 1.0)))
	var cur_sy = float(visual_data.get("scale_y", visual_data.get("scale", 1.0)))

	sel_corner_asset_opt.clear()
	var selected_idx := 0
	if stage != null:
		stage.ensure_default_visual_libraries()
		for i in range(stage.corner_assets.size()):
			var a = stage.corner_assets[i]
			var aid: String = str(a.get("id", "corner_%d" % (i + 1)))
			var aname: String = str(a.get("name", aid))
			sel_corner_asset_opt.add_item(aname)
			var cur_idx = sel_corner_asset_opt.item_count - 1
			sel_corner_asset_opt.set_item_metadata(cur_idx, aid)
			if aid == cur_asset or aname == cur_asset or a.get("path", "") == cur_asset or (cur_asset.is_empty() and i == 0):
				selected_idx = cur_idx

	sel_corner_asset_opt.select(selected_idx)
	sel_corner_rot_spin.set_value_no_signal(cur_rot)
	sel_corner_mx_chk.set_pressed_no_signal(cur_mx)
	sel_corner_my_chk.set_pressed_no_signal(cur_my)
	if sel_corner_offset_spin != null:
		sel_corner_offset_spin.set_value_no_signal(cur_offset)
	if sel_corner_scale_x_spin != null:
		sel_corner_scale_x_spin.set_value_no_signal(cur_sx)
	if sel_corner_scale_y_spin != null:
		sel_corner_scale_y_spin.set_value_no_signal(cur_sy)

func _on_sel_corner_rot_changed(new_rot: float) -> void:
	if current_stage == null or current_selected_corner_name.is_empty():
		return
	var cur_vis = current_stage.get_corner_visual(current_selected_corner_name)
	var cur_asset = str(cur_vis.get("asset", active_corner_asset))
	var cur_mx = bool(cur_vis.get("mirror_x", false))
	var cur_my = bool(cur_vis.get("mirror_y", false))
	var cur_offset = float(cur_vis.get("offset", 0.0))
	var cur_sx = float(cur_vis.get("scale_x", active_corner_scale_x))
	var cur_sy = float(cur_vis.get("scale_y", active_corner_scale_y))
	current_stage.set_corner_visual(current_selected_corner_name, cur_asset, new_rot, cur_mx, cur_my, cur_offset, cur_sx, cur_sy)
	stage_settings_changed.emit(current_stage)
	corner_visual_modified.emit(current_stage, current_selected_corner_name, cur_asset, new_rot, cur_mx, cur_my, cur_offset, cur_sx, cur_sy)

func _on_sel_corner_asset_changed(idx: int) -> void:
	if current_stage == null or current_selected_corner_name.is_empty():
		return
	var chosen_asset = str(sel_corner_asset_opt.get_item_metadata(idx)) if idx >= 0 else sel_corner_asset_opt.get_item_text(idx)
	var cur_vis = current_stage.get_corner_visual(current_selected_corner_name)
	var cur_rot = float(cur_vis.get("rotation", active_corner_rot))
	var cur_mx = bool(cur_vis.get("mirror_x", false))
	var cur_my = bool(cur_vis.get("mirror_y", false))
	var cur_offset = float(cur_vis.get("offset", 0.0))
	var cur_sx = float(cur_vis.get("scale_x", active_corner_scale_x))
	var cur_sy = float(cur_vis.get("scale_y", active_corner_scale_y))
	current_stage.set_corner_visual(current_selected_corner_name, chosen_asset, cur_rot, cur_mx, cur_my, cur_offset, cur_sx, cur_sy)
	stage_settings_changed.emit(current_stage)
	corner_visual_modified.emit(current_stage, current_selected_corner_name, chosen_asset, cur_rot, cur_mx, cur_my, cur_offset, cur_sx, cur_sy)

func _on_sel_corner_mirror_changed(_t: bool) -> void:
	if current_stage == null or current_selected_corner_name.is_empty():
		return
	var cur_vis = current_stage.get_corner_visual(current_selected_corner_name)
	var cur_asset = str(cur_vis.get("asset", active_corner_asset))
	var cur_rot = float(cur_vis.get("rotation", active_corner_rot))
	var mx = sel_corner_mx_chk.button_pressed if sel_corner_mx_chk != null else false
	var my = sel_corner_my_chk.button_pressed if sel_corner_my_chk != null else false
	var cur_offset = float(cur_vis.get("offset", 0.0))
	var cur_sx = float(cur_vis.get("scale_x", active_corner_scale_x))
	var cur_sy = float(cur_vis.get("scale_y", active_corner_scale_y))
	current_stage.set_corner_visual(current_selected_corner_name, cur_asset, cur_rot, mx, my, cur_offset, cur_sx, cur_sy)
	stage_settings_changed.emit(current_stage)
	corner_visual_modified.emit(current_stage, current_selected_corner_name, cur_asset, cur_rot, mx, my, cur_offset, cur_sx, cur_sy)

func _on_sel_corner_offset_changed(new_offset: float) -> void:
	if current_stage == null or current_selected_corner_name.is_empty():
		return
	var cur_vis = current_stage.get_corner_visual(current_selected_corner_name)
	var cur_asset = str(cur_vis.get("asset", active_corner_asset))
	var cur_rot = float(cur_vis.get("rotation", active_corner_rot))
	var cur_mx = bool(cur_vis.get("mirror_x", false))
	var cur_my = bool(cur_vis.get("mirror_y", false))
	var cur_sx = float(cur_vis.get("scale_x", active_corner_scale_x))
	var cur_sy = float(cur_vis.get("scale_y", active_corner_scale_y))
	current_stage.set_corner_visual(current_selected_corner_name, cur_asset, cur_rot, cur_mx, cur_my, new_offset, cur_sx, cur_sy)
	stage_settings_changed.emit(current_stage)
	corner_visual_modified.emit(current_stage, current_selected_corner_name, cur_asset, cur_rot, cur_mx, cur_my, new_offset, cur_sx, cur_sy)

func _on_sel_corner_scale_x_changed(new_sx: float) -> void:
	if current_stage == null or current_selected_corner_name.is_empty():
		return
	var cur_vis = current_stage.get_corner_visual(current_selected_corner_name)
	var cur_asset = str(cur_vis.get("asset", active_corner_asset))
	var cur_rot = float(cur_vis.get("rotation", active_corner_rot))
	var cur_mx = bool(cur_vis.get("mirror_x", false))
	var cur_my = bool(cur_vis.get("mirror_y", false))
	var cur_offset = float(cur_vis.get("offset", 0.0))
	var cur_sy = float(cur_vis.get("scale_y", active_corner_scale_y))
	current_stage.set_corner_visual(current_selected_corner_name, cur_asset, cur_rot, cur_mx, cur_my, cur_offset, new_sx, cur_sy)
	stage_settings_changed.emit(current_stage)
	corner_visual_modified.emit(current_stage, current_selected_corner_name, cur_asset, cur_rot, cur_mx, cur_my, cur_offset, new_sx, cur_sy)

func _on_sel_corner_scale_y_changed(new_sy: float) -> void:
	if current_stage == null or current_selected_corner_name.is_empty():
		return
	var cur_vis = current_stage.get_corner_visual(current_selected_corner_name)
	var cur_asset = str(cur_vis.get("asset", active_corner_asset))
	var cur_rot = float(cur_vis.get("rotation", active_corner_rot))
	var cur_mx = bool(cur_vis.get("mirror_x", false))
	var cur_my = bool(cur_vis.get("mirror_y", false))
	var cur_offset = float(cur_vis.get("offset", 0.0))
	var cur_sx = float(cur_vis.get("scale_x", active_corner_scale_x))
	current_stage.set_corner_visual(current_selected_corner_name, cur_asset, cur_rot, cur_mx, cur_my, cur_offset, cur_sx, new_sy)
	stage_settings_changed.emit(current_stage)
	corner_visual_modified.emit(current_stage, current_selected_corner_name, cur_asset, cur_rot, cur_mx, cur_my, cur_offset, cur_sx, new_sy)

func _on_sel_corner_remove_pressed() -> void:
	if current_stage == null or current_selected_corner_name.is_empty():
		return
	current_stage.remove_corner_visual(current_selected_corner_name)
	sel_corner_box.visible = false
	current_selected_corner_name = ""
	stage_settings_changed.emit(current_stage)
	_update_corner_status()

# =============================================================================
# HINT PANEL LOGIC & EVENT HANDLERS
# =============================================================================

func update_hint_display() -> void:
	if current_stage == null:
		if hint_points_lbl != null:
			hint_points_lbl.text = "Points: 0"
		if hint_start_lbl != null:
			hint_start_lbl.text = "Path Start: (none)"
		if hint_end_lbl != null:
			hint_end_lbl.text = "Path End: (none)"
		return

	if hint_enable_chk != null:
		hint_enable_chk.set_pressed_no_signal(current_stage.hint_enabled)
	if hint_color_btn != null:
		hint_color_btn.color = current_stage.hint_laser_color
	if hint_width_spin != null:
		hint_width_spin.set_value_no_signal(current_stage.hint_laser_width)
	if hint_opacity_spin != null:
		hint_opacity_spin.set_value_no_signal(current_stage.hint_laser_opacity)

	var pts: Array[Vector2i] = current_stage.hint_path_points
	if hint_points_lbl != null:
		hint_points_lbl.text = "Points: %d" % pts.size()
	if hint_start_lbl != null:
		if not pts.is_empty():
			hint_start_lbl.text = "Path Start: (%d, %d)" % [pts[0].x, pts[0].y]
		else:
			hint_start_lbl.text = "Path Start: (none)"
	if hint_end_lbl != null:
		if not pts.is_empty():
			hint_end_lbl.text = "Path End: (%d, %d)" % [pts[pts.size() - 1].x, pts[pts.size() - 1].y]
		else:
			hint_end_lbl.text = "Path End: (none)"

func _on_hint_enable_toggled(enabled: bool) -> void:
	if current_stage == null:
		return
	current_stage.hint_enabled = enabled
	hint_settings_changed.emit(current_stage)
	stage_settings_changed.emit(current_stage)

func _on_hint_color_changed(col: Color) -> void:
	if current_stage == null:
		return
	current_stage.hint_laser_color = col
	hint_settings_changed.emit(current_stage)
	stage_settings_changed.emit(current_stage)

func _on_hint_width_changed(val: float) -> void:
	if current_stage == null:
		return
	current_stage.hint_laser_width = val
	hint_settings_changed.emit(current_stage)
	stage_settings_changed.emit(current_stage)

func _on_hint_opacity_changed(val: float) -> void:
	if current_stage == null:
		return
	current_stage.hint_laser_opacity = val
	hint_settings_changed.emit(current_stage)
	stage_settings_changed.emit(current_stage)

func _on_hint_draw_pressed() -> void:
	# Mode 11 = ToolMode.HINT_DRAW
	hint_tool_mode_requested.emit(11)

func _on_hint_erase_pressed() -> void:
	# Mode 12 = ToolMode.HINT_ERASE
	hint_tool_mode_requested.emit(12)

func _on_hint_clear_pressed() -> void:
	if current_stage == null:
		return
	current_stage.clear_hint_path()
	update_hint_display()
	hint_settings_changed.emit(current_stage)
	stage_settings_changed.emit(current_stage)


