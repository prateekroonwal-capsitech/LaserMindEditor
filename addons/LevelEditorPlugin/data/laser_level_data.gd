@tool
extends Resource
class_name LaserLevelData

const STAGE_COUNT: int = 3
const DEFAULT_STAGE_COUNT: int = 3

@export var level_id: int = 1
@export var level_number: int = 1
@export var level_name: String = "Level 01"
@export var universal_timer: float = 60.0
@export var star_threshold_3: float = 35.0
@export var star_threshold_2: float = 50.0
@export var star_threshold_1: float = 60.0
@export var coin_reward_3: int = 100
@export var coin_reward_2: int = 50
@export var coin_reward_1: int = 25
@export var stages: Array[LaserStageData] = []
@export var mechanic_tags: PackedStringArray = []
@export var manual_difficulty_override: String = ""

func _init() -> void:
	ensure_stages()

func ensure_three_stages() -> void:
	ensure_stages()

func ensure_stages() -> void:
	if stages == null:
		stages = []

	if stages.is_empty():
		for i in range(1, DEFAULT_STAGE_COUNT + 1):
			var st := LaserStageData.new()
			st.stage_index = i
			match i:
				1:
					st.grid_width = 5
					st.grid_height = 5
					st.time_limit = 15.0
					st.time_bonus = 5.0
				2:
					st.grid_width = 6
					st.grid_height = 6
					st.time_limit = 20.0
					st.time_bonus = 5.0
				3:
					st.grid_width = 7
					st.grid_height = 7
					st.time_limit = 25.0
					st.time_bonus = 5.0
				_:
					st.grid_width = 7
					st.grid_height = 7
					st.time_limit = 25.0
					st.time_bonus = 5.0
			stages.append(st)

	for i in range(stages.size()):
		if stages[i] != null:
			stages[i].stage_index = i + 1

func get_stage_count() -> int:
	ensure_stages()
	return stages.size()

func get_stage(index_1_based: int) -> LaserStageData:
	ensure_stages()
	var idx = clamp(index_1_based - 1, 0, stages.size() - 1)
	return stages[idx]

func add_stage() -> LaserStageData:
	ensure_stages()
	var st := LaserStageData.new()
	st.stage_index = stages.size() + 1
	var last_stage: LaserStageData = stages[stages.size() - 1] if not stages.is_empty() else null
	if last_stage != null:
		st.grid_width = last_stage.grid_width
		st.grid_height = last_stage.grid_height
		st.time_limit = last_stage.time_limit
		st.time_bonus = last_stage.time_bonus
	else:
		st.grid_width = 7
		st.grid_height = 7
		st.time_limit = 25.0
		st.time_bonus = 5.0
	stages.append(st)
	return st

func remove_stage(index_1_based: int) -> bool:
	ensure_stages()
	if stages.size() <= 1:
		return false
	var idx = index_1_based - 1
	if idx >= 0 and idx < stages.size():
		stages.remove_at(idx)
		for i in range(stages.size()):
			if stages[i] != null:
				stages[i].stage_index = i + 1
		return true
	return false

func duplicate_data() -> LaserLevelData:
	var clone := LaserLevelData.new()
	clone.level_id = level_id
	clone.level_number = level_number
	clone.level_name = level_name
	clone.universal_timer = universal_timer
	clone.star_threshold_3 = star_threshold_3
	clone.star_threshold_2 = star_threshold_2
	clone.star_threshold_1 = star_threshold_1
	clone.coin_reward_3 = coin_reward_3
	clone.coin_reward_2 = coin_reward_2
	clone.coin_reward_1 = coin_reward_1
	clone.mechanic_tags = mechanic_tags.duplicate()
	clone.manual_difficulty_override = manual_difficulty_override
	clone.stages = []
	for st in stages:
		if st != null:
			clone.stages.append(st.duplicate_data())
	return clone

func to_dict() -> Dictionary:
	ensure_stages()
	var stages_dict: Array = []
	for st in stages:
		if st != null:
			stages_dict.append(st.to_dict())
	return {
		"level_id": level_id,
		"level_number": level_number,
		"level_name": level_name,
		"universal_timer": universal_timer,
		"star_threshold_3": star_threshold_3,
		"star_threshold_2": star_threshold_2,
		"star_threshold_1": star_threshold_1,
		"coin_reward_3": coin_reward_3,
		"coin_reward_2": coin_reward_2,
		"coin_reward_1": coin_reward_1,
		"mechanic_tags": Array(mechanic_tags),
		"manual_difficulty_override": manual_difficulty_override,
		"stages": stages_dict
	}

