@tool
extends Control
class_name GridCanvas

signal cell_clicked(cell: Vector2i, button_idx: int)
signal object_selected(object: LaserObjectData)
signal selection_changed(selected_objects: Array[LaserObjectData])
signal object_modified(object: LaserObjectData)
signal stage_dirty_needed
signal stage_activated(stage_index: int)
signal cell_visual_selected(stage: LaserStageData, cell: Vector2i, visual_data: Dictionary)
signal border_visual_selected(stage: LaserStageData, side: String, index: int, visual_data: Dictionary)
signal corner_visual_selected(stage: LaserStageData, corner: String, visual_data: Dictionary)
signal hint_path_modified(stage: LaserStageData)

const BoardLayoutManager = preload("res://addons/LevelEditorPlugin/core/board_layout_helper.gd")
const BoardVisualGenerator = preload("res://addons/LevelEditorPlugin/core/board_visual_generator.gd")

enum ToolMode {
	SELECT,
	PAINT,
	MOVE,
	ROTATE,
	ERASE,
	TILE_PAINT,
	TILE_ERASE,
	BORDER_PAINT,
	BORDER_ERASE,
	CORNER_PAINT,
	CORNER_ERASE,
	HINT_DRAW,
	HINT_ERASE
}

const STAGE_GAP_CELLS: int = 4
const HINT_MODE_DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.52)

var current_level: LaserLevelData = null
var stages: Array[LaserStageData] = []
var current_stage: LaserStageData = null
var current_stage_idx: int = 1
var is_side_by_side: bool = true
var is_hint_mode_active: bool = false

var simulation_results: Dictionary = {}
var simulation_result: Dictionary = {}
var active_stage_transitions: Dictionary = {}
var current_tool: ToolMode = ToolMode.SELECT
var active_palette_type: LaserObjectData.ObjectType = LaserObjectData.ObjectType.FIXED_MIRROR
var active_palette_rot: int = 0
var active_palette_color: Color = Color.RED
var active_palette_custom_data: Dictionary = {}
var active_tile_coord: Vector2i = Vector2i(0, 0)
var active_tile_type: BoardVisualGenerator.TileType = BoardVisualGenerator.TileType.MIDDLE
var active_tile_texture: Texture2D = null
var active_tile_rot: int = 0
var active_tile_rot_float: float = 0.0
var active_cell_asset: String = "cell_1"
var selected_cell_visual_pos: Vector2i = Vector2i(-1, -1)
var active_movable_area_id: String = "area_001"

# Outer Perimeter Border Visual Painting State
var active_border_asset: String = "border_1"
var active_border_rot: float = 0.0
var active_border_offset: float = 0.0
var active_border_scale_x: float = 1.0
var active_border_scale_y: float = 1.0
var hovered_border_side: String = ""
var hovered_border_index: int = -1
var selected_border_side: String = ""
var selected_border_index: int = -1

# Outer Perimeter Corner Visual Painting State
var active_corner_asset: String = "corner_1"
var active_corner_rot: float = 0.0
var active_corner_mirror_x: bool = false
var active_corner_mirror_y: bool = false
var active_corner_offset: float = 0.0
var active_corner_scale_x: float = 1.0
var active_corner_scale_y: float = 1.0
var hovered_corner_name: String = ""
var selected_corner_name: String = ""

var zoom_level: float = 1.0
var pan_offset: Vector2 = Vector2(100, 80)
var cell_size: float = 48.0
var show_grid_coords: bool = true
var show_laser_preview: bool = true

var is_panning: bool = false
var pan_start_mouse: Vector2 = Vector2.ZERO
var pan_start_offset: Vector2 = Vector2.ZERO
var hovered_stage_idx: int = -1
var hovered_cell: Vector2i = Vector2i(-1, -1)
var hovered_frame_piece: String = ""
var hovered_frame_stage: LaserStageData = null
var selected_objects: Array[LaserObjectData] = []
var drag_object: LaserObjectData = null
var drag_start_cell: Vector2i = Vector2i.ZERO
var drag_start_snapshot: LaserStageData = null
var is_dragging_object: bool = false
var is_box_selecting: bool = false
var box_select_start: Vector2 = Vector2.ZERO
var box_select_current: Vector2 = Vector2.ZERO
var is_brush_painting: bool = false
var is_brush_erasing: bool = false
var last_painted_cell: Vector2i = Vector2i(-999, -999)
var last_painted_stage: LaserStageData = null
var brush_snapshot: LaserStageData = null
var undo_manager: LevelEditorUndoManager = null

func _init() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	resized.connect(func(): queue_redraw())

func set_level(level: LaserLevelData, active_idx: int = 1) -> void:
	current_level = level
	if current_level != null:
		current_level.ensure_stages()
		stages = current_level.stages
	else:
		stages = []
	current_stage_idx = active_idx
	current_stage = get_stage_by_index(active_idx)
	selected_objects.clear()
	selection_changed.emit(selected_objects)
	recalculate_simulation()
	queue_redraw()

func set_stage(stage: LaserStageData) -> void:
	current_stage = stage
	if stage != null:
		current_stage_idx = stage.stage_index
		if not stages.has(stage):
			stages = [stage]
	else:
		stages = []
	selected_objects.clear()
	selection_changed.emit(selected_objects)
	recalculate_simulation()
	queue_redraw()

func set_active_stage(stage_idx: int) -> void:
	current_stage_idx = stage_idx
	current_stage = get_stage_by_index(stage_idx)
	if simulation_results.has(stage_idx):
		simulation_result = simulation_results[stage_idx]
	queue_redraw()

func set_side_by_side(enabled: bool) -> void:
	if is_side_by_side == enabled:
		return
	is_side_by_side = enabled
	recalculate_simulation()
	zoom_to_fit()

func set_hint_mode(active: bool) -> void:
	if is_hint_mode_active != active:
		is_hint_mode_active = active
		if not active and (current_tool == ToolMode.HINT_DRAW or current_tool == ToolMode.HINT_ERASE):
			current_tool = ToolMode.SELECT
		queue_redraw()

func is_hint_mode() -> bool:
	return is_hint_mode_active

func set_active_movable_area_id(area_id: String) -> void:
	active_movable_area_id = area_id
	queue_redraw()

func start_new_movable_area() -> String:
	if current_stage != null:
		active_movable_area_id = current_stage.get_next_movable_area_id()
	else:
		active_movable_area_id = "area_001"
	queue_redraw()
	return active_movable_area_id

func get_stage_by_index(idx: int) -> LaserStageData:
	for st in stages:
		if st != null and st.stage_index == idx:
			return st
	if current_level != null:
		return current_level.get_stage(idx)
	return current_stage

func get_stage_rect_in_cells(stage_idx: int) -> Rect2i:
	if not is_side_by_side:
		var st = get_stage_by_index(stage_idx)
		var w = st.grid_width if st != null else 6
		var h = st.grid_height if st != null else 6
		return Rect2i(0, 0, w, h)

	var accum_x: int = 0
	for st in stages:
		if st == null:
			continue
		var r := Rect2i(accum_x, 0, st.grid_width, st.grid_height)
		if st.stage_index == stage_idx:
			return r
		accum_x += st.grid_width + STAGE_GAP_CELLS

	return Rect2i(0, 0, 6, 6)

func get_visible_stages() -> Array[LaserStageData]:
	var res: Array[LaserStageData] = []
	if is_side_by_side:
		for s in stages:
			if s != null:
				res.append(s)
	elif current_stage != null:
		res.append(current_stage)
	return res

func get_total_bounding_rect_cells() -> Rect2i:
	var visible_stages = get_visible_stages()
	if visible_stages.is_empty():
		return Rect2i(0, 0, 6, 6)

	var min_x: int = 0
	var min_y: int = 0
	var max_x: int = 0
	var max_y: int = 0

	for i in range(visible_stages.size()):
		var st = visible_stages[i]
		if st == null:
			continue
		var r = get_stage_rect_in_cells(st.stage_index)
		if i == 0:
			min_x = r.position.x
			min_y = r.position.y
			max_x = r.position.x + r.size.x
			max_y = r.position.y + r.size.y
		else:
			min_x = min(min_x, r.position.x)
			min_y = min(min_y, r.position.y)
			max_x = max(max_x, r.position.x + r.size.x)
			max_y = max(max_y, r.position.y + r.size.y)

	return Rect2i(min_x, min_y, max(1, max_x - min_x), max(1, max_y - min_y))

func screen_to_stage_and_cell(screen_pos: Vector2) -> Dictionary:
	var local_world_pos = (screen_pos - pan_offset) / (cell_size * zoom_level)
	var world_cell = Vector2i(int(floor(local_world_pos.x)), int(floor(local_world_pos.y)))

	var visible_stages = stages if is_side_by_side else ([current_stage] if current_stage != null else [])
	for st in visible_stages:
		if st == null:
			continue
		var r = get_stage_rect_in_cells(st.stage_index)
		if world_cell.x >= r.position.x and world_cell.x < r.position.x + r.size.x and \
		   world_cell.y >= r.position.y and world_cell.y < r.position.y + r.size.y:
			var local_cell = world_cell - r.position
			return {
				"inside": true,
				"stage": st,
				"stage_idx": st.stage_index,
				"cell": local_cell,
				"world_cell": world_cell,
				"is_edge": false
			}
		# Check outer edge perimeter around the board (for outside laser sources, gates, exit gates)
		if world_cell.x >= r.position.x - 1 and world_cell.x <= r.position.x + r.size.x and \
		   world_cell.y >= r.position.y - 1 and world_cell.y <= r.position.y + r.size.y:
			var local_cell = world_cell - r.position
			if st.is_valid_edge_position(local_cell):
				return {
					"inside": true,
					"stage": st,
					"stage_idx": st.stage_index,
					"cell": local_cell,
					"world_cell": world_cell,
					"is_edge": true
				}

	return {
		"inside": false,
		"stage": null,
		"stage_idx": -1,
		"cell": Vector2i(-1, -1),
		"world_cell": world_cell,
		"is_edge": false
	}

