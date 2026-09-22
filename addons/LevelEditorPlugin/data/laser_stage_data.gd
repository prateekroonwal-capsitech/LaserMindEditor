@tool
extends Resource
class_name LaserStageData

enum Direction {
	LEFT,
	RIGHT,
	UP,
	DOWN
}

const DIRECTION_NAMES: Dictionary = {
	Direction.LEFT: "Left",
	Direction.RIGHT: "Right",
	Direction.UP: "Up",
	Direction.DOWN: "Down"
}

enum TransitionDir {
	NONE,
	LEFT,
	RIGHT,
	UP,
	DOWN
}

const TRANSITION_DIR_NAMES: Dictionary = {
	TransitionDir.NONE: "None (Center)",
	TransitionDir.LEFT: "← From Left",
	TransitionDir.RIGHT: "→ From Right",
	TransitionDir.UP: "↑ From Top",
	TransitionDir.DOWN: "↓ From Bottom"
}

@export var stage_index: int = 1
@export var grid_width: int = 6
@export var grid_height: int = 12
@export var entry_point: Vector2i = Vector2i(-1, -1)
@export var entry_direction: Direction = Direction.LEFT
@export var exit_point: Vector2i = Vector2i(-1, -1)
@export var exit_direction: Direction = Direction.RIGHT
@export var time_limit: float = 20.0
@export var time_bonus: float = 5.0
@export var objects: Array[LaserObjectData] = []
@export var metadata: Dictionary = {}

@export var stage_screen_position: Vector2 = Vector2(-9999.0, -9999.0)
@export var stage_transition_direction: TransitionDir = TransitionDir.NONE
@export var board_image_path: String = ""
@export var board_slice_cols: int = 0
@export var board_slice_rows: int = 0
@export var board_tiles: Dictionary = {}
@export var custom_tiles: Dictionary = {}
@export var board_margin_left: int = 0
@export var board_margin_top: int = 0
@export var board_margin_right: int = 0
@export var board_margin_bottom: int = 0
@export var show_tile_borders: bool = true
@export var hidden_frame_pieces: Array[String] = []

@export var cell_visuals: Dictionary = {}
@export var border_horizontal_edge_path: String = ""
@export var border_vertical_edge_path: String = ""
@export var border_corner_path: String = ""
@export var border_enabled: bool = true

# --- 3-Library Visual Asset Model ---
@export var cell_assets: Array[Dictionary] = []
@export var border_assets: Array[Dictionary] = []
@export var corner_assets: Array[Dictionary] = []
@export var border_visuals: Dictionary = {}
@export var corner_visuals: Dictionary = {}

func ensure_default_visual_libraries() -> void:
	if cell_assets.is_empty():
		cell_assets = [
			{
				"id": "cell_1",
				"name": "Cell Image 1",
				"path": "res://addons/LevelEditorPlugin/assets/default/cells/demo_cell_01.svg"
			}
		]
	if border_assets.is_empty():
		var b_path = border_horizontal_edge_path if not border_horizontal_edge_path.is_empty() else "res://addons/LevelEditorPlugin/assets/default/borders/demo_border_01.svg"
		border_assets = [
			{
				"id": "border_1",
				"name": "Border Image 1",
				"path": b_path
			}
		]
	if corner_assets.is_empty():
		var c_path = border_corner_path if not border_corner_path.is_empty() else "res://addons/LevelEditorPlugin/assets/default/corners/demo_corner_01.svg"
		corner_assets = [
			{
				"id": "corner_1",
				"name": "Corner Image 1",
				"path": c_path
			}
		]

func update_cell_asset(asset_id: String, p_path: String, p_name: String = "") -> void:
	ensure_default_visual_libraries()
	for item in cell_assets:
		if item.get("id", "") == asset_id:
			item["path"] = p_path
			if not p_name.is_empty():
				item["name"] = p_name
			elif not p_path.is_empty():
				item["name"] = p_path.get_file()
			break