static func from_dict(d: Dictionary) -> LaserLevelData:
	var lvl := LaserLevelData.new()
	lvl.level_id = int(d.get("level_id", 1))
	lvl.level_number = int(d.get("level_number", 1))
	lvl.level_name = str(d.get("level_name", "Level 01"))
	lvl.universal_timer = float(d.get("universal_timer", 60.0))
	lvl.star_threshold_3 = float(d.get("star_threshold_3", 35.0))
	lvl.star_threshold_2 = float(d.get("star_threshold_2", 50.0))
	lvl.star_threshold_1 = float(d.get("star_threshold_1", 60.0))
	lvl.coin_reward_3 = int(d.get("coin_reward_3", 100))
	lvl.coin_reward_2 = int(d.get("coin_reward_2", 50))
	lvl.coin_reward_1 = int(d.get("coin_reward_1", 25))
	lvl.manual_difficulty_override = str(d.get("manual_difficulty_override", ""))
	var tags_raw = d.get("mechanic_tags", [])
	var tags: PackedStringArray = []
	for t in tags_raw:
		tags.append(str(t))
	lvl.mechanic_tags = tags

	lvl.stages = []
	var st_arr = d.get("stages", [])
	for sd in st_arr:
		if sd is Dictionary:
			lvl.stages.append(LaserStageData.from_dict(sd))
	lvl.ensure_stages()
	return lvl

func to_legacy_level_data(stage_idx: int = 1) -> Resource:
	var st := get_stage(stage_idx)
	var leg_script_path := "res://Game/Scripts/Resources/LevelData.gd"
	if not ResourceLoader.exists(leg_script_path):
		return null
	var LevelDataScript = load(leg_script_path)
	if LevelDataScript == null:
		return null
	var leg = LevelDataScript.new()
	leg.level_id = level_id

	for obj in st.objects:
		if obj == null or not obj.enabled:
			continue
		match obj.type:
			LaserObjectData.ObjectType.LASER_SOURCE:
				var sp := "res://Game/Scripts/Resources/EmitterData.gd"
				if ResourceLoader.exists(sp):
					var emit = load(sp).new()
					emit.grid_cell = obj.grid_pos
					emit.direction_degrees = obj.rotation_deg
					emit.active_directions = [obj.rotation_deg]
					leg.emitters.append(emit)

			LaserObjectData.ObjectType.FIXED_MIRROR:
				var sp := "res://Game/Scripts/Resources/FixedMirrorData.gd"
				if ResourceLoader.exists(sp):
					var fm = load(sp).new()
					fm.grid_cell = obj.grid_pos
					fm.rotation_steps = int(obj.rotation_deg / 90) % 4
					leg.fixed_mirrors.append(fm)

			LaserObjectData.ObjectType.MOVABLE_MIRROR, LaserObjectData.ObjectType.ROTATABLE_MIRROR:
				var sp := "res://Game/Scripts/Resources/MirrorData.gd"
				if ResourceLoader.exists(sp):
					var m = load(sp).new()
					m.grid_cell = obj.grid_pos
					m.rotation_steps = int(obj.rotation_deg / 90) % 4
					leg.mirrors.append(m)

			LaserObjectData.ObjectType.GOAL:
				var sp := "res://Game/Scripts/Resources/ReceiverData.gd"
				if ResourceLoader.exists(sp):
					var rec = load(sp).new()
					rec.grid_cell = obj.grid_pos
					leg.receivers.append(rec)
					if "receiver" in leg and leg.receiver == null:
						leg.receiver = rec

			LaserObjectData.ObjectType.ROCK:
				var sp := "res://Game/Scripts/Resources/WallData.gd"
				if ResourceLoader.exists(sp):
					var w = load(sp).new()
					w.grid_cell = obj.grid_pos
					leg.walls.append(w)

			LaserObjectData.ObjectType.ICE:
				var sp := "res://Game/Scripts/Resources/StopperData.gd"
				if ResourceLoader.exists(sp):
					var stp = load(sp).new()
					stp.grid_cell = obj.grid_pos
					leg.stoppers.append(stp)

			LaserObjectData.ObjectType.SPLITTER:
				var sp := "res://Game/Scripts/Resources/SplitterData.gd"
				if ResourceLoader.exists(sp):
					var spl = load(sp).new()
					spl.grid_cell = obj.grid_pos
					spl.rotation_steps = int(obj.rotation_deg / 90) % 4
					leg.splitters.append(spl)

			LaserObjectData.ObjectType.COLOR_GLASS:
				var sp := "res://Game/Scripts/Resources/GlassData.gd"
				if ResourceLoader.exists(sp):
					var gl = load(sp).new()
					gl.grid_cell = obj.grid_pos
					leg.glasses.append(gl)

			LaserObjectData.ObjectType.COLOR_WALL:
				var sp := "res://Game/Scripts/Resources/WallData.gd"
				if ResourceLoader.exists(sp):
					var w = load(sp).new()
					w.grid_cell = obj.grid_pos
					leg.walls.append(w)

			LaserObjectData.ObjectType.GATE:
				var sp := "res://Game/Scripts/Resources/GateData.gd"
				if ResourceLoader.exists(sp):
					var g = load(sp).new()
					g.grid_cell = obj.grid_pos
					leg.gates.append(g)

			LaserObjectData.ObjectType.SWITCH:
				var sp := "res://Game/Scripts/Resources/BatteryData.gd"
				if ResourceLoader.exists(sp):
					var b = load(sp).new()
					b.grid_cell = obj.grid_pos
					leg.batteries.append(b)

	return leg