func screen_to_stage_and_perimeter_border(screen_pos: Vector2) -> Dictionary:
	var c_sz = cell_size * zoom_level
	var visible_stages = stages if is_side_by_side else ([current_stage] if current_stage != null else [])
	var sides = ["top", "bottom", "left", "right"]
	for st in visible_stages:
		if st == null:
			continue
		var r = get_stage_rect_in_cells(st.stage_index)
		var board_pos = pan_offset + Vector2(r.position) * c_sz

		# 1. First test all PLACED border visuals with their actual transformed geometry
		for side in sides:
			var count = st.grid_width if (side == "top" or side == "bottom") else st.grid_height
			for i in range(count):
				if st.has_border_visual(side, i):
					var t_info := BoardVisualGenerator.get_border_piece_transform(st, board_pos, Vector2(c_sz, c_sz), side, i, zoom_level)
					var hit_rect: Rect2 = t_info.visual_rect.grow(max(4.0 * zoom_level, (c_sz * 0.5 - min(t_info.visual_rect.size.x, t_info.visual_rect.size.y) * 0.5)))
					if hit_rect.has_point(screen_pos):
						return {
							"inside": true,
							"stage": st,
							"stage_idx": st.stage_index,
							"side": side,
							"index": i,
							"rect": t_info.visual_rect,
							"center": t_info.center,
							"is_placed": true
						}

		# 2. If no placed border is hit, test empty perimeter slots
		for side in sides:
			var count = st.grid_width if (side == "top" or side == "bottom") else st.grid_height
			for i in range(count):
				if not st.has_border_visual(side, i):
					var off_val := (active_border_offset if current_tool == ToolMode.BORDER_PAINT else 0.0)
					var t_info := BoardVisualGenerator.get_border_piece_transform(st, board_pos, Vector2(c_sz, c_sz), side, i, zoom_level, {
						"asset": active_border_asset,
						"rotation": active_border_rot,
						"offset": off_val,
						"scale_x": active_border_scale_x,
						"scale_y": active_border_scale_y
					})
					var base_rect := BoardVisualGenerator.get_perimeter_border_rect(board_pos, Vector2(c_sz, c_sz), st.grid_width, st.grid_height, side, i, off_val)
					if base_rect.has_point(screen_pos) or t_info.visual_rect.has_point(screen_pos):
						return {
							"inside": true,
							"stage": st,
							"stage_idx": st.stage_index,
							"side": side,
							"index": i,
							"rect": base_rect,
							"center": t_info.center,
							"is_placed": false
						}

	return { "inside": false, "stage": null, "stage_idx": -1, "side": "", "index": -1, "rect": Rect2(), "center": Vector2.ZERO, "is_placed": false }

func screen_to_stage_and_outer_corner(screen_pos: Vector2) -> Dictionary:
	var c_sz = cell_size * zoom_level
	var visible_stages = stages if is_side_by_side else ([current_stage] if current_stage != null else [])
	var corners = ["top_left", "top_right", "bottom_left", "bottom_right"]
	for st in visible_stages:
		if st == null:
			continue
		var r = get_stage_rect_in_cells(st.stage_index)
		var board_pos = pan_offset + Vector2(r.position) * c_sz

		# 1. First test all PLACED corner visuals
		for c_name in corners:
			if st.has_corner_visual(c_name):
				var t_info := BoardVisualGenerator.get_corner_piece_transform(st, board_pos, Vector2(c_sz, c_sz), c_name, zoom_level)
				var hit_rect: Rect2 = t_info.visual_rect.grow(max(4.0 * zoom_level, (c_sz * 0.5 - min(t_info.visual_rect.size.x, t_info.visual_rect.size.y) * 0.5)))
				if hit_rect.has_point(screen_pos):
					return {
						"inside": true,
						"stage": st,
						"stage_idx": st.stage_index,
						"corner": c_name,
						"rect": t_info.visual_rect,
						"center": t_info.center,
						"is_placed": true
					}

		# 2. Test empty corner slots
		for c_name in corners:
			if not st.has_corner_visual(c_name):
				var off_val := (active_corner_offset if current_tool == ToolMode.CORNER_PAINT else 0.0)
				var t_info := BoardVisualGenerator.get_corner_piece_transform(st, board_pos, Vector2(c_sz, c_sz), c_name, zoom_level, {
					"asset": active_corner_asset,
					"rotation": active_corner_rot,
					"mirror_x": active_corner_mirror_x,
					"mirror_y": active_corner_mirror_y,
					"offset": off_val,
					"scale_x": active_corner_scale_x,
					"scale_y": active_corner_scale_y
				})
				var base_rect := BoardVisualGenerator.get_outer_corner_rect(board_pos, Vector2(c_sz, c_sz), st.grid_width, st.grid_height, c_name, off_val)
				if base_rect.has_point(screen_pos) or t_info.visual_rect.has_point(screen_pos):
					return {
						"inside": true,
						"stage": st,
						"stage_idx": st.stage_index,
						"corner": c_name,
						"rect": base_rect,
						"center": t_info.center,
						"is_placed": false
					}

	return { "inside": false, "stage": null, "stage_idx": -1, "corner": "", "rect": Rect2(), "center": Vector2.ZERO, "is_placed": false }

func stage_cell_to_screen(stage_idx: int, local_cell: Vector2i) -> Vector2:
	var r = get_stage_rect_in_cells(stage_idx)
	return pan_offset + Vector2(r.position + local_cell) * cell_size * zoom_level

func grid_to_screen(cell: Vector2i) -> Vector2:
	return stage_cell_to_screen(current_stage_idx, cell)

func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var hit = screen_to_stage_and_cell(screen_pos)
	if hit.inside:
		return hit.cell
	var local_pos = (screen_pos - pan_offset) / (cell_size * zoom_level)
	return Vector2i(int(floor(local_pos.x)), int(floor(local_pos.y)))

func recalculate_simulation() -> void:
	simulation_results.clear()
	active_stage_transitions.clear()
	if not show_laser_preview:
		simulation_result = {}
		queue_redraw()
		return

	if is_side_by_side:
		var carried_laser_active: bool = false
		var carried_laser_color: Color = Color(1.0, 0.2, 0.2, 1.0)

		var sorted_stages: Array[LaserStageData] = []
		for st in stages:
			if st != null:
				sorted_stages.append(st)
		sorted_stages.sort_custom(func(a, b): return a.stage_index < b.stage_index)

		for st in sorted_stages:
			var has_local_sources: bool = false
			for obj in st.objects:
				if obj != null and obj.enabled and obj.type == LaserObjectData.ObjectType.LASER_SOURCE:
					has_local_sources = true
					break

			var allow_emission: bool = false
			var in_color: Color = Color(-1, -1, -1, -1)

			if has_local_sources:
				allow_emission = true
			elif carried_laser_active:
				allow_emission = true
				in_color = carried_laser_color
			else:
				allow_emission = false

			var sim = LaserSimulation.simulate_stage(st, allow_emission, in_color)
			simulation_results[st.stage_index] = sim

			var exit_hit: bool = false
			var hit_color: Color = Color(1.0, 0.2, 0.2, 1.0)
			for seg in sim.get("segments", []):
				if seg.get("hit_type", "") in ["exit_gate", "goal"]:
					exit_hit = true
					hit_color = seg.get("color", hit_color)
					break
				if st.exit_point != Vector2i(-1, -1) and (seg.get("end", Vector2i(-1, -1)) == st.exit_point or seg.get("hit_pos", Vector2i(-1, -1)) == st.exit_point):
					exit_hit = true
					hit_color = seg.get("color", hit_color)
					break

			if exit_hit:
				active_stage_transitions[st.stage_index] = hit_color

			carried_laser_active = exit_hit
			carried_laser_color = hit_color
	else:
		if current_stage != null:
			simulation_results[current_stage.stage_index] = LaserSimulation.simulate_stage(current_stage, true)

	if current_stage != null and simulation_results.has(current_stage.stage_index):
		simulation_result = simulation_results[current_stage.stage_index]
	else:
		simulation_result = {}
	queue_redraw()

func center_view() -> void:
	var b_rect = get_total_bounding_rect_cells()
	var total_px = Vector2(b_rect.size) * cell_size * zoom_level
	var center_board_offset = Vector2(b_rect.position) * cell_size * zoom_level
	pan_offset = (size - total_px) * 0.5 - center_board_offset + Vector2(0, 36.0 * zoom_level)
	queue_redraw()

func zoom_to_fit() -> void:
	var b_rect = get_total_bounding_rect_cells()
	var total_w_px = float(b_rect.size.x) * cell_size
	var total_h_px = float(b_rect.size.y) * cell_size
	var fit_zoom_x = (size.x - 120.0) / max(1.0, total_w_px)
	var fit_zoom_y = (size.y - 190.0) / max(1.0, total_h_px)
	zoom_level = clamp(min(fit_zoom_x, fit_zoom_y), 0.25, 2.5)
	center_view()

func focus_stage(stage_idx: int) -> void:
	set_active_stage(stage_idx)
	var r = get_stage_rect_in_cells(stage_idx)
	var stage_px_center = (Vector2(r.position) + Vector2(r.size) * 0.5) * cell_size * zoom_level
	pan_offset = size * 0.5 - stage_px_center + Vector2(0, 36.0 * zoom_level)
	queue_redraw()

