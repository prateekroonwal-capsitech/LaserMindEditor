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

func is_inside_grid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height

func get_object_at(pos: Vector2i) -> LaserObjectData:
	for obj in objects:
		if obj != null and obj.grid_pos == pos and obj.type != LaserObjectData.ObjectType.MOVABLE_AREA:
			return obj
	for obj in objects:
		if obj != null and obj.grid_pos == pos:
			return obj
	return null

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
	st.metadata = d.get("metadata", {}).duplicate(true)
	st.objects = []
	var objs_raw = d.get("objects", [])
	for od in objs_raw:
		if od is Dictionary:
			st.objects.append(LaserObjectData.from_dict(od))
	return st
