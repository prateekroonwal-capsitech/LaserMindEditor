@tool
extends Control
class_name LaserMindEditorMain

var current_level: LaserLevelData = null
var current_stage_idx: int = 1
var undo_manager: LevelEditorUndoManager = LevelEditorUndoManager.new()

var top_bar: PanelContainer
var stage_tabs: StageTabs
var grid_canvas: GridCanvas
var object_palette: ObjectPalette
var inspector_panel: InspectorPanel
var bottom_panel: BottomPanel
var level_browser: LevelBrowser
var playtest_dialog: PlaytestDialog

var level_title_lbl: Label
var undo_btn: Button
var redo_btn: Button
var open_btn: MenuButton
var open_file_dialog: FileDialog
var save_btn: Button
var play_game_btn: Button
var sim_dialog_btn: Button
var autosave_timer: Timer

var copied_objects: Array[LaserObjectData] = []

func _init() -> void:
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_setup_ui()
	_setup_shortcuts()
	_load_default_level()

func _setup_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 2)
	add_child(root_vbox)

	top_bar = PanelContainer.new()
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var tb_hbox := HBoxContainer.new()
	tb_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_hbox.add_theme_constant_override("separation", 6)
	top_bar.add_child(tb_hbox)

	var app_logo := Label.new()
	app_logo.text = "⚡ LASER MIND"
	app_logo.add_theme_font_size_override("font_size", 14)
	app_logo.modulate = Color(1.0, 0.9, 0.3)
	tb_hbox.add_child(app_logo)

	level_title_lbl = Label.new()
	level_title_lbl.text = "Level 01"
	level_title_lbl.add_theme_font_size_override("font_size", 13)
	tb_hbox.add_child(level_title_lbl)

	tb_hbox.add_child(VSeparator.new())

	open_btn = MenuButton.new()
	open_btn.text = "📂 Open"
	open_btn.tooltip_text = "Open & Edit Level [Ctrl+O]"
	open_btn.custom_minimum_size = Vector2(0, 32)
	open_btn.add_theme_font_size_override("font_size", 12)
	var open_popup := open_btn.get_popup()
	open_popup.about_to_popup.connect(_populate_open_menu)
	open_popup.id_pressed.connect(_on_open_menu_item_selected)
	tb_hbox.add_child(open_btn)

	save_btn = Button.new()
	save_btn.text = "💾 Save"
	save_btn.tooltip_text = "Save Level (.tres) [Ctrl+S]"
	save_btn.custom_minimum_size = Vector2(0, 32)
	save_btn.add_theme_font_size_override("font_size", 12)
	save_btn.pressed.connect(_on_save_pressed)
	tb_hbox.add_child(save_btn)

	var exp_btn := Button.new()
	exp_btn.text = "📤 JSON"
	exp_btn.tooltip_text = "Export Level to JSON"
	exp_btn.custom_minimum_size = Vector2(0, 32)
	exp_btn.add_theme_font_size_override("font_size", 12)
	exp_btn.pressed.connect(_on_export_json_pressed)
	tb_hbox.add_child(exp_btn)

	tb_hbox.add_child(VSeparator.new())

	undo_btn = Button.new()
	undo_btn.text = "↶ Undo"
	undo_btn.tooltip_text = "Undo [Ctrl+Z]"
	undo_btn.custom_minimum_size = Vector2(0, 32)
	undo_btn.add_theme_font_size_override("font_size", 12)
	undo_btn.pressed.connect(_on_undo_pressed)
	tb_hbox.add_child(undo_btn)

	redo_btn = Button.new()
	redo_btn.text = "↷ Redo"
	redo_btn.tooltip_text = "Redo [Ctrl+Y]"
	redo_btn.custom_minimum_size = Vector2(0, 32)
	redo_btn.add_theme_font_size_override("font_size", 12)
	redo_btn.pressed.connect(_on_redo_pressed)
	tb_hbox.add_child(redo_btn)

	tb_hbox.add_child(VSeparator.new())

	var fit_btn := Button.new()
	fit_btn.text = "🔍 Fit"
	fit_btn.tooltip_text = "Fit Grid to View (F)"
	fit_btn.custom_minimum_size = Vector2(0, 32)
	fit_btn.add_theme_font_size_override("font_size", 12)
	fit_btn.pressed.connect(func(): grid_canvas.zoom_to_fit())
	tb_hbox.add_child(fit_btn)

	var grid_toggle_btn := Button.new()
	grid_toggle_btn.text = "# Grid"
	grid_toggle_btn.tooltip_text = "Toggle Grid Coordinates (G)"
	grid_toggle_btn.custom_minimum_size = Vector2(0, 32)
	grid_toggle_btn.add_theme_font_size_override("font_size", 12)
	grid_toggle_btn.pressed.connect(func():
		grid_canvas.show_grid_coords = not grid_canvas.show_grid_coords
		grid_canvas.queue_redraw()
	)
	tb_hbox.add_child(grid_toggle_btn)

	var laser_toggle_btn := Button.new()
	laser_toggle_btn.text = "🔴 Laser"
	laser_toggle_btn.tooltip_text = "Toggle Laser Simulation Preview (L)"
	laser_toggle_btn.custom_minimum_size = Vector2(0, 32)
	laser_toggle_btn.add_theme_font_size_override("font_size", 12)
	laser_toggle_btn.pressed.connect(func():
		grid_canvas.show_laser_preview = not grid_canvas.show_laser_preview
		grid_canvas.recalculate_simulation()
	)
	tb_hbox.add_child(laser_toggle_btn)

	var sbs_toggle_btn := Button.new()
	sbs_toggle_btn.text = "🔲 Side-by-Side"
	sbs_toggle_btn.tooltip_text = "Toggle Side-by-Side (All Stages) / Single Stage View"
	sbs_toggle_btn.custom_minimum_size = Vector2(0, 32)
	sbs_toggle_btn.add_theme_font_size_override("font_size", 12)
	sbs_toggle_btn.pressed.connect(func():
		grid_canvas.set_side_by_side(not grid_canvas.is_side_by_side)
		sbs_toggle_btn.text = "🔲 Side-by-Side" if grid_canvas.is_side_by_side else "▫ Single Stage"
	)
	tb_hbox.add_child(sbs_toggle_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_hbox.add_child(spacer)

	sim_dialog_btn = Button.new()
	sim_dialog_btn.text = "🧪 Sim Dialog"
	sim_dialog_btn.tooltip_text = "Open Lightweight In-Editor Mock Simulation Dialog"
	sim_dialog_btn.custom_minimum_size = Vector2(0, 32)
	sim_dialog_btn.add_theme_font_size_override("font_size", 12)
	sim_dialog_btn.pressed.connect(_on_sim_dialog_pressed)
	tb_hbox.add_child(sim_dialog_btn)

	play_game_btn = Button.new()
	play_game_btn.text = "▶ PLAY GAME (P)"
	play_game_btn.tooltip_text = "Auto-save & Launch Real Game Scene (P)"
	play_game_btn.modulate = Color(0.35, 1.3, 0.45)
	play_game_btn.custom_minimum_size = Vector2(0, 32)
	play_game_btn.add_theme_font_size_override("font_size", 13)
	play_game_btn.pressed.connect(_on_play_real_game_pressed)
	tb_hbox.add_child(play_game_btn)

	root_vbox.add_child(top_bar)

	stage_tabs = StageTabs.new()
	stage_tabs.stage_selected.connect(_on_stage_tab_selected)
	stage_tabs.stage_added.connect(_on_stage_added)
	stage_tabs.stage_removed.connect(_on_stage_removed)
	stage_tabs.stage_pasted.connect(_on_stage_pasted)
	stage_tabs.stage_cleared.connect(_on_stage_cleared)
	root_vbox.add_child(stage_tabs)

	var outer_hsplit := HSplitContainer.new()
	outer_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_hsplit.split_offset = 220
	root_vbox.add_child(outer_hsplit)

	var left_tabs := TabContainer.new()
	left_tabs.custom_minimum_size = Vector2(210, 0)
	left_tabs.size_flags_horizontal = Control.SIZE_FILL
	left_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	object_palette = ObjectPalette.new()
	object_palette.name = "Palette"
	object_palette.tool_changed.connect(_on_palette_tool_changed)
	object_palette.palette_item_selected.connect(_on_palette_item_selected)
	object_palette.custom_element_selected.connect(_on_custom_element_selected)
	left_tabs.add_child(object_palette)

	level_browser = LevelBrowser.new()
	level_browser.name = "Browser"
	level_browser.level_opened.connect(_on_level_opened)
	level_browser.level_created.connect(_on_level_created)
	level_browser.level_duplicated.connect(_on_level_duplicated)
	level_browser.level_deleted.connect(_on_level_deleted)
	level_browser.batch_validation_requested.connect(_on_batch_validate)
	level_browser.batch_solvability_requested.connect(_on_batch_solvability)
	level_browser.export_all_json_requested.connect(_on_export_all_json)
	left_tabs.add_child(level_browser)
	outer_hsplit.add_child(left_tabs)

	var inner_hsplit := HSplitContainer.new()
	inner_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_hsplit.split_offset = 750
	outer_hsplit.add_child(inner_hsplit)

	var center_vsplit := VSplitContainer.new()
	center_vsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_vsplit.split_offset = 450
	inner_hsplit.add_child(center_vsplit)

	grid_canvas = GridCanvas.new()
	grid_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_canvas.object_selected.connect(_on_canvas_object_selected)
	grid_canvas.object_modified.connect(_on_canvas_object_modified)
	grid_canvas.stage_dirty_needed.connect(_on_stage_content_changed)
	grid_canvas.stage_activated.connect(_on_canvas_stage_activated)
	grid_canvas.cell_visual_selected.connect(_on_cell_visual_selected)
	grid_canvas.border_visual_selected.connect(_on_border_visual_selected)
	grid_canvas.corner_visual_selected.connect(_on_corner_visual_selected)
	grid_canvas.undo_manager = undo_manager
	center_vsplit.add_child(grid_canvas)

	bottom_panel = BottomPanel.new()
	bottom_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_panel.size_flags_vertical = Control.SIZE_FILL
	bottom_panel.error_item_clicked.connect(_on_error_item_focused)
	bottom_panel.request_run_solvability.connect(_on_run_solvability_requested)
	center_vsplit.add_child(bottom_panel)

	inspector_panel = InspectorPanel.new()
	inspector_panel.custom_minimum_size = Vector2(240, 0)
	inspector_panel.size_flags_horizontal = Control.SIZE_FILL
	inspector_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_panel.object_changed.connect(_on_inspector_object_changed)
	inspector_panel.stage_settings_changed.connect(_on_stage_settings_changed)
	inspector_panel.tile_paint_selected.connect(_on_board_tile_selected)
	inspector_panel.tile_tool_mode_requested.connect(_on_board_tile_tool_mode_requested)
	inspector_panel.cell_visual_paint_selected.connect(_on_cell_visual_paint_selected)
	inspector_panel.cell_visual_modified.connect(_on_cell_visual_modified)
	inspector_panel.border_visual_paint_selected.connect(_on_border_visual_paint_selected)
	inspector_panel.border_erase_selected.connect(_on_border_erase_selected)
	inspector_panel.border_visual_modified.connect(_on_border_visual_modified)
	inspector_panel.corner_visual_paint_selected.connect(_on_corner_visual_paint_selected)
	inspector_panel.corner_erase_selected.connect(_on_corner_erase_selected)
	inspector_panel.corner_visual_modified.connect(_on_corner_visual_modified)
	inspector_panel.level_settings_changed.connect(_on_level_settings_changed)
	inspector_panel.request_delete_selected.connect(_delete_selected_objects)
	inspector_panel.request_duplicate_selected.connect(_duplicate_selected_objects)
	inspector_panel.custom_name_renamed.connect(func(_idx: int, _new_name: String):
		object_palette.reload_custom_elements()
	)
	inspector_panel.request_snap_stage_position.connect(_on_snap_stage_position_requested)
	inner_hsplit.add_child(inspector_panel)

	object_palette.custom_elements_updated.connect(func(_elems: Array[Dictionary]):
		inspector_panel.rebuild_type_dropdown()
	)

	playtest_dialog = PlaytestDialog.new()
	add_child(playtest_dialog)

	undo_manager.dirty_state_changed.connect(_on_dirty_state_changed)
	undo_manager.history_changed.connect(_update_undo_redo_buttons)

	autosave_timer = Timer.new()
	autosave_timer.wait_time = 60.0
	autosave_timer.autostart = true
	autosave_timer.timeout.connect(_on_autosave)
	add_child(autosave_timer)

	open_file_dialog = FileDialog.new()
	open_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_file_dialog.access = FileDialog.ACCESS_RESOURCES
	open_file_dialog.current_dir = LevelMigration.get_levels_dir()
	open_file_dialog.filters = PackedStringArray(["*.tres ; Laser Level Resource", "*.json ; Laser Level JSON"])
	open_file_dialog.file_selected.connect(_on_level_file_selected)
	add_child(open_file_dialog)

func _setup_shortcuts() -> void:
	pass

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey

		if k.is_command_or_control_pressed():
			match k.keycode:
				KEY_Z:
					if k.shift_pressed:
						_on_redo_pressed()
					else:
						_on_undo_pressed()
					get_viewport().set_input_as_handled()
				KEY_Y:
					_on_redo_pressed()
					get_viewport().set_input_as_handled()
				KEY_S:
					_on_save_pressed()
					get_viewport().set_input_as_handled()
				KEY_O:
					_open_file_picker()
					get_viewport().set_input_as_handled()
				KEY_C:
					_copy_selected_objects()
					get_viewport().set_input_as_handled()
				KEY_V:
					_paste_objects()
					get_viewport().set_input_as_handled()
				KEY_D:
					_duplicate_selected_objects()
					get_viewport().set_input_as_handled()
		else:
			match k.keycode:
				KEY_V:
					object_palette.select_tool(GridCanvas.ToolMode.SELECT)
				KEY_B:
					object_palette.select_tool(GridCanvas.ToolMode.PAINT)
				KEY_E:
					object_palette.select_tool(GridCanvas.ToolMode.ERASE)
				KEY_R:
					object_palette.select_tool(GridCanvas.ToolMode.ROTATE)
				KEY_F:
					grid_canvas.zoom_to_fit()
				KEY_G:
					grid_canvas.show_grid_coords = not grid_canvas.show_grid_coords
					grid_canvas.queue_redraw()
				KEY_L:
					grid_canvas.show_laser_preview = not grid_canvas.show_laser_preview
					grid_canvas.recalculate_simulation()
				KEY_P:
					_on_play_real_game_pressed()
				KEY_DELETE, KEY_BACKSPACE:
					_delete_selected_objects()

func _load_default_level() -> void:
	var lvl = LevelMigration.load_laser_level(1)
	if lvl == null:
		lvl = LaserLevelData.new()
		lvl.level_id = 1
		lvl.level_number = 1
		lvl.ensure_three_stages()
	set_level(lvl)

func set_level(lvl: LaserLevelData) -> void:
	current_level = lvl
	current_level.ensure_three_stages()
	current_stage_idx = 1
	undo_manager.clear()

	if stage_tabs != null:
		stage_tabs.set_level(current_level)
	if inspector_panel != null:
		inspector_panel.set_level(current_level)
	if grid_canvas != null:
		grid_canvas.set_level(current_level, 1)
		grid_canvas.zoom_to_fit()
	_activate_stage(1, false)
	_update_title()
	_run_analysis_and_validation()
	if level_browser != null:
		level_browser.refresh_list()

func _activate_stage(stage_idx: int, refit_view: bool = true) -> void:
	current_stage_idx = stage_idx
	if current_level == null:
		return
	var st = current_level.get_stage(stage_idx)
	if grid_canvas != null:
		grid_canvas.set_active_stage(stage_idx)
		if refit_view:
			if grid_canvas.is_side_by_side:
				grid_canvas.focus_stage(stage_idx)
			else:
				grid_canvas.zoom_to_fit()
	if inspector_panel != null:
		inspector_panel.set_stage(st)
	_run_analysis_and_validation()

func _on_canvas_stage_activated(idx: int) -> void:
	if current_stage_idx == idx:
		return
	current_stage_idx = idx
	if stage_tabs != null:
		stage_tabs.active_stage_idx = idx
		stage_tabs._update_tabs()
	if current_level != null:
		var st = current_level.get_stage(idx)
		if inspector_panel != null:
			inspector_panel.set_stage(st)
	_run_analysis_and_validation()

func _update_title() -> void:
	if level_title_lbl == null or current_level == null:
		return
	var dirty_mark = " *" if undo_manager.is_dirty() else ""
	level_title_lbl.text = "%s (ID: %d)%s" % [current_level.level_name, current_level.level_id, dirty_mark]

func _run_analysis_and_validation() -> void:
	if current_level == null or bottom_panel == null:
		return
	var val_res := LevelValidator.validate_level(current_level)
	bottom_panel.update_validation(val_res)

	var cur_st = current_level.get_stage(current_stage_idx)
	var diff_res := DifficultyAnalyzer.analyze_stage(cur_st)
	bottom_panel.update_difficulty(diff_res)

	var solv_res := SolvabilityChecker.check_stage_solvability(cur_st, 300)
	bottom_panel.update_solvability(solv_res)

	bottom_panel.update_quality(current_level, val_res["is_valid"], solv_res["status"] == SolvabilityChecker.Status.SOLVABLE)

func _on_stage_tab_selected(idx: int) -> void:
	_activate_stage(idx, true)

func _on_stage_added(new_idx: int) -> void:
	if grid_canvas != null and current_level != null:
		grid_canvas.set_level(current_level, new_idx)
		grid_canvas.zoom_to_fit()
	_activate_stage(new_idx, false)
	_on_stage_content_changed()

func _on_stage_removed(new_active_idx: int) -> void:
	if grid_canvas != null and current_level != null:
		grid_canvas.set_level(current_level, new_active_idx)
		grid_canvas.zoom_to_fit()
	_activate_stage(new_active_idx, false)
	_on_stage_content_changed()

func _on_palette_tool_changed(mode: GridCanvas.ToolMode) -> void:
	grid_canvas.current_tool = mode

func _on_palette_item_selected(type: LaserObjectData.ObjectType, rot: int, col: Color) -> void:
	grid_canvas.active_palette_type = type
	grid_canvas.active_palette_rot = rot
	grid_canvas.active_palette_color = col

func _on_custom_element_selected(custom_data: Dictionary) -> void:
	grid_canvas.active_palette_custom_data = custom_data

func _on_canvas_object_selected(obj: LaserObjectData) -> void:
	inspector_panel.set_selected_object(obj)

func _on_canvas_object_modified(obj: LaserObjectData) -> void:
	inspector_panel.set_selected_object(obj)
	_on_stage_content_changed()

func _on_stage_content_changed() -> void:
	if grid_canvas != null:
		grid_canvas.recalculate_simulation()
		grid_canvas.queue_redraw()
	_update_title()
	_run_analysis_and_validation()

func _on_stage_cleared(idx: int, before_snap: LaserStageData = null) -> void:
	var cur_st = current_level.get_stage(idx) if current_level != null else null
	if undo_manager != null and before_snap != null and cur_st != null:
		undo_manager.commit_snapshot(before_snap, cur_st)
	if grid_canvas != null:
		grid_canvas.selected_objects.clear()
		grid_canvas.selection_changed.emit(grid_canvas.selected_objects)
		grid_canvas.recalculate_simulation()
		grid_canvas.queue_redraw()
	if inspector_panel != null:
		inspector_panel.set_selected_object(null)
	_on_stage_content_changed()

func _on_stage_pasted(idx: int, before_snap: LaserStageData = null) -> void:
	var cur_st = current_level.get_stage(idx) if current_level != null else null
	if undo_manager != null and before_snap != null and cur_st != null:
		undo_manager.commit_snapshot(before_snap, cur_st)
	if grid_canvas != null:
		grid_canvas.selected_objects.clear()
		grid_canvas.selection_changed.emit(grid_canvas.selected_objects)
		grid_canvas.recalculate_simulation()
		grid_canvas.queue_redraw()
	if inspector_panel != null:
		inspector_panel.set_selected_object(null)
	_on_stage_content_changed()

func _on_inspector_object_changed(obj: LaserObjectData) -> void:
	grid_canvas.recalculate_simulation()
	grid_canvas.queue_redraw()
	_on_stage_content_changed()

func _on_stage_settings_changed(st: LaserStageData) -> void:
	grid_canvas.recalculate_simulation()
	grid_canvas.zoom_to_fit()
	grid_canvas.queue_redraw()
	if stage_tabs != null:
		stage_tabs._update_flow_text()
	_on_stage_content_changed()

func _on_board_tile_selected(tile_coord: Vector2i) -> void:
	if grid_canvas != null:
		grid_canvas.active_tile_coord = tile_coord
		grid_canvas.active_tile_type = clampi(tile_coord.x, 0, 2) as BoardVisualGenerator.TileType
		grid_canvas.active_tile_rot = tile_coord.y
		grid_canvas.current_tool = GridCanvas.ToolMode.TILE_PAINT
		grid_canvas.queue_redraw()

func _on_board_tile_tool_mode_requested(mode: int) -> void:
	if grid_canvas != null:
		grid_canvas.current_tool = mode as GridCanvas.ToolMode
		grid_canvas.queue_redraw()

func _on_cell_visual_selected(stage: LaserStageData, cell: Vector2i, visual_data: Dictionary) -> void:
	if inspector_panel != null:
		inspector_panel.inspect_cell_visual(stage, cell, visual_data)

func _on_cell_visual_paint_selected(asset: String, rot_deg: float) -> void:
	if grid_canvas != null:
		grid_canvas.active_cell_asset = asset
		grid_canvas.active_tile_rot_float = rot_deg
		grid_canvas.current_tool = GridCanvas.ToolMode.TILE_PAINT
		grid_canvas.queue_redraw()

func _on_cell_visual_modified(stage: LaserStageData, cell: Vector2i, asset: String, rot_deg: float) -> void:
	if grid_canvas != null:
		grid_canvas.queue_redraw()
	_on_stage_content_changed()

func _on_border_visual_selected(stage: LaserStageData, side: String, index: int, visual_data: Dictionary) -> void:
	if inspector_panel != null:
		inspector_panel.inspect_border_visual(stage, side, index, visual_data)

func _on_border_visual_paint_selected(asset: String, rot_deg: float, offset: float = 0.0, scale_x: float = 1.0, scale_y: float = 1.0) -> void:
	if grid_canvas != null:
		grid_canvas.active_border_asset = asset
		grid_canvas.active_border_rot = rot_deg
		grid_canvas.active_border_offset = offset
		grid_canvas.active_border_scale_x = scale_x
		grid_canvas.active_border_scale_y = scale_y
		grid_canvas.current_tool = GridCanvas.ToolMode.BORDER_PAINT
		grid_canvas.queue_redraw()

func _on_border_erase_selected() -> void:
	if grid_canvas != null:
		grid_canvas.current_tool = GridCanvas.ToolMode.BORDER_ERASE
		grid_canvas.queue_redraw()

func _on_border_visual_modified(_stage: LaserStageData, _side: String, _index: int, _asset: String, _rot_deg: float, _offset: float = 0.0, _scale_x: float = 1.0, _scale_y: float = 1.0) -> void:
	if grid_canvas != null:
		grid_canvas.queue_redraw()
	_on_stage_content_changed()

func _on_corner_visual_selected(stage: LaserStageData, corner: String, visual_data: Dictionary) -> void:
	if inspector_panel != null:
		inspector_panel.inspect_corner_visual(stage, corner, visual_data)

func _on_corner_visual_paint_selected(asset: String, rot_deg: float, mx: bool, my: bool, offset: float = 0.0, scale_x: float = 1.0, scale_y: float = 1.0) -> void:
	if grid_canvas != null:
		grid_canvas.active_corner_asset = asset
		grid_canvas.active_corner_rot = rot_deg
		grid_canvas.active_corner_mirror_x = mx
		grid_canvas.active_corner_mirror_y = my
		grid_canvas.active_corner_offset = offset
		grid_canvas.active_corner_scale_x = scale_x
		grid_canvas.active_corner_scale_y = scale_y
		grid_canvas.current_tool = GridCanvas.ToolMode.CORNER_PAINT
		grid_canvas.queue_redraw()

func _on_corner_erase_selected() -> void:
	if grid_canvas != null:
		grid_canvas.current_tool = GridCanvas.ToolMode.CORNER_ERASE
		grid_canvas.queue_redraw()

func _on_corner_visual_modified(_stage: LaserStageData, _corner: String, _asset: String, _rot_deg: float, _mx: bool, _my: bool, _offset: float = 0.0, _scale_x: float = 1.0, _scale_y: float = 1.0) -> void:
	if grid_canvas != null:
		grid_canvas.queue_redraw()
	_on_stage_content_changed()

func _on_level_settings_changed(lvl: LaserLevelData) -> void:
	_on_stage_content_changed()

func _on_error_item_focused(stage_idx: int, cell: Vector2i, obj_id: String) -> void:
	if stage_idx > 0 and stage_idx != current_stage_idx:
		stage_tabs.select_stage(stage_idx)

	var st = current_level.get_stage(current_stage_idx)
	var target_obj: LaserObjectData = null
	if not obj_id.is_empty():
		target_obj = st.get_object_by_id(obj_id)
	elif cell != Vector2i(-1, -1):
		target_obj = st.get_object_at(cell)

	if target_obj != null:
		grid_canvas.selected_objects = [target_obj]
		grid_canvas.selection_changed.emit(grid_canvas.selected_objects)
		inspector_panel.set_selected_object(target_obj)

	if cell != Vector2i(-1, -1):
		var cell_screen = grid_canvas.stage_cell_to_screen(current_stage_idx, cell)
		grid_canvas.pan_offset += (grid_canvas.size * 0.5 - cell_screen)
		grid_canvas.queue_redraw()

func _on_run_solvability_requested() -> void:
	var st = current_level.get_stage(current_stage_idx)
	var solv_res := SolvabilityChecker.check_stage_solvability(st, 2000)
	bottom_panel.update_solvability(solv_res)

func _on_sim_dialog_pressed() -> void:
	if current_level != null:
		playtest_dialog.start_playtest(current_level)

func _on_play_real_game_pressed() -> void:
	if current_level == null:
		return

	if object_palette != null and not object_palette.custom_elements.is_empty():
		CustomElementsManager.save_elements(object_palette.custom_elements)
	var save_err = LevelMigration.save_laser_level_tres(current_level)
	if save_err == OK:
		undo_manager.mark_saved()
		_update_title()
		level_browser.refresh_list()
		print("Laser Mind: Auto-saved Level %d before launching playtest." % current_level.level_id)
	else:
		push_warning("Laser Mind: Failed to auto-save level before playtest!")

	var session_data: Dictionary = {
		"playtest_active": true,
		"level_id": current_level.level_id,
		"stage_idx": current_stage_idx,
		"timestamp": Time.get_unix_time_from_system()
	}
	var file = FileAccess.open("user://laser_mind_playtest.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(session_data, "\t"))
		file.close()

	var target_scene := _get_playtest_scene_path()
	if not target_scene.is_empty() and ResourceLoader.exists(target_scene) and Engine.is_editor_hint() and EditorInterface != null:
		_sync_gameplay_tscn_level_number(current_level.level_id)
		EditorInterface.play_custom_scene(target_scene)
	else:
		playtest_dialog.start_playtest(current_level)

func _on_save_pressed() -> void:
	if current_level == null:
		return
	if object_palette != null and not object_palette.custom_elements.is_empty():
		CustomElementsManager.save_elements(object_palette.custom_elements)
	var err = LevelMigration.save_laser_level_tres(current_level)
	if err == OK:
		undo_manager.mark_saved()
		_update_title()
		level_browser.refresh_list()
		_sync_gameplay_tscn_level_number(current_level.level_id)
		print("Laser Mind: Level %d saved successfully (.tres)." % current_level.level_id)
		if is_inside_tree() and save_btn != null:
			var prev_txt = save_btn.text
			save_btn.text = "✅ Saved!"
			get_tree().create_timer(1.2).timeout.connect(func():
				if is_instance_valid(save_btn):
					save_btn.text = prev_txt
			)
	else:
		push_error("Laser Mind: Failed to save Level %d (Error code: %d)" % [current_level.level_id, err])

func _on_export_json_pressed() -> void:
	if current_level == null:
		return
	var err = LevelMigration.export_laser_level_json(current_level)
	if err == OK:
		print("Laser Mind: Level %d exported successfully (.json)." % current_level.level_id)

func _on_autosave() -> void:
	if undo_manager.is_dirty() and current_level != null:
		LevelMigration.save_laser_level_tres(current_level)
		undo_manager.mark_saved()
		_update_title()

func _on_dirty_state_changed(_is_dirty: bool) -> void:
	_update_title()

func _update_undo_redo_buttons() -> void:
	undo_btn.disabled = not undo_manager.can_undo()
	redo_btn.disabled = not undo_manager.can_redo()

func _on_undo_pressed() -> void:
	var target_stage_idx = current_stage_idx
	if undo_manager != null and undo_manager.has_method("peek_undo_stage_idx"):
		target_stage_idx = undo_manager.peek_undo_stage_idx()
	var cur_st = current_level.get_stage(target_stage_idx)
	if undo_manager.undo(cur_st):
		if target_stage_idx != current_stage_idx:
			_activate_stage(target_stage_idx, false)
			if stage_tabs != null:
				stage_tabs.active_stage_idx = target_stage_idx
				stage_tabs._update_tabs()
		grid_canvas.selected_objects.clear()
		inspector_panel.set_selected_object(null)
		grid_canvas.recalculate_simulation()
		grid_canvas.queue_redraw()
		_on_stage_content_changed()

func _on_redo_pressed() -> void:
	var target_stage_idx = current_stage_idx
	if undo_manager != null and undo_manager.has_method("peek_redo_stage_idx"):
		target_stage_idx = undo_manager.peek_redo_stage_idx()
	var cur_st = current_level.get_stage(target_stage_idx)
	if undo_manager.redo(cur_st):
		if target_stage_idx != current_stage_idx:
			_activate_stage(target_stage_idx, false)
			if stage_tabs != null:
				stage_tabs.active_stage_idx = target_stage_idx
				stage_tabs._update_tabs()
		grid_canvas.selected_objects.clear()
		inspector_panel.set_selected_object(null)
		grid_canvas.recalculate_simulation()
		grid_canvas.queue_redraw()
		_on_stage_content_changed()

func _delete_selected_objects() -> void:
	var cur_st = current_level.get_stage(current_stage_idx)
	if cur_st == null or grid_canvas.selected_objects.is_empty():
		return
	var snap = cur_st.duplicate_data()
	for obj in grid_canvas.selected_objects:
		cur_st.remove_object(obj)
	grid_canvas.selected_objects.clear()
	grid_canvas.selection_changed.emit(grid_canvas.selected_objects)
	inspector_panel.set_selected_object(null)
	grid_canvas.recalculate_simulation()
	grid_canvas.queue_redraw()
	undo_manager.commit_snapshot(snap, cur_st)
	_on_stage_content_changed()

func _duplicate_selected_objects() -> void:
	var cur_st = current_level.get_stage(current_stage_idx)
	if cur_st == null or grid_canvas.selected_objects.is_empty():
		return
	var snap = cur_st.duplicate_data()
	var new_selected: Array[LaserObjectData] = []
	for obj in grid_canvas.selected_objects:
		var clone = obj.duplicate_data()
		clone.id = clone.generate_new_id()
		clone.grid_pos += Vector2i(1, 1)
		if cur_st.is_inside_grid(clone.grid_pos):
			cur_st.add_object(clone)
			new_selected.append(clone)
	if not new_selected.is_empty():
		grid_canvas.selected_objects = new_selected
		grid_canvas.selection_changed.emit(new_selected)
		inspector_panel.set_selected_object(new_selected[0])
		grid_canvas.recalculate_simulation()
		grid_canvas.queue_redraw()
		undo_manager.commit_snapshot(snap, cur_st)
		_on_stage_content_changed()

func _copy_selected_objects() -> void:
	copied_objects.clear()
	for obj in grid_canvas.selected_objects:
		copied_objects.append(obj.duplicate_data())

func _paste_objects() -> void:
	var cur_st = current_level.get_stage(current_stage_idx)
	if cur_st == null or copied_objects.is_empty():
		return
	var snap = cur_st.duplicate_data()
	var new_selected: Array[LaserObjectData] = []
	for obj in copied_objects:
		var clone = obj.duplicate_data()
		clone.id = clone.generate_new_id()
		clone.grid_pos += Vector2i(1, 1)
		if cur_st.is_inside_grid(clone.grid_pos):
			cur_st.add_object(clone)
			new_selected.append(clone)
	if not new_selected.is_empty():
		grid_canvas.selected_objects = new_selected
		grid_canvas.selection_changed.emit(new_selected)
		inspector_panel.set_selected_object(new_selected[0])
		grid_canvas.recalculate_simulation()
		grid_canvas.queue_redraw()
		undo_manager.commit_snapshot(snap, cur_st)
		_on_stage_content_changed()

func _on_level_opened(id: int) -> void:
	if undo_manager.is_dirty() and current_level != null:
		LevelMigration.save_laser_level_tres(current_level)
		print("Laser Mind: Auto-saved Level %d before opening Level %d" % [current_level.level_id, id])
	var lvl = LevelMigration.load_laser_level(id)
	if lvl != null:
		set_level(lvl)
		_sync_gameplay_tscn_level_number(id)
		print("Laser Mind: Opened Level %d successfully." % id)
	else:
		push_error("Laser Mind: Failed to load Level %d" % id)

func _populate_open_menu() -> void:
	if open_btn == null:
		return
	var popup := open_btn.get_popup()
	popup.clear()
	var ids := LevelMigration.get_all_level_ids()
	for id in ids:
		var title := "Level %02d" % id
		popup.add_item(title, id)
	if not ids.is_empty():
		popup.add_separator()
	popup.add_item("📁 Browse File (.tres / .json)...", 99999)

func _on_open_menu_item_selected(id: int) -> void:
	if id == 99999:
		_open_file_picker()
	else:
		_on_level_opened(id)

func _open_file_picker() -> void:
	if open_file_dialog != null:
		open_file_dialog.current_dir = LevelMigration.get_levels_dir()
		open_file_dialog.popup_centered_ratio(0.7)

func _on_level_file_selected(path: String) -> void:
	if undo_manager.is_dirty() and current_level != null:
		LevelMigration.save_laser_level_tres(current_level)
		print("Laser Mind: Auto-saved Level %d before opening file %s" % [current_level.level_id, path])
	var lvl := LevelMigration.load_level_from_path(path)
	if lvl != null:
		set_level(lvl)
		_sync_gameplay_tscn_level_number(lvl.level_id)
		print("Laser Mind: Opened level %s" % path)
	else:
		push_error("Laser Mind: Could not load level from %s" % path)

func _on_level_created(new_lvl: LaserLevelData) -> void:
	set_level(new_lvl)
	_on_save_pressed()

func _on_level_duplicated(old_id: int, new_id: int) -> void:
	var src = LevelMigration.load_laser_level(old_id)
	if src != null:
		var clone = src.duplicate_data()
		clone.level_id = new_id
		clone.level_number = new_id
		clone.level_name = "Level %02d" % new_id
		LevelMigration.save_laser_level_tres(clone)
		set_level(clone)
		_sync_gameplay_tscn_level_number(new_id)

func _on_level_deleted(id: int) -> void:
	var path_tres = LevelMigration.LASER_TRES_PATTERN % id
	if FileAccess.file_exists(path_tres):
		DirAccess.remove_absolute(path_tres)
	var path_json = LevelMigration.LASER_JSON_PATTERN % id
	if FileAccess.file_exists(path_json):
		DirAccess.remove_absolute(path_json)
	if current_level != null and current_level.level_id == id:
		var all_ids = LevelMigration.get_all_level_ids()
		if not all_ids.is_empty():
			_on_level_opened(all_ids[0])
		else:
			_load_default_level()

func _on_batch_validate() -> void:
	var ids = LevelMigration.get_all_level_ids()
	var valid_count = 0
	for id in ids:
		var lvl = LevelMigration.load_laser_level(id)
		if lvl != null:
			var res = LevelValidator.validate_level(lvl)
			if res["is_valid"]:
				valid_count += 1
	print("Batch Validation: %d / %d levels valid." % [valid_count, ids.size()])

func _on_batch_solvability() -> void:
	var ids = LevelMigration.get_all_level_ids()
	print("Batch Solvability Check started for %d levels." % ids.size())

func _on_export_all_json() -> void:
	var ids = LevelMigration.get_all_level_ids()
	for id in ids:
		var lvl = LevelMigration.load_laser_level(id)
		if lvl != null:
			LevelMigration.export_laser_level_json(lvl)
	print("Exported %d levels to JSON." % ids.size())

func _on_snap_stage_position_requested() -> void:
	if grid_canvas == null or inspector_panel == null:
		return
	if current_level == null:
		return

	var stage_idx := grid_canvas.current_stage_idx
	var r := grid_canvas.get_stage_rect_in_cells(stage_idx)
	var cell_sz := grid_canvas.cell_size * grid_canvas.zoom_level

	var origin := grid_canvas.pan_offset + Vector2(r.position) * (grid_canvas.cell_size * grid_canvas.zoom_level)

	inspector_panel.snap_stage_position_from_canvas(origin)
	print("📌 Stage %d position snapped to (%.0f, %.0f)" % [stage_idx, origin.x, origin.y])

func _get_playtest_scene_path() -> String:
	if ProjectSettings.has_setting("laser_editor/paths/gameplay_scene_path"):
		var p: String = ProjectSettings.get_setting("laser_editor/paths/gameplay_scene_path")
		if ResourceLoader.exists(p) or FileAccess.file_exists(ProjectSettings.globalize_path(p)):
			return p
	if ResourceLoader.exists("res://Game/GamePlay.tscn") or FileAccess.file_exists(ProjectSettings.globalize_path("res://Game/GamePlay.tscn")):
		return "res://Game/GamePlay.tscn"
	return ""

func _sync_gameplay_tscn_level_number(level_id: int) -> void:
	var tscn_path := _get_playtest_scene_path()
	if tscn_path.is_empty():
		return
	var abs_path := ProjectSettings.globalize_path(tscn_path)

	if not FileAccess.file_exists(abs_path):
		return

	var file_r := FileAccess.open(abs_path, FileAccess.READ)
	if file_r == null:
		return
	var content := file_r.get_as_text()
	file_r.close()

	var regex := RegEx.new()
	regex.compile("level_number\\s*=\\s*\\d+")
	var new_line := "level_number = %d" % level_id

	var new_content: String
	if regex.search(content) != null:
		new_content = regex.sub(content, new_line)
	else:
		if content.contains("script = ExtResource"):
			new_content = content.replace(
				"script = ExtResource",
				"level_number = %d\nscript = ExtResource" % level_id
			)
		else:
			return

	if new_content == content:
		return

	var file_w := FileAccess.open(abs_path, FileAccess.WRITE)
	if file_w == null:
		return
	file_w.store_string(new_content)
	file_w.close()

	if Engine.is_editor_hint() and is_instance_valid(EditorInterface):
		EditorInterface.get_resource_filesystem().scan()

	print("✅ Playtest scene level_number updated to Level %d" % level_id)
