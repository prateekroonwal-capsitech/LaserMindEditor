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
@export var board_margin_left: int = 0
@export var board_margin_top: int = 0
@export var board_margin_right: int = 0
@export var board_margin_bottom: int = 0
@export var show_tile_borders: bool = true
@export var hidden_frame_pieces: Array[String] = []

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

func set_board_tile(cell: Vector2i, tile_coord: Vector2i) -> void:
	board_tiles["%d,%d" % [cell.x, cell.y]] = [tile_coord.x, tile_coord.y]

func get_board_tile(cell: Vector2i) -> Vector2i:
	var key := "%d,%d" % [cell.x, cell.y]
	if board_tiles.has(key):
		var val = board_tiles[key]
		if val is Array and val.size() >= 2:
			return Vector2i(int(val[0]), int(val[1]))
	return Vector2i(-1, -1)

func has_board_tile(cell: Vector2i) -> bool:
	return board_tiles.has("%d,%d" % [cell.x, cell.y])

func remove_board_tile(cell: Vector2i) -> void:
	board_tiles.erase("%d,%d" % [cell.x, cell.y])

func clear_all_board_tiles() -> void:
	board_tiles.clear()

func auto_fill_board_tiles() -> void:
	var cols = get_effective_slice_cols()
	var rows = get_effective_slice_rows()
	board_tiles.clear()
	for x in range(grid_width):
		for y in range(grid_height):
			var tx = x % cols
			var ty = y % rows
			set_board_tile(Vector2i(x, y), Vector2i(tx, ty))

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
	clone.board_margin_left = board_margin_left
	clone.board_margin_top = board_margin_top
	clone.board_margin_right = board_margin_right
	clone.board_margin_bottom = board_margin_bottom
	clone.show_tile_borders = show_tile_borders
	clone.hidden_frame_pieces = hidden_frame_pieces.duplicate()
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
		"board_margin_left": board_margin_left,
		"board_margin_top": board_margin_top,
		"board_margin_right": board_margin_right,
		"board_margin_bottom": board_margin_bottom,
		"show_tile_borders": show_tile_borders,
		"hidden_frame_pieces": hidden_frame_pieces,
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
	st.board_margin_left = int(d.get("board_margin_left", 0))
	st.board_margin_top = int(d.get("board_margin_top", 0))
	st.board_margin_right = int(d.get("board_margin_right", 0))
	st.board_margin_bottom = int(d.get("board_margin_bottom", 0))
	st.show_tile_borders = bool(d.get("show_tile_borders", true))
	var hfp_raw = d.get("hidden_frame_pieces", [])
	st.hidden_frame_pieces = []
	for p in hfp_raw:
		st.hidden_frame_pieces.append(str(p))
	st.metadata = d.get("metadata", {}).duplicate(true)
	st.objects = []
	var objs_raw = d.get("objects", [])
	for od in objs_raw:
		if od is Dictionary:
			st.objects.append(LaserObjectData.from_dict(od))
	return st

