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
	if obj_section != null:
		obj_section.visible = (idx == 0)
	if stage_section != null:
		stage_section.visible = (idx == 1)
	if lvl_section != null:
		lvl_section.visible = (idx == 2)

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