func update_border_asset(asset_id: String, p_path: String, p_name: String = "") -> void:
	ensure_default_visual_libraries()
	for item in border_assets:
		if item.get("id", "") == asset_id:
			item["path"] = p_path
			if not p_name.is_empty():
				item["name"] = p_name
			elif not p_path.is_empty():
				item["name"] = p_path.get_file()
			break

func update_corner_asset(asset_id: String, p_path: String, p_name: String = "") -> void:
	ensure_default_visual_libraries()
	for item in corner_assets:
		if item.get("id", "") == asset_id:
			item["path"] = p_path
			if not p_name.is_empty():
				item["name"] = p_name
			elif not p_path.is_empty():
				item["name"] = p_path.get_file()
			break

func add_cell_asset(p_path: String, p_name: String = "") -> String:
	ensure_default_visual_libraries()
	var new_id := "cell_%d" % (cell_assets.size() + 1)
	var disp_name := p_name if not p_name.is_empty() else (p_path.get_file() if not p_path.is_empty() else ("Cell Image %d" % (cell_assets.size() + 1)))
	cell_assets.append({
		"id": new_id,
		"name": disp_name,
		"path": p_path
	})
	return new_id

func remove_cell_asset(asset_id: String) -> bool:
	ensure_default_visual_libraries()
	var idx := -1
	for i in range(cell_assets.size()):
		if cell_assets[i].get("id", "") == asset_id:
			idx = i
			break
	if idx >= 0:
		cell_assets.remove_at(idx)
		var to_erase: Array[String] = []
		for k in cell_visuals.keys():
			var cv = cell_visuals[k]
			if cv is Dictionary and cv.get("asset", "") == asset_id:
				to_erase.append(k)
		for k in to_erase:
			cell_visuals.erase(k)
		return true
	return false

func add_border_asset(p_path: String, p_name: String = "") -> String:
	ensure_default_visual_libraries()
	var new_id := "border_%d" % (border_assets.size() + 1)
	var disp_name := p_name if not p_name.is_empty() else (p_path.get_file() if not p_path.is_empty() else ("Border Image %d" % (border_assets.size() + 1)))
	border_assets.append({
		"id": new_id,
		"name": disp_name,
		"path": p_path
	})
	return new_id

func remove_border_asset(asset_id: String) -> bool:
	ensure_default_visual_libraries()
	var idx := -1
	for i in range(border_assets.size()):
		if border_assets[i].get("id", "") == asset_id:
			idx = i
			break
	if idx >= 0:
		border_assets.remove_at(idx)
		var to_erase: Array[String] = []
		for k in border_visuals.keys():
			var bv = border_visuals[k]
			if bv is Dictionary and bv.get("asset", "") == asset_id:
				to_erase.append(k)
		for k in to_erase:
			border_visuals.erase(k)
		return true
	return false

func add_corner_asset(p_path: String, p_name: String = "") -> String:
	ensure_default_visual_libraries()
	var new_id := "corner_%d" % (corner_assets.size() + 1)
	var disp_name := p_name if not p_name.is_empty() else (p_path.get_file() if not p_path.is_empty() else ("Corner Image %d" % (corner_assets.size() + 1)))
	corner_assets.append({
		"id": new_id,
		"name": disp_name,
		"path": p_path
	})
	return new_id

func remove_corner_asset(asset_id: String) -> bool:
	ensure_default_visual_libraries()
	var idx := -1
	for i in range(corner_assets.size()):
		if corner_assets[i].get("id", "") == asset_id:
			idx = i
			break
	if idx >= 0:
		corner_assets.remove_at(idx)
		var to_erase: Array[String] = []
		for k in corner_visuals.keys():
			var cv = corner_visuals[k]
			if cv is Dictionary and cv.get("asset", "") == asset_id:
				to_erase.append(k)
		for k in to_erase:
			corner_visuals.erase(k)
		return true
	return false

# --- Outer Perimeter Border Painting API ---
func set_border_visual(side: String, index: int, asset_id: String, rot_deg: float) -> void:
	var key := "%s,%d" % [side.to_lower(), index]
	border_visuals[key] = {
		"side": side.to_lower(),
		"index": int(index),
		"asset": str(asset_id),
		"rotation": float(rot_deg)
	}