func _apply_zoom(factor: float, anchor_pos: Vector2) -> void:
	var old_zoom = zoom_level
	var new_zoom = clamp(zoom_level * factor, 0.25, 3.0)
	if is_equal_approx(old_zoom, new_zoom):
		return
	pan_offset = anchor_pos - (anchor_pos - pan_offset) * (new_zoom / old_zoom)
	zoom_level = new_zoom
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_apply_zoom(1.15, mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_apply_zoom(0.87, mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				is_panning = true
				pan_start_mouse = mb.position
				pan_start_offset = pan_offset
			else:
				is_panning = false
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if Input.is_key_pressed(KEY_SPACE):
				if mb.pressed:
					is_panning = true
					pan_start_mouse = mb.position
					pan_start_offset = pan_offset
				else:
					is_panning = false
				accept_event()
			else:
				_handle_left_click(mb)
				accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				var hit = screen_to_stage_and_cell(mb.position)
				var border_hit = screen_to_stage_and_perimeter_border(mb.position)
				var corner_hit = screen_to_stage_and_outer_corner(mb.position)

				if current_tool == ToolMode.BORDER_PAINT and border_hit.inside:
					var st: LaserStageData = border_hit.stage
					if st.stage_index != current_stage_idx:
						current_stage_idx = st.stage_index
						current_stage = st
						stage_activated.emit(current_stage_idx)
					_erase_border(st, border_hit.side, border_hit.index)
					accept_event()
					return

				if current_tool == ToolMode.CORNER_PAINT and corner_hit.inside:
					var st: LaserStageData = corner_hit.stage
					if st.stage_index != current_stage_idx:
						current_stage_idx = st.stage_index
						current_stage = st
						stage_activated.emit(current_stage_idx)
					_erase_corner(st, corner_hit.corner)
					accept_event()
					return

				if hit.inside:
					var st: LaserStageData = hit.stage
					var cell: Vector2i = hit.cell
					if st.stage_index != current_stage_idx:
						current_stage_idx = st.stage_index
						current_stage = st
						stage_activated.emit(current_stage_idx)
					if current_tool == ToolMode.TILE_PAINT:
						_erase_board_tile(st, cell)
						accept_event()
						return
					var obj = st.get_object_at(cell)
					if obj != null:
						var snap = st.duplicate_data() if undo_manager != null else null
						obj.rotation_deg = (obj.rotation_deg + 45) % 360
						object_modified.emit(obj)
						recalculate_simulation()
						if undo_manager != null and snap != null:
							undo_manager.commit_snapshot(snap, st)
						stage_dirty_needed.emit()
						queue_redraw()
				accept_event()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if is_panning:
			pan_offset = pan_start_offset + (mm.position - pan_start_mouse)
			queue_redraw()
			accept_event()
		elif is_box_selecting:
			box_select_current = mm.position
			queue_redraw()
		elif is_brush_painting:
			var hit = screen_to_stage_and_cell(mm.position)
			var border_hit = screen_to_stage_and_perimeter_border(mm.position)
			var corner_hit = screen_to_stage_and_outer_corner(mm.position)
			if current_tool == ToolMode.CORNER_PAINT and corner_hit.inside:
				_paint_corner(corner_hit.stage, corner_hit.corner)
			elif current_tool == ToolMode.BORDER_PAINT and border_hit.inside:
				_paint_border(border_hit.stage, border_hit.side, border_hit.index)
			elif current_tool == ToolMode.HINT_DRAW and hit.inside and (hit.cell != last_painted_cell or hit.stage != last_painted_stage):
				last_painted_cell = hit.cell
				last_painted_stage = hit.stage
				hit.stage.add_hint_point(hit.cell)
				hint_path_modified.emit(hit.stage)
				stage_dirty_needed.emit()
				queue_redraw()
			elif hit.inside and (hit.cell != last_painted_cell or hit.stage != last_painted_stage):
				if current_tool == ToolMode.TILE_PAINT:
					_paint_board_tile(hit.stage, hit.cell)
				else:
					_paint_cell(hit.stage, hit.cell)
		elif is_brush_erasing:
			var hit = screen_to_stage_and_cell(mm.position)
			var border_hit = screen_to_stage_and_perimeter_border(mm.position)
			var corner_hit = screen_to_stage_and_outer_corner(mm.position)
			if current_tool == ToolMode.CORNER_ERASE and corner_hit.inside:
				_erase_corner(corner_hit.stage, corner_hit.corner)
			elif current_tool == ToolMode.BORDER_ERASE and border_hit.inside:
				_erase_border(border_hit.stage, border_hit.side, border_hit.index)
			elif current_tool == ToolMode.HINT_ERASE and hit.inside and (hit.cell != last_painted_cell or hit.stage != last_painted_stage):
				last_painted_cell = hit.cell
				last_painted_stage = hit.stage
				if hit.stage.remove_hint_point(hit.cell):
					hint_path_modified.emit(hit.stage)
					stage_dirty_needed.emit()
					queue_redraw()
			elif hit.inside and (hit.cell != last_painted_cell or hit.stage != last_painted_stage):
				if current_tool == ToolMode.TILE_ERASE:
					_erase_board_tile(hit.stage, hit.cell)
				else:
					_erase_cell(hit.stage, hit.cell)
		elif is_dragging_object and drag_object != null and current_stage != null:
			var hit = screen_to_stage_and_cell(mm.position)
			if hit.inside and hit.stage == current_stage:
				var target_cell: Vector2i = hit.cell
				if drag_object.grid_pos != target_cell:
					var old_pos = drag_object.grid_pos
					var new_pos = current_stage.step_object_orthogonally(drag_object, target_cell)
					if new_pos != old_pos:
						recalculate_simulation()
						queue_redraw()
		else:
			var hit = screen_to_stage_and_cell(mm.position)
			var border_hit = screen_to_stage_and_perimeter_border(mm.position)
			var corner_hit = screen_to_stage_and_outer_corner(mm.position)
			var old_hp := hovered_frame_piece
			var old_hs := hovered_frame_stage
			var old_bs := hovered_border_side
			var old_bi := hovered_border_index
			var old_cn := hovered_corner_name

			if corner_hit.inside:
				hovered_corner_name = corner_hit.corner
			else:
				hovered_corner_name = ""

			if border_hit.inside:
				hovered_border_side = border_hit.side
				hovered_border_index = border_hit.index
			else:
				hovered_border_side = ""
				hovered_border_index = -1

			if hit.inside:
				hovered_frame_piece = ""
				hovered_frame_stage = null
				if hit.stage_idx != hovered_stage_idx or hit.cell != hovered_cell or hovered_border_side != old_bs or hovered_border_index != old_bi or hovered_corner_name != old_cn:
					hovered_stage_idx = hit.stage_idx
					hovered_cell = hit.cell
					queue_redraw()
				elif old_hp != "":
					queue_redraw()
			else:
				if hovered_stage_idx != -1 or hovered_cell != Vector2i(-1, -1) or hovered_border_side != old_bs or hovered_border_index != old_bi or hovered_corner_name != old_cn:
					hovered_stage_idx = -1
					hovered_cell = Vector2i(-1, -1)
					queue_redraw()
				var found_piece := ""
				var found_stage: LaserStageData = null
				var c_sz := cell_size * zoom_level
				for st in get_visible_stages():
					if st != null and st.has_board_margins() and not st.board_image_path.is_empty():
						var b_tex := BoardLayoutManager.get_board_texture(st.board_image_path)
						if b_tex != null:
							var r = get_stage_rect_in_cells(st.stage_index)
							var b_pos = pan_offset + Vector2(r.position) * c_sz
							var b_sz = Vector2(r.size) * c_sz
							var piece := BoardLayoutManager.get_frame_piece_at_point(
								mm.position,
								Rect2(b_pos, b_sz),
								st.get_board_margins(),
								b_tex.get_size(),
								st.grid_width,
								st.grid_height
							)
							if not piece.is_empty():
								found_piece = piece
								found_stage = st
								break
				if found_piece != hovered_frame_piece or found_stage != hovered_frame_stage:
					hovered_frame_piece = found_piece
					hovered_frame_stage = found_stage
					queue_redraw()

func _handle_left_click(mb: InputEventMouseButton) -> void:
	if mb.pressed:
		if is_inside_tree():
			grab_focus()

		# 1. Outer Corner Tool Mode Handling
		if current_tool == ToolMode.CORNER_PAINT or current_tool == ToolMode.CORNER_ERASE:
			var ch = screen_to_stage_and_outer_corner(mb.position)
			if ch.inside:
				var cst: LaserStageData = ch.stage
				if cst.stage_index != current_stage_idx:
					current_stage_idx = cst.stage_index
					current_stage = cst
					stage_activated.emit(current_stage_idx)
				if current_tool == ToolMode.CORNER_PAINT:
					is_brush_painting = true
					_paint_corner(cst, ch.corner)
				else:
					is_brush_erasing = true
					_erase_corner(cst, ch.corner)
				return

		# 2. Outer Border Tool Mode Handling
		if current_tool == ToolMode.BORDER_PAINT or current_tool == ToolMode.BORDER_ERASE:
			var bh = screen_to_stage_and_perimeter_border(mb.position)
			if bh.inside:
				var bst: LaserStageData = bh.stage
				if bst.stage_index != current_stage_idx:
					current_stage_idx = bst.stage_index
					current_stage = bst
					stage_activated.emit(current_stage_idx)
				if current_tool == ToolMode.BORDER_PAINT:
					is_brush_painting = true
					_paint_border(bst, bh.side, bh.index)
				else:
					is_brush_erasing = true
					_erase_border(bst, bh.side, bh.index)
				return

		var hit = screen_to_stage_and_cell(mb.position)

		# 3. Outer Grid Inspection when in SELECT mode
		if current_tool == ToolMode.SELECT:
			var ch = screen_to_stage_and_outer_corner(mb.position)
			if ch.inside:
				var cst: LaserStageData = ch.stage
				if cst.has_corner_visual(ch.corner):
					if cst.stage_index != current_stage_idx:
						current_stage_idx = cst.stage_index
						current_stage = cst
						stage_activated.emit(current_stage_idx)
					selected_corner_name = ch.corner
					selected_border_side = ""
					selected_border_index = -1
					selected_cell_visual_pos = Vector2i(-1, -1)
					corner_visual_selected.emit(cst, ch.corner, cst.get_corner_visual(ch.corner))
					selected_objects.clear()
					selection_changed.emit(selected_objects)
					queue_redraw()
					return

			var bh = screen_to_stage_and_perimeter_border(mb.position)
			if bh.inside:
				var bst: LaserStageData = bh.stage
				if bst.has_border_visual(bh.side, bh.index):
					if bst.stage_index != current_stage_idx:
						current_stage_idx = bst.stage_index
						current_stage = bst
						stage_activated.emit(current_stage_idx)
					selected_border_side = bh.side
					selected_border_index = bh.index
					selected_corner_name = ""
					selected_cell_visual_pos = Vector2i(-1, -1)
					border_visual_selected.emit(bst, bh.side, bh.index, bst.get_border_visual(bh.side, bh.index))
					selected_objects.clear()
					selection_changed.emit(selected_objects)
					queue_redraw()
					return

		if not hit.inside:
			var c_sz := cell_size * zoom_level
			var clicked_frame_piece := ""
			var target_st: LaserStageData = null
			for st in get_visible_stages():
				if st != null and st.has_board_margins() and not st.board_image_path.is_empty():
					var b_tex := BoardLayoutManager.get_board_texture(st.board_image_path)
					if b_tex != null:
						var r = get_stage_rect_in_cells(st.stage_index)
						var b_pos = pan_offset + Vector2(r.position) * c_sz
						var b_sz = Vector2(r.size) * c_sz
						var piece := BoardLayoutManager.get_frame_piece_at_point(
							mb.position,
							Rect2(b_pos, b_sz),
							st.get_board_margins(),
							b_tex.get_size(),
							st.grid_width,
							st.grid_height
						)
						if not piece.is_empty():
							clicked_frame_piece = piece
							target_st = st
							break
			if not clicked_frame_piece.is_empty() and target_st != null:
				if target_st.stage_index != current_stage_idx:
					current_stage_idx = target_st.stage_index
					current_stage = target_st
					stage_activated.emit(current_stage_idx)
				var snap = target_st.duplicate_data() if undo_manager != null else null
				target_st.toggle_frame_piece(clicked_frame_piece)
				if undo_manager != null and snap != null:
					undo_manager.commit_snapshot(snap, target_st)
				stage_dirty_needed.emit()
				queue_redraw()
				return

			if not Input.is_key_pressed(KEY_CTRL):
				selected_objects.clear()
				selection_changed.emit(selected_objects)
			queue_redraw()
			return

		var st: LaserStageData = hit.stage
		var cell: Vector2i = hit.cell

		if st.stage_index != current_stage_idx:
			current_stage_idx = st.stage_index
			current_stage = st
			stage_activated.emit(current_stage_idx)

		cell_clicked.emit(cell, MOUSE_BUTTON_LEFT)

		match current_tool:
			ToolMode.SELECT:
				var obj = st.get_object_at(cell)

				if obj != null:
					if obj.movable_area_id.is_empty():
						var ma = st.get_movable_area_at(obj.grid_pos)
						if ma != null and not ma.movable_area_id.is_empty():
							obj.movable_area_id = ma.movable_area_id
					if not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_SHIFT):
						selected_objects.clear()
					if not selected_objects.has(obj):
						selected_objects.append(obj)
					drag_object = obj
					drag_start_cell = obj.grid_pos
					drag_start_snapshot = st.duplicate_data() if undo_manager != null else null
					is_dragging_object = true
					object_selected.emit(obj)
					selection_changed.emit(selected_objects)
				elif st.has_cell_visual(cell):
					selected_cell_visual_pos = cell
					selected_border_side = ""
					selected_border_index = -1
					selected_corner_name = ""
					cell_visual_selected.emit(st, cell, st.get_cell_visual(cell))
					if not Input.is_key_pressed(KEY_CTRL):
						selected_objects.clear()
						selection_changed.emit(selected_objects)
				else:
					selected_cell_visual_pos = Vector2i(-1, -1)
					selected_border_side = ""
					selected_border_index = -1
					selected_corner_name = ""
					cell_visual_selected.emit(st, cell, {})
					if not Input.is_key_pressed(KEY_CTRL):
						selected_objects.clear()
						selection_changed.emit(selected_objects)
					is_box_selecting = true
					box_select_start = mb.position
					box_select_current = mb.position
				queue_redraw()

			ToolMode.PAINT:
				is_brush_painting = true
				_paint_cell(st, cell)

			ToolMode.ROTATE:
				var obj = st.get_object_at(cell)
				if obj != null:
					var snap = st.duplicate_data() if undo_manager != null else null
					obj.rotation_deg = (obj.rotation_deg + 45) % 360
					object_modified.emit(obj)
					recalculate_simulation()
					if undo_manager != null and snap != null:
						undo_manager.commit_snapshot(snap, st)
					stage_dirty_needed.emit()
					queue_redraw()

			ToolMode.ERASE:
				is_brush_erasing = true
				_erase_cell(st, cell)

			ToolMode.TILE_PAINT:
				is_brush_painting = true
				_paint_board_tile(st, cell)

			ToolMode.TILE_ERASE:
				is_brush_erasing = true
				_erase_board_tile(st, cell)

			ToolMode.HINT_DRAW:
				is_brush_painting = true
				last_painted_cell = cell
				last_painted_stage = st
				st.add_hint_point(cell)
				hint_path_modified.emit(st)
				stage_dirty_needed.emit()
				queue_redraw()

			ToolMode.HINT_ERASE:
				is_brush_erasing = true
				last_painted_cell = cell
				last_painted_stage = st
				if st.remove_hint_point(cell):
					hint_path_modified.emit(st)
					stage_dirty_needed.emit()
					queue_redraw()

			ToolMode.MOVE:
				var obj = st.get_object_at(cell)
				if obj != null:
					drag_object = obj
					drag_start_cell = obj.grid_pos
					drag_start_snapshot = st.duplicate_data() if undo_manager != null else null
					is_dragging_object = true

	else:
		if is_brush_painting or is_brush_erasing:
			if undo_manager != null and brush_snapshot != null and current_stage != null:
				undo_manager.commit_snapshot(brush_snapshot, current_stage)
			is_brush_painting = false
			is_brush_erasing = false
			last_painted_cell = Vector2i(-999, -999)
			last_painted_stage = null
			brush_snapshot = null

		if is_dragging_object:
			if drag_object != null and drag_object.grid_pos != drag_start_cell:
				if undo_manager != null and drag_start_snapshot != null and current_stage != null:
					undo_manager.commit_snapshot(drag_start_snapshot, current_stage)
				object_modified.emit(drag_object)
				stage_dirty_needed.emit()
			is_dragging_object = false
			drag_object = null
			drag_start_snapshot = null
			recalculate_simulation()
			queue_redraw()

		if is_box_selecting:
			is_box_selecting = false
			_finish_box_select()
			queue_redraw()

func _paint_cell(st: LaserStageData, cell: Vector2i) -> void:
	if st == null:
		return
	if not st.is_inside_grid(cell) and not st.is_valid_edge_position(cell):
		return
	last_painted_cell = cell
	last_painted_stage = st

	var snap = st.duplicate_data() if undo_manager != null else null

	# --- 1. Edge-specific object handling (LASER_SOURCE, GATE, EXIT_GATE, GOAL) ---
	if active_palette_type in [LaserObjectData.ObjectType.LASER_SOURCE, LaserObjectData.ObjectType.GATE, LaserObjectData.ObjectType.EXIT_GATE, LaserObjectData.ObjectType.GOAL]:
		var target_edge_cell := cell
		var effective_rot := active_palette_rot
		if not st.is_valid_edge_position(cell):
			if active_palette_rot == 0:
				target_edge_cell = Vector2i(-1, cell.y)
			elif active_palette_rot == 180:
				target_edge_cell = Vector2i(st.grid_width, cell.y)
			elif active_palette_rot == 90:
				target_edge_cell = Vector2i(cell.x, -1)
			elif active_palette_rot == 270:
				target_edge_cell = Vector2i(cell.x, st.grid_height)
			else:
				target_edge_cell = Vector2i(-1, cell.y)
		else:
			if target_edge_cell.x == -1:
				effective_rot = 0
			elif target_edge_cell.x == st.grid_width:
				effective_rot = 180
			elif target_edge_cell.y == -1:
				effective_rot = 90
			elif target_edge_cell.y == st.grid_height:
				effective_rot = 270

		var existing_edge_obj = st.get_object_at(target_edge_cell)
		if existing_edge_obj != null:
			st.remove_object(existing_edge_obj)

		if active_palette_type == LaserObjectData.ObjectType.LASER_SOURCE:
			for o in st.objects:
				if o != null and o.type == LaserObjectData.ObjectType.LASER_SOURCE:
					st.remove_object(o)
					break
			st.entry_point = target_edge_cell
			if target_edge_cell.x == -1:
				st.entry_direction = LaserStageData.Direction.RIGHT
			elif target_edge_cell.x == st.grid_width:
				st.entry_direction = LaserStageData.Direction.LEFT
			elif target_edge_cell.y == -1:
				st.entry_direction = LaserStageData.Direction.DOWN
			elif target_edge_cell.y == st.grid_height:
				st.entry_direction = LaserStageData.Direction.UP
		elif active_palette_type == LaserObjectData.ObjectType.EXIT_GATE or active_palette_type == LaserObjectData.ObjectType.GOAL:
			st.exit_point = target_edge_cell
			if target_edge_cell.x == -1:
				st.exit_direction = LaserStageData.Direction.LEFT
			elif target_edge_cell.x == st.grid_width:
				st.exit_direction = LaserStageData.Direction.RIGHT
			elif target_edge_cell.y == -1:
				st.exit_direction = LaserStageData.Direction.UP
			elif target_edge_cell.y == st.grid_height:
				st.exit_direction = LaserStageData.Direction.DOWN

		var new_obj = LaserObjectData.create(active_palette_type, target_edge_cell, effective_rot)
		new_obj.color = active_palette_color
		st.add_object(new_obj)
		selected_objects = [new_obj]
		object_selected.emit(new_obj)
		selection_changed.emit(selected_objects)

	# --- 2. MOVABLE_AREA tile-painting workflow ---
	elif active_palette_type == LaserObjectData.ObjectType.MOVABLE_AREA:
		if not st.is_inside_grid(cell):
			return

		var target_area_id := active_movable_area_id
		if target_area_id.is_empty():
			if not selected_objects.is_empty() and selected_objects[0] != null and selected_objects[0].type == LaserObjectData.ObjectType.MOVABLE_AREA and not selected_objects[0].movable_area_id.is_empty():
				target_area_id = selected_objects[0].movable_area_id
			elif not selected_objects.is_empty() and selected_objects[0] != null and not selected_objects[0].movable_area_id.is_empty():
				target_area_id = selected_objects[0].movable_area_id
			else:
				var all_ids := st.get_all_movable_area_ids()
				if all_ids.is_empty():
					target_area_id = "area_001"
				else:
					target_area_id = all_ids[0]
			active_movable_area_id = target_area_id

		var existing_area = st.get_movable_area_at(cell)
		if existing_area != null:
			existing_area.color = active_palette_color
			existing_area.movable_area_id = target_area_id
			object_modified.emit(existing_area)
		else:
			var new_area = LaserObjectData.create(LaserObjectData.ObjectType.MOVABLE_AREA, cell, 0)
			new_area.color = active_palette_color
			new_area.movable_area_id = target_area_id
			st.add_object(new_area)
			selected_objects = [new_area]
			object_selected.emit(new_area)
			selection_changed.emit(selected_objects)

		# If an existing foreground movable object sits on this cell, associate it
		var fg = st.get_foreground_object_at(cell)
		if fg != null and (fg.movable or fg.type == LaserObjectData.ObjectType.MOVABLE_MIRROR):
			fg.movable = true
			if fg.movable_area_id.is_empty():
				fg.movable_area_id = target_area_id

	# --- 3. Normal playable grid object placement & clean replacement (Requirements 3 & 4) ---
	else:
		if not st.is_inside_grid(cell):
			return

		var existing_fg = st.get_foreground_object_at(cell)
		if existing_fg != null:
			st.remove_object(existing_fg)

		var new_obj = LaserObjectData.create(active_palette_type, cell, active_palette_rot)
		new_obj.color = active_palette_color

		var under_area = st.get_movable_area_at(cell)
		if under_area != null and (new_obj.movable or new_obj.type == LaserObjectData.ObjectType.MOVABLE_MIRROR):
			new_obj.movable = true
			if not under_area.movable_area_id.is_empty():
				new_obj.movable_area_id = under_area.movable_area_id
			else:
				under_area.movable_area_id = "area_%s" % new_obj.id
				new_obj.movable_area_id = under_area.movable_area_id

		if active_palette_type == LaserObjectData.ObjectType.CUSTOM:
			var c_data = active_palette_custom_data
			if c_data.is_empty():
				var all_elems = CustomElementsManager.load_elements()
				if not all_elems.is_empty():
					c_data = all_elems[0]
			if not c_data.is_empty():
				new_obj.properties["custom_id"] = c_data.get("id", "custom_1")
				new_obj.properties["custom_name"] = c_data.get("name", "Custom")
				new_obj.properties["custom_index"] = c_data.get("index", 0)
				new_obj.properties["scene_path"] = c_data.get("scene_path", "")
				if c_data.has("color"):
					new_obj.color = c_data["color"]
			else:
				new_obj.properties["custom_name"] = "Custom"
				new_obj.properties["scene_path"] = ""

		st.add_object(new_obj)
		selected_objects = [new_obj]
		object_selected.emit(new_obj)
		selection_changed.emit(selected_objects)

	recalculate_simulation()
	if undo_manager != null and snap != null:
		undo_manager.commit_snapshot(snap, st)
	stage_dirty_needed.emit()
	queue_redraw()

func _erase_cell(st: LaserStageData, cell: Vector2i) -> void:
	if st == null or (not st.is_inside_grid(cell) and not st.is_valid_edge_position(cell)):
		return
	last_painted_cell = cell
	last_painted_stage = st
	var snap = st.duplicate_data() if undo_manager != null else null
	var target = st.get_movable_area_at(cell) if active_palette_type == LaserObjectData.ObjectType.MOVABLE_AREA else (st.get_foreground_object_at(cell) if st.get_foreground_object_at(cell) != null else st.get_object_at(cell))
	if target != null and st.remove_object(target):
		recalculate_simulation()
		if undo_manager != null and snap != null:
			undo_manager.commit_snapshot(snap, st)
		stage_dirty_needed.emit()
		queue_redraw()

func _paint_board_tile(st: LaserStageData, cell: Vector2i) -> void:
	if st == null or not st.is_inside_grid(cell):
		return
	last_painted_cell = cell
	last_painted_stage = st
	var snap = st.duplicate_data() if undo_manager != null else null
	var t_rot: float = active_tile_rot_float
	var asset_str: String = active_cell_asset
	if asset_str.is_empty():
		st.ensure_default_visual_libraries()
		if not st.cell_assets.is_empty():
			asset_str = str(st.cell_assets[0].get("id", "cell_1"))
	st.set_cell_visual(cell, asset_str, t_rot)
	selected_cell_visual_pos = cell
	cell_visual_selected.emit(st, cell, st.get_cell_visual(cell))
	if undo_manager != null and snap != null:
		undo_manager.commit_snapshot(snap, st)
	stage_dirty_needed.emit()
	queue_redraw()

func _erase_board_tile(st: LaserStageData, cell: Vector2i) -> void:
	if st == null or not st.is_inside_grid(cell):
		return
	last_painted_cell = cell
	last_painted_stage = st
	var snap = st.duplicate_data() if undo_manager != null else null
	st.remove_cell_visual(cell)
	if selected_cell_visual_pos == cell:
		selected_cell_visual_pos = Vector2i(-1, -1)
		cell_visual_selected.emit(st, cell, {})
	if undo_manager != null and snap != null:
		undo_manager.commit_snapshot(snap, st)
	stage_dirty_needed.emit()
	queue_redraw()

func _paint_border(st: LaserStageData, side: String, index: int) -> void:
	if st == null or side.is_empty() or index < 0:
		return
	var snap = st.duplicate_data() if undo_manager != null else null
	var asset_str: String = active_border_asset
	if asset_str.is_empty():
		st.ensure_default_visual_libraries()
		if not st.border_assets.is_empty():
			asset_str = str(st.border_assets[0].get("id", "border_1"))
	st.set_border_visual(side, index, asset_str, active_border_rot, active_border_offset, active_border_scale_x, active_border_scale_y)
	selected_border_side = side
	selected_border_index = index
	border_visual_selected.emit(st, side, index, st.get_border_visual(side, index))
	if undo_manager != null and snap != null:
		undo_manager.commit_snapshot(snap, st)
	stage_dirty_needed.emit()
	queue_redraw()

func _erase_border(st: LaserStageData, side: String, index: int) -> void:
	if st == null or side.is_empty() or index < 0:
		return
	var snap = st.duplicate_data() if undo_manager != null else null
	st.remove_border_visual(side, index)
	if selected_border_side == side and selected_border_index == index:
		selected_border_side = ""
		selected_border_index = -1
		border_visual_selected.emit(st, side, index, {})
	if undo_manager != null and snap != null:
		undo_manager.commit_snapshot(snap, st)
	stage_dirty_needed.emit()
	queue_redraw()

func _paint_corner(st: LaserStageData, corner: String) -> void:
	if st == null or corner.is_empty():
		return
	var snap = st.duplicate_data() if undo_manager != null else null
	var asset_str: String = active_corner_asset
	if asset_str.is_empty():
		st.ensure_default_visual_libraries()
		if not st.corner_assets.is_empty():
			asset_str = str(st.corner_assets[0].get("id", "corner_1"))
	st.set_corner_visual(corner, asset_str, active_corner_rot, active_corner_mirror_x, active_corner_mirror_y, active_corner_offset, active_corner_scale_x, active_corner_scale_y)
	selected_corner_name = corner
	corner_visual_selected.emit(st, corner, st.get_corner_visual(corner))
	if undo_manager != null and snap != null:
		undo_manager.commit_snapshot(snap, st)
	stage_dirty_needed.emit()
	queue_redraw()

func _erase_corner(st: LaserStageData, corner: String) -> void:
	if st == null or corner.is_empty():
		return
	var snap = st.duplicate_data() if undo_manager != null else null
	st.remove_corner_visual(corner)
	if selected_corner_name == corner:
		selected_corner_name = ""
		corner_visual_selected.emit(st, corner, {})
	if undo_manager != null and snap != null:
		undo_manager.commit_snapshot(snap, st)
	stage_dirty_needed.emit()
	queue_redraw()

func _finish_box_select() -> void:
	var rect := Rect2(box_select_start, box_select_current - box_select_start).abs()
	if rect.size.length_squared() < 16.0:
		return
	if current_stage == null:
		return

	if not Input.is_key_pressed(KEY_CTRL):
		selected_objects.clear()

	var visible_stages = stages if is_side_by_side else ([current_stage] if current_stage != null else [])
	var c_sz = cell_size * zoom_level

	for st in visible_stages:
		if st == null:
			continue
		var r = get_stage_rect_in_cells(st.stage_index)
		var board_pos = pan_offset + Vector2(r.position) * c_sz
		for obj in st.objects:
			if obj == null:
				continue
			var obj_screen = board_pos + (Vector2(obj.grid_pos) + Vector2(0.5, 0.5)) * c_sz
			if rect.has_point(obj_screen):
				if not selected_objects.has(obj):
					selected_objects.append(obj)
				if st.stage_index != current_stage_idx:
					current_stage_idx = st.stage_index
					current_stage = st
					stage_activated.emit(current_stage_idx)

	selection_changed.emit(selected_objects)
	if not selected_objects.is_empty():
		object_selected.emit(selected_objects[0])

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.11, 0.13, 1.0))

	var visible_stages = stages if is_side_by_side else ([current_stage] if current_stage != null else [])
	if visible_stages.is_empty():
		var font := ThemeDB.fallback_font
		draw_string(font, size * 0.5 - Vector2(80, 0), "No Stages Loaded", HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(0.6, 0.6, 0.6))
		return

	var c_sz = cell_size * zoom_level
	var font := ThemeDB.fallback_font

	for idx in range(visible_stages.size()):
		var st = visible_stages[idx]
		if st == null:
			continue
		var r = get_stage_rect_in_cells(st.stage_index)
		var is_active = (st.stage_index == current_stage_idx)
		var board_pos = pan_offset + Vector2(r.position) * c_sz
		var board_sz = Vector2(r.size) * c_sz

		draw_rect(Rect2(board_pos + Vector2(5, 5) * zoom_level, board_sz), Color(0.03, 0.03, 0.05, 0.6))
		var bg_col = Color(0.16, 0.18, 0.22, 1.0) if is_active else Color(0.13, 0.14, 0.17, 0.95)
		draw_rect(Rect2(board_pos, board_sz), bg_col)

		BoardVisualGenerator.draw_board(
			self,
			st,
			board_pos,
			Vector2(c_sz, c_sz),
			zoom_level,
			st.show_tile_borders,
			Color(0.24, 0.27, 0.33, 0.35) if is_active else Color(0.20, 0.22, 0.26, 0.25)
		)

		var outer_bounds = Rect2(board_pos, board_sz)
		if is_active:
			draw_rect(outer_bounds.grow(2.0 * zoom_level), Color(1.0, 0.82, 0.2, 0.85), false, 2.5 * zoom_level)
			draw_rect(outer_bounds.grow(4.0 * zoom_level), Color(1.0, 0.82, 0.2, 0.25), false, 1.5 * zoom_level)
		else:
			draw_rect(outer_bounds, Color(0.26, 0.30, 0.36, 0.6), false, 1.5)

		if show_grid_coords and zoom_level > 0.55:
			var coord_col := Color(0.75, 0.80, 0.90)
			for x in range(st.grid_width):
				var txt = str(x)
				var pos = board_pos + Vector2(float(x) * c_sz + c_sz * 0.5 - 4.0 * zoom_level, -10.0 * zoom_level)
				draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, int(11 * zoom_level), coord_col)
			for y in range(st.grid_height):
				var txt = str(y)
				var pos = board_pos + Vector2(-24.0 * zoom_level, float(y) * c_sz + c_sz * 0.5 + 4.0 * zoom_level)
				draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_RIGHT, -1, int(11 * zoom_level), coord_col)

		var header_h = max(24.0, 26.0 * zoom_level)
		var header_y = board_pos.y - header_h - (42.0 * zoom_level)
		var header_rect = Rect2(board_pos.x, header_y, board_sz.x, header_h)
		var h_bg = Color(0.20, 0.26, 0.35, 0.95) if is_active else Color(0.14, 0.16, 0.20, 0.85)
		draw_rect(header_rect, h_bg)
		var h_border = Color(1.0, 0.85, 0.3, 0.9) if is_active else Color(0.3, 0.35, 0.42, 0.6)
		draw_rect(header_rect, h_border, false, 1.5)

		var title_txt = "STAGE %d  (%dx%d)" % [st.stage_index, st.grid_width, st.grid_height]
		if is_active:
			title_txt += " ● ACTIVE"
		var title_col = Color(1.0, 0.9, 0.4) if is_active else Color(0.75, 0.8, 0.88)
		draw_string(font, header_rect.position + Vector2(8, header_h * 0.68), title_txt, HORIZONTAL_ALIGNMENT_LEFT, int(board_sz.x - 16), int(12 * zoom_level), title_col)

		var sim: Dictionary = simulation_results.get(st.stage_index, {})

		# 1. Movable Area floor tiles
		for obj in st.objects:
			if obj != null and obj.enabled and obj.type == LaserObjectData.ObjectType.MOVABLE_AREA:
				_draw_puzzle_object(obj, c_sz, r.position, sim)

		# 2. Puzzle objects (mirrors, rocks, glass, switches, walls, etc.)
		for obj in st.objects:
			if obj == null or not obj.enabled or obj.type == LaserObjectData.ObjectType.MOVABLE_AREA:
				continue
			_draw_puzzle_object(obj, c_sz, r.position, sim)

		# 3. Laser beams & glow rendered ABOVE puzzle objects
		if show_laser_preview and sim.has("segments"):
			var segments: Array = sim.get("segments", [])
			for seg in segments:
				var s_cell: Vector2i = seg["start"]
				var e_cell: Vector2i = seg["end"]
				var b_color: Color = seg["color"]

				var p1 = board_pos + (Vector2(s_cell) + Vector2(0.5, 0.5)) * c_sz
				var p2 = board_pos + (Vector2(e_cell) + Vector2(0.5, 0.5)) * c_sz

				draw_line(p1, p2, Color(b_color.r, b_color.g, b_color.b, 0.35), 7.0 * zoom_level, true)
				draw_line(p1, p2, Color(b_color.r, b_color.g, b_color.b, 0.85), 3.5 * zoom_level, true)
				draw_line(p1, p2, Color(1.0, 1.0, 1.0, 0.95), 1.4 * zoom_level, true)
				draw_circle(p1, 2.5 * zoom_level, Color.WHITE)
				draw_circle(p2, 2.5 * zoom_level, Color.WHITE)

		for sel in selected_objects:
			if sel != null and st.objects.has(sel):
				var sel_rect := Rect2(board_pos + Vector2(sel.grid_pos) * c_sz, Vector2(c_sz, c_sz))
				draw_rect(sel_rect, Color(1.0, 0.8, 0.2, 0.2))
				draw_rect(sel_rect, Color(1.0, 0.85, 0.1, 1.0), false, 2.5)

				# Requirement 11: Highlight associated movable area when a movable object is selected
				if sel.movable or not sel.movable_area_id.is_empty() or sel.type == LaserObjectData.ObjectType.MOVABLE_MIRROR:
					var associated_areas = st.get_movable_areas_for_object(sel)
					for marea in associated_areas:
						if marea != null and marea.grid_pos != sel.grid_pos:
							var ma_rect := Rect2(board_pos + Vector2(marea.grid_pos) * c_sz, Vector2(c_sz, c_sz))
							draw_rect(ma_rect.grow(-2.0 * zoom_level), Color(0.2, 0.8, 1.0, 0.25), true)
							draw_rect(ma_rect.grow(-1.0 * zoom_level), Color(0.3, 0.9, 1.0, 0.95), false, 2.0 * zoom_level)

		# Selected Cell Visual Highlight
		if is_active and selected_cell_visual_pos.x >= 0 and st.has_cell_visual(selected_cell_visual_pos):
			var cv_rect := Rect2(board_pos + Vector2(selected_cell_visual_pos) * c_sz, Vector2(c_sz, c_sz))
			draw_rect(cv_rect, Color(1.0, 0.85, 0.1, 0.2))
			draw_rect(cv_rect, Color(1.0, 0.85, 0.1, 1.0), false, 2.5 * zoom_level)

		# Selected Border Visual Highlight
		if is_active and not selected_border_side.is_empty() and selected_border_index >= 0 and st.has_border_visual(selected_border_side, selected_border_index):
			var t_info := BoardVisualGenerator.get_border_piece_transform(st, board_pos, Vector2(c_sz, c_sz), selected_border_side, selected_border_index, zoom_level)
			var bv_rect: Rect2 = t_info.rect.grow(2.0 * zoom_level)
			draw_rect(bv_rect, Color(1.0, 0.85, 0.1, 0.25))
			draw_rect(bv_rect, Color(1.0, 0.85, 0.1, 1.0), false, 2.5 * zoom_level)

		# Selected Corner Visual Highlight
		if is_active and not selected_corner_name.is_empty() and st.has_corner_visual(selected_corner_name):
			var t_info := BoardVisualGenerator.get_corner_piece_transform(st, board_pos, Vector2(c_sz, c_sz), selected_corner_name, zoom_level)
			var crn_rect: Rect2 = t_info.rect.grow(2.0 * zoom_level)
			draw_rect(crn_rect, Color(1.0, 0.85, 0.1, 0.25))
			draw_rect(crn_rect, Color(1.0, 0.85, 0.1, 1.0), false, 2.5 * zoom_level)

		if is_active and is_box_selecting:
			var sel_rect = Rect2(box_select_start, box_select_current - box_select_start).abs()
			draw_rect(sel_rect, Color(0.3, 0.6, 1.0, 0.15))
			draw_rect(sel_rect, Color(0.3, 0.6, 1.0, 0.8), false, 1.5)

		# Outer Perimeter Corner Paint/Erase Previews and Hover
		if is_active and not hovered_corner_name.is_empty() and (current_tool == ToolMode.CORNER_PAINT or current_tool == ToolMode.CORNER_ERASE or current_tool == ToolMode.SELECT):
			var is_placed := st.has_corner_visual(hovered_corner_name)
			var t_info: Dictionary
			if current_tool == ToolMode.CORNER_PAINT and not is_placed:
				t_info = BoardVisualGenerator.get_corner_piece_transform(st, board_pos, Vector2(c_sz, c_sz), hovered_corner_name, zoom_level, {
					"asset": active_corner_asset,
					"rotation": active_corner_rot,
					"mirror_x": active_corner_mirror_x,
					"mirror_y": active_corner_mirror_y,
					"offset": active_corner_offset,
					"scale_x": active_corner_scale_x,
					"scale_y": active_corner_scale_y
				})
			else:
				t_info = BoardVisualGenerator.get_corner_piece_transform(st, board_pos, Vector2(c_sz, c_sz), hovered_corner_name, zoom_level)

			var crn_preview_rect: Rect2 = t_info.rect.grow(2.0 * zoom_level)
			if current_tool == ToolMode.CORNER_PAINT:
				var c_tex: Texture2D = t_info.get("texture", null)
				if c_tex != null:
					BoardVisualGenerator.draw_border_or_corner_visual(self, t_info.center, c_tex, float(t_info.rotation), float(t_info.draw_scale_x), float(t_info.draw_scale_y), bool(t_info.mirror_x), bool(t_info.mirror_y), Color(1.0, 1.0, 1.0, 0.65))
				draw_rect(crn_preview_rect, Color(1.0, 0.9, 0.2, 0.85), false, 2.0 * zoom_level)
			elif current_tool == ToolMode.CORNER_ERASE and is_placed:
				draw_rect(crn_preview_rect, Color(1.0, 0.2, 0.2, 0.65), false, 2.0 * zoom_level)
			elif current_tool == ToolMode.SELECT and is_placed:
				draw_rect(crn_preview_rect, Color(1.0, 1.0, 1.0, 0.25), false, 1.5 * zoom_level)

		# Outer Perimeter Border Paint/Erase Previews and Hover
		if is_active and not hovered_border_side.is_empty() and hovered_border_index >= 0 and (current_tool == ToolMode.BORDER_PAINT or current_tool == ToolMode.BORDER_ERASE or current_tool == ToolMode.SELECT):
			var is_placed := st.has_border_visual(hovered_border_side, hovered_border_index)
			var t_info: Dictionary
			if current_tool == ToolMode.BORDER_PAINT and not is_placed:
				t_info = BoardVisualGenerator.get_border_piece_transform(st, board_pos, Vector2(c_sz, c_sz), hovered_border_side, hovered_border_index, zoom_level, {
					"asset": active_border_asset,
					"rotation": active_border_rot,
					"offset": active_border_offset,
					"scale_x": active_border_scale_x,
					"scale_y": active_border_scale_y
				})
			else:
				t_info = BoardVisualGenerator.get_border_piece_transform(st, board_pos, Vector2(c_sz, c_sz), hovered_border_side, hovered_border_index, zoom_level)

			var border_preview_rect: Rect2 = t_info.rect.grow(2.0 * zoom_level)
			if current_tool == ToolMode.BORDER_PAINT:
				var b_tex: Texture2D = t_info.get("texture", null)
				if b_tex != null:
					BoardVisualGenerator.draw_border_or_corner_visual(self, t_info.center, b_tex, float(t_info.rotation), float(t_info.draw_scale_x), float(t_info.draw_scale_y), false, false, Color(1.0, 1.0, 1.0, 0.65))
				draw_rect(border_preview_rect, Color(1.0, 0.9, 0.2, 0.85), false, 2.0 * zoom_level)
			elif current_tool == ToolMode.BORDER_ERASE and is_placed:
				draw_rect(border_preview_rect, Color(1.0, 0.2, 0.2, 0.65), false, 2.0 * zoom_level)
			elif current_tool == ToolMode.SELECT and is_placed:
				draw_rect(border_preview_rect, Color(1.0, 1.0, 1.0, 0.25), false, 1.5 * zoom_level)

		if hovered_stage_idx == st.stage_index and st.is_inside_grid(hovered_cell):
			var h_rect := Rect2(board_pos + Vector2(hovered_cell) * c_sz, Vector2(c_sz, c_sz))
			draw_rect(h_rect, Color(1.0, 1.0, 1.0, 0.12), false, 1.5)

			if current_tool == ToolMode.PAINT:
				if active_palette_type == LaserObjectData.ObjectType.MOVABLE_AREA:
					var p_col = active_palette_color if active_palette_color.a > 0.05 else Color(0.2, 0.65, 1.0, 1.0)
					draw_rect(h_rect.grow(-2.0 * zoom_level), Color(p_col.r, p_col.g, p_col.b, 0.35), true)
					draw_rect(h_rect.grow(-2.0 * zoom_level), Color(p_col.r, p_col.g, p_col.b, 0.85), false, 1.5 * zoom_level)
				else:
					var center = board_pos + (Vector2(hovered_cell) + Vector2(0.5, 0.5)) * c_sz
					draw_circle(center, 8.0 * zoom_level, Color(active_palette_color.r, active_palette_color.g, active_palette_color.b, 0.45))
			elif current_tool == ToolMode.TILE_PAINT:
				var prev_tex: Texture2D = BoardVisualGenerator.get_cell_asset_texture(st, active_cell_asset)
				if prev_tex != null:
					var r_deg: float = active_tile_rot_float if active_tile_rot_float != 0.0 else float(active_tile_rot)
					BoardVisualGenerator.draw_cell_visual(self, h_rect, prev_tex, r_deg, false, false, Color(1.0, 1.0, 1.0, 0.65))
				draw_rect(h_rect, Color(1.0, 0.9, 0.2, 0.85), false, 2.0 * zoom_level)
			elif current_tool == ToolMode.TILE_ERASE:
				draw_rect(h_rect, Color(1.0, 0.2, 0.2, 0.6), false, 2.0 * zoom_level)

		# -----------------------------------------------------------------
		# Visual-Only Hint Mode Dark Tint Overlay & Hint Laser Path Rendering
		# -----------------------------------------------------------------
		if is_hint_mode():
			var dim_rect := outer_bounds.grow(c_sz * 1.5)
			draw_rect(dim_rect, HINT_MODE_DIM_COLOR)

			if not st.hint_path_points.is_empty():
				var h_pts: Array[Vector2i] = st.hint_path_points
				var h_col: Color = st.hint_laser_color
				var h_op: float = clampf(st.hint_laser_opacity, 0.0, 1.0)
				var h_w: float = maxf(1.0, st.hint_laser_width) * zoom_level
				var eff_col := Color(h_col.r, h_col.g, h_col.b, h_col.a * h_op)

				# 1. Draw multi-layered laser path segments
				if h_pts.size() >= 2:
					for p_i in range(h_pts.size() - 1):
						var pt_a: Vector2i = h_pts[p_i]
						var pt_b: Vector2i = h_pts[p_i + 1]
						var scr_a = board_pos + (Vector2(pt_a) + Vector2(0.5, 0.5)) * c_sz
						var scr_b = board_pos + (Vector2(pt_b) + Vector2(0.5, 0.5)) * c_sz

						# Outer glow
						draw_line(scr_a, scr_b, Color(eff_col.r, eff_col.g, eff_col.b, eff_col.a * 0.35), h_w * 2.2, true)
						# Main laser beam
						draw_line(scr_a, scr_b, eff_col, h_w, true)
						# Bright laser core
						draw_line(scr_a, scr_b, Color(1.0, 1.0, 1.0, eff_col.a * 0.9), maxf(1.0, h_w * 0.35), true)

				# 2. Draw node points (Start, End, and Intermediate)
				for p_i in range(h_pts.size()):
					var pt: Vector2i = h_pts[p_i]
					var pt_scr = board_pos + (Vector2(pt) + Vector2(0.5, 0.5)) * c_sz
					if p_i == 0:
						# Start Point: Bright green ring + glow
						draw_circle(pt_scr, 7.5 * zoom_level, Color(0.2, 1.0, 0.4, 0.35 * h_op))
						draw_arc(pt_scr, 7.0 * zoom_level, 0.0, TAU, 16, Color(0.3, 1.0, 0.5, h_op), 2.0 * zoom_level)
						draw_circle(pt_scr, 3.5 * zoom_level, Color(1.0, 1.0, 1.0, h_op))
					elif p_i == h_pts.size() - 1:
						# End Point: Bright red/orange target ring + glow
						draw_circle(pt_scr, 7.5 * zoom_level, Color(1.0, 0.3, 0.3, 0.35 * h_op))
						draw_arc(pt_scr, 7.0 * zoom_level, 0.0, TAU, 16, Color(1.0, 0.4, 0.3, h_op), 2.0 * zoom_level)
						draw_circle(pt_scr, 3.5 * zoom_level, Color(1.0, 1.0, 1.0, h_op))
					else:
						# Intermediate Point: Clean circular node
						draw_circle(pt_scr, 4.0 * zoom_level, Color(eff_col.r, eff_col.g, eff_col.b, 0.6 * h_op))
						draw_circle(pt_scr, 2.0 * zoom_level, Color(1.0, 1.0, 1.0, 0.9 * h_op))

			if hovered_stage_idx == st.stage_index and st.is_inside_grid(hovered_cell):
				var h_rect := Rect2(board_pos + Vector2(hovered_cell) * c_sz, Vector2(c_sz, c_sz))
				if current_tool == ToolMode.HINT_DRAW:
					var h_col = st.hint_laser_color
					var center = board_pos + (Vector2(hovered_cell) + Vector2(0.5, 0.5)) * c_sz
					draw_rect(h_rect, Color(h_col.r, h_col.g, h_col.b, 0.25), true)
					draw_rect(h_rect, Color(h_col.r, h_col.g, h_col.b, 0.9), false, 2.0 * zoom_level)
					draw_circle(center, 6.0 * zoom_level, Color(h_col.r, h_col.g, h_col.b, 0.7))
					draw_circle(center, 2.5 * zoom_level, Color.WHITE)
				elif current_tool == ToolMode.HINT_ERASE:
					draw_rect(h_rect, Color(1.0, 0.2, 0.2, 0.3), true)
					draw_rect(h_rect, Color(1.0, 0.2, 0.2, 0.9), false, 2.0 * zoom_level)
					var center = board_pos + (Vector2(hovered_cell) + Vector2(0.5, 0.5)) * c_sz
					var cross_sz = 6.0 * zoom_level
					draw_line(center - Vector2(cross_sz, cross_sz), center + Vector2(cross_sz, cross_sz), Color(1.0, 0.3, 0.3), 2.0 * zoom_level)
					draw_line(center - Vector2(cross_sz, -cross_sz), center + Vector2(cross_sz, -cross_sz), Color(1.0, 0.3, 0.3), 2.0 * zoom_level)

		if is_side_by_side and idx < visible_stages.size() - 1:
			var next_st = visible_stages[idx + 1]
			var next_r = get_stage_rect_in_cells(next_st.stage_index)
			var next_board_pos = pan_offset + Vector2(next_r.position) * c_sz
			var gap_start_x = board_pos.x + board_sz.x
			var gap_end_x = next_board_pos.x
			var mid_x = (gap_start_x + gap_end_x) * 0.5
			var mid_y = board_pos.y + board_sz.y * 0.5

			var is_transition_laser_active: bool = active_stage_transitions.has(st.stage_index)
			var arrow_color: Color = active_stage_transitions[st.stage_index] if is_transition_laser_active else Color(0.35, 0.45, 0.55, 0.45)
			var arrow_start = Vector2(gap_start_x + 14.0 * zoom_level, mid_y)
			var arrow_end = Vector2(gap_end_x - 28.0 * zoom_level, mid_y)
			if arrow_end.x > arrow_start.x + 10.0 * zoom_level:
				if is_transition_laser_active:
					draw_line(arrow_start, arrow_end, Color(arrow_color.r, arrow_color.g, arrow_color.b, 0.35), 7.0 * zoom_level)
					draw_line(arrow_start, arrow_end, Color(1.0, 1.0, 1.0, 0.9), 1.8 * zoom_level)
				draw_line(arrow_start, arrow_end, arrow_color, 2.5 * zoom_level)
				var tip = arrow_end
				var head_sz = 8.0 * zoom_level
				var p_top = tip + Vector2(-head_sz, -head_sz * 0.7)
				var p_bot = tip + Vector2(-head_sz, head_sz * 0.7)
				draw_colored_polygon(PackedVector2Array([tip, p_top, p_bot]), arrow_color)

				var dir_name = LaserStageData.DIRECTION_NAMES.get(st.exit_direction, "Right")
				var flow_txt = ("⚡ %s Laser" % dir_name) if is_transition_laser_active else ("%s Flow" % dir_name)
				draw_string(font, Vector2(mid_x - 45 * zoom_level, mid_y - 8 * zoom_level), flow_txt, HORIZONTAL_ALIGNMENT_CENTER, int(90 * zoom_level), int(10 * zoom_level), arrow_color)

	if is_box_selecting:
		var b_rect := Rect2(box_select_start, box_select_current - box_select_start).abs()
		draw_rect(b_rect, Color(0.2, 0.6, 1.0, 0.2))
		draw_rect(b_rect, Color(0.4, 0.8, 1.0, 0.9), false, 1.5)

