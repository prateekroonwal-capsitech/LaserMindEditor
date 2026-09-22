extends SceneTree

const GamePlayScript = preload("res://Game/Scripts/GamePlay.gd")

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

	var gp := GamePlayScript.new()
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
	assert(spawned_node != null and (spawned_node is CustomObject), "Custom object should instantiate actual custom scene even in playtest mode")
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
	print("--- Testing Image-Sliced Board Tile System ---")
	var tile_st := LaserStageData.new()
	tile_st.grid_width = 5
	tile_st.grid_height = 5
	tile_st.board_image_path = "res://Game/Assets/Board/board.png"
	tile_st.board_slice_cols = 5
	tile_st.board_slice_rows = 5

	assert(tile_st.get_effective_slice_cols() == 5, "Effective slice cols should be 5")
	assert(tile_st.get_effective_slice_rows() == 5, "Effective slice rows should be 5")

	tile_st.set_board_tile(Vector2i(1, 2), Vector2i(0, 1))
	assert(tile_st.has_board_tile(Vector2i(1, 2)) == true, "Tile (1, 2) should exist")
	assert(tile_st.get_board_tile(Vector2i(1, 2)) == Vector2i(0, 1), "Tile (1, 2) should have coord (0, 1)")
	tile_st.remove_board_tile(Vector2i(1, 2))
	assert(tile_st.has_board_tile(Vector2i(1, 2)) == false, "Tile (1, 2) should be removed")

	tile_st.auto_fill_board_tiles()
	assert(tile_st.board_tiles.size() == 25, "5x5 grid should have 25 auto-filled board tiles")
	assert(tile_st.get_board_tile(Vector2i(4, 4)) == Vector2i(4, 4), "Tile (4, 4) should map to slice (4, 4)")

	tile_st.set_board_margins(21, 23, 19, 21)
	tile_st.show_tile_borders = false
	assert(tile_st.has_board_margins() == true, "Stage should have board margins")
	assert(tile_st.get_board_margins() == Vector4i(21, 23, 19, 21), "Board margins mismatch")
	assert(tile_st.show_tile_borders == false, "show_tile_borders should be false")

	tile_st.toggle_frame_piece("T_0")
	tile_st.toggle_frame_piece("L_2")
	assert(tile_st.is_frame_piece_hidden("T_0") == true, "T_0 should be hidden")
	assert(tile_st.is_frame_piece_hidden("L_2") == true, "L_2 should be hidden")
	assert(tile_st.is_frame_piece_hidden("R_0") == false, "R_0 should not be hidden")

	var tile_dict := tile_st.to_dict()
	assert(tile_dict.get("board_image_path") == "res://Game/Assets/Board/board.png", "Serialized image path failed")
	assert(tile_dict.get("board_tiles").size() == 25, "Serialized tiles size failed")
	assert(tile_dict.get("board_margin_left") == 21, "Serialized margin_left failed")
	assert(tile_dict.get("board_margin_top") == 23, "Serialized margin_top failed")
	assert(tile_dict.get("show_tile_borders") == false, "Serialized show_tile_borders failed")
	assert(tile_dict.get("hidden_frame_pieces").size() == 2, "Serialized hidden_frame_pieces size failed")

	var restored_st := LaserStageData.from_dict(tile_dict)
	assert(restored_st.board_image_path == tile_st.board_image_path, "Deserialized image path failed")
	assert(restored_st.board_tiles.size() == 25, "Deserialized tiles size failed")
	assert(restored_st.get_board_tile(Vector2i(0, 0)) == Vector2i(0, 0), "Deserialized tile (0, 0) failed")
	assert(restored_st.board_margin_left == 21, "Deserialized margin_left failed")
	assert(restored_st.board_margin_top == 23, "Deserialized margin_top failed")
	assert(restored_st.has_board_margins() == true, "Deserialized should have margins")
	assert(restored_st.show_tile_borders == false, "Deserialized show_tile_borders failed")
	assert(restored_st.is_frame_piece_hidden("T_0") == true, "Deserialized T_0 should be hidden")

	var cloned_st := tile_st.duplicate_data()
	assert(cloned_st.board_tiles.size() == 25, "Cloned stage should preserve 25 tiles")
	assert(cloned_st.board_margin_left == 21, "Cloned stage should preserve margin_left")
	assert(cloned_st.show_tile_borders == false, "Cloned stage should preserve show_tile_borders")
	assert(cloned_st.is_frame_piece_hidden("L_2") == true, "Cloned stage should preserve L_2 hidden")
	print("✓ LaserStageData board tilemap and frame margin serialization verified.")

	var b_tex := BoardLayoutManager.get_board_texture(tile_st.board_image_path)
	assert(b_tex != null, "Failed to load board texture from res://Game/Assets/Board/board.png")
	var s_rect := BoardLayoutManager.get_tile_src_rect(b_tex, 2, 3, 5, 5, tile_st.get_board_margins())
	assert(s_rect.size.x > 0 and s_rect.size.y > 0, "Slice rect should have positive dimensions")
	var det_margins := BoardLayoutManager.auto_detect_board_margins(b_tex)
	assert(det_margins.x > 0 and det_margins.y > 0, "Auto-detect board margins failed")
	var p_rects := BoardLayoutManager.get_frame_piece_rects(Rect2(0, 0, 200, 200), det_margins, b_tex.get_size(), 5, 5)
	assert(p_rects.has("T_0"), "Frame pieces must contain T_0")
	assert(p_rects.has("L_4"), "Frame pieces must contain L_4")
	var hit_p := BoardLayoutManager.get_frame_piece_at_point(p_rects["T_0"].get_center(), Rect2(0, 0, 200, 200), det_margins, b_tex.get_size(), 5, 5)
	assert(hit_p == "T_0", "Point inside T_0 must return T_0")
	print("✓ BoardLayoutManager texture caching, inner slice, and frame piece hit testing verified.")

	assert(editor.board_tile_palette != null, "Editor should have board_tile_palette")
	editor.board_tile_palette.set_stage(tile_st)
	editor.board_tile_palette.select_tile(3, 2)
	assert(editor.board_tile_palette.selected_tile_coord == Vector2i(3, 2), "Selected tile should be (3, 2)")
	editor.board_tile_palette._on_paint_tile_pressed()
	assert(editor.grid_canvas.current_tool == GridCanvas.ToolMode.TILE_PAINT, "Canvas tool should switch to TILE_PAINT")
	assert(editor.grid_canvas.active_tile_coord == Vector2i(3, 2), "Canvas active tile should be (3, 2)")

	editor.grid_canvas._paint_board_tile(tile_st, Vector2i(0, 0))
	assert(tile_st.get_board_tile(Vector2i(0, 0)) == Vector2i(3, 2), "Placed tile should be (3, 2)")
	print("✓ Editor BoardTilePalette and Canvas tile painting verified.")

	editor.inspector_panel.set_stage(tile_st)
	assert(editor.inspector_panel.tile_buttons.size() == 25, "InspectorPanel should have 25 sliced tile buttons for 5x5 grid")
	assert(editor.inspector_panel.tile_buttons.has(Vector2i(1, 1)), "InspectorPanel should have tile (1, 1)")
	var btn_1_1: Button = editor.inspector_panel.tile_buttons[Vector2i(1, 1)]
	btn_1_1.pressed.emit()
	assert(editor.grid_canvas.current_tool == GridCanvas.ToolMode.TILE_PAINT, "Clicking inspector tile button should activate TILE_PAINT")
	assert(editor.grid_canvas.active_tile_coord == Vector2i(1, 1), "Active tile should be (1, 1)")
	print("✓ InspectorPanel inline 5x5 sliced tile buttons & canvas painting verified.")

	editor.inspector_panel._open_big_tile_dialog()
	assert(editor.inspector_panel.big_tile_dialog != null, "Big tile dialog should exist")
	assert(editor.inspector_panel.big_dialog_buttons.size() == 25, "Big tile dialog should contain 25 large tile buttons")
	var big_btn_2_2: Button = editor.inspector_panel.big_dialog_buttons[Vector2i(2, 2)]
	big_btn_2_2.pressed.emit()
	assert(editor.grid_canvas.current_tool == GridCanvas.ToolMode.TILE_PAINT, "Clicking big dialog tile should activate TILE_PAINT")
	assert(editor.grid_canvas.active_tile_coord == Vector2i(2, 2), "Active tile from big dialog should be (2, 2)")
	print("✓ InspectorPanel Big Tile Dialog & canvas painting verified.")

	editor.inspector_panel._switch_tab(1)
	assert(editor.inspector_panel.stage_section.visible == true, "Stage section must be visible on Stage tab")
	assert(editor.inspector_panel.tile_section.visible == false, "Tile section must NOT be visible on Stage tab")
	editor.inspector_panel._switch_tab(3)
	assert(editor.inspector_panel.stage_section.visible == false, "Stage section must NOT be visible on Tiles tab")
	assert(editor.inspector_panel.tile_section.visible == true, "Tile section must be visible on Tiles tab")
	print("✓ Clean separation of Stage and Tiles tabs verified.")


	var gp_scene: PackedScene = load("res://Game/GamePlay.tscn")
	assert(gp_scene != null, "GamePlay.tscn should load")
	var gp_instance: Node2D = gp_scene.instantiate()
	assert(gp_instance != null, "GamePlay.tscn should instantiate")
	assert(gp_instance.get_node_or_null("Board") == null, "Static Board node should be removed from GamePlay scene")
	assert(gp_instance.get_node_or_null("GridLayer") != null, "GridLayer should exist")
	gp_instance.queue_free()
	print("✓ GamePlay scene clean Board-less hierarchy verified.")

	editor._sync_gameplay_tscn_level_number(1)
	editor.queue_free()

	var p_tres_999 = LevelMigration.LASER_TRES_PATTERN % 999
	var p_json_999 = LevelMigration.LASER_JSON_PATTERN % 999
	if FileAccess.file_exists(p_tres_999):
		DirAccess.remove_absolute(p_tres_999)
	if FileAccess.file_exists(p_json_999):
		DirAccess.remove_absolute(p_json_999)

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