func get_border_visual(side: String, index: int) -> Dictionary:
	var key := "%s,%d" % [side.to_lower(), index]
	if border_visuals.has(key):
		var v = border_visuals[key]
		if v is Dictionary:
			return {
				"side": side.to_lower(),
				"index": int(index),
				"asset": str(v.get("asset", "")),
				"rotation": float(v.get("rotation", 0.0))
			}
	return {}

func has_border_visual(side: String, index: int) -> bool:
	var key := "%s,%d" % [side.to_lower(), index]
	return border_visuals.has(key)

func remove_border_visual(side: String, index: int) -> void:
	var key := "%s,%d" % [side.to_lower(), index]
	border_visuals.erase(key)

func clear_all_border_visuals() -> void:
	border_visuals.clear()

func get_border_visuals_count() -> int:
	return border_visuals.size()

# --- Outer Perimeter Corner Painting API ---
func set_corner_visual(corner: String, asset_id: String, rot_deg: float, mirror_x: bool = false, mirror_y: bool = false) -> void:
	var key := corner.to_lower()
	corner_visuals[key] = {
		"corner": key,
		"asset": str(asset_id),
		"rotation": float(rot_deg),
		"mirror_x": bool(mirror_x),
		"mirror_y": bool(mirror_y)
	}

func get_corner_visual(corner: String) -> Dictionary:
	var key := corner.to_lower()
	if corner_visuals.has(key):
		var v = corner_visuals[key]
		if v is Dictionary:
			return {
				"corner": key,
				"asset": str(v.get("asset", "")),
				"rotation": float(v.get("rotation", 0.0)),
				"mirror_x": bool(v.get("mirror_x", false)),
				"mirror_y": bool(v.get("mirror_y", false))
			}
	return {}

func has_corner_visual(corner: String) -> bool:
	var key := corner.to_lower()
	return corner_visuals.has(key)

func remove_corner_visual(corner: String) -> void:
	var key := corner.to_lower()
	corner_visuals.erase(key)

func clear_all_corner_visuals() -> void:
	corner_visuals.clear()

func get_corner_visuals_count() -> int:
	return corner_visuals.size()

@export var tile_middle_path: String = ""
@export var tile_edge_path: String = ""
@export var tile_corner_path: String = ""
@export var tile_opening_path: String = ""

func is_frame_piece_hidden(key: String) -> bool:
	return key in hidden_frame_pieces

func set_frame_piece_hidden(key: String, hidden: bool) -> void:
	if hidden and not (key in hidden_frame_pieces):
		hidden_frame_pieces.append(key)
	elif not hidden and (key in hidden_frame_pieces):
		hidden_frame_pieces.erase(key)

func toggle_frame_piece(key: String) -> void:
	if key in hidden_frame_pieces:
		hidden_frame_pieces.erase(key)
	else:
		hidden_frame_pieces.append(key)

func clear_hidden_frame_pieces() -> void:
	hidden_frame_pieces.clear()

func toggle_side_frame_pieces(side: String) -> void:
	var count := grid_width if (side == "T" or side == "B") else grid_height
	var all_hidden := true
	for i in range(count):
		if not ("%s_%d" % [side, i] in hidden_frame_pieces):
			all_hidden = false
			break
	for i in range(count):
		var k := "%s_%d" % [side, i]
		if all_hidden:
			hidden_frame_pieces.erase(k)
		elif not (k in hidden_frame_pieces):
			hidden_frame_pieces.append(k)

func has_board_margins() -> bool:
	return board_margin_left > 0 or board_margin_top > 0 or board_margin_right > 0 or board_margin_bottom > 0

func get_board_margins() -> Vector4i:
	return Vector4i(board_margin_left, board_margin_top, board_margin_right, board_margin_bottom)

func set_board_margins(l: int, t: int, r: int, b: int) -> void:
	board_margin_left = max(0, l)
	board_margin_top = max(0, t)
	board_margin_right = max(0, r)
	board_margin_bottom = max(0, b)

func get_effective_slice_cols() -> int:
	return board_slice_cols if board_slice_cols > 0 else max(1, grid_width)

