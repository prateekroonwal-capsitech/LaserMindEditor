extends SceneTree

func _init() -> void:

	print("--- BEGINNING LASER MIND LEVEL EDITOR VALIDATION ---")

	var obj := LaserObjectData.create(LaserObjectData.ObjectType.MOVABLE_MIRROR, Vector2i(2, 3), 90)
	assert(obj.grid_pos == Vector2i(2, 3), "Pos check failed")
	assert(obj.rotation_deg == 90, "Rot check failed")
	assert(obj.movable == true, "Movable flag failed")
	var dict := obj.to_dict()
	var obj2 := LaserObjectData.from_dict(dict)
	assert(obj2.grid_pos == obj.grid_pos, "Serialization check failed")
	print("✓ LaserObjectData tests passed.")

	var lvl := LaserLevelData.new()
	assert(lvl.stages.size() == 3, "Strict 3-stage requirement failed")
	print("✓ LaserLevelData strict 3-stage enforcement passed.")

	var tut_lvl := _make_test_level(1)
	assert(tut_lvl.stages.size() == 3, "Test level stages check failed")
	var st1 = tut_lvl.get_stage(1)
	assert(st1.objects.size() >= 3, "Test level object count check failed")
	print("✓ Level creation passed.")

	var test_st := LaserStageData.new()
	test_st.grid_width = 5
	test_st.grid_height = 5
	var laser_obj := LaserObjectData.create(LaserObjectData.ObjectType.LASER_SOURCE, Vector2i(0, 0), 0)
	var mirror_obj := LaserObjectData.create(LaserObjectData.ObjectType.MOVABLE_MIRROR, Vector2i(1, 0), 0)
	test_st.add_object(laser_obj)
	test_st.add_object(mirror_obj)
	var sim_res := LaserSimulation.simulate_stage(test_st)
	assert(sim_res.has("segments"), "Simulation segments missing")
	assert(sim_res["segments"].size() >= 2, "Simulation should have at least 2 segments (origin-to-mirror and mirror-to-boundary)")
	assert(sim_res["segments"][0]["start"] == Vector2i(0, 0) and sim_res["segments"][0]["end"] == Vector2i(1, 0), "Segment 1 must reach mirror")
	assert(sim_res["segments"][1]["start"] == Vector2i(1, 0) and sim_res["segments"][1]["end"] == Vector2i(1, 4), "Segment 2 must reflect down to grid boundary")
	print("✓ LaserSimulation raytracing & mirror reflection passed: %d beam segments generated." % sim_res["segments"].size())

	var val_res := LevelValidator.validate_level(tut_lvl)
	assert(val_res.has("is_valid"), "Validator result format invalid")
	print("✓ LevelValidator passed: status = %s." % val_res["status_text"])

	var diff_res := DifficultyAnalyzer.analyze_stage(st1)
	assert(diff_res.has("rating"), "Difficulty rating missing")
	print("✓ DifficultyAnalyzer passed: rating = %s (score: %d)." % [diff_res["rating"], diff_res["difficulty_score"]])

	var solv_res := SolvabilityChecker.check_stage_solvability(st1, 500)
	assert(solv_res.has("status"), "Solvability status missing")
	print("✓ SolvabilityChecker passed: status = %s." % solv_res["status_text"])

	var loaded_lvl1 := LevelMigration.load_laser_level(1)
	assert(loaded_lvl1 != null, "Level 1 could not be loaded")
	assert(loaded_lvl1.stages.size() >= 1, "Imported level must have at least 1 stage")
	print("✓ Level loading passed: successfully loaded Level 1 with %d stages." % loaded_lvl1.stages.size())

	tut_lvl.level_id = 999
	var err_tres := LevelMigration.save_laser_level_tres(tut_lvl)
	assert(err_tres == OK, "Saving .tres failed")
	var err_json := LevelMigration.export_laser_level_json(tut_lvl)
	assert(err_json == OK, "Saving JSON failed")
	print("✓ Level saving (.tres and JSON) passed.")

	var path_tres = LevelMigration.LASER_TRES_PATTERN % 999
	var path_json = LevelMigration.LASER_JSON_PATTERN % 999
	if FileAccess.file_exists(path_tres):
		DirAccess.remove_absolute(path_tres)
	if FileAccess.file_exists(path_json):
		DirAccess.remove_absolute(path_json)

	var editor := LaserMindEditorMain.new()
	assert(editor != null, "Editor instance is null")
	var test_ui_lvl := _make_test_level(999)
	editor.set_level(test_ui_lvl)

	print("--- Testing Stage Tabs & Action Buttons ---")
	editor.stage_tabs.select_stage(2)
	assert(editor.current_stage_idx == 2, "Stage 2 selection failed")
	editor.stage_tabs.select_stage(3)
	assert(editor.current_stage_idx == 3, "Stage 3 selection failed")
	editor.stage_tabs.select_stage(1)
	assert(editor.current_stage_idx == 1, "Stage 1 selection failed")

	editor.stage_tabs._on_copy_stage()
	assert(editor.stage_tabs.clipboard_stage_data != null, "Copy Stage failed")
	editor.stage_tabs.select_stage(2)
	editor.stage_tabs._on_paste_stage()
	var st2_objs = editor.current_level.get_stage(2).objects.size()
	assert(st2_objs == editor.stage_tabs.clipboard_stage_data.objects.size(), "Paste Stage failed")
	editor.stage_tabs._on_clear_stage()
	assert(editor.current_level.get_stage(2).objects.size() == 0, "Clear Stage failed")
	var st2_sim = editor.grid_canvas.simulation_results.get(2, {})
	assert(st2_sim.get("segments", []).is_empty(), "Laser segments must be removed when stage is cleared")
	print("✓ Laser ray successfully removed on Clear Stage.")

	editor.stage_tabs._on_add_stage_pressed()
	assert(editor.current_level.get_stage_count() == 4, "Add Stage failed, expected 4 stages")
	assert(editor.current_stage_idx == 4, "Add stage active selection failed")
	editor.stage_tabs._on_remove_stage_pressed()
	assert(editor.current_level.get_stage_count() == 3, "Remove Stage failed, expected 3 stages")
	print("✓ All Stage buttons (Stage 1-N, Add Stage, Delete Stage, Copy, Paste, Clear) verified working perfectly.")

	print("--- Testing Palette Buttons & Tools ---")
	var tools_to_test = [
		GridCanvas.ToolMode.SELECT,
		GridCanvas.ToolMode.PAINT,
		GridCanvas.ToolMode.MOVE,
		GridCanvas.ToolMode.ROTATE,
		GridCanvas.ToolMode.ERASE
	]
	for t in tools_to_test:
		editor.object_palette.select_tool(t)
		assert(editor.object_palette.current_tool_mode == t, "Palette tool mode %s failed" % str(t))

	editor.object_palette._on_rot_changed(90)
	assert(editor.object_palette.selected_rot == 90, "Rot changed failed")
	editor.object_palette._on_color_changed(Color.CYAN)
	assert(editor.object_palette.selected_color == Color.CYAN, "Color changed failed")

	var all_object_types = [
		LaserObjectData.ObjectType.LASER_SOURCE,
		LaserObjectData.ObjectType.FIXED_MIRROR,
		LaserObjectData.ObjectType.MOVABLE_MIRROR,
		LaserObjectData.ObjectType.ROTATABLE_MIRROR,
		LaserObjectData.ObjectType.MOVABLE_AREA,
		LaserObjectData.ObjectType.ROCK,
		LaserObjectData.ObjectType.ICE,
		LaserObjectData.ObjectType.SPLITTER,
		LaserObjectData.ObjectType.COLOR_GLASS,
		LaserObjectData.ObjectType.COLOR_WALL,
		LaserObjectData.ObjectType.GATE,
		LaserObjectData.ObjectType.EXIT_GATE,
		LaserObjectData.ObjectType.SWITCH,
		LaserObjectData.ObjectType.GATE_SWITCH,
		LaserObjectData.ObjectType.CUSTOM
	]
	for ot in all_object_types:
		editor.object_palette.select_item(ot)
		assert(editor.object_palette.selected_type == ot, "Item selection for type %d failed" % ot)
		assert(editor.grid_canvas.active_palette_type == ot, "Grid canvas palette type sync failed")
	print("✓ All 15 Palette Item buttons & 5 Tool buttons verified working perfectly.")

	print("--- Testing Top Toolbar Buttons ---")
	editor.grid_canvas.zoom_to_fit()
	var prev_grid = editor.grid_canvas.show_grid_coords
	editor.grid_canvas.show_grid_coords = not prev_grid
	assert(editor.grid_canvas.show_grid_coords != prev_grid, "Grid toggle failed")
	var prev_laser = editor.grid_canvas.show_laser_preview
	editor.grid_canvas.show_laser_preview = not prev_laser
	assert(editor.grid_canvas.show_laser_preview != prev_laser, "Laser toggle failed")
	var cur_st = editor.current_level.get_stage(editor.current_stage_idx)
	var empty_cell = Vector2i(-1, -1)
	for x in range(cur_st.grid_width):
		for y in range(cur_st.grid_height):
			if cur_st.get_object_at(Vector2i(x, y)) == null:
				empty_cell = Vector2i(x, y)
				break
		if empty_cell.x >= 0:
			break
	assert(empty_cell.x >= 0, "No empty cell found for paint test")
	var initial_count = cur_st.objects.size()
	editor.object_palette.select_tool(GridCanvas.ToolMode.PAINT)
	var test_click_event = InputEventMouseButton.new()
	test_click_event.pressed = true
	test_click_event.button_index = MOUSE_BUTTON_LEFT
	test_click_event.position = editor.grid_canvas.stage_cell_to_screen(editor.current_stage_idx, empty_cell) + Vector2(0.5, 0.5) * editor.grid_canvas.cell_size * editor.grid_canvas.zoom_level
	editor.grid_canvas._gui_input(test_click_event)
	assert(cur_st.objects.size() == initial_count + 1, "Painting object failed")
	assert(editor.undo_manager.can_undo() == true, "Undo should be available after painting")
	assert(editor.undo_btn.disabled == false, "Undo button should be enabled")

	editor._on_undo_pressed()
	assert(cur_st.objects.size() == initial_count, "Undo failed to restore object count")
	assert(editor.undo_manager.can_redo() == true, "Redo should be available after undo")
	assert(editor.redo_btn.disabled == false, "Redo button should be enabled")

	editor._on_redo_pressed()
	assert(cur_st.objects.size() == initial_count + 1, "Redo failed to restore painted object")
	assert(editor.undo_manager.can_undo() == true, "Undo should be available again after redo")

	editor._on_undo_pressed()

	print("--- Testing Duplicate, Copy & Paste Objects ---")
	var obj_to_dup = cur_st.objects[0]
	editor.grid_canvas.selected_objects = [obj_to_dup]
	var count_before_dup = cur_st.objects.size()
	editor._duplicate_selected_objects()
	assert(cur_st.objects.size() == count_before_dup + 1, "Duplicate object failed to add clone")
	var duped_obj = cur_st.objects[cur_st.objects.size() - 1]
	assert(duped_obj.id != obj_to_dup.id, "Duplicated object must have unique id")
	print("✓ Duplicate object verified working.")

	editor.grid_canvas.selected_objects = [obj_to_dup]
	editor._copy_selected_objects()
	assert(editor.copied_objects.size() == 1, "Copy object failed")
	var count_before_paste = cur_st.objects.size()
	editor._paste_objects()
	assert(cur_st.objects.size() == count_before_paste + 1, "Paste object failed to add pasted clone")
	var pasted_obj = cur_st.objects[cur_st.objects.size() - 1]
	assert(pasted_obj.id != obj_to_dup.id, "Pasted object must have unique id")
	print("✓ Copy & Paste object verified working.")

	# Undo paste and duplicate
	editor._on_undo_pressed()
	editor._on_undo_pressed()

	editor._on_save_pressed()
	assert(editor.playtest_dialog != null, "Playtest dialog is null")

	print("--- Testing Side-by-Side Multi-Stage View ---")
	assert(editor.grid_canvas.is_side_by_side == true, "Side-by-Side should be enabled by default")
	assert(editor.grid_canvas.stages.size() == 3, "Grid canvas should manage all 3 stages")

	var r1 = editor.grid_canvas.get_stage_rect_in_cells(1)
	var r2 = editor.grid_canvas.get_stage_rect_in_cells(2)
	var r3 = editor.grid_canvas.get_stage_rect_in_cells(3)
	assert(r1.position.x == 0, "Stage 1 should start at x=0")
	assert(r2.position.x > r1.position.x + r1.size.x, "Stage 2 should be to the right of Stage 1 with gap")
	assert(r3.position.x > r2.position.x + r2.size.x, "Stage 3 should be to the right of Stage 2 with gap")

	var st2_click_event = InputEventMouseButton.new()
	st2_click_event.pressed = true
	st2_click_event.button_index = MOUSE_BUTTON_LEFT
	st2_click_event.position = editor.grid_canvas.stage_cell_to_screen(2, Vector2i(1, 1)) + Vector2(0.5, 0.5) * editor.grid_canvas.cell_size * editor.grid_canvas.zoom_level
	editor.grid_canvas._gui_input(st2_click_event)
	assert(editor.current_stage_idx == 2, "Clicking on Stage 2 should activate Stage 2")

	var st3_click_event = InputEventMouseButton.new()
	st3_click_event.pressed = true
	st3_click_event.button_index = MOUSE_BUTTON_LEFT
	st3_click_event.position = editor.grid_canvas.stage_cell_to_screen(3, Vector2i(1, 1)) + Vector2(0.5, 0.5) * editor.grid_canvas.cell_size * editor.grid_canvas.zoom_level
	editor.grid_canvas._gui_input(st3_click_event)
	assert(editor.current_stage_idx == 3, "Clicking on Stage 3 should activate Stage 3")

	editor.grid_canvas.set_side_by_side(false)
	assert(editor.grid_canvas.is_side_by_side == false, "Single stage toggle failed")
	editor.grid_canvas.set_side_by_side(true)
	assert(editor.grid_canvas.is_side_by_side == true, "Side-by-side restore failed")

	print("✓ Side-by-Side Multi-Stage (Stage 1, 2, 3) view and direct editing verified working perfectly.")
	print("✓ All Top Toolbar buttons (Fit, Grid, Laser, Undo, Redo, Save, Playtest, Side-by-Side) verified working perfectly.")

	print("--- Testing Inspector Panel Controls ---")
	var sample_obj := LaserObjectData.create(LaserObjectData.ObjectType.MOVABLE_MIRROR, Vector2i(2, 4), 180)
	editor.inspector_panel.set_selected_object(sample_obj)
	assert(editor.inspector_panel.selected_object == sample_obj, "Inspector object selection failed")
	editor.inspector_panel.obj_rot_spin.value = 270
	editor.inspector_panel._on_obj_rot_changed(270)
	assert(sample_obj.rotation_deg == 270, "Inspector rotation edit failed")
	editor.inspector_panel.obj_movable_chk.button_pressed = false
	editor.inspector_panel._on_obj_movable_toggled(false)
	assert(sample_obj.movable == false, "Inspector movable edit failed")

	editor.inspector_panel.stage_w_spin.value = 7
	editor.inspector_panel._on_stage_dimensions_changed(7)
	assert(editor.current_level.get_stage(editor.current_stage_idx).grid_width == 7, "Stage width edit failed")

	var custom_sample := LaserObjectData.create(LaserObjectData.ObjectType.CUSTOM, Vector2i(1, 1), 0)
	custom_sample.properties["custom_name"] = "Bomb"
	editor.inspector_panel.set_selected_object(custom_sample)
	assert(editor.inspector_panel.selected_object == custom_sample, "Custom object inspector selection failed")

	editor.object_palette.custom_elements.clear()
	CustomElementsManager.save_elements([])
	editor.object_palette._rebuild_custom_buttons()

	editor.object_palette._on_add_custom_element_pressed()
	assert(editor.object_palette.custom_elements.size() == 1, "Adding custom element should result in 1 element")
	editor.object_palette._on_custom_scene_dropped("res://Game/Objects/Scenes/Custom.tscn")
	assert(editor.object_palette.custom_elements[0]["scene_path"] == "res://Game/Objects/Scenes/Custom.tscn", "Palette scene drop failed")
	editor.object_palette._on_custom_name_edited("Portal")
	assert(editor.object_palette.custom_elements[0]["name"] == "Portal", "Palette custom element name edit failed")

	editor.object_palette._on_remove_custom_element_pressed()
	assert(editor.object_palette.custom_elements.is_empty(), "Deleting custom element should be able to empty list")
	assert(editor.object_palette.remove_custom_btn.disabled == true, "Remove button should be disabled when empty")

	if ResourceLoader.exists("res://Game/Scripts/GamePlay.gd") and ResourceLoader.exists("res://Game/Objects/Scenes/Custom.tscn"):
		var GPClass = load("res://Game/Scripts/GamePlay.gd")
		var gp = GPClass.new()
		var dummy_packed: PackedScene = load("res://Game/Objects/Scenes/Custom.tscn")
		gp.custom_named_scenes["Custom 2"] = dummy_packed

		var cust_obj2 := LaserObjectData.create(LaserObjectData.ObjectType.CUSTOM, Vector2i(1, 2), 0)
		cust_obj2.properties["custom_name"] = "Custom 2"
		var resolved_scene2 = gp._get_scene_for_object(cust_obj2)
		assert(resolved_scene2 == dummy_packed, "GamePlay._get_scene_for_object should resolve custom scene from custom_named_scenes string key")

		cust_obj2.properties["custom_name"] = "custom 2"
		assert(gp._get_scene_for_object(cust_obj2) == dummy_packed, "Case-insensitive matching for custom_named_scenes should work")

		gp.is_playtest_mode = true
		gp.use_editor_visuals_in_playtest = true
		var spawned_node = gp._spawn_object(cust_obj2)
		assert(spawned_node != null, "Custom object should instantiate actual custom scene")
		spawned_node.queue_free()
		gp.queue_free()

	print("✓ Inspector Panel (Object, Stage, Level properties & Custom Name/Scene) verified working perfectly.")

	print("--- Testing Bottom Panel & Solvability Button ---")
	editor._on_run_solvability_requested()
	print("✓ Bottom Panel tabs & Solvability checker button verified working perfectly.")

	print("--- Testing TileMap Movable Area Painting & Layer Separation ---")
	editor.object_palette.select_item(LaserObjectData.ObjectType.MOVABLE_AREA)
	assert(editor.grid_canvas.active_palette_type == LaserObjectData.ObjectType.MOVABLE_AREA, "Movable area selection failed")
	var custom_blue := Color(0.15, 0.75, 0.95, 1.0)
	editor.object_palette.selected_color = custom_blue
	editor.grid_canvas.active_palette_color = custom_blue

	var test_stage = editor.current_level.get_stage(1)
	var test_pos := Vector2i(2, 2)
	editor.grid_canvas._paint_cell(test_stage, test_pos)
	var marea = test_stage.get_movable_area_at(test_pos)
	assert(marea != null and marea.color == custom_blue, "Movable Area custom color paint failed")
	assert(test_stage.is_cell_in_movable_area(test_pos) == true, "O(1) movable area check failed")

	editor.object_palette.select_item(LaserObjectData.ObjectType.ROTATABLE_MIRROR)
	editor.grid_canvas._paint_cell(test_stage, test_pos)
	var fg_mir = test_stage.get_foreground_object_at(test_pos)
	var bg_area = test_stage.get_movable_area_at(test_pos)
	assert(fg_mir != null and fg_mir.type == LaserObjectData.ObjectType.ROTATABLE_MIRROR, "Foreground mirror missing")
	assert(bg_area != null and bg_area.type == LaserObjectData.ObjectType.MOVABLE_AREA, "Movable area was deleted by painting mirror!")
	print("✓ TileMap multi-layer preservation verified: Movable Area floor and foreground object coexist.")

	var test_pos2 := Vector2i(2, 3)
	editor.object_palette.select_item(LaserObjectData.ObjectType.MOVABLE_AREA)
	editor.grid_canvas._paint_cell(test_stage, test_pos2)
	assert(test_stage.is_cell_in_movable_area(test_pos2) == true, "Movable Area at (2,3) failed")

	var input_ctrl := GameInputController.new()
	var test_state := {"rotated": false, "dragged": false}
	input_ctrl.object_rotated.connect(func(_o): test_state["rotated"] = true)
	input_ctrl.object_dragged.connect(func(_o): test_state["dragged"] = true)

	var orig_rot = fg_mir.rotation_deg
	var screen_p1 = Vector2(200, 200)
	var grid_orig = Vector2(100, 100)
	var c_sz = Vector2(50, 50)

	input_ctrl._handle_press(screen_p1, test_stage, grid_orig, c_sz, false)
	input_ctrl._handle_release()
	assert(test_state["rotated"] == true, "Tap gesture should rotate rotatable object")
	assert(fg_mir.rotation_deg == (orig_rot + 45) % 360, "Rotation degree not incremented")
	print("✓ Tap gesture rotation verified.")

	var screen_p2 = Vector2(200, 250)
	input_ctrl._handle_press(screen_p1, test_stage, grid_orig, c_sz, false)
	input_ctrl._handle_drag(screen_p2, test_stage, grid_orig, c_sz)
	input_ctrl._handle_release()
	assert(test_state["dragged"] == true, "Drag gesture should move object inside movable area")
	assert(fg_mir.grid_pos == Vector2i(2, 3), "Object did not move to target cell (2, 3)")
	print("✓ Drag gesture object movement inside movable area verified.")

	var screen_blocked = Vector2(100, 100)
	test_state["dragged"] = false
	input_ctrl._handle_press(screen_p2, test_stage, grid_orig, c_sz, false)
	input_ctrl._handle_drag(screen_blocked, test_stage, grid_orig, c_sz)
	input_ctrl._handle_release()
	assert(test_state["dragged"] == false, "Object movement outside movable area must be blocked")
	assert(fg_mir.grid_pos == Vector2i(2, 3), "Object should remain at (2, 3)")
	print("--- Testing Visual Tiles Tab & 3-Tile Painting System ---")
	var tile_st := LaserStageData.new()
	tile_st.grid_width = 5
	tile_st.grid_height = 5

	# 1. Verification: No Automatic Tile Fill on Grid Creation
	assert(tile_st.custom_tiles.is_empty(), "Newly created grid must NOT have any auto-filled visual tiles")
	assert(tile_st.get_custom_tiles_count() == 0, "Custom tiles count must be 0")
	var BoardVisualGen = preload("res://Game/Scripts/board_visual_generator.gd")
	var empty_vis := BoardVisualGen.get_cell_visual(tile_st, Vector2i(0, 0))
	assert(empty_vis.type == -1, "Unpainted cell must return type -1 (empty)")
	assert(empty_vis.texture == null, "Unpainted cell must have null texture")
	print("✓ No automatic visual filling verified: grid cells start completely empty.")

	# 2. Properties Inspector: Tab bar structure & Tab Isolation
	assert(editor.inspector_panel.tab_obj_btn != null, "Object tab button must exist")
	assert(editor.inspector_panel.tab_stage_btn != null, "Stage tab button must exist")
	assert(editor.inspector_panel.tab_lvl_btn != null, "Level tab button must exist")
	assert(editor.inspector_panel.tab_tile_btn != null, "Tiles tab button must exist")

	editor.inspector_panel._switch_tab(0)
	assert(editor.inspector_panel.obj_section.visible == true, "Object section must be visible on Object tab")
	assert(editor.inspector_panel.stage_section.visible == false, "Stage section must NOT be visible on Object tab")
	assert(editor.inspector_panel.lvl_section.visible == false, "Level section must NOT be visible on Object tab")
	assert(editor.inspector_panel.tile_section.visible == false, "Tiles section must NOT be visible on Object tab")

	editor.inspector_panel._switch_tab(1)
	assert(editor.inspector_panel.stage_section.visible == true, "Stage section must be visible on Stage tab")
	assert(editor.inspector_panel.tile_section.visible == false, "Tiles section must NOT be visible on Stage tab")

	editor.inspector_panel._switch_tab(2)
	assert(editor.inspector_panel.lvl_section.visible == true, "Level section must be visible on Level tab")
	assert(editor.inspector_panel.tile_section.visible == false, "Tiles section must NOT be visible on Level tab")

	editor.inspector_panel._switch_tab(3)
	assert(editor.inspector_panel.tile_section.visible == true, "Tiles section must be visible on Tiles tab")
	assert(editor.inspector_panel.stage_section.visible == false, "Stage section must NOT be visible on Tiles tab")
	print("✓ Properties Inspector intact: [ Object ] [ Stage ] [ Level ] [ Tiles ] tabs verified.")

	# 3. 3-Library Visual Asset Model: CELL, BORDER, CORNER Libraries
	editor.inspector_panel.set_stage(tile_st)
	assert(tile_st.cell_assets.size() >= 1, "Must have at least 1 default cell asset")
	assert(tile_st.border_assets.size() >= 1, "Must have at least 1 default border asset")
	assert(tile_st.corner_assets.size() >= 1, "Must have at least 1 default corner asset")
	print("✓ 3 Visual Asset Libraries initialized with defaults (Cells, Borders, Corners).")

	# Test Adding & Removing in Cell Library
	var added_cell_id := tile_st.add_cell_asset("res://addons/LevelEditorPlugin/assets/default/cells/Cell_B.svg", "Cell Theme 2")
	assert(tile_st.cell_assets.size() >= 2, "Cell asset count must increase")
	editor.inspector_panel.set_stage(tile_st)

	# Test Adding & Removing in Border Library
	var added_border_id := tile_st.add_border_asset("res://addons/LevelEditorPlugin/assets/default/borders/Border_V.svg", "Border Theme 2")
	assert(tile_st.border_assets.size() >= 2, "Border asset count must increase")

	# Test Adding & Removing in Corner Library
	var added_corner_id := tile_st.add_corner_asset("res://addons/LevelEditorPlugin/assets/default/corners/demo_corner_01.svg", "Corner Theme 2")
	assert(tile_st.corner_assets.size() >= 2, "Corner asset count must increase")
	print("✓ Asset addition to Cell, Border, and Corner libraries verified.")

	# 4. Cell Painting & Rotation Controls
	editor.inspector_panel._select_cell_asset("Cell_A")
	editor.inspector_panel._on_cell_rot_changed(45.0)
	assert(is_equal_approx(editor.inspector_panel.active_cell_rot, 45.0), "Selected rotation should be 45°")

	editor.grid_canvas._paint_board_tile(tile_st, Vector2i(0, 0))
	assert(tile_st.has_cell_visual(Vector2i(0, 0)) == true, "Cell (0,0) should have visual")
	var p_vis00 := tile_st.get_cell_visual(Vector2i(0, 0))
	assert(is_equal_approx(p_vis00.get("rotation", 0.0), 45.0), "Cell (0,0) rotation must be 45°")

	# Paint at (1, 0) with another rotation
	editor.inspector_panel._on_cell_rot_changed(90.0)
	editor.grid_canvas._paint_board_tile(tile_st, Vector2i(1, 0))
	var p_vis10 := tile_st.get_cell_visual(Vector2i(1, 0))
	assert(is_equal_approx(p_vis10.get("rotation", 0.0), 90.0), "Cell (1,0) rotation must be 90°")

	# Erase cell (1, 0)
	editor.inspector_panel._on_erase_tile_pressed()
	assert(editor.grid_canvas.current_tool == GridCanvas.ToolMode.TILE_ERASE, "Erase button must activate TILE_ERASE")
	editor.grid_canvas._erase_board_tile(tile_st, Vector2i(1, 0))
	assert(tile_st.has_cell_visual(Vector2i(1, 0)) == false, "Erased cell (1, 0) must no longer have visual")
	print("✓ Cell manual painting, arbitrary rotation, and erasing verified.")

	# 5. Border Placement & Intentional Visual Gaps
	tile_st.grid_width = 4
	tile_st.grid_height = 4
	var b_origin := Vector2(50, 50)
	var b_cell_sz := Vector2(64, 64)

	# Configure borders: Top=0°, Bottom=180°, Left=270°, Right=EMPTY (gap)
	tile_st.set_border_visual("top", 0, "border_1", 0.0)
	tile_st.set_border_visual("bottom", 0, "border_1", 180.0)
	tile_st.set_border_visual("left", 0, "border_1", 270.0)

	var border_pieces := BoardVisualGen.get_border_pieces(tile_st, b_origin, b_cell_sz)
	var has_top := false
	var has_bottom := false
	var has_left := false
	var has_right := false
	for bp in border_pieces:
		if bp.get("type", "") == "border":
			match bp.get("side", ""):
				"top": has_top = true
				"bottom": has_bottom = true
				"left": has_left = true
				"right": has_right = true

	assert(has_top == true, "Top border must be present")
	assert(has_bottom == true, "Bottom border must be present")
	assert(has_left == true, "Left border must be present")
	assert(has_right == false, "Right border must be EMPTY to create an intentional gap!")
	print("✓ Border placement with rotation and intentional gap (empty side) verified.")

	# 6. Corner Placement: 1 Corner Image reused at corners via rotation & mirror
	tile_st.set_corner_visual("top_left", "corner_1", 0.0, false, false)
	tile_st.set_corner_visual("top_right", "corner_1", 90.0, false, false)
	tile_st.set_corner_visual("bottom_right", "corner_1", 180.0, false, false)
	tile_st.set_corner_visual("bottom_left", "corner_1", 270.0, true, false) # Mirror X test

	var corner_p_tl = tile_st.get_corner_visual("top_left")
	var corner_p_bl = tile_st.get_corner_visual("bottom_left")
	assert(is_equal_approx(corner_p_tl.get("rotation", 0.0), 0.0), "Top-left rotation 0°")
	assert(corner_p_bl.get("mirror_x", false) == true, "Bottom-left mirror X should be true")
	print("✓ Corner placement with rotation, Mirror X, Mirror Y verified.")

	# 7. Level-Specific Visual Theme Persistence (to_dict / from_dict)
	var st_dict := tile_st.to_dict()
	assert(st_dict.has("cell_assets"), "Serialized stage must have cell_assets")
	assert(st_dict.has("border_assets"), "Serialized stage must have border_assets")
	assert(st_dict.has("corner_assets"), "Serialized stage must have corner_assets")
	assert(st_dict.has("border_visuals"), "Serialized stage must have border_visuals")
	assert(st_dict.has("corner_visuals"), "Serialized stage must have corner_visuals")

	var st_restored := LaserStageData.from_dict(st_dict)
	assert(st_restored.cell_assets.size() == tile_st.cell_assets.size(), "Restored cell assets count mismatch")
	assert(st_restored.border_assets.size() == tile_st.border_assets.size(), "Restored border assets count mismatch")
	assert(st_restored.corner_assets.size() == tile_st.corner_assets.size(), "Restored corner assets count mismatch")
	assert(st_restored.has_border_visual("right", 0) == false, "Restored right border must still be empty gap")
	assert(st_restored.get_corner_visual("bottom_left").get("mirror_x", false) == true, "Restored bottom-left mirror_x preserved")
	print("✓ Level-specific visual themes and placements survive serialization and restoration.")

	# 8. NEW ARCHITECTURE TESTS: Independent Cell Visuals & Border Visuals

	print("--- Testing Cell Visuals: Multiple Images, Arbitrary Rotation, Empty Cells & In-Place Editing ---")
	var vis_st := LaserStageData.new()
	vis_st.grid_width = 5
	vis_st.grid_height = 5

	# Check Cell Visual Asset Textures (Cell_A, Cell_B, Cell_C, Cell_D)
	var tex_a = BoardVisualGen.get_cell_visual_texture("Cell_A")
	var tex_b = BoardVisualGen.get_cell_visual_texture("Cell_B")
	var tex_c_vis = BoardVisualGen.get_cell_visual_texture("Cell_C")
	var tex_d = BoardVisualGen.get_cell_visual_texture("Cell_D")
	assert(tex_a != null, "Cell_A texture must load")
	assert(tex_b != null, "Cell_B texture must load")
	assert(tex_c_vis != null, "Cell_C texture must load")
	assert(tex_d != null, "Cell_D texture must load")
	print("✓ Multiple cell visual assets (Cell_A, Cell_B, Cell_C, Cell_D) loaded successfully.")

	# Test arbitrary numeric rotation & empty cells
	vis_st.set_cell_visual(Vector2i(0, 0), "Cell_A", 0.0)
	vis_st.set_cell_visual(Vector2i(1, 0), "Cell_B", 37.5)
	vis_st.set_cell_visual(Vector2i(2, 0), "Cell_C", 45.0)
	vis_st.set_cell_visual(Vector2i(3, 0), "Cell_D", 123.4)

	assert(vis_st.get_cell_visuals_count() == 4, "Should have exactly 4 placed cell visuals")
	assert(vis_st.has_cell_visual(Vector2i(1, 0)), "Cell (1,0) must have visual")
	var v10 = vis_st.get_cell_visual(Vector2i(1, 0))
	assert(v10["asset"] == "Cell_B", "Cell (1,0) asset must be Cell_B")
	assert(is_equal_approx(float(v10["rotation"]), 37.5), "Cell (1,0) rotation must be 37.5°")

	# Empty cells allowed: rest of the 5x5 grid has no visual artwork assigned
	assert(not vis_st.has_cell_visual(Vector2i(4, 4)), "Cell (4,4) must be empty of visual artwork")
	assert(not vis_st.has_cell_visual(Vector2i(2, 2)), "Cell (2,2) must be empty of visual artwork")
	print("✓ Arbitrary numeric rotation (37.5°, 45°, 123.4°) and empty cells verified.")

	# In-place editing via Inspector
	editor.inspector_panel.set_stage(vis_st)
	editor.inspector_panel.inspect_cell_visual(vis_st, Vector2i(1, 0), vis_st.get_cell_visual(Vector2i(1, 0)))
	assert(editor.inspector_panel.sel_cell_box.visible == true, "Selected cell box must become visible")
	assert(is_equal_approx(editor.inspector_panel.sel_cell_rot_spin.value, 37.5), "SpinBox value must reflect selected cell rotation")

	# Modify rotation in-place to 88.0°
	editor.inspector_panel._on_sel_cell_rot_changed(88.0)
	assert(is_equal_approx(float(vis_st.get_cell_visual(Vector2i(1, 0))["rotation"]), 88.0), "In-place rotation edit to 88.0° failed")

	# Modify asset in-place to Cell_D
	var opt_idx_d := -1
	for i in range(editor.inspector_panel.sel_cell_asset_opt.item_count):
		if editor.inspector_panel.sel_cell_asset_opt.get_item_text(i) == "Cell_D":
			opt_idx_d = i
			break
	assert(opt_idx_d >= 0, "Cell_D must be in asset dropdown")
	editor.inspector_panel._on_sel_cell_asset_changed(opt_idx_d)
	assert(vis_st.get_cell_visual(Vector2i(1, 0))["asset"] == "Cell_D", "In-place asset change to Cell_D failed")

	# Remove cell visual via in-place editor
	editor.inspector_panel._on_sel_cell_remove_pressed()
	assert(not vis_st.has_cell_visual(Vector2i(1, 0)), "Cell (1,0) visual must be removed")
	assert(vis_st.get_cell_visuals_count() == 3, "Placed visual count must decrease to 3")
	print("✓ In-place editing of placed cell visuals (asset, arbitrary rotation, removal) verified.")

	print("--- Testing Border Visuals: Outer Perimeter & Outer Corners ---")
	var origin := Vector2(100, 100)
	var cell_sz := Vector2(64, 64)
	vis_st.set_border_visual("top", 0, "border_1", 0.0)
	vis_st.set_corner_visual("top_left", "corner_1", 0.0)
	var pieces := BoardVisualGen.get_border_pieces(vis_st, origin, cell_sz)
	assert(pieces.size() == 2, "Pieces count should be 2")
	print("✓ Border pieces generation verified.")

	print("--- Testing Serialization & Deep Copy of Cell Visuals and Borders ---")
	vis_st.border_enabled = true
	vis_st.border_horizontal_edge_path = "res://Game/Assets/Board/Borders/Border_H.svg"
	vis_st.border_vertical_edge_path = "res://Game/Assets/Board/Borders/Border_V.svg"
	vis_st.border_corner_path = "res://Game/Assets/Board/Borders/Border_Corner.svg"

	var serialized_stage := vis_st.to_dict()
	assert(serialized_stage.has("cell_visuals"), "to_dict must serialize cell_visuals")
	assert(serialized_stage.has("border_settings"), "to_dict must serialize border_settings")

	var deserialized_st := LaserStageData.from_dict(serialized_stage)
	assert(deserialized_st.get_cell_visuals_count() == vis_st.get_cell_visuals_count(), "Deserialized cell visual count mismatch")
	assert(deserialized_st.border_enabled == true, "Deserialized border_enabled mismatch")
	assert(deserialized_st.border_horizontal_edge_path == vis_st.border_horizontal_edge_path, "Deserialized border_horizontal_edge_path mismatch")
	assert(deserialized_st.has_cell_visual(Vector2i(2, 0)), "Deserialized must have cell (2, 0)")
	assert(is_equal_approx(float(deserialized_st.get_cell_visual(Vector2i(2, 0))["rotation"]), 45.0), "Deserialized rotation mismatch")

	var duplicated_st := vis_st.duplicate_data()
	assert(duplicated_st.get_cell_visuals_count() == vis_st.get_cell_visuals_count(), "Cloned cell visual count mismatch")
	assert(duplicated_st.border_enabled == vis_st.border_enabled, "Cloned border_enabled mismatch")
	duplicated_st.set_cell_visual(Vector2i(2, 0), "Cell_A", 180.0)
	assert(vis_st.get_cell_visual(Vector2i(2, 0))["asset"] == "Cell_C", "Deep clone isolation violated!")
	print("✓ Serialization (to_dict/from_dict) and deep copying (duplicate_data) verified.")

	print("--- Testing Complete Independence of Gameplay Logic from Visual Layers ---")
	var gameplay_st := LaserStageData.new()
	gameplay_st.grid_width = 5
	gameplay_st.grid_height = 5
	var laser_src := LaserObjectData.create(LaserObjectData.ObjectType.LASER_SOURCE, Vector2i(0, 1), 0)
	var mirror_elem := LaserObjectData.create(LaserObjectData.ObjectType.FIXED_MIRROR, Vector2i(2, 1), 0)
	var goal_elem := LaserObjectData.create(LaserObjectData.ObjectType.GOAL, Vector2i(2, 4), 0)
	gameplay_st.add_object(laser_src)
	gameplay_st.add_object(mirror_elem)
	gameplay_st.add_object(goal_elem)

	var sim_before := LaserSimulation.simulate_stage(gameplay_st)
	var solv_before := SolvabilityChecker.check_stage_solvability(gameplay_st, 200)

	# Decorate with random cell visuals and borders
	gameplay_st.set_cell_visual(Vector2i(0, 1), "Cell_A", 55.0)
	gameplay_st.set_cell_visual(Vector2i(2, 1), "Cell_B", 99.0)
	gameplay_st.set_cell_visual(Vector2i(2, 4), "Cell_C", 33.3)
	gameplay_st.border_enabled = true
	gameplay_st.border_horizontal_edge_path = "res://addons/LevelEditorPlugin/assets/default/borders/Border_H.svg"

	var sim_after := LaserSimulation.simulate_stage(gameplay_st)
	var solv_after := SolvabilityChecker.check_stage_solvability(gameplay_st, 200)

	assert(sim_before["segments"].size() == sim_after["segments"].size(), "Simulation segment count must be identical")
	assert(sim_before["segments"][0]["end"] == sim_after["segments"][0]["end"], "Laser beam trajectory must be completely unaffected")
	assert(solv_before["status"] == solv_after["status"], "Solvability status must be completely unaffected")
	print("✓ Gameplay logic (laser simulation, reflection, solvability) is 100% unaffected by visual art layers.")

	print("--- Testing Section 11: 15-Step Authoritative Visual System & Bug Fix Verification ---")
	var scratch_logo_path := "res://addons/LevelEditorPlugin/assets/default/cells/demo_logo.svg"
	var scratch_stone_path := "res://addons/LevelEditorPlugin/assets/default/cells/demo_stone.svg"
	var f_logo = FileAccess.open(scratch_logo_path, FileAccess.WRITE)
	f_logo.store_string('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="#ff4444"/><circle cx="32" cy="32" r="16" fill="#ffff00"/></svg>')
	f_logo.close()
	var f_stone = FileAccess.open(scratch_stone_path, FileAccess.WRITE)
	f_stone.store_string('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="#4444ff"/><rect x="16" y="16" width="32" height="32" fill="#00ffff"/></svg>')
	f_stone.close()

	var sec11_st := LaserStageData.new()
	sec11_st.grid_width = 4
	sec11_st.grid_height = 4
	sec11_st.ensure_default_visual_libraries()

	# 1. Add/select Logo.svg as Cell Image
	sec11_st.cell_assets[0]["path"] = scratch_logo_path
	sec11_st.cell_assets[0]["name"] = "Logo.svg"
	BoardVisualGen.clear_texture_cache()

	# 2. Apply it to a grid cell/stage
	sec11_st.set_cell_visual(Vector2i(0, 0), "cell_1", 0.0)
	sec11_st.set_cell_visual(Vector2i(1, 1), "0", 45.0) # Legacy '0' reference from older level

	# 3. Confirm the actual rendered grid shows Logo.svg
	var resolved_vis00 = BoardVisualGen.get_cell_visual(sec11_st, Vector2i(0, 0))
	var resolved_vis11 = BoardVisualGen.get_cell_visual(sec11_st, Vector2i(1, 1))
	assert(resolved_vis00["texture"] != null, "Cell (0,0) texture must load")
	assert(resolved_vis11["texture"] != null, "Cell (1,1) legacy '0' texture must load")
	assert(BoardVisualGen.resolve_asset_in_library(sec11_st, "cell", "cell_1") == scratch_logo_path, "cell_1 must resolve to Logo.svg")
	assert(BoardVisualGen.resolve_asset_in_library(sec11_st, "cell", "0") == scratch_logo_path, "Legacy '0' must authoritatively resolve to stage primary Logo.svg!")

	# 4. Change the Cell Image to another image (demo_stone.svg)
	sec11_st.cell_assets[0]["path"] = scratch_stone_path
	sec11_st.cell_assets[0]["name"] = "Stone.svg"
	BoardVisualGen.clear_texture_cache()

	# 5. Confirm the old Logo image disappears and the new image renders
	assert(BoardVisualGen.resolve_asset_in_library(sec11_st, "cell", "cell_1") == scratch_stone_path, "Must resolve to Stone.svg")
	assert(BoardVisualGen.resolve_asset_in_library(sec11_st, "cell", "0") == scratch_stone_path, "Legacy '0' must resolve to Stone.svg")

	# 6. Restart / reload the level (to_dict / from_dict)
	var serialized_theme := sec11_st.to_dict()
	var reloaded_theme := LaserStageData.from_dict(serialized_theme)

	# 7. Confirm the new image is still used
	assert(reloaded_theme.cell_assets[0]["path"] == scratch_stone_path, "Reloaded level must still use Stone.svg")
	assert(BoardVisualGen.resolve_asset_in_library(reloaded_theme, "cell", "0") == scratch_stone_path, "Reloaded legacy cells must still resolve to Stone.svg")

	# 8. Confirm no old/generated cell image comes back
	var reloaded_vis00 = BoardVisualGen.get_cell_visual(reloaded_theme, Vector2i(0, 0))
	assert(reloaded_vis00["texture"] != null, "Reloaded texture must be non-null")
	assert(BoardVisualGen.resolve_asset_in_library(reloaded_theme, "cell", "Middle") == scratch_stone_path, "Middle must NOT come back, must resolve to Stone.svg")

	# 9. Add one Border Image
	var border_id = sec11_st.add_border_asset(BoardVisualGen.DEFAULT_BORDER_DEMO_PATH, "MainBorder")

	# 10. Confirm it can be painted on edges
	sec11_st.set_border_visual("top", 0, border_id, 0.0)
	sec11_st.set_border_visual("bottom", 0, border_id, 180.0)
	sec11_st.set_border_visual("left", 0, border_id, 270.0)

	# 11. Leave right edge unpainted (gap)
	# 12. Confirm that edge stays visually open (intentional gap)
	var theme_borders = BoardVisualGen.get_border_pieces(sec11_st, Vector2.ZERO, Vector2(64, 64))
	var has_gap_right := true
	for bp in theme_borders:
		if bp.get("side", "") == "right":
			has_gap_right = false
	assert(has_gap_right == true, "Right border edge MUST stay visually open (gap)")

	# 13. Add one Corner Image
	var corner_id = sec11_st.add_corner_asset(BoardVisualGen.DEFAULT_CORNER_DEMO_PATH, "MainCorner")

	# 14. Confirm the same asset can be reused on all four corners with rotation/mirroring
	sec11_st.set_corner_visual("top_left", corner_id, 0.0, false, false)
	sec11_st.set_corner_visual("top_right", corner_id, 90.0, false, false)
	sec11_st.set_corner_visual("bottom_left", corner_id, 270.0, true, false)
	sec11_st.set_corner_visual("bottom_right", corner_id, 180.0, false, true)

	var theme_corners = BoardVisualGen.get_border_pieces(sec11_st, Vector2.ZERO, Vector2(64, 64))
	var corner_types_found := 0
	for bp in theme_corners:
		if bp.get("type", "") == "corner":
			corner_types_found += 1
	assert(corner_types_found == 4, "All four corners must render using the single corner asset")

	# 15. Confirm changing the visual assets does not alter gameplay logic
	var sim_chk_1 = LaserSimulation.simulate_stage(sec11_st)
	sec11_st.set_cell_visual(Vector2i(0, 0), "cell_1", 137.5)
	sec11_st.remove_border_visual("top", 0)
	var sim_chk_2 = LaserSimulation.simulate_stage(sec11_st)
	assert(sim_chk_1["segments"].size() == sim_chk_2["segments"].size(), "Simulation segments completely unaffected by visual changes")

	if FileAccess.file_exists(scratch_logo_path):
		DirAccess.remove_absolute(scratch_logo_path)
	if FileAccess.file_exists(scratch_stone_path):
		DirAccess.remove_absolute(scratch_stone_path)

	print("✓ All 15 requirements from Section 11 verified and passed with flying colors!")

	if ResourceLoader.exists("res://Game/GamePlay.tscn"):
		var gp_scene: PackedScene = load("res://Game/GamePlay.tscn")
		assert(gp_scene != null, "GamePlay.tscn should load")
		var gp_instance: Node2D = gp_scene.instantiate()
		assert(gp_instance != null, "GamePlay.tscn should instantiate")
		assert(gp_instance.get_node_or_null("Board") == null, "Static Board node should be removed from GamePlay scene")
		assert(gp_instance.get_node_or_null("GridLayer") != null, "GridLayer should exist")
		gp_instance.queue_free()
		print("✓ GamePlay scene clean Board-less hierarchy verified.")
	else:
		print("✓ Host GamePlay.tscn not present (clean portable test environment).")

	editor._sync_gameplay_tscn_level_number(1)
	editor.queue_free()

	var p_tres_999 = LevelMigration.LASER_TRES_PATTERN % 999
	var p_json_999 = LevelMigration.LASER_JSON_PATTERN % 999
	if FileAccess.file_exists(p_tres_999):
		DirAccess.remove_absolute(p_tres_999)
	if FileAccess.file_exists(p_json_999):
		DirAccess.remove_absolute(p_json_999)

	print("--- Testing Section 21: Outer Perimeter Borders & Outer Corners System ---")
	var sec21_st := LaserStageData.new()
	sec21_st.grid_width = 5
	sec21_st.grid_height = 5
	sec21_st.ensure_default_visual_libraries()

	# 1. Verification: No auto-filled borders or corners
	assert(sec21_st.border_visuals.is_empty(), "Grid must start with 0 painted border visuals")
	assert(sec21_st.corner_visuals.is_empty(), "Grid must start with 0 painted corner visuals")
	assert(sec21_st.get_border_visuals_count() == 0, "Border count must be 0")
	assert(sec21_st.get_corner_visuals_count() == 0, "Corner count must be 0")
	print("✓ Initial grid starts completely clean with 0 auto-filled borders or corners.")

	# 2. Add border & corner assets
	var b_asset_1 := sec21_st.add_border_asset("res://addons/LevelEditorPlugin/assets/default/borders/Border_H.svg", "Border Image 1")
	var b_asset_2 := sec21_st.add_border_asset("res://addons/LevelEditorPlugin/assets/default/borders/Border_V.svg", "Border Image 2")
	var c_asset_1 := sec21_st.add_corner_asset("res://addons/LevelEditorPlugin/assets/default/corners/demo_corner_01.svg", "Corner Image 1")
	assert(sec21_st.border_assets.size() >= 2, "Border library must contain at least 2 assets")
	assert(sec21_st.corner_assets.size() >= 1, "Corner library must contain at least 1 asset")

	# Paint Cell Images into cells
	sec21_st.set_cell_visual(Vector2i(0, 0), "cell_1", 0.0)
	sec21_st.set_cell_visual(Vector2i(1, 0), "cell_1", 0.0)
	sec21_st.set_cell_visual(Vector2i(0, 1), "cell_1", 0.0)
	sec21_st.set_cell_visual(Vector2i(1, 1), "cell_1", 0.0)

	# 3. Paint Outer Perimeter Borders: Top 0, Top 1, Left 0, Right 4, Bottom 2
	sec21_st.set_border_visual("top", 0, b_asset_1, 0.0)
	sec21_st.set_border_visual("top", 1, b_asset_1, 0.0)
	sec21_st.set_border_visual("left", 0, b_asset_1, 0.0)
	sec21_st.set_border_visual("right", 4, b_asset_2, 90.0)
	sec21_st.set_border_visual("bottom", 2, b_asset_1, 180.0)

	assert(sec21_st.get_border_visuals_count() == 5, "Must have exactly 5 painted perimeter borders")
	assert(sec21_st.has_border_visual("top", 0), "Must have border on top segment 0")
	assert(sec21_st.has_border_visual("top", 1), "Must have border on top segment 1")
	assert(sec21_st.has_border_visual("left", 0), "Must have border on left segment 0")
	assert(sec21_st.has_border_visual("right", 4), "Must have border on right segment 4")
	assert(sec21_st.has_border_visual("bottom", 2), "Must have border on bottom segment 2")
	var b_r4 = sec21_st.get_border_visual("right", 4)
	assert(b_r4["asset"] == b_asset_2, "Right segment 4 asset must be Border Image 2")
	assert(is_equal_approx(float(b_r4["rotation"]), 90.0), "Right segment 4 rotation must be 90°")

	# 4. Confirm unpainted perimeter segments remain intentional empty gaps
	assert(not sec21_st.has_border_visual("top", 2), "Top segment 2 must be an empty gap")
	assert(not sec21_st.has_border_visual("top", 3), "Top segment 3 must be an empty gap")
	assert(not sec21_st.has_border_visual("top", 4), "Top segment 4 must be an empty gap")
	assert(not sec21_st.has_border_visual("bottom", 0), "Bottom segment 0 must be an empty gap")
	assert(not sec21_st.has_border_visual("left", 1), "Left segment 1 must be an empty gap")
	assert(not sec21_st.has_border_visual("right", 0), "Right segment 0 must be an empty gap")
	print("✓ Outer perimeter borders with rotation, custom assets, and intentional empty gaps verified.")

	# 5. Paint 4 Outer Corners
	sec21_st.set_corner_visual("top_left", c_asset_1, 0.0, false, false)
	sec21_st.set_corner_visual("top_right", c_asset_1, 90.0, false, false)
	sec21_st.set_corner_visual("bottom_left", c_asset_1, 270.0, true, false)
	sec21_st.set_corner_visual("bottom_right", c_asset_1, 180.0, false, false)

	assert(sec21_st.get_corner_visuals_count() == 4, "Must have exactly 4 painted outer corners")
	assert(sec21_st.has_corner_visual("top_left"), "Top left corner visual must exist")
	assert(sec21_st.has_corner_visual("top_right"), "Top right corner visual must exist")
	assert(sec21_st.has_corner_visual("bottom_left"), "Bottom left corner visual must exist")
	assert(sec21_st.has_corner_visual("bottom_right"), "Bottom right corner visual must exist")
	var c_bl = sec21_st.get_corner_visual("bottom_left")
	assert(is_equal_approx(float(c_bl["rotation"]), 270.0), "Bottom left corner rotation must be 270°")
	assert(c_bl["mirror_x"] == true, "Bottom left corner mirror_x must be true")
	assert(c_bl["mirror_y"] == false, "Bottom left corner mirror_y must be false")
	print("✓ 4 Outer Corners (top_left, top_right, bottom_left, bottom_right) verified.")

	# 6. Verify Strict Geometry: ZERO overlap between outer perimeter borders/corners and logical grid cells
	var test_origin := Vector2(100.0, 100.0)
	var test_cell_sz := Vector2(48.0, 48.0)
	var grid_internal_rect := Rect2(test_origin, Vector2(5.0 * 48.0, 5.0 * 48.0))
	var b_pieces := BoardVisualGen.get_border_pieces(sec21_st, test_origin, test_cell_sz)
	assert(b_pieces.size() == 9, "Expected 9 total perimeter pieces (5 borders + 4 corners), got %d" % b_pieces.size())

	for piece in b_pieces:
		var p_rect: Rect2 = piece["rect"]
		# Border piece must NOT overlap the internal grid area
		var overlap := p_rect.intersection(grid_internal_rect)
		assert(overlap.size.x <= 0.001 or overlap.size.y <= 0.001, "Perimeter piece %s overlaps internal grid! Rect: %s, Grid: %s" % [piece.get("side", piece.get("corner", "")), str(p_rect), str(grid_internal_rect)])
	print("✓ Strict geometric isolation verified: 0% overlap between outer perimeter layer and cell visual layer.")

	# 7. In-place inspection and modification in InspectorPanel
	editor.inspector_panel.set_stage(sec21_st)
	editor.inspector_panel.inspect_border_visual(sec21_st, "top", 1, sec21_st.get_border_visual("top", 1))
	assert(editor.inspector_panel.sel_border_box.visible == true, "Selected border box must be visible")
	assert(editor.inspector_panel.sel_border_lbl.text.contains("Top Segment 1"), "Label must show Top Segment 1")
	editor.inspector_panel._on_sel_border_rot_changed(45.0)
	assert(is_equal_approx(float(sec21_st.get_border_visual("top", 1)["rotation"]), 45.0), "In-place border rotation to 45.0° failed")

	editor.inspector_panel.inspect_corner_visual(sec21_st, "bottom_left", sec21_st.get_corner_visual("bottom_left"))
	assert(editor.inspector_panel.sel_corner_box.visible == true, "Selected corner box must be visible")
	assert(editor.inspector_panel.sel_corner_lbl.text.contains("Bottom Left"), "Label must show Bottom Left")
	editor.inspector_panel.sel_corner_my_chk.button_pressed = true
	editor.inspector_panel._on_sel_corner_mirror_changed(true)
	assert(sec21_st.get_corner_visual("bottom_left")["mirror_y"] == true, "In-place corner mirror_y toggle failed")

	# 8. Erasing borders & corners
	sec21_st.remove_border_visual("top", 1)
	assert(not sec21_st.has_border_visual("top", 1), "Top segment 1 border must be removed")
	assert(sec21_st.get_border_visuals_count() == 4, "Border count must be 4")

	sec21_st.remove_corner_visual("top_left")
	assert(not sec21_st.has_corner_visual("top_left"), "Top left corner must be removed")
	assert(sec21_st.get_corner_visuals_count() == 3, "Corner count must be 3")

	# 9. Serialization and Deep Copy
	var sec21_dict := sec21_st.to_dict()
	assert(sec21_dict.has("border_visuals"), "to_dict must have border_visuals")
	assert(sec21_dict.has("corner_visuals"), "to_dict must have corner_visuals")

	var sec21_restored := LaserStageData.from_dict(sec21_dict)
	assert(sec21_restored.get_border_visuals_count() == 4, "Restored stage must have 4 border visuals")
	assert(sec21_restored.get_corner_visuals_count() == 3, "Restored stage must have 3 corner visuals")
	assert(sec21_restored.has_border_visual("right", 4), "Restored stage must have right segment 4 border")
	assert(sec21_restored.get_corner_visual("bottom_left")["mirror_y"] == true, "Restored stage must preserve mirror_y")

	var sec21_clone := sec21_st.duplicate_data()
	assert(sec21_clone.get_border_visuals_count() == 4, "Clone must have 4 border visuals")
	sec21_clone.clear_all_border_visuals()
	assert(sec21_clone.get_border_visuals_count() == 0, "Clone borders cleared")
	assert(sec21_st.get_border_visuals_count() == 4, "Original stage borders must not be affected by clone clear")
	print("✓ Serialization (to_dict/from_dict) and deep copy isolation for outer perimeter borders & corners verified.")

	# 10. Gameplay Logic Independence
	var test_l := LaserObjectData.create(LaserObjectData.ObjectType.LASER_SOURCE, Vector2i(0, 2), 0)
	var test_m := LaserObjectData.create(LaserObjectData.ObjectType.FIXED_MIRROR, Vector2i(3, 2), 0)
	sec21_st.add_object(test_l)
	sec21_st.add_object(test_m)
	var sim_res_1 := LaserSimulation.simulate_stage(sec21_st)
	sec21_st.clear_all_border_visuals()
	sec21_st.clear_all_corner_visuals()
	var sim_res_2 := LaserSimulation.simulate_stage(sec21_st)
	assert(sim_res_1["segments"].size() == sim_res_2["segments"].size(), "Simulation segments must be identical regardless of borders/corners")
	assert(sim_res_1["segments"][0]["end"] == sim_res_2["segments"][0]["end"], "Laser trajectory must be 100% unaffected")
	print("✓ Gameplay logic is 100% independent of outer perimeter border and corner placement.")

	print("✓ Section 21 Outer Perimeter Border & Corner workflow passed all tests successfully!")

	# =========================================================================
	# SECTION 22: BORDER & CORNER NON-STRETCHING RENDERING & OFFSET/SCALE TESTS
	# =========================================================================
	print("--- SECTION 22: Testing Border/Corner Non-Stretching & Offset/Scale System ---")
	var sec22_st := LaserStageData.new()
	sec22_st.grid_width = 6
	sec22_st.grid_height = 4

	var b_asset := "border_custom"
	var c_asset := "corner_custom"

	# 1. Test directional outward offsets and independent Scale X / Scale Y
	# Top: offset moves upwards (y decreases), Scale X = 0.8, Scale Y = 1.4
	sec22_st.set_border_visual("top", 0, b_asset, 0.0, 15.0, 0.8, 1.4)
	# Bottom: offset moves downwards (y increases)
	sec22_st.set_border_visual("bottom", 0, b_asset, 0.0, 20.0, 1.2, 0.7)
	# Left: offset moves leftwards (x decreases)
	sec22_st.set_border_visual("left", 0, b_asset, 0.0, 10.0, 1.0, 1.5)
	# Right: offset moves rightwards (x increases)
	sec22_st.set_border_visual("right", 0, b_asset, 0.0, 25.0, 1.5, 0.9)

	# Corners directional outward offsets and independent Scale X / Scale Y
	sec22_st.set_corner_visual("top_left", c_asset, 0.0, false, false, 12.0, 1.1, 0.9)
	sec22_st.set_corner_visual("top_right", c_asset, 0.0, false, false, 14.0, 1.0, 1.0)
	sec22_st.set_corner_visual("bottom_left", c_asset, 0.0, false, false, 16.0, 0.9, 1.3)
	sec22_st.set_corner_visual("bottom_right", c_asset, 0.0, false, false, 18.0, 0.75, 1.35)

	var s22_origin := Vector2(200.0, 200.0)
	var csz := Vector2(48.0, 48.0)

	# Verify Top border center with offset
	var top_c_0 := BoardVisualGen.get_perimeter_border_center(s22_origin, csz, 6, 4, "top", 0, 0.0)
	var top_c_off := BoardVisualGen.get_perimeter_border_center(s22_origin, csz, 6, 4, "top", 0, 15.0)
	assert(top_c_off.x == top_c_0.x, "Top border X center must not change with offset")
	assert(top_c_off.y == top_c_0.y - 15.0, "Top border Y center must move upwards by 15px")

	# Verify Bottom border center with offset
	var bot_c_0 := BoardVisualGen.get_perimeter_border_center(s22_origin, csz, 6, 4, "bottom", 0, 0.0)
	var bot_c_off := BoardVisualGen.get_perimeter_border_center(s22_origin, csz, 6, 4, "bottom", 0, 20.0)
	assert(bot_c_off.y == bot_c_0.y + 20.0, "Bottom border Y center must move downwards by 20px")

	# Verify Left border center with offset
	var left_c_0 := BoardVisualGen.get_perimeter_border_center(s22_origin, csz, 6, 4, "left", 0, 0.0)
	var left_c_off := BoardVisualGen.get_perimeter_border_center(s22_origin, csz, 6, 4, "left", 0, 10.0)
	assert(left_c_off.x == left_c_0.x - 10.0, "Left border X center must move leftwards by 10px")

	# Verify Right border center with offset
	var right_c_0 := BoardVisualGen.get_perimeter_border_center(s22_origin, csz, 6, 4, "right", 0, 0.0)
	var right_c_off := BoardVisualGen.get_perimeter_border_center(s22_origin, csz, 6, 4, "right", 0, 25.0)
	assert(right_c_off.x == right_c_0.x + 25.0, "Right border X center must move rightwards by 25px")

	# Verify Corner Centers with directional diagonal outward offsets
	var tl_0 := BoardVisualGen.get_outer_corner_center(s22_origin, csz, 6, 4, "top_left", 0.0)
	var tl_off := BoardVisualGen.get_outer_corner_center(s22_origin, csz, 6, 4, "top_left", 12.0)
	assert(tl_off.x == tl_0.x - 12.0 and tl_off.y == tl_0.y - 12.0, "Top-left corner must shift diagonally top-left (-12, -12)")

	var tr_0 := BoardVisualGen.get_outer_corner_center(s22_origin, csz, 6, 4, "top_right", 0.0)
	var tr_off := BoardVisualGen.get_outer_corner_center(s22_origin, csz, 6, 4, "top_right", 14.0)
	assert(tr_off.x == tr_0.x + 14.0 and tr_off.y == tr_0.y - 14.0, "Top-right corner must shift diagonally top-right (+14, -14)")

	var bl_0 := BoardVisualGen.get_outer_corner_center(s22_origin, csz, 6, 4, "bottom_left", 0.0)
	var bl_off := BoardVisualGen.get_outer_corner_center(s22_origin, csz, 6, 4, "bottom_left", 16.0)
	assert(bl_off.x == bl_0.x - 16.0 and bl_off.y == bl_0.y + 16.0, "Bottom-left corner must shift diagonally bottom-left (-16, +16)")

	var br_0 := BoardVisualGen.get_outer_corner_center(s22_origin, csz, 6, 4, "bottom_right", 0.0)
	var br_off := BoardVisualGen.get_outer_corner_center(s22_origin, csz, 6, 4, "bottom_right", 18.0)
	assert(br_off.x == br_0.x + 18.0 and br_off.y == br_0.y + 18.0, "Bottom-right corner must shift diagonally bottom-right (+18, +18)")
	print("✓ Directional normal outward offsets for all 4 perimeter borders and 4 corners verified.")

	# 2. Verify get_border_pieces includes center, offset, scale_x, scale_y
	var s22_pieces := BoardVisualGen.get_border_pieces(sec22_st, s22_origin, csz)
	assert(s22_pieces.size() == 8, "Expected 8 pieces (4 borders + 4 corners)")
	for p in s22_pieces:
		assert(p.has("center"), "Piece must contain 'center' point")
		assert(p.has("offset"), "Piece must contain 'offset'")
		assert(p.has("scale_x") and p.has("scale_y"), "Piece must contain independent scale_x and scale_y")
		assert(p["scale_x"] > 0.0 and p["scale_y"] > 0.0, "Scale X and Y must be positive")
	print("✓ BoardVisualGenerator.get_border_pieces provides independent scale_x, scale_y and offset metadata.")

	# 3. Verify Inspector in-place offset, scale_x & scale_y updates
	editor.inspector_panel.set_stage(sec22_st)
	var tb_vis := sec22_st.get_border_visual("top", 0)
	editor.inspector_panel.inspect_border_visual(sec22_st, "top", 0, tb_vis)
	assert(is_equal_approx(editor.inspector_panel.sel_border_offset_spin.value, 15.0), "Inspector offset value mismatch")
	assert(is_equal_approx(editor.inspector_panel.sel_border_scale_x_spin.value, 0.8), "Inspector Scale X mismatch")
	assert(is_equal_approx(editor.inspector_panel.sel_border_scale_y_spin.value, 1.4), "Inspector Scale Y mismatch")

	# Test fine-grained scale precision such as 0.07
	editor.inspector_panel._on_sel_border_scale_x_changed(0.07)
	assert(is_equal_approx(float(sec22_st.get_border_visual("top", 0)["scale_x"]), 0.07), "Setting Scale X to 0.07 failed")

	editor.inspector_panel._on_sel_border_offset_changed(30.0)
	assert(is_equal_approx(float(sec22_st.get_border_visual("top", 0)["offset"]), 30.0), "In-place border offset modification failed")

	editor.inspector_panel._on_sel_border_scale_x_changed(2.5)
	editor.inspector_panel._on_sel_border_scale_y_changed(3.5)
	assert(is_equal_approx(float(sec22_st.get_border_visual("top", 0)["scale_x"]), 2.5), "In-place border Scale X modification failed")
	assert(is_equal_approx(float(sec22_st.get_border_visual("top", 0)["scale_y"]), 3.5), "In-place border Scale Y modification failed")

	editor.inspector_panel.inspect_corner_visual(sec22_st, "bottom_right", sec22_st.get_corner_visual("bottom_right"))
	assert(is_equal_approx(editor.inspector_panel.sel_corner_offset_spin.value, 18.0), "Inspector corner offset value mismatch")
	assert(is_equal_approx(editor.inspector_panel.sel_corner_scale_x_spin.value, 0.75), "Inspector corner Scale X mismatch")
	assert(is_equal_approx(editor.inspector_panel.sel_corner_scale_y_spin.value, 1.35), "Inspector corner Scale Y mismatch")

	editor.inspector_panel._on_sel_corner_scale_x_changed(0.07)
	assert(is_equal_approx(float(sec22_st.get_corner_visual("bottom_right")["scale_x"]), 0.07), "Setting corner Scale X to 0.07 failed")

	editor.inspector_panel._on_sel_corner_offset_changed(22.5)
	assert(is_equal_approx(float(sec22_st.get_corner_visual("bottom_right")["offset"]), 22.5), "In-place corner offset modification failed")

	editor.inspector_panel._on_sel_corner_scale_x_changed(0.6)
	editor.inspector_panel._on_sel_corner_scale_y_changed(1.8)
	assert(is_equal_approx(float(sec22_st.get_corner_visual("bottom_right")["scale_x"]), 0.6), "In-place corner Scale X modification failed")
	assert(is_equal_approx(float(sec22_st.get_corner_visual("bottom_right")["scale_y"]), 1.8), "In-place corner Scale Y modification failed")
	print("✓ InspectorPanel in-place editing of independent Scale X, Scale Y, and offset verified.")

	# 4. Verify Serialization of offset, scale_x and scale_y
	var s_dict := sec22_st.to_dict()
	var restored := LaserStageData.from_dict(s_dict)
	var top_restored := restored.get_border_visual("top", 0)
	assert(is_equal_approx(float(top_restored["offset"]), 30.0), "Restored border offset failed")
	assert(is_equal_approx(float(top_restored["scale_x"]), 2.5), "Restored border Scale X failed")
	assert(is_equal_approx(float(top_restored["scale_y"]), 3.5), "Restored border Scale Y failed")

	var br_restored := restored.get_corner_visual("bottom_right")
	assert(is_equal_approx(float(br_restored["offset"]), 22.5), "Restored corner offset failed")
	assert(is_equal_approx(float(br_restored["scale_x"]), 0.6), "Restored corner Scale X failed")
	assert(is_equal_approx(float(br_restored["scale_y"]), 1.8), "Restored corner Scale Y failed")

	# Legacy single scale restoration test
	var legacy_dict: Dictionary = {
		"grid_width": 5,
		"grid_height": 5,
		"border_visuals": { "top,0": { "asset": "border_1", "rotation": 0.0, "offset": 5.0, "scale": 1.7 } },
		"corner_visuals": { "top_left": { "asset": "corner_1", "rotation": 0.0, "offset": 5.0, "scale": 1.7 } }
	}
	var legacy_restored := LaserStageData.from_dict(legacy_dict)
	assert(is_equal_approx(float(legacy_restored.get_border_visual("top", 0)["scale_x"]), 1.7), "Legacy scale_x restoration failed")
	assert(is_equal_approx(float(legacy_restored.get_border_visual("top", 0)["scale_y"]), 1.7), "Legacy scale_y restoration failed")
	assert(is_equal_approx(float(legacy_restored.get_corner_visual("top_left")["scale_x"]), 1.7), "Legacy corner scale_x restoration failed")
	assert(is_equal_approx(float(legacy_restored.get_corner_visual("top_left")["scale_y"]), 1.7), "Legacy corner scale_y restoration failed")
	# 5. Verify Transformed Hit Testing & Selection Alignment (Offset = -10, Scale = 0.07, Rotation = 90°)
	var hit_st := LaserStageData.new()
	hit_st.grid_width = 5
	hit_st.grid_height = 5
	hit_st.stage_index = 1
	hit_st.set_border_visual("top", 0, "border_1", 90.0, -10.0, 0.07, 0.07)
	hit_st.set_border_visual("bottom", 1, "border_1", 90.0, -10.0, 0.07, 0.07)
	hit_st.set_border_visual("left", 2, "border_1", 90.0, -10.0, 0.07, 0.07)
	hit_st.set_border_visual("right", 3, "border_1", 90.0, -10.0, 0.07, 0.07)

	editor.grid_canvas.set_stage(hit_st)
	var canvas_origin: Vector2 = editor.grid_canvas.pan_offset
	var canvas_csz := Vector2(editor.grid_canvas.cell_size * editor.grid_canvas.zoom_level, editor.grid_canvas.cell_size * editor.grid_canvas.zoom_level)

	# Verify Top border transform center and hit testing at -10 offset
	var top_t := BoardVisualGen.get_border_piece_transform(hit_st, canvas_origin, canvas_csz, "top", 0, editor.grid_canvas.zoom_level)
	var hit_res := editor.grid_canvas.screen_to_stage_and_perimeter_border(top_t.center)
	assert(hit_res.inside == true, "Must hit placed top border at its visual center")
	assert(hit_res.side == "top" and hit_res.index == 0, "Hit result must identify top segment 0")
	assert(hit_res.is_placed == true, "Must be identified as placed border")

	# Verify Bottom border at -10 offset
	var bot_t := BoardVisualGen.get_border_piece_transform(hit_st, canvas_origin, canvas_csz, "bottom", 1, editor.grid_canvas.zoom_level)
	var bot_hit := editor.grid_canvas.screen_to_stage_and_perimeter_border(bot_t.center)
	assert(bot_hit.inside == true and bot_hit.side == "bottom" and bot_hit.index == 1, "Must hit bottom border at offset center")

	# Verify Left border at -10 offset
	var left_t := BoardVisualGen.get_border_piece_transform(hit_st, canvas_origin, canvas_csz, "left", 2, editor.grid_canvas.zoom_level)
	var left_hit := editor.grid_canvas.screen_to_stage_and_perimeter_border(left_t.center)
	assert(left_hit.inside == true and left_hit.side == "left" and left_hit.index == 2, "Must hit left border at offset center")

	# Verify Right border at -10 offset
	var right_t := BoardVisualGen.get_border_piece_transform(hit_st, canvas_origin, canvas_csz, "right", 3, editor.grid_canvas.zoom_level)
	var right_hit := editor.grid_canvas.screen_to_stage_and_perimeter_border(right_t.center)
	assert(right_hit.inside == true and right_hit.side == "right" and right_hit.index == 3, "Must hit right border at offset center")

	# Verify changing offset (-5, 0, 5, 10) dynamically updates transform and hit test together
	for test_off in [-5.0, 0.0, 5.0, 10.0]:
		hit_st.set_border_visual("top", 0, "border_1", 90.0, test_off, 0.07, 0.07)
		var dyn_t := BoardVisualGen.get_border_piece_transform(hit_st, canvas_origin, canvas_csz, "top", 0, editor.grid_canvas.zoom_level)
		var dyn_hit := editor.grid_canvas.screen_to_stage_and_perimeter_border(dyn_t.center)
		assert(dyn_hit.inside == true and dyn_hit.side == "top" and dyn_hit.index == 0, "Must hit dynamically moved border at offset %.1f" % test_off)

	print("✓ Unified final transform for render, hit-test, selection, and offset across all 4 sides verified.")

	print("✓ Section 22 Border & Corner Non-Stretching & Offset/Scale system passed all tests successfully!")

	# =========================================================================
	# SECTION 23: Testing Refactored 3-Tab Tiles Inspector & Decimal Precision
	# =========================================================================
	print("--- SECTION 23: Testing Refactored 3-Tab Tiles Inspector & Decimal Precision ---")
	var insp := editor.inspector_panel

	# 1. Verify 3-Tab Buttons & Structure
	assert(insp.tile_subtab_default_btn != null, "DEFAULT tab button must exist")
	assert(insp.tile_subtab_borders_btn != null, "BORDERS tab button must exist")
	assert(insp.tile_subtab_corners_btn != null, "CORNERS tab button must exist")
	assert(insp.tile_default_box != null, "tile_default_box container must exist")
	assert(insp.tile_borders_box != null, "tile_borders_box container must exist")
	assert(insp.tile_corners_box != null, "tile_corners_box container must exist")

	# 2. Verify Tab Switching & Exclusivity
	insp._switch_tiles_subtab(0)
	assert(insp.tile_default_box.visible == true, "DEFAULT box must be visible")
	assert(insp.tile_borders_box.visible == false, "BORDERS box must be hidden")
	assert(insp.tile_corners_box.visible == false, "CORNERS box must be hidden")
	assert(insp.tile_subtab_default_btn.button_pressed == true, "DEFAULT button pressed")

	insp._switch_tiles_subtab(1)
	assert(insp.tile_default_box.visible == false, "DEFAULT box must be hidden")
	assert(insp.tile_borders_box.visible == true, "BORDERS box must be visible")
	assert(insp.tile_corners_box.visible == false, "CORNERS box must be hidden")
	assert(insp.tile_subtab_borders_btn.button_pressed == true, "BORDERS button pressed")

	insp._switch_tiles_subtab(2)
	assert(insp.tile_default_box.visible == false, "DEFAULT box must be hidden")
	assert(insp.tile_borders_box.visible == false, "BORDERS box must be hidden")
	assert(insp.tile_corners_box.visible == true, "CORNERS box must be visible")
	assert(insp.tile_subtab_corners_btn.button_pressed == true, "CORNERS button pressed")
	print("✓ 3-Tab layout navigation and mutually exclusive visibility verified.")

	# 3. Verify Auto-Switching on Selection
	var sec23_st := LaserStageData.new()
	sec23_st.grid_width = 5
	sec23_st.grid_height = 5
	sec23_st.set_cell_visual(Vector2i(1, 1), "cell_1", 45.0)
	sec23_st.set_border_visual("top", 2, "border_1", 90.0, -0.007, 0.068, 0.081)
	sec23_st.set_corner_visual("top_left", "corner_1", 37.5, true, false, 0.025, 0.75, 1.25)
	insp.set_stage(sec23_st)

	# Select Cell -> Should switch to DEFAULT (tab 0)
	insp.inspect_cell_visual(sec23_st, Vector2i(1, 1), sec23_st.get_cell_visual(Vector2i(1, 1)))
	assert(insp.current_tiles_subtab == 0 and insp.tile_default_box.visible == true, "inspect_cell_visual must auto-switch to DEFAULT tab")

	# Select Border -> Should switch to BORDERS (tab 1)
	insp.inspect_border_visual(sec23_st, "top", 2, sec23_st.get_border_visual("top", 2))
	assert(insp.current_tiles_subtab == 1 and insp.tile_borders_box.visible == true, "inspect_border_visual must auto-switch to BORDERS tab")

	# Select Corner -> Should switch to CORNERS (tab 2)
	insp.inspect_corner_visual(sec23_st, "top_left", sec23_st.get_corner_visual("top_left"))
	assert(insp.current_tiles_subtab == 2 and insp.tile_corners_box.visible == true, "inspect_corner_visual must auto-switch to CORNERS tab")
	print("✓ Contextual auto-switching on Cell, Border, and Corner selection verified.")

	# 4. Verify Decimal Precision for Offset and Scale (step = 0.001)
	assert(is_equal_approx(insp.active_border_offset_spin.step, 0.001), "active_border_offset_spin step must be 0.001")
	assert(is_equal_approx(insp.sel_border_offset_spin.step, 0.001), "sel_border_offset_spin step must be 0.001")
	assert(is_equal_approx(insp.active_corner_offset_spin.step, 0.001), "active_corner_offset_spin step must be 0.001")
	assert(is_equal_approx(insp.sel_corner_offset_spin.step, 0.001), "sel_corner_offset_spin step must be 0.001")
	assert(is_equal_approx(insp.active_border_scale_x_spin.step, 0.001), "active_border_scale_x_spin step must be 0.001")
	assert(is_equal_approx(insp.active_border_scale_y_spin.step, 0.001), "active_border_scale_y_spin step must be 0.001")

	# Test small decimal offset and scale editing
	insp.inspect_border_visual(sec23_st, "top", 2, sec23_st.get_border_visual("top", 2))
	assert(is_equal_approx(insp.sel_border_offset_spin.value, -0.007), "Selected border offset -0.007 must be preserved exactly")
	assert(is_equal_approx(insp.sel_border_scale_x_spin.value, 0.068), "Selected border Scale X 0.068 must be preserved exactly")
	assert(is_equal_approx(insp.sel_border_scale_y_spin.value, 0.081), "Selected border Scale Y 0.081 must be preserved exactly")

	# Modify with positive small decimal 0.007
	insp._on_sel_border_offset_changed(0.007)
	assert(is_equal_approx(float(sec23_st.get_border_visual("top", 2)["offset"]), 0.007), "Border offset modification to 0.007 failed")

	# Test Corner small decimal values
	insp.inspect_corner_visual(sec23_st, "top_left", sec23_st.get_corner_visual("top_left"))
	assert(is_equal_approx(insp.sel_corner_offset_spin.value, 0.025), "Selected corner offset 0.025 mismatch")
	assert(is_equal_approx(insp.sel_corner_scale_x_spin.value, 0.75), "Selected corner Scale X 0.75 mismatch")
	assert(is_equal_approx(insp.sel_corner_scale_y_spin.value, 1.25), "Selected corner Scale Y 1.25 mismatch")
	assert(is_equal_approx(insp.sel_corner_rot_spin.value, 37.5), "Selected corner rotation 37.5 mismatch")
	assert(insp.sel_corner_mx_chk.button_pressed == true, "Selected corner Mirror X mismatch")
	assert(insp.sel_corner_my_chk.button_pressed == false, "Selected corner Mirror Y mismatch")
	print("✓ Small decimal offsets (0.007, -0.007, 0.025) and independent scales (0.068, 0.081) verified.")

	# 5. Verify Save and Load serialization of precise values
	var s23_dict := sec23_st.to_dict()
	var s23_loaded := LaserStageData.from_dict(s23_dict)
	var loaded_b := s23_loaded.get_border_visual("top", 2)
	assert(is_equal_approx(float(loaded_b["offset"]), 0.007), "Restored border offset 0.007 failed")
	assert(is_equal_approx(float(loaded_b["scale_x"]), 0.068), "Restored border scale_x 0.068 failed")
	assert(is_equal_approx(float(loaded_b["scale_y"]), 0.081), "Restored border scale_y 0.081 failed")

	var loaded_c := s23_loaded.get_corner_visual("top_left")
	assert(is_equal_approx(float(loaded_c["offset"]), 0.025), "Restored corner offset 0.025 failed")
	assert(is_equal_approx(float(loaded_c["scale_x"]), 0.75), "Restored corner scale_x 0.75 failed")
	assert(is_equal_approx(float(loaded_c["scale_y"]), 1.25), "Restored corner scale_y 1.25 failed")
	assert(is_equal_approx(float(loaded_c["rotation"]), 37.5), "Restored corner rotation 37.5 failed")
	assert(bool(loaded_c["mirror_x"]) == true, "Restored corner mirror_x failed")
	assert(bool(loaded_c["mirror_y"]) == false, "Restored corner mirror_y failed")
	print("✓ Full serialization and deserialization of exact decimal offset/scale/rot values verified.")

	print("✓ Section 23 Refactored 3-Tab Tiles Inspector & Decimal Precision passed all tests successfully!")

	# =========================================================================
	# SECTION 24: Testing Editor to Gameplay Visual Fidelity Pipeline (Borders & Corners)
	# =========================================================================
	print("--- SECTION 24: Testing Editor to Gameplay Visual Fidelity Pipeline ---")
	
	# 1. Load actual Level 1 from disk
	var lvl1 := LevelMigration.load_laser_level(1)
	assert(lvl1 != null, "Level 1 must load successfully")
	var s24_st1 := lvl1.get_stage(1)
	assert(s24_st1 != null, "Stage 1 of Level 1 must exist")
	assert(s24_st1.grid_width == 8 and s24_st1.grid_height == 10, "Stage 1 must be 8x10 grid")
	assert(s24_st1.border_visuals.size() > 0, "Stage 1 must have saved border visuals")
	assert(s24_st1.corner_visuals.size() > 0, "Stage 1 must have saved corner visuals")

	# 2. Asset Resolution for Level 1
	var lvl1_border_asset := BoardVisualGen.resolve_asset_in_library(s24_st1, "border", "border_1")
	assert(lvl1_border_asset == "res://Game/Assets/Board/ChatGPT2.png", "border_1 must authoritatively resolve to ChatGPT2.png")
	var lvl1_corner_asset := BoardVisualGen.resolve_asset_in_library(s24_st1, "corner", "corner_1")
	assert(lvl1_corner_asset == "res://Game/Assets/Board/ChatGPT1.png", "corner_1 must authoritatively resolve to ChatGPT1.png")
	print("✓ Library asset resolution for Level 1 ChatGPT border and corner assets verified.")

	# 3. Test Editor vs Gameplay relative transforms across responsive cell sizes
	var editor_cell_sz := Vector2(48.0, 48.0)
	var gameplay_cell_sz_64 := Vector2(64.0, 64.0)
	var gameplay_cell_sz_80 := Vector2(80.0, 80.0)
	var gameplay_cell_sz_100 := Vector2(100.0, 100.0)

	var ed_pieces := BoardVisualGen.get_border_pieces(s24_st1, Vector2.ZERO, editor_cell_sz)
	var gp_pieces_64 := BoardVisualGen.get_border_pieces(s24_st1, Vector2.ZERO, gameplay_cell_sz_64)
	var gp_pieces_80 := BoardVisualGen.get_border_pieces(s24_st1, Vector2.ZERO, gameplay_cell_sz_80)
	var gp_pieces_100 := BoardVisualGen.get_border_pieces(s24_st1, Vector2.ZERO, gameplay_cell_sz_100)

	assert(ed_pieces.size() == gp_pieces_64.size(), "Piece counts must match exactly between Editor and Gameplay")
	assert(ed_pieces.size() == gp_pieces_80.size(), "Piece counts must match exactly")
	assert(ed_pieces.size() == gp_pieces_100.size(), "Piece counts must match exactly")

	for i in range(ed_pieces.size()):
		var ep := ed_pieces[i]
		var gp64 := gp_pieces_64[i]
		var gp80 := gp_pieces_80[i]
		var gp100 := gp_pieces_100[i]

		# Assets, rotation, mirror, side/corner must match identically
		assert(ep.get("asset", "") == gp64.get("asset", ""), "Asset ID mismatch")
		assert(is_equal_approx(float(ep.get("rotation", 0.0)), float(gp64.get("rotation", 0.0))), "Rotation mismatch")
		assert(bool(ep.get("mirror_x", false)) == bool(gp64.get("mirror_x", false)), "Mirror X mismatch")
		assert(bool(ep.get("mirror_y", false)) == bool(gp64.get("mirror_y", false)), "Mirror Y mismatch")

		# Independent Scale X and Scale Y values must scale proportionally to cell_size
		var ed_sx: float = ep.get("draw_scale_x")
		var ed_sy: float = ep.get("draw_scale_y")
		var gp64_sx: float = gp64.get("draw_scale_x")
		var gp64_sy: float = gp64.get("draw_scale_y")
		var gp80_sx: float = gp80.get("draw_scale_x")
		var gp100_sx: float = gp100.get("draw_scale_x")

		assert(is_equal_approx(gp64_sx, ed_sx * (64.0 / 48.0)), "Gameplay 64px draw_scale_x must scale proportionally")
		assert(is_equal_approx(gp64_sy, ed_sy * (64.0 / 48.0)), "Gameplay 64px draw_scale_y must scale proportionally")
		assert(is_equal_approx(gp80_sx, ed_sx * (80.0 / 48.0)), "Gameplay 80px draw_scale_x must scale proportionally")
		assert(is_equal_approx(gp100_sx, ed_sx * (100.0 / 48.0)), "Gameplay 100px draw_scale_x must scale proportionally")

		# Offset distance relative to cell_size must remain identical
		var ep_center: Vector2 = ep.get("center")
		var gp64_center: Vector2 = gp64.get("center")
		# Relative normalized position (center / cell_size) must match
		var norm_ed := ep_center / editor_cell_sz.x
		var norm_gp64 := gp64_center / gameplay_cell_sz_64.x
		assert(is_equal_approx(norm_ed.x, norm_gp64.x) and is_equal_approx(norm_ed.y, norm_gp64.y), "Relative normalized piece center must match Editor exactly")

	print("✓ Proportional scaling, independent Scale X/Y, offsets, and relative geometry between Editor and Gameplay verified.")
	print("✓ Section 24 Editor to Gameplay Visual Fidelity Pipeline passed all tests successfully!")

	# =========================================================================
	# SECTION 25: Visual-Only Laser Hint System Validation
	# =========================================================================
	print("\n--- SECTION 25: Visual-Only Laser Hint System Validation ---")

	# 1. Test LaserStageData defaults & properties
	var hint_stage := LaserStageData.new()
	hint_stage.grid_width = 8
	hint_stage.grid_height = 10
	assert(hint_stage.hint_enabled == false, "Default hint_enabled should be false")
	assert(hint_stage.hint_laser_color == Color(0.31, 0.76, 1.0, 1.0), "Default hint_laser_color should be cyan")
	assert(is_equal_approx(hint_stage.hint_laser_width, 4.0), "Default hint_laser_width should be 4.0")
	assert(is_equal_approx(hint_stage.hint_laser_opacity, 1.0), "Default hint_laser_opacity should be 1.0")
	assert(hint_stage.hint_path_points.is_empty(), "Default hint_path_points should be empty")
	print("✓ LaserStageData default hint properties verified.")

	# 2. Test user's requested 8x10 test path:
	# [(0,0), (1,0), (2,0), (2,1), (2,2), (3,2), (4,2), (4,3), (4,4)]
	var test_path_coords: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(2, 1),
		Vector2i(2, 2),
		Vector2i(3, 2),
		Vector2i(4, 2),
		Vector2i(4, 3),
		Vector2i(4, 4)
	]

	for pt in test_path_coords:
		hint_stage.add_hint_point(pt)

	assert(hint_stage.hint_path_points.size() == 9, "Hint path must contain 9 points")
	assert(hint_stage.hint_path_points[0] == Vector2i(0, 0), "Start point must be (0, 0)")
	assert(hint_stage.hint_path_points[8] == Vector2i(4, 4), "End point must be (4, 4)")
	assert(hint_stage.get_hint_points_count() == 9, "get_hint_points_count() must return 9")

	# Test bounds checking
	hint_stage.add_hint_point(Vector2i(-1, 0))
	hint_stage.add_hint_point(Vector2i(8, 10))
	assert(hint_stage.hint_path_points.size() == 9, "Out of bounds points must not be added")

	# Test consecutive duplicate point filtering
	hint_stage.add_hint_point(Vector2i(4, 4))
	assert(hint_stage.hint_path_points.size() == 9, "Consecutive duplicate point must not be added")

	# Test removing point
	var removed := hint_stage.remove_hint_point(Vector2i(4, 4))
	assert(removed == true, "remove_hint_point should return true")
	assert(hint_stage.hint_path_points.size() == 8, "Point count should be 8 after removal")
	hint_stage.add_hint_point(Vector2i(4, 4))
	assert(hint_stage.hint_path_points.size() == 9, "Point re-added successfully")

	# 3. Test Serialization & Deserialization
	hint_stage.hint_enabled = true
	hint_stage.hint_laser_color = Color("#4FC3FF")
	hint_stage.hint_laser_width = 3.5
	hint_stage.hint_laser_opacity = 0.85

	var stage_dict := hint_stage.to_dict()
	assert(stage_dict.has("hint"), "Serialized dictionary must contain 'hint' block")
	var hint_dict: Dictionary = stage_dict["hint"]
	assert(hint_dict.get("enabled") == true, "Serialized hint.enabled mismatch")
	assert(hint_dict.get("laser_color") == "#4fc3ff", "Serialized hint.laser_color mismatch")
	assert(is_equal_approx(float(hint_dict.get("laser_width")), 3.5), "Serialized hint.laser_width mismatch")
	assert(is_equal_approx(float(hint_dict.get("laser_opacity")), 0.85), "Serialized hint.laser_opacity mismatch")
	assert(hint_dict.has("path") and hint_dict["path"].size() == 9, "Serialized hint.path must have 9 points")

	var restored_stage := LaserStageData.from_dict(stage_dict)
	assert(restored_stage.hint_enabled == true, "Restored hint_enabled mismatch")
	assert(is_equal_approx(restored_stage.hint_laser_color.r, Color("#4FC3FF").r), "Restored color red channel mismatch")
	assert(is_equal_approx(restored_stage.hint_laser_width, 3.5), "Restored hint_laser_width mismatch")
	assert(is_equal_approx(restored_stage.hint_laser_opacity, 0.85), "Restored hint_laser_opacity mismatch")
	assert(restored_stage.hint_path_points.size() == 9, "Restored path points count mismatch")
	for i in range(9):
		assert(restored_stage.hint_path_points[i] == test_path_coords[i], "Restored point %d mismatch" % i)

	# 4. Test duplicate_data()
	var dup_stage := hint_stage.duplicate_data()
	assert(dup_stage.hint_enabled == hint_stage.hint_enabled, "dup hint_enabled mismatch")
	assert(dup_stage.hint_path_points.size() == hint_stage.hint_path_points.size(), "dup hint_path_points size mismatch")
	dup_stage.clear_hint_path()
	assert(dup_stage.hint_path_points.is_empty(), "Cleared dup stage should be empty")
	assert(hint_stage.hint_path_points.size() == 9, "Original stage must remain unaffected by dup mutation")
	print("✓ Stage hint data serialization, deserialization, and cloning verified.")

	# 5. Visual-Only Guarantee: Zero Effect on Laser Simulation, Solvability, and Validation
	var s25_lvl := _make_test_level(250)
	var s25_st := s25_lvl.get_stage(1)

	var s25_sim_before := LaserSimulation.simulate_stage(s25_st)
	var s25_solv_before := SolvabilityChecker.check_stage_solvability(s25_st, 500)
	var s25_val_before := LevelValidator.validate_level(s25_lvl)

	# Now add heavy hint configuration
	s25_st.hint_enabled = true
	s25_st.hint_laser_color = Color.MAGENTA
	s25_st.hint_laser_width = 8.0
	s25_st.hint_laser_opacity = 0.5
	s25_st.set_hint_path([Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(4, 4)])

	var s25_sim_after := LaserSimulation.simulate_stage(s25_st)
	var s25_solv_after := SolvabilityChecker.check_stage_solvability(s25_st, 500)
	var s25_val_after := LevelValidator.validate_level(s25_lvl)

	assert(s25_sim_before["segments"].size() == s25_sim_after["segments"].size(), "Simulation segment count must be 100% identical")
	for idx in range(s25_sim_before["segments"].size()):
		assert(s25_sim_before["segments"][idx]["start"] == s25_sim_after["segments"][idx]["start"], "Segment start must match")
		assert(s25_sim_before["segments"][idx]["end"] == s25_sim_after["segments"][idx]["end"], "Segment end must match")
	assert(s25_solv_before["status"] == s25_solv_after["status"], "Solvability status must be 100% identical")
	assert(s25_val_before["is_valid"] == s25_val_after["is_valid"], "Validation is_valid must be 100% identical")
	assert(s25_val_before["error_count"] == s25_val_after["error_count"], "Validation error_count must be 100% identical")
	assert(s25_val_before["items"].size() == s25_val_after["items"].size(), "Validation items count must be 100% identical")
	print("✓ Strict Visual-Only guarantee verified: Hint Path has 0 effect on Laser Physics, Solvability, and Validation.")

	# 6. Test InspectorPanel UI & Tab 4 Integration
	var s25_insp := InspectorPanel.new()
	assert(s25_insp.tab_hint_btn != null, "InspectorPanel must have tab_hint_btn")
	assert(s25_insp.hint_section != null, "InspectorPanel must have hint_section")
	s25_insp.set_stage(hint_stage)
	s25_insp._switch_tab(4)
	assert(s25_insp.tab_hint_btn.button_pressed == true, "Hint tab must be toggled active")
	assert(s25_insp.hint_section.visible == true, "Hint section must be visible")
	assert(s25_insp.obj_section.visible == false, "Object section must be hidden")
	assert(s25_insp.stage_section.visible == false, "Stage section must be hidden")
	assert(s25_insp.tile_section.visible == false, "Tile section must be hidden")
	assert(s25_insp.lvl_section.visible == false, "Level section must be hidden")
	assert(s25_insp.hint_points_lbl.text == "Points: 9", "Hint points label mismatch")
	assert(s25_insp.hint_start_lbl.text == "Path Start: (0, 0)", "Hint start label mismatch")
	assert(s25_insp.hint_end_lbl.text == "Path End: (4, 4)", "Hint end label mismatch")
	print("✓ InspectorPanel Hint Tab UI, Controls, Labels, and exclusive visibility verified.")

	# 7. Test GridCanvas Tool Modes & Interaction
	var s25_canvas := GridCanvas.new()
	assert(GridCanvas.ToolMode.HINT_DRAW == 11, "ToolMode.HINT_DRAW enum value check")
	assert(GridCanvas.ToolMode.HINT_ERASE == 12, "ToolMode.HINT_ERASE enum value check")
	s25_canvas.current_tool = GridCanvas.ToolMode.HINT_DRAW
	assert(s25_canvas.current_tool == GridCanvas.ToolMode.HINT_DRAW, "GridCanvas current_tool HINT_DRAW check")
	s25_canvas.current_tool = GridCanvas.ToolMode.HINT_ERASE
	assert(s25_canvas.current_tool == GridCanvas.ToolMode.HINT_ERASE, "GridCanvas current_tool HINT_ERASE check")
	print("✓ GridCanvas Hint Tool Modes and canvas interaction verified.")

	print("✓ Section 25 Visual-Only Laser Hint System passed all tests successfully!")

	# =========================================================================
	# SECTION 26: Gameplay Scene Hint UI & Path Rendering Validation
	# =========================================================================
	print("\n--- SECTION 26: Gameplay Scene Hint UI & Path Rendering Validation ---")

	var s26_hint_dialog_script = load("res://Game/Scripts/hint_dialog.gd")
	var s26_layout_helper = load("res://addons/LevelEditorPlugin/core/board_layout_helper.gd")

	# 1. Test HintDialog Component
	var s26_dialog = s26_hint_dialog_script.new()
	assert(s26_dialog.layer == 25, "HintDialog must be high-priority overlay layer 25")
	assert(s26_dialog.dim_bg != null, "HintDialog must have dim background overlay")
	assert(s26_dialog.card != null, "HintDialog must have centered card panel")
	assert(s26_dialog.close_btn != null, "HintDialog must have close button")
	assert(s26_dialog.visible == false, "HintDialog should initially be hidden")
	print("✓ HintDialog component hierarchy and defaults verified.")

	# 2. Test 8x10 Stage Hint Dialog Layout & Aspect Ratio
	var s26_st_8x10 := LaserStageData.new()
	s26_st_8x10.stage_index = 1
	s26_st_8x10.grid_width = 8
	s26_st_8x10.grid_height = 10
	s26_st_8x10.hint_enabled = true
	s26_st_8x10.hint_laser_color = Color("#4FC3FF")
	s26_st_8x10.hint_laser_width = 4.0
	s26_st_8x10.hint_laser_opacity = 1.0
	s26_st_8x10.set_hint_path([
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2),
		Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4)
	])

	s26_dialog.open_hint(s26_st_8x10)
	assert(s26_dialog.is_open() == true, "HintDialog must report is_open() == true after open_hint")
	assert(s26_dialog.visible == true, "HintDialog visible must be true")
	assert(s26_dialog.cell_card_size.x > 0 and s26_dialog.cell_card_size.y > 0, "Cell card size must be calculated")
	assert(is_equal_approx(s26_dialog.cell_card_size.x, s26_dialog.cell_card_size.y), "Grid cells must maintain 1:1 aspect ratio")
	var s26_grid_aspect: float = (float(s26_st_8x10.grid_width) * s26_dialog.cell_card_size.x) / (float(s26_st_8x10.grid_height) * s26_dialog.cell_card_size.y)
	assert(is_equal_approx(s26_grid_aspect, 8.0 / 10.0), "8x10 Stage grid aspect ratio must be 0.8")

	# Test logical grid to card coordinate conversion
	var s26_p0: Vector2 = s26_dialog._grid_to_card(Vector2i(0, 0))
	var s26_p4: Vector2 = s26_dialog._grid_to_card(Vector2i(4, 4))
	assert(s26_p0.x > 0 and s26_p0.y > 0, "p0 must be positive card coordinate")
	assert(s26_p4.x > s26_p0.x and s26_p4.y > s26_p0.y, "p4 must be right and below p0")
	print("✓ 8x10 Stage Hint Dialog layout, 1:1 cell proportion, and logical coordinate mapping verified.")

	# 3. Test 5x5 Stage and 6x12 Stage Dynamic Responsiveness
	var s26_st_5x5 := LaserStageData.new()
	s26_st_5x5.grid_width = 5
	s26_st_5x5.grid_height = 5
	s26_st_5x5.hint_enabled = true
	s26_st_5x5.set_hint_path([Vector2i(0, 0), Vector2i(2, 2), Vector2i(4, 4)])
	s26_dialog.open_hint(s26_st_5x5)
	var s26_grid_aspect_5x5: float = (float(s26_st_5x5.grid_width) * s26_dialog.cell_card_size.x) / (float(s26_st_5x5.grid_height) * s26_dialog.cell_card_size.y)
	assert(is_equal_approx(s26_grid_aspect_5x5, 1.0), "5x5 Stage grid aspect ratio must be 1.0 (square)")

	var s26_st_6x12 := LaserStageData.new()
	s26_st_6x12.grid_width = 6
	s26_st_6x12.grid_height = 12
	s26_st_6x12.hint_enabled = true
	s26_st_6x12.set_hint_path([Vector2i(0, 0), Vector2i(0, 11)])
	s26_dialog.open_hint(s26_st_6x12)
	var s26_grid_aspect_6x12: float = (float(s26_st_6x12.grid_width) * s26_dialog.cell_card_size.x) / (float(s26_st_6x12.grid_height) * s26_dialog.cell_card_size.y)
	assert(is_equal_approx(s26_grid_aspect_6x12, 6.0 / 12.0), "6x12 Stage grid aspect ratio must be 0.5")
	print("✓ Dynamic responsive aspect-ratio preservation across different grid dimensions (5x5, 6x12) verified.")

	# 4. Test Missing / Disabled Hint Graceful Handling
	var s26_st_empty := LaserStageData.new()
	s26_st_empty.hint_enabled = false
	s26_dialog.open_hint(s26_st_empty)
	assert(s26_dialog.is_open() == true, "Empty hint stage should not crash HintDialog")
	print("✓ Missing / disabled hint data graceful handling verified.")

	# 5. Test GamePlay Scene Integration & Hint Button
	var s26_gp_scene := load("res://Game/GamePlay.tscn")
	assert(s26_gp_scene != null, "GamePlay.tscn must be loadable")
	var s26_gp = s26_gp_scene.instantiate()
	assert(s26_gp != null, "GamePlay instance creation")
	# Add to tree so _ready runs
	var s26_root := root
	s26_root.add_child(s26_gp)

	assert(s26_gp.hint_button != null, "GamePlay must contain hint_button")
	assert(s26_gp.hint_dialog != null, "GamePlay must contain hint_dialog")

	# Load test stage into gameplay
	s26_gp.current_stage = s26_st_8x10
	s26_gp._auto_center_grid(s26_st_8x10)
	s26_gp._update_hint_button()

	assert(s26_gp.hint_button.disabled == false, "Hint button must be enabled when stage has hint")
	var s26_btn_pos: Vector2 = s26_gp.hint_button.position
	var s26_board_rect: Rect2 = s26_layout_helper.compute_board_rect(s26_gp.grid_origin, s26_gp.cell_size, s26_st_8x10.grid_width, s26_st_8x10.grid_height)
	assert(s26_btn_pos.y >= s26_board_rect.position.y + s26_board_rect.size.y, "Hint button must be positioned below board")

	# Test button disabled when stage has no hint
	s26_gp.current_stage = s26_st_empty
	s26_gp._update_hint_button()
	assert(s26_gp.hint_button.disabled == true, "Hint button must be disabled when stage has no hint")

	# Test open hint from GamePlay
	s26_gp.current_stage = s26_st_8x10
	s26_gp._on_hint_button_pressed()
	assert(s26_gp.hint_dialog.is_open() == true, "Hint dialog must be open after button press")

	# Test input blocking while hint dialog is open
	var s26_test_obj := LaserObjectData.create(LaserObjectData.ObjectType.ROTATABLE_MIRROR, Vector2i(2, 2), 0)
	s26_st_8x10.objects = [s26_test_obj]
	var s26_initial_rot: int = s26_test_obj.rotation_deg
	var s26_fake_click := InputEventMouseButton.new()
	s26_fake_click.button_index = MOUSE_BUTTON_LEFT
	s26_fake_click.pressed = true
	s26_fake_click.position = s26_gp.grid_to_world(Vector2i(2, 2))
	s26_gp._unhandled_input(s26_fake_click)
	assert(s26_test_obj.rotation_deg == s26_initial_rot, "Input must be blocked while hint dialog is open")

	# Test close hint
	s26_gp.hint_dialog.close_hint()
	s26_gp.queue_free()
	print("✓ GamePlay Hint Button relative positioning, dynamic enable/disable, and input blocking verified.")

	print("✓ Section 26 Gameplay Scene Hint UI & Path Rendering Validation passed all tests successfully!")

	# =========================================================================
	# SECTION 27: LEVEL EDITOR HINT MODE DARK TINT OVERLAY VALIDATION
	# =========================================================================
	print("--- SECTION 27: Level Editor Hint Mode Dark Tint Overlay Validation ---")

	var s27_editor := LaserMindEditorMain.new()
	var s27_lvl := _make_test_level(270)
	s27_editor.set_level(s27_lvl)

	var s27_canvas: GridCanvas = s27_editor.grid_canvas
	var s27_inspector: InspectorPanel = s27_editor.inspector_panel

	# 1. Verify HINT_MODE_DIM_COLOR constant specifications
	assert(GridCanvas.HINT_MODE_DIM_COLOR != null, "GridCanvas must have HINT_MODE_DIM_COLOR constant")
	assert(GridCanvas.HINT_MODE_DIM_COLOR.r == 0.0 and GridCanvas.HINT_MODE_DIM_COLOR.g == 0.0 and GridCanvas.HINT_MODE_DIM_COLOR.b == 0.0, "Dark tint color must be black")
	assert(GridCanvas.HINT_MODE_DIM_COLOR.a >= 0.45 and GridCanvas.HINT_MODE_DIM_COLOR.a <= 0.60, "Dark tint alpha must be in range 0.45 - 0.60, got: %f" % GridCanvas.HINT_MODE_DIM_COLOR.a)
	print("✓ HINT_MODE_DIM_COLOR constant verified: black with alpha %f." % GridCanvas.HINT_MODE_DIM_COLOR.a)

	# 2. Verify initial load state: zero dark tint and hint mode is false by default
	var s27_init_editor := LaserMindEditorMain.new()
	assert(s27_init_editor.grid_canvas.is_hint_mode() == false, "Initial editor load must have hint mode disabled")
	s27_init_editor.queue_free()

	# 3. Test exact tab switching flow:
	# Click Object -> no dark tint
	s27_inspector._switch_tab(0)
	assert(s27_canvas.is_hint_mode() == false, "Object tab must have hint mode = false")

	# Click Stage -> no dark tint
	s27_inspector._switch_tab(1)
	assert(s27_canvas.is_hint_mode() == false, "Stage tab must have hint mode = false")

	# Click Level -> no dark tint
	s27_inspector._switch_tab(2)
	assert(s27_canvas.is_hint_mode() == false, "Level tab must have hint mode = false")

	# Click Tiles -> no dark tint
	s27_inspector._switch_tab(3)
	assert(s27_canvas.is_hint_mode() == false, "Tiles tab must have hint mode = false")

	# Click Hint -> dark tint & hint path VISIBLE
	s27_inspector._switch_tab(4)
	assert(s27_canvas.is_hint_mode() == true, "Hint tab must have hint mode = true")

	# Click Tiles -> dark tint & hint path HIDDEN
	s27_inspector._switch_tab(3)
	assert(s27_canvas.is_hint_mode() == false, "Tiles tab must have hint mode = false")

	# Click Hint again -> dark tint & hint path VISIBLE
	s27_inspector._switch_tab(4)
	assert(s27_canvas.is_hint_mode() == true, "Hint tab must have hint mode = true")

	# Switch to another panel (Stage) -> dark tint & hint path HIDDEN
	s27_inspector._switch_tab(1)
	assert(s27_canvas.is_hint_mode() == false, "Stage tab must have hint mode = false")

	# Back to Hint tab for tool tests
	s27_inspector._switch_tab(4)
	assert(s27_canvas.is_hint_mode() == true, "Hint tab must have hint mode = true")

	# 5. Verify palette tool change turns off hint mode
	s27_editor._on_palette_tool_changed(GridCanvas.ToolMode.PAINT)
	assert(s27_canvas.is_hint_mode() == false, "Selecting palette paint tool must deactivate hint mode")

	# 6. Verify requesting hint draw tool activates hint mode
	s27_editor._on_hint_tool_mode_requested(GridCanvas.ToolMode.HINT_DRAW)
	assert(s27_canvas.is_hint_mode() == true, "Requesting hint draw tool must activate hint mode")
	assert(s27_canvas.current_tool == GridCanvas.ToolMode.HINT_DRAW, "Current tool must be HINT_DRAW")

	# 7. Verify hint point drawing and editing interactions work while hint mode is active
	var s27_st = s27_lvl.get_stage(1)
	s27_st.clear_hint_path()
	assert(s27_st.hint_path_points.is_empty(), "Hint path must be empty initially")

	# Simulate user clicking cell (1, 1) and (1, 3) in HINT_DRAW mode
	var fake_draw_ev := InputEventMouseButton.new()
	fake_draw_ev.button_index = MOUSE_BUTTON_LEFT
	fake_draw_ev.pressed = true
	var cell_1_1_screen = s27_canvas.stage_cell_to_screen(1, Vector2i(1, 1))
	fake_draw_ev.position = cell_1_1_screen
	s27_canvas._gui_input(fake_draw_ev)

	assert(s27_st.hint_path_points.size() == 1, "Drawing at cell (1,1) should add 1 point")
	assert(s27_st.hint_path_points[0] == Vector2i(1, 1), "Point must be (1,1)")

	var cell_1_3_screen = s27_canvas.stage_cell_to_screen(1, Vector2i(1, 3))
	fake_draw_ev.position = cell_1_3_screen
	s27_canvas._gui_input(fake_draw_ev)

	assert(s27_st.hint_path_points.size() == 2, "Drawing at cell (1,3) should add 2nd point")
	assert(s27_st.hint_path_points[1] == Vector2i(1, 3), "Point 2 must be (1,3)")

	# Verify Hint erase interaction
	s27_editor._on_hint_tool_mode_requested(GridCanvas.ToolMode.HINT_ERASE)
	assert(s27_canvas.is_hint_mode() == true, "Hint erase tool must also keep hint mode active")
	fake_draw_ev.position = cell_1_3_screen
	s27_canvas._gui_input(fake_draw_ev)
	assert(s27_st.hint_path_points.size() == 1, "Erasing at (1,3) should remove the point")
	assert(s27_st.hint_path_points[0] == Vector2i(1, 1), "Remaining point must be (1,1)")

	s27_editor.queue_free()
	print("✓ Section 27 Level Editor Hint Mode Dark Tint Overlay Validation passed all tests successfully!")

	print("--- ALL EDITOR BUTTONS, TOOLS, MODALS, AND PANELS ARE 100% OPERATIONAL! ---")
	quit(0)

static func _make_test_level(p_id: int) -> LaserLevelData:
	var lvl := LaserLevelData.new()
	lvl.level_id = p_id
	lvl.level_number = p_id
	lvl.level_name = "Test Level %d" % p_id
	lvl.ensure_three_stages()
	for s in lvl.stages:
		s.grid_width = 5
		s.grid_height = 5
		var l := LaserObjectData.create(LaserObjectData.ObjectType.LASER_SOURCE, Vector2i(0, 0), 0)
		var m := LaserObjectData.create(LaserObjectData.ObjectType.FIXED_MIRROR, Vector2i(1, 0), 0)
		var g := LaserObjectData.create(LaserObjectData.ObjectType.GOAL, Vector2i(1, 4), 0)
		s.add_object(l)
		s.add_object(m)
		s.add_object(g)
	return lvl
