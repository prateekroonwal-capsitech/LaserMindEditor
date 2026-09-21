@tool
extends Resource
class_name LaserObjectData

enum ObjectType {
	LASER_SOURCE,
	FIXED_MIRROR,
	MOVABLE_MIRROR,
	ROTATABLE_MIRROR,
	MOVABLE_AREA,
	GOAL,
	ROCK,
	ICE,
	SPLITTER,
	COLOR_GLASS,
	COLOR_WALL,
	GATE,
	SWITCH,
	GATE_SWITCH,
	CUSTOM,
	EXIT_GATE
}

const ENTRY_GATE = ObjectType.GATE

const TYPE_NAMES: Dictionary = {
	ObjectType.LASER_SOURCE: "Laser",
	ObjectType.FIXED_MIRROR: "Fixed Mirror",
	ObjectType.MOVABLE_MIRROR: "Movable Mirror",
	ObjectType.ROTATABLE_MIRROR: "Rotatable Mirror",
	ObjectType.MOVABLE_AREA: "Movable Area",
	ObjectType.ROCK: "Rock",
	ObjectType.ICE: "Ice",
	ObjectType.SPLITTER: "Splitter",
	ObjectType.COLOR_GLASS: "Color Glass",
	ObjectType.COLOR_WALL: "Color Wall",
	ObjectType.GATE: "Entry Gate",
	ObjectType.SWITCH: "Switch",
	ObjectType.GATE_SWITCH: "Gate with switch",
	ObjectType.CUSTOM: "Custom",
	ObjectType.EXIT_GATE: "Exit Gate",
}

const TYPE_SHORT_NAMES: Dictionary = {
	ObjectType.LASER_SOURCE: "Laser",
	ObjectType.FIXED_MIRROR: "FixMir",
	ObjectType.MOVABLE_MIRROR: "MovMir",
	ObjectType.ROTATABLE_MIRROR: "RotMir",
	ObjectType.MOVABLE_AREA: "MovArea",
	ObjectType.ROCK: "Rock",
	ObjectType.ICE: "Ice",
	ObjectType.SPLITTER: "Split",
	ObjectType.COLOR_GLASS: "Glass",
	ObjectType.COLOR_WALL: "ColWall",
	ObjectType.GATE: "EntGate",
	ObjectType.SWITCH: "Switch",
	ObjectType.GATE_SWITCH: "GateSw",
	ObjectType.CUSTOM: "Custom",
	ObjectType.EXIT_GATE: "ExtGate",
}

@export var id: String = ""
@export var type: ObjectType = ObjectType.FIXED_MIRROR
@export var grid_pos: Vector2i = Vector2i.ZERO
@export var rotation_deg: int = 0
@export var color: Color = Color(1.0, 0.2, 0.2, 1.0)
@export var movable: bool = false
@export var rotatable: bool = false
@export var enabled: bool = true
@export var target_id: String = ""
@export var properties: Dictionary = {}

func _init() -> void:
	if id.is_empty():
		id = generate_id(type)

static func create(p_type: ObjectType, p_pos: Vector2i, p_rot: int = 0) -> LaserObjectData:
	var obj := LaserObjectData.new()
	obj.type = p_type
	obj.grid_pos = p_pos
	obj.rotation_deg = p_rot
	obj.id = generate_id(p_type)
	if p_type == ObjectType.MOVABLE_MIRROR:
		obj.movable = true
	elif p_type == ObjectType.ROTATABLE_MIRROR:
		obj.rotatable = true
	return obj

static func generate_id(p_type: ObjectType) -> String:
	var prefix := "obj"
	match p_type:
		ObjectType.LASER_SOURCE: prefix = "laser"
		ObjectType.FIXED_MIRROR: prefix = "fmir"
		ObjectType.MOVABLE_MIRROR: prefix = "mmir"
		ObjectType.ROTATABLE_MIRROR: prefix = "rmir"
		ObjectType.MOVABLE_AREA: prefix = "marea"
		ObjectType.ROCK: prefix = "rock"
		ObjectType.ICE: prefix = "ice"
		ObjectType.SPLITTER: prefix = "split"
		ObjectType.COLOR_GLASS: prefix = "glass"
		ObjectType.COLOR_WALL: prefix = "cwall"
		ObjectType.GATE: prefix = "gate"
		ObjectType.SWITCH: prefix = "switch"
		ObjectType.GATE_SWITCH: prefix = "gsw"
		ObjectType.CUSTOM: prefix = "custom"
		ObjectType.EXIT_GATE: prefix = "xgate"
	return "%s_%04d" % [prefix, randi() % 10000]

func generate_new_id() -> String:
	var old_id = id
	var new_id = generate_id(type)
	var attempts: int = 0
	while new_id == old_id and attempts < 100:
		new_id = generate_id(type)
		attempts += 1
	id = new_id
	return id

func _generate_unique_id() -> String:
	return generate_new_id()

func duplicate_data() -> LaserObjectData:
	var clone := LaserObjectData.new()
	clone.id = id
	clone.type = type
	clone.grid_pos = grid_pos
	clone.rotation_deg = rotation_deg
	clone.color = color
	clone.movable = movable
	clone.rotatable = rotatable
	clone.enabled = enabled
	clone.target_id = target_id
	clone.properties = properties.duplicate(true)
	return clone

func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": int(type),
		"grid_pos": [grid_pos.x, grid_pos.y],
		"rotation_deg": rotation_deg,
		"color": color.to_html(false),
		"movable": movable,
		"rotatable": rotatable,
		"enabled": enabled,
		"target_id": target_id,
		"properties": properties
	}

static func from_dict(d: Dictionary) -> LaserObjectData:
	var obj := LaserObjectData.new()
	obj.id = str(d.get("id", ""))
	obj.type = int(d.get("type", 0)) as ObjectType
	var p = d.get("grid_pos", [0, 0])
	obj.grid_pos = Vector2i(int(p[0]), int(p[1]))
	obj.rotation_deg = int(d.get("rotation_deg", 0))
	if d.has("color"):
		obj.color = Color.from_string(str(d.get("color")), Color.RED)
	obj.movable = bool(d.get("movable", false))
	obj.rotatable = bool(d.get("rotatable", false))
	obj.enabled = bool(d.get("enabled", true))
	obj.target_id = str(d.get("target_id", ""))
	obj.properties = d.get("properties", {}).duplicate(true)
	return obj

func get_direction_vector() -> Vector2i:
	match rotation_deg:
		0: return Vector2i(1, 0)
		90: return Vector2i(0, 1)
		180: return Vector2i(-1, 0)
		270: return Vector2i(0, -1)
		45: return Vector2i(1, 1)
		135: return Vector2i(-1, 1)
		225: return Vector2i(-1, -1)
		315: return Vector2i(1, -1)
		_: return Vector2i(1, 0)