func get_effective_slice_rows() -> int:
	return board_slice_rows if board_slice_rows > 0 else max(1, grid_height)

func set_cell_visual(cell: Vector2i, asset_path_or_name: String, rot_deg: float) -> void:
	var key := "%d,%d" % [cell.x, cell.y]
	cell_visuals[key] = {
		"asset": str(asset_path_or_name),
		"rotation": float(rot_deg)
	}

func get_cell_visual(cell: Vector2i) -> Dictionary:
	var key := "%d,%d" % [cell.x, cell.y]
	if cell_visuals.has(key):
		var v = cell_visuals[key]
		if v is Dictionary:
			return {
				"asset": str(v.get("asset", "")),
				"rotation": float(v.get("rotation", 0.0))
			}
	elif has_custom_tile(cell):
		var ct = get_custom_tile(cell)
		return {
			"asset": str(ct.get("asset", ct.get("type", 0))),
			"rotation": float(ct.get("rotation", 0.0))
		}
	return {}

func has_cell_visual(cell: Vector2i) -> bool:
	var key := "%d,%d" % [cell.x, cell.y]
	return cell_visuals.has(key) or has_custom_tile(cell)

func remove_cell_visual(cell: Vector2i) -> void:
	var key := "%d,%d" % [cell.x, cell.y]
	cell_visuals.erase(key)
	if custom_tiles.has(key):
		custom_tiles.erase(key)

func clear_all_cell_visuals() -> void:
	cell_visuals.clear()
	custom_tiles.clear()

func get_cell_visuals_count() -> int:
	return cell_visuals.size() if not cell_visuals.is_empty() else get_custom_tiles_count()

func set_custom_tile(cell: Vector2i, tile_type: int, rot_deg: int) -> void:
	var key := "%d,%d" % [cell.x, cell.y]
	custom_tiles[key] = {
		"type": int(tile_type),
		"rotation": int(rot_deg),
		"rot": int(rot_deg)
	}
	board_tiles[key] = [int(tile_type), int(rot_deg)]
	cell_visuals[key] = {
		"asset": str(tile_type),
		"rotation": float(rot_deg)
	}

func get_custom_tile(cell: Vector2i) -> Dictionary:
	var key := "%d,%d" % [cell.x, cell.y]
	if custom_tiles.has(key):
		var val = custom_tiles[key]
		if val is Dictionary:
			var rot_val = int(val.get("rotation", val.get("rot", 0)))
			return { "type": int(val.get("type", 0)), "rotation": rot_val, "rot": rot_val }
		elif val is Array and val.size() >= 2:
			return { "type": int(val[0]), "rotation": int(val[1]), "rot": int(val[1]) }
	elif board_tiles.has(key):
		var bval = board_tiles[key]
		if bval is Array and bval.size() >= 2:
			return { "type": int(bval[0]), "rotation": int(bval[1]), "rot": int(bval[1]) }
		elif bval is Dictionary:
			var rot_val = int(bval.get("rotation", bval.get("rot", 0)))
			return { "type": int(bval.get("type", 0)), "rotation": rot_val, "rot": rot_val }
	return {}

func has_custom_tile(cell: Vector2i) -> bool:
	var key := "%d,%d" % [cell.x, cell.y]
	return custom_tiles.has(key) or board_tiles.has(key) or cell_visuals.has(key)

func remove_custom_tile(cell: Vector2i) -> void:
	var key := "%d,%d" % [cell.x, cell.y]
	custom_tiles.erase(key)
	board_tiles.erase(key)
	cell_visuals.erase(key)

func clear_all_custom_tiles() -> void:
	custom_tiles.clear()
	board_tiles.clear()
	cell_visuals.clear()

func get_custom_tiles_count() -> int:
	return custom_tiles.size()

func set_board_tile(cell: Vector2i, tile_coord: Vector2i) -> void:
	set_custom_tile(cell, tile_coord.x, tile_coord.y)

func get_board_tile(cell: Vector2i) -> Vector2i:
	var t := get_custom_tile(cell)
	if not t.is_empty():
		return Vector2i(int(t.get("type", 0)), int(t.get("rot", 0)))
	return Vector2i(-1, -1)