func _draw_puzzle_object(obj: LaserObjectData, c_sz: float, stage_offset: Vector2i = Vector2i.ZERO, sim_res: Dictionary = {}) -> void:
	var center = pan_offset + (Vector2(stage_offset) + Vector2(obj.grid_pos) + Vector2(0.5, 0.5)) * c_sz
	var rad = c_sz * 0.42
	var font := ThemeDB.fallback_font

	match obj.type:
		LaserObjectData.ObjectType.LASER_SOURCE:
			draw_circle(center, rad * 0.8, Color(0.25, 0.28, 0.35))
			draw_circle(center, rad * 0.5, obj.color)
			draw_circle(center, rad * 0.2, Color.WHITE)
			var rot_rad = deg_to_rad(float(obj.rotation_deg))
			var p_tip = center + Vector2(rad * 1.1, 0).rotated(rot_rad)
			draw_line(center, p_tip, obj.color, 3.5 * zoom_level)

		LaserObjectData.ObjectType.FIXED_MIRROR:
			var rot_rad = deg_to_rad(float(obj.rotation_deg))
			var p1 = center + Vector2(-rad, -rad).rotated(rot_rad)
			var p2 = center + Vector2(rad, rad).rotated(rot_rad)
			draw_line(p1, p2, Color(0.3, 0.6, 0.9, 0.5), 6.0 * zoom_level)
			draw_line(p1, p2, Color(0.85, 0.95, 1.0), 2.5 * zoom_level)

		LaserObjectData.ObjectType.MOVABLE_MIRROR:
			var r_sz = rad * 1.6
			var box = Rect2(center - Vector2(r_sz, r_sz) * 0.5, Vector2(r_sz, r_sz))
			draw_rect(box, Color(0.2, 0.3, 0.4, 0.6), true)
			draw_rect(box, Color(0.4, 0.7, 1.0, 0.8), false, 1.5)
			var rot_rad = deg_to_rad(float(obj.rotation_deg))
			var p1 = center + Vector2(-rad, -rad).rotated(rot_rad)
			var p2 = center + Vector2(rad, rad).rotated(rot_rad)
			draw_line(p1, p2, Color(0.9, 0.95, 1.0), 3.0 * zoom_level)

		LaserObjectData.ObjectType.ROTATABLE_MIRROR:
			draw_arc(center, rad * 0.85, 0, TAU, 16, Color(0.5, 0.8, 0.3, 0.7), 1.5)
			var rot_rad = deg_to_rad(float(obj.rotation_deg))
			var p1 = center + Vector2(-rad * 0.7, -rad * 0.7).rotated(rot_rad)
			var p2 = center + Vector2(rad * 0.7, rad * 0.7).rotated(rot_rad)
			draw_line(p1, p2, Color(0.9, 1.0, 0.9), 3.0 * zoom_level)

		LaserObjectData.ObjectType.MOVABLE_AREA:
			var col: Color = obj.color if (obj.color != Color(1.0, 0.2, 0.2, 1.0) and obj.color.a > 0.05) else Color(0.18, 0.62, 0.98, 1.0)
			var tile_rect = Rect2(pan_offset + (Vector2(stage_offset) + Vector2(obj.grid_pos)) * c_sz, Vector2(c_sz, c_sz))
			draw_rect(tile_rect.grow(-2.0 * zoom_level), Color(col.r, col.g, col.b, 0.32), true)
			draw_rect(tile_rect.grow(-2.0 * zoom_level), Color(col.r, col.g, col.b, 0.85), false, 1.5 * zoom_level)
			var m_rad = rad * 0.35
			draw_arc(center, m_rad, 0, TAU, 12, col, 1.2 * zoom_level)
			draw_line(center - Vector2(m_rad, 0), center + Vector2(m_rad, 0), col, 1.0 * zoom_level)
			draw_line(center - Vector2(0, m_rad), center + Vector2(0, m_rad), col, 1.0 * zoom_level)

		LaserObjectData.ObjectType.ROCK:
			var pts: PackedVector2Array = [
				center + Vector2(-rad, -rad * 0.6),
				center + Vector2(rad * 0.2, -rad),
				center + Vector2(rad, -rad * 0.4),
				center + Vector2(rad * 0.8, rad * 0.8),
				center + Vector2(-rad * 0.5, rad),
				center + Vector2(-rad * 0.9, rad * 0.2)
			]
			draw_colored_polygon(pts, Color(0.45, 0.42, 0.4))
			draw_polyline(pts, Color(0.3, 0.28, 0.26), 1.5)

		LaserObjectData.ObjectType.ICE:
			var r_sz = rad * 1.5
			var box = Rect2(center - Vector2(r_sz, r_sz) * 0.5, Vector2(r_sz, r_sz))
			draw_rect(box, Color(0.4, 0.8, 0.95, 0.65), true)
			draw_rect(box, Color(0.8, 0.95, 1.0, 0.9), false, 1.5)

		LaserObjectData.ObjectType.SPLITTER:
			draw_circle(center, rad * 0.85, Color(0.3, 0.25, 0.4))
			var rot_rad = deg_to_rad(float(obj.rotation_deg))
			var bar1 = center + Vector2(-rad * 0.6, -rad * 0.3).rotated(rot_rad)
			var bar2 = center + Vector2(rad * 0.6, -rad * 0.3).rotated(rot_rad)
			var stem = center + Vector2(0, rad * 0.6).rotated(rot_rad)
			draw_line(bar1, bar2, Color(0.8, 0.5, 1.0), 3.0 * zoom_level)
			draw_line(center, stem, Color(0.8, 0.5, 1.0), 3.0 * zoom_level)

		LaserObjectData.ObjectType.COLOR_GLASS:
			var r_sz = rad * 1.4
			var box = Rect2(center - Vector2(r_sz, r_sz) * 0.5, Vector2(r_sz, r_sz))
			draw_rect(box, Color(obj.color.r, obj.color.g, obj.color.b, 0.55), true)
			draw_rect(box, Color.WHITE, false, 1.5)

		LaserObjectData.ObjectType.COLOR_WALL:
			var r_sz = rad * 1.6
			var box = Rect2(center - Vector2(r_sz, r_sz) * 0.5, Vector2(r_sz, r_sz))
			draw_rect(box, Color(obj.color.r * 0.7, obj.color.g * 0.7, obj.color.b * 0.7, 1.0), true)
			draw_rect(box, Color(obj.color.r, obj.color.g, obj.color.b, 1.0), false, 2.5)

		LaserObjectData.ObjectType.GATE:
			var r_sz = rad * 1.5
			var box = Rect2(center - Vector2(r_sz, r_sz) * 0.5, Vector2(r_sz, r_sz))
			draw_rect(box, Color(0.35, 0.08, 0.08, 0.85), true)
			draw_rect(box, Color(0.9, 0.25, 0.25), false, 2.0 * zoom_level)
			var door_w = r_sz * 0.5
			var door_h = r_sz * 0.7
			var door_rect = Rect2(center.x - door_w * 0.5, center.y + r_sz * 0.5 - door_h, door_w, door_h)
			draw_rect(door_rect, Color(0.18, 0.04, 0.04, 0.95), true)
			draw_line(door_rect.position, door_rect.position + door_rect.size, Color(1.0, 0.6, 0.6, 0.7), 1.5 * zoom_level)
			draw_line(Vector2(door_rect.position.x + door_rect.size.x, door_rect.position.y), Vector2(door_rect.position.x, door_rect.position.y + door_rect.size.y), Color(1.0, 0.6, 0.6, 0.7), 1.5 * zoom_level)
			draw_circle(center + Vector2(0, -rad * 0.1), rad * 0.2, Color.WHITE)
			draw_circle(center + Vector2(0, -rad * 0.1), rad * 0.12, Color(0.9, 0.2, 0.2))

		LaserObjectData.ObjectType.EXIT_GATE:
			var r_sz = rad * 1.5
			var box = Rect2(center - Vector2(r_sz, r_sz) * 0.5, Vector2(r_sz, r_sz))
			var x_hit = sim_res.get("exit_gates_hit", {}).get(obj.grid_pos, false)
			var base_c = Color(0.1, 0.7, 0.45, 0.9) if x_hit else Color(0.08, 0.35, 0.25, 0.85)
			var border_c = Color(0.4, 1.0, 0.7) if x_hit else Color(0.2, 0.8, 0.5)
			draw_rect(box, base_c, true)
			draw_rect(box, border_c, false, 2.5 * zoom_level)
			var door_w = r_sz * 0.5
			var door_h = r_sz * 0.7
			var door_rect = Rect2(center.x - door_w * 0.5, center.y + r_sz * 0.5 - door_h, door_w, door_h)
			draw_rect(door_rect, Color(0.02, 0.15, 0.1, 0.95), true)
			var arr_start = center + Vector2(0, rad * 0.25)
			var arr_end = center + Vector2(0, -rad * 0.25)
			draw_line(arr_start, arr_end, Color.WHITE, 2.0 * zoom_level)
			draw_line(arr_end, arr_end + Vector2(-rad * 0.2, rad * 0.2), Color.WHITE, 2.0 * zoom_level)
			draw_line(arr_end, arr_end + Vector2(rad * 0.2, rad * 0.2), Color.WHITE, 2.0 * zoom_level)

		LaserObjectData.ObjectType.SWITCH:
			var hit = sim_res.get("switches_hit", {}).get(obj.grid_pos, false)
			var s_col = Color(0.3, 1.0, 0.5) if hit else Color(0.7, 0.7, 0.3)
			draw_circle(center, rad * 0.7, s_col)
			draw_arc(center, rad * 0.85, 0, TAU, 12, Color.WHITE, 1.5)

		LaserObjectData.ObjectType.GATE_SWITCH:
			draw_rect(Rect2(center - Vector2(rad, rad) * 0.6, Vector2(rad, rad) * 1.2), Color(0.6, 0.4, 0.2))
			draw_circle(center, rad * 0.4, Color.GOLD)

		LaserObjectData.ObjectType.GOAL:
			var g_hit = sim_res.get("goals_hit", {}).get(obj.grid_pos, false)
			var g_col = Color(0.2, 1.0, 0.4) if g_hit else obj.color
			draw_circle(center, rad * 0.85, Color(0.15, 0.15, 0.2))
			draw_arc(center, rad * 0.7, 0, TAU, 16, g_col, 2.5 * zoom_level)
			draw_circle(center, rad * 0.35, g_col)
			if g_hit:
				draw_circle(center, rad * 0.15, Color.WHITE)

		LaserObjectData.ObjectType.CUSTOM:
			var r_sz = rad * 1.4
			var box = Rect2(center - Vector2(r_sz, r_sz) * 0.5, Vector2(r_sz, r_sz))
			draw_rect(box, Color(obj.color.r * 0.4, obj.color.g * 0.4, obj.color.b * 0.4, 0.8), true)
			draw_rect(box, obj.color, false, 2.0)
			var pts: PackedVector2Array = [
				center + Vector2(0, -rad * 0.6),
				center + Vector2(rad * 0.6, 0),
				center + Vector2(0, rad * 0.6),
				center + Vector2(-rad * 0.6, 0)
			]
			draw_colored_polygon(pts, obj.color)
			draw_polyline(pts, Color.WHITE, 1.5)

		_:
			draw_circle(center, rad * 0.5, obj.color)

	if zoom_level > 1.1:
		var name_str = ""
		if obj.type == LaserObjectData.ObjectType.CUSTOM:
			name_str = str(obj.properties.get("custom_name", ""))
		if name_str.is_empty():
			name_str = LaserObjectData.TYPE_SHORT_NAMES.get(obj.type, "")
		draw_string(font, center + Vector2(-rad, rad + 11), name_str, HORIZONTAL_ALIGNMENT_CENTER, int(rad * 2), int(9 * zoom_level), Color(0.8, 0.8, 0.8, 0.8))