static func from_legacy_level_data(legacy: Resource) -> LaserLevelData:
	var lvl := LaserLevelData.new()
	if legacy == null:
		return lvl
	lvl.level_id = legacy.get("level_id") if "level_id" in legacy else 1
	lvl.level_number = lvl.level_id
	lvl.level_name = "Level %02d" % lvl.level_id
	lvl.ensure_three_stages()

	var st1: LaserStageData = lvl.get_stage(1)
	st1.grid_width = legacy.get("GRID_COLUMNS") if "GRID_COLUMNS" in legacy else 6
	st1.grid_height = legacy.get("GRID_ROWS") if "GRID_ROWS" in legacy else 12
	st1.clear_all_objects()

	if legacy.has_method("get_all_emitters"):
		for emit in legacy.get_all_emitters():
			if emit != null:
				var dir: int = emit.direction_degrees if "direction_degrees" in emit else 0
				var obj := LaserObjectData.create(LaserObjectData.ObjectType.LASER_SOURCE, emit.grid_cell, dir)
				st1.add_object(obj)
	elif "emitters" in legacy and legacy.emitters is Array:
		for emit in legacy.emitters:
			if emit != null:
				var dir: int = emit.direction_degrees if "direction_degrees" in emit else 0
				var obj := LaserObjectData.create(LaserObjectData.ObjectType.LASER_SOURCE, emit.grid_cell, dir)
				st1.add_object(obj)

	if legacy.has_method("get_all_receivers"):
		for rec in legacy.get_all_receivers():
			if rec != null:
				var obj := LaserObjectData.create(LaserObjectData.ObjectType.GOAL, rec.grid_cell, 0)
				st1.add_object(obj)
	elif "receivers" in legacy and legacy.receivers is Array:
		for rec in legacy.receivers:
			if rec != null:
				var obj := LaserObjectData.create(LaserObjectData.ObjectType.GOAL, rec.grid_cell, 0)
				st1.add_object(obj)

	if "mirrors" in legacy and legacy.mirrors is Array:
		for m in legacy.mirrors:
			if m != null:
				var rot: int = (m.rotation_steps * 90) if "rotation_steps" in m else 0
				var obj := LaserObjectData.create(LaserObjectData.ObjectType.MOVABLE_MIRROR, m.grid_cell, rot)
				st1.add_object(obj)

	if "fixed_mirrors" in legacy and legacy.fixed_mirrors is Array:
		for fm in legacy.fixed_mirrors:
			if fm != null:
				var rot: int = (fm.rotation_steps * 90) if "rotation_steps" in fm else 0
				var obj := LaserObjectData.create(LaserObjectData.ObjectType.FIXED_MIRROR, fm.grid_cell, rot)
				st1.add_object(obj)

	if "walls" in legacy and legacy.walls is Array:
		for w in legacy.walls:
			if w != null:
				var obj := LaserObjectData.create(LaserObjectData.ObjectType.ROCK, w.grid_cell, 0)
				st1.add_object(obj)

	if "stoppers" in legacy and legacy.stoppers is Array:
		for stp in legacy.stoppers:
			if stp != null:
				var obj := LaserObjectData.create(LaserObjectData.ObjectType.ICE, stp.grid_cell, 0)
				st1.add_object(obj)

	if "splitters" in legacy and legacy.splitters is Array:
		for spl in legacy.splitters:
			if spl != null:
				var rot: int = (spl.rotation_steps * 90) if "rotation_steps" in spl else 0
				var obj := LaserObjectData.create(LaserObjectData.ObjectType.SPLITTER, spl.grid_cell, rot)
				st1.add_object(obj)

	if "glasses" in legacy and legacy.glasses is Array:
		for gl in legacy.glasses:
			if gl != null:
				var obj := LaserObjectData.create(LaserObjectData.ObjectType.COLOR_GLASS, gl.grid_cell, 0)
				st1.add_object(obj)

	if "gates" in legacy and legacy.gates is Array:
		for g in legacy.gates:
			if g != null:
				var obj := LaserObjectData.create(LaserObjectData.ObjectType.GATE, g.grid_cell, 0)
				st1.add_object(obj)

	if "batteries" in legacy and legacy.batteries is Array:
		for b in legacy.batteries:
			if b != null:
				var obj := LaserObjectData.create(LaserObjectData.ObjectType.SWITCH, b.grid_cell, 0)
				st1.add_object(obj)

	var st2: LaserStageData = lvl.get_stage(2)
	st2.grid_width = st1.grid_width
	st2.grid_height = st1.grid_height
	st2.objects.clear()
	for obj in st1.objects:
		st2.add_object(obj.duplicate_data())

	var st3: LaserStageData = lvl.get_stage(3)
	st3.grid_width = st1.grid_width
	st3.grid_height = st1.grid_height
	st3.objects.clear()
	for obj in st1.objects:
		st3.add_object(obj.duplicate_data())

	return lvl