func has_board_tile(cell: Vector2i) -> bool:
	return has_custom_tile(cell)

func remove_board_tile(cell: Vector2i) -> void:
	remove_custom_tile(cell)

func clear_all_board_tiles() -> void:
	clear_all_custom_tiles()

func auto_fill_board_tiles() -> void:
	var cols = get_effective_slice_cols()
	var rows = get_effective_slice_rows()
	board_tiles.clear()
	for x in range(grid_width):
		for y in range(grid_height):
			var tx = x % cols
			var ty = y % rows
			set_board_tile(Vector2i(x, y), Vector2i(tx, ty))

func set_tile_textures(middle: String, edge: String, corner: String, opening: String = "") -> void:
	tile_middle_path = middle
	tile_edge_path = edge
	tile_corner_path = corner
	tile_opening_path = opening

func has_whole_image_tiles() -> bool:
	return not tile_middle_path.strip_edges().is_empty() or not tile_edge_path.strip_edges().is_empty() or not tile_corner_path.strip_edges().is_empty()

func get_movable_area_at(pos: Vector2i) -> LaserObjectData:
	for obj in objects:
		if obj != null and obj.grid_pos == pos and obj.type == LaserObjectData.ObjectType.MOVABLE_AREA:
			return obj
	return null

func get_foreground_object_at(pos: Vector2i) -> LaserObjectData:
	for obj in objects:
		if obj != null and obj.grid_pos == pos and obj.type != LaserObjectData.ObjectType.MOVABLE_AREA:
			return obj
	return null

func has_movable_areas() -> bool:
	for obj in objects:
		if obj != null and obj.enabled and obj.type == LaserObjectData.ObjectType.MOVABLE_AREA:
			return true
	return false

func is_cell_in_movable_area(pos: Vector2i) -> bool:
	return get_movable_area_at(pos) != null

func is_inside_grid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height

func get_object_at(pos: Vector2i) -> LaserObjectData:
	var fg = get_foreground_object_at(pos)
	return fg if fg != null else get_movable_area_at(pos)

func get_objects_at(pos: Vector2i) -> Array[LaserObjectData]:
	var result: Array[LaserObjectData] = []
	for obj in objects:
		if obj != null and obj.grid_pos == pos:
			result.append(obj)
	return result

func get_object_by_id(p_id: String) -> LaserObjectData:
	for obj in objects:
		if obj != null and obj.id == p_id:
			return obj
	return null

func add_object(obj: LaserObjectData) -> bool:
	if obj == null:
		return false
	objects.append(obj)
	return true

func remove_object(obj: LaserObjectData) -> bool:
	var idx = objects.find(obj)
	if idx != -1:
		objects.remove_at(idx)
		return true
	return false

func remove_object_at(pos: Vector2i) -> bool:
	var removed: bool = false
	var i = objects.size() - 1
	while i >= 0:
		if objects[i] != null and objects[i].grid_pos == pos:
			objects.remove_at(i)
			removed = true
		i -= 1
	return removed

func clear_all_objects() -> void:
	objects.clear()

func duplicate_data() -> LaserStageData:
	var clone := LaserStageData.new()
	clone.stage_index = stage_index
	clone.grid_width = grid_width
	clone.grid_height = grid_height
	clone.entry_point = entry_point
	clone.entry_direction = entry_direction
	clone.exit_point = exit_point
	clone.exit_direction = exit_direction
	clone.time_limit = time_limit
	clone.time_bonus = time_bonus
	clone.stage_screen_position = stage_screen_position
	clone.stage_transition_direction = stage_transition_direction
	clone.board_image_path = board_image_path
	clone.board_slice_cols = board_slice_cols
	clone.board_slice_rows = board_slice_rows
	clone.board_tiles = board_tiles.duplicate(true)
	clone.custom_tiles = custom_tiles.duplicate(true)
	clone.cell_visuals = cell_visuals.duplicate(true)
	clone.border_horizontal_edge_path = border_horizontal_edge_path
	clone.border_vertical_edge_path = border_vertical_edge_path
	clone.border_corner_path = border_corner_path
	clone.border_enabled = border_enabled
	clone.cell_assets = cell_assets.duplicate(true)
	clone.border_assets = border_assets.duplicate(true)
	clone.corner_assets = corner_assets.duplicate(true)
	clone.border_visuals = border_visuals.duplicate(true)
	clone.corner_visuals = corner_visuals.duplicate(true)
	clone.board_margin_left = board_margin_left
	clone.board_margin_top = board_margin_top
	clone.board_margin_right = board_margin_right
	clone.board_margin_bottom = board_margin_bottom
	clone.show_tile_borders = show_tile_borders
	clone.hidden_frame_pieces = hidden_frame_pieces.duplicate()
	clone.tile_middle_path = tile_middle_path
	clone.tile_edge_path = tile_edge_path
	clone.tile_corner_path = tile_corner_path
	clone.tile_opening_path = tile_opening_path
	clone.metadata = metadata.duplicate(true)
	clone.objects = []
	for obj in objects:
		if obj != null:
			clone.objects.append(obj.duplicate_data())
	return clone

func to_dict() -> Dictionary:
	var objs_arr: Array = []
	for obj in objects:
		if obj != null:
			objs_arr.append(obj.to_dict())
	return {
		"stage_index": stage_index,
		"grid_width": grid_width,
		"grid_height": grid_height,
		"entry_point": [entry_point.x, entry_point.y],
		"entry_direction": int(entry_direction),
		"exit_point": [exit_point.x, exit_point.y],
		"exit_direction": int(exit_direction),
		"time_limit": time_limit,
		"time_bonus": time_bonus,
		"stage_screen_position": [stage_screen_position.x, stage_screen_position.y],
		"stage_transition_direction": int(stage_transition_direction),
		"board_image_path": board_image_path,
		"board_slice_cols": board_slice_cols,
		"board_slice_rows": board_slice_rows,
		"board_tiles": board_tiles,
		"custom_tiles": custom_tiles,
		"cell_visuals": cell_visuals,
		"border_horizontal_edge_path": border_horizontal_edge_path,
		"border_vertical_edge_path": border_vertical_edge_path,
		"border_corner_path": border_corner_path,
		"border_enabled": border_enabled,
		"cell_assets": cell_assets,
		"border_assets": border_assets,
		"corner_assets": corner_assets,
		"border_visuals": border_visuals,
		"corner_visuals": corner_visuals,
		"border_settings": {
			"enabled": border_enabled,
			"horizontal": border_horizontal_edge_path,
			"vertical": border_vertical_edge_path,
			"corner": border_corner_path
		},
		"board_margin_left": board_margin_left,
		"board_margin_top": board_margin_top,
		"board_margin_right": board_margin_right,
		"board_margin_bottom": board_margin_bottom,
		"show_tile_borders": show_tile_borders,
		"hidden_frame_pieces": hidden_frame_pieces,
		"tile_middle_path": tile_middle_path,
		"tile_edge_path": tile_edge_path,
		"tile_corner_path": tile_corner_path,
		"tile_opening_path": tile_opening_path,
		"metadata": metadata,
		"objects": objs_arr
	}

static func from_dict(d: Dictionary) -> LaserStageData:
	var st := LaserStageData.new()
	st.stage_index = int(d.get("stage_index", 1))
	st.grid_width = int(d.get("grid_width", 6))
	st.grid_height = int(d.get("grid_height", 12))
	var ep = d.get("entry_point", [0, 0])
	st.entry_point = Vector2i(int(ep[0]), int(ep[1]))
	st.entry_direction = int(d.get("entry_direction", 0)) as Direction
	var xp = d.get("exit_point", [st.grid_width - 1, st.grid_height - 1])
	st.exit_point = Vector2i(int(xp[0]), int(xp[1]))
	st.exit_direction = int(d.get("exit_direction", 1)) as Direction
	st.time_limit = float(d.get("time_limit", 20.0))
	st.time_bonus = float(d.get("time_bonus", 5.0))
	var ssp_raw = d.get("stage_screen_position", [-9999.0, -9999.0])
	st.stage_screen_position = Vector2(float(ssp_raw[0]), float(ssp_raw[1]))
	st.stage_transition_direction = int(d.get("stage_transition_direction", 0)) as TransitionDir
	st.board_image_path = str(d.get("board_image_path", ""))
	st.board_slice_cols = int(d.get("board_slice_cols", 0))
	st.board_slice_rows = int(d.get("board_slice_rows", 0))
	st.board_tiles = d.get("board_tiles", {}).duplicate(true)
	st.custom_tiles = d.get("custom_tiles", {}).duplicate(true)
	st.cell_visuals = d.get("cell_visuals", {}).duplicate(true)
	st.border_horizontal_edge_path = str(d.get("border_horizontal_edge_path", ""))
	st.border_vertical_edge_path = str(d.get("border_vertical_edge_path", ""))
	st.border_corner_path = str(d.get("border_corner_path", ""))
	st.border_enabled = bool(d.get("border_enabled", true))
	var bs = d.get("border_settings", {})
	if bs is Dictionary and not bs.is_empty():
		st.border_enabled = bool(bs.get("enabled", st.border_enabled))
		st.border_horizontal_edge_path = str(bs.get("horizontal", st.border_horizontal_edge_path))
		st.border_vertical_edge_path = str(bs.get("vertical", st.border_vertical_edge_path))
		st.border_corner_path = str(bs.get("corner", st.border_corner_path))

	# 3-Library Visual Assets & Placement Deserialization
	st.cell_assets = d.get("cell_assets", []).duplicate(true)
	st.border_assets = d.get("border_assets", []).duplicate(true)
	st.corner_assets = d.get("corner_assets", []).duplicate(true)
	st.border_visuals = d.get("border_visuals", {}).duplicate(true)
	st.corner_visuals = d.get("corner_visuals", {}).duplicate(true)
	st.ensure_default_visual_libraries()

	# If cell_visuals is empty but custom_tiles has items, populate cell_visuals
	if st.cell_visuals.is_empty() and not st.custom_tiles.is_empty():
		for k in st.custom_tiles.keys():
			var cv = st.custom_tiles[k]
			if cv is Dictionary:
				st.cell_visuals[k] = {
					"asset": str(cv.get("asset", cv.get("type", 0))),
					"rotation": float(cv.get("rotation", cv.get("rot", 0.0)))
				}
	# If custom_tiles was empty but board_tiles had items, migrate them
	if st.custom_tiles.is_empty() and not st.board_tiles.is_empty():
		for k in st.board_tiles.keys():
			var val = st.board_tiles[k]
			if val is Array and val.size() >= 2:
				st.custom_tiles[k] = { "type": int(val[0]), "rot": int(val[1]), "rotation": int(val[1]) }
				st.cell_visuals[k] = { "asset": str(val[0]), "rotation": float(val[1]) }
			elif val is Dictionary:
				st.custom_tiles[k] = val.duplicate(true)
				st.cell_visuals[k] = { "asset": str(val.get("asset", val.get("type", 0))), "rotation": float(val.get("rotation", 0.0)) }
	st.board_margin_left = int(d.get("board_margin_left", 0))
	st.board_margin_top = int(d.get("board_margin_top", 0))
	st.board_margin_right = int(d.get("board_margin_right", 0))
	st.board_margin_bottom = int(d.get("board_margin_bottom", 0))
	st.show_tile_borders = bool(d.get("show_tile_borders", true))
	var hfp_raw = d.get("hidden_frame_pieces", [])
	st.hidden_frame_pieces = []
	for p in hfp_raw:
		st.hidden_frame_pieces.append(str(p))
	st.tile_middle_path = str(d.get("tile_middle_path", ""))
	st.tile_edge_path = str(d.get("tile_edge_path", ""))
	st.tile_corner_path = str(d.get("tile_corner_path", ""))
	st.tile_opening_path = str(d.get("tile_opening_path", ""))
	st.metadata = d.get("metadata", {}).duplicate(true)
	st.objects = []
	var objs_raw = d.get("objects", [])
	for od in objs_raw:
		if od is Dictionary:
			st.objects.append(LaserObjectData.from_dict(od))
	return st

