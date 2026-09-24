@tool
extends RefCounted
class_name LaserSimulation

const MAX_STEPS: int = 250
const MAX_BEAMS: int = 64
const MAX_PASSES: int = 3

static func simulate_stage(stage: LaserStageData, allow_entry_gate_emission: bool = true, incoming_laser_color: Color = Color(-1, -1, -1, -1)) -> Dictionary:
	if stage == null:
		return _empty_result()

	var object_map: Dictionary = {}
	var laser_sources: Array[LaserObjectData] = []
	var goals: Array[LaserObjectData] = []
	var switches: Array[LaserObjectData] = []
	var gates: Array[LaserObjectData] = []
	var exit_gates: Array[LaserObjectData] = []

	for obj in stage.objects:
		if obj == null or not obj.enabled:
			continue
		if obj.type == LaserObjectData.ObjectType.MOVABLE_AREA:
			if not object_map.has(obj.grid_pos):
				object_map[obj.grid_pos] = obj
		else:
			object_map[obj.grid_pos] = obj

		match obj.type:
			LaserObjectData.ObjectType.LASER_SOURCE:
				laser_sources.append(obj)
			LaserObjectData.ObjectType.GOAL:
				goals.append(obj)
			LaserObjectData.ObjectType.SWITCH, LaserObjectData.ObjectType.GATE_SWITCH:
				switches.append(obj)
			LaserObjectData.ObjectType.GATE:
				gates.append(obj)
			LaserObjectData.ObjectType.EXIT_GATE:
				exit_gates.append(obj)

	var open_gates: Dictionary = {}
	var final_segments: Array[Dictionary] = []
	var goals_hit: Dictionary = {}
	var exit_gates_hit: Dictionary = {}
	var switches_hit: Dictionary = {}
	var reflections_count: int = 0
	var total_path_len: int = 0

	for _pass in range(MAX_PASSES):
		final_segments.clear()
		goals_hit.clear()
		exit_gates_hit.clear()
		switches_hit.clear()
		reflections_count = 0
		total_path_len = 0

		var queue: Array[Dictionary] = []
		var processed_states: Dictionary = {}

		for src in laser_sources:
			var start_dir: Vector2i = src.get_direction_vector()
			queue.append({
				"pos": src.grid_pos,
				"dir": start_dir,
				"color": src.color,
				"is_origin": true
			})

		if laser_sources.is_empty() and allow_entry_gate_emission:
			for eg in gates:
				var entry_dir: Vector2i = eg.get_direction_vector()
				if entry_dir == Vector2i.ZERO:
					entry_dir = Vector2i(1, 0)
				var ray_color: Color = incoming_laser_color if incoming_laser_color.a >= 0.0 else (eg.color if eg.color.a > 0.0 else Color(1.0, 0.2, 0.2, 1.0))
				queue.append({
					"pos": eg.grid_pos,
					"dir": entry_dir,
					"color": ray_color,
					"is_origin": true
				})
			if gates.is_empty() and stage.entry_point != Vector2i(-1, -1) and stage.is_inside_grid(stage.entry_point):
				var entry_dir: Vector2i = Vector2i(1, 0)
				match stage.entry_direction:
					LaserStageData.Direction.LEFT: entry_dir = Vector2i(-1, 0)
					LaserStageData.Direction.RIGHT: entry_dir = Vector2i(1, 0)
					LaserStageData.Direction.UP: entry_dir = Vector2i(0, -1)
					LaserStageData.Direction.DOWN: entry_dir = Vector2i(0, 1)
				var ray_color: Color = incoming_laser_color if incoming_laser_color.a >= 0.0 else Color(1.0, 0.2, 0.2, 1.0)
				queue.append({
					"pos": stage.entry_point,
					"dir": entry_dir,
					"color": ray_color,
					"is_origin": true
				})

		var beam_counter: int = 0

		while not queue.is_empty() and beam_counter < MAX_BEAMS:
			beam_counter += 1
			var beam_data: Dictionary = queue.pop_front()
			var current_pos: Vector2i = beam_data["pos"]
			var current_dir: Vector2i = beam_data["dir"]
			var beam_color: Color = beam_data["color"]
			var segment_start: Vector2i = current_pos

			var steps: int = 0
			var beam_stopped: bool = false

			while steps < MAX_STEPS:
				steps += 1
				var next_pos: Vector2i = current_pos + current_dir
				total_path_len += 1

				if not stage.is_inside_grid(next_pos):
					var edge_obj: LaserObjectData = object_map.get(next_pos, null)
					if edge_obj != null and (edge_obj.type == LaserObjectData.ObjectType.EXIT_GATE or edge_obj.type == LaserObjectData.ObjectType.GOAL):
						if edge_obj.type == LaserObjectData.ObjectType.EXIT_GATE:
							exit_gates_hit[next_pos] = true
						else:
							goals_hit[next_pos] = true
						final_segments.append({
							"start": segment_start,
							"end": next_pos,
							"color": beam_color,
							"hit_type": "exit_gate" if edge_obj.type == LaserObjectData.ObjectType.EXIT_GATE else "goal",
							"hit_pos": next_pos
						})
					else:
						final_segments.append({
							"start": segment_start,
							"end": current_pos,
							"color": beam_color,
							"hit_type": "boundary",
							"hit_pos": next_pos
						})
					beam_stopped = true
					break

				var loop_key: String = "%d,%d_%d,%d_%s" % [next_pos.x, next_pos.y, current_dir.x, current_dir.y, beam_color.to_html(false)]
				if processed_states.has(loop_key):
					final_segments.append({
						"start": segment_start,
						"end": next_pos,
						"color": beam_color,
						"hit_type": "loop",
						"hit_pos": next_pos
					})
					beam_stopped = true
					break
				processed_states[loop_key] = true

				var obj: LaserObjectData = object_map.get(next_pos, null)
				current_pos = next_pos

				if obj != null:
					match obj.type:
						LaserObjectData.ObjectType.ROCK, LaserObjectData.ObjectType.ICE:
							final_segments.append({
								"start": segment_start,
								"end": current_pos,
								"color": beam_color,
								"hit_type": "blocker",
								"hit_pos": current_pos
							})
							beam_stopped = true
							break

						LaserObjectData.ObjectType.CUSTOM:
							final_segments.append({
								"start": segment_start,
								"end": current_pos,
								"color": beam_color,
								"hit_type": "custom",
								"hit_pos": current_pos
							})
							beam_stopped = true
							break

						LaserObjectData.ObjectType.GOAL, LaserObjectData.ObjectType.EXIT_GATE:
							if obj.type == LaserObjectData.ObjectType.GOAL:
								goals_hit[current_pos] = true
							else:
								exit_gates_hit[current_pos] = true
							final_segments.append({
								"start": segment_start,
								"end": current_pos,
								"color": beam_color,
								"hit_type": "goal" if obj.type == LaserObjectData.ObjectType.GOAL else "exit_gate",
								"hit_pos": current_pos
							})
							beam_stopped = true
							break

						LaserObjectData.ObjectType.SWITCH, LaserObjectData.ObjectType.GATE_SWITCH:
							switches_hit[current_pos] = true

						LaserObjectData.ObjectType.GATE:
							var is_open: bool = open_gates.get(obj.id, false)
							if not is_open:
								final_segments.append({
									"start": segment_start,
									"end": current_pos,
									"color": beam_color,
									"hit_type": "gate_closed",
									"hit_pos": current_pos
								})
								beam_stopped = true
								break

						LaserObjectData.ObjectType.MOVABLE_AREA:
							pass

						LaserObjectData.ObjectType.COLOR_GLASS:
							beam_color = obj.color

						LaserObjectData.ObjectType.COLOR_WALL:
							if not _colors_match(beam_color, obj.color):
								final_segments.append({
									"start": segment_start,
									"end": current_pos,
									"color": beam_color,
									"hit_type": "color_wall_blocked",
									"hit_pos": current_pos
								})
								beam_stopped = true
								break

						LaserObjectData.ObjectType.FIXED_MIRROR, LaserObjectData.ObjectType.MOVABLE_MIRROR, LaserObjectData.ObjectType.ROTATABLE_MIRROR:
							final_segments.append({
								"start": segment_start,
								"end": current_pos,
								"color": beam_color,
								"hit_type": "mirror",
								"hit_pos": current_pos
							})
							reflections_count += 1
							var new_dir: Vector2i = _reflect_direction(current_dir, obj.rotation_deg)
							if new_dir == Vector2i.ZERO:
								beam_stopped = true
								break
							current_dir = new_dir
							segment_start = current_pos

						LaserObjectData.ObjectType.SPLITTER:
							final_segments.append({
								"start": segment_start,
								"end": current_pos,
								"color": beam_color,
								"hit_type": "splitter",
								"hit_pos": current_pos
							})
							var split_dirs: Array[Vector2i] = _get_splitter_dirs(current_dir, obj.rotation_deg)
							for s_dir in split_dirs:
								queue.append({
									"pos": current_pos,
									"dir": s_dir,
									"color": beam_color,
									"is_origin": false
								})
							beam_stopped = true
							break

			if not beam_stopped:
				final_segments.append({
					"start": segment_start,
					"end": current_pos,
					"color": beam_color,
					"hit_type": "open",
					"hit_pos": current_pos
				})

		var state_changed: bool = false
		for sw_pos in switches_hit.keys():
			var sw_obj: LaserObjectData = object_map.get(sw_pos, null)
			if sw_obj != null:
				for g in gates:
					if sw_obj.target_id.is_empty() or sw_obj.target_id == g.id:
						if not open_gates.get(g.id, false):
							open_gates[g.id] = true
							state_changed = true

		if not state_changed:
			break

	var all_goals_ok: bool = false
	if not goals.is_empty() or not exit_gates.is_empty():
		all_goals_ok = true
		for g in goals:
			if not goals_hit.get(g.grid_pos, false):
				all_goals_ok = false
				break
		if all_goals_ok:
			for xg in exit_gates:
				if not exit_gates_hit.get(xg.grid_pos, false):
					all_goals_ok = false
					break
	elif stage.exit_point != Vector2i(-1, -1):
		for seg in final_segments:
			if seg.get("end", Vector2i(-1, -1)) == stage.exit_point or seg.get("hit_pos", Vector2i(-1, -1)) == stage.exit_point:
				all_goals_ok = true
				break

	return {
		"segments": final_segments,
		"goals_hit": goals_hit,
		"exit_gates_hit": exit_gates_hit,
		"switches_hit": switches_hit,
		"all_goals_satisfied": all_goals_ok,
		"total_path_length": total_path_len,
		"reflections_count": reflections_count,
		"beam_count": final_segments.size()
	}

static func _reflect_direction(incoming: Vector2i, rot_deg: int) -> Vector2i:
	var norm_rot: int = ((rot_deg % 360) + 360) % 360
	var step_45: int = int(round(float(norm_rot) / 45.0)) % 8

	match step_45:
		0, 4:
			return Vector2i(incoming.y, incoming.x)
		2, 6:
			return Vector2i(-incoming.y, -incoming.x)
		1, 5:
			if incoming.x != 0:
				return Vector2i(-incoming.x, 0)
			return Vector2i.ZERO
		3, 7:
			if incoming.y != 0:
				return Vector2i(0, -incoming.y)
			return Vector2i.ZERO
		_:
			return Vector2i(incoming.y, incoming.x)

static func _get_splitter_dirs(incoming: Vector2i, rot_deg: int) -> Array[Vector2i]:
	var step: int = int(round(float(rot_deg) / 90.0)) % 4
	var base_ports: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]
	var rotated_ports: Array[Vector2i] = []
	var rad: float = deg_to_rad(float(step) * 90.0)

	for port in base_ports:
		var r_v := Vector2(port).rotated(rad)
		rotated_ports.append(Vector2i(int(round(r_v.x)), int(round(r_v.y))))

	var entry_port: Vector2i = -incoming
	if not rotated_ports.has(entry_port):
		return []

	var exits: Array[Vector2i] = []
	for p in rotated_ports:
		if p != entry_port:
			exits.append(p)
	return exits

static func _colors_match(c1: Color, c2: Color) -> bool:
	return abs(c1.r - c2.r) < 0.2 and abs(c1.g - c2.g) < 0.2 and abs(c1.b - c2.b) < 0.2

static func _empty_result() -> Dictionary:
	return {
		"segments": [],
		"goals_hit": {},
		"exit_gates_hit": {},
		"switches_hit": {},
		"all_goals_satisfied": false,
		"total_path_length": 0,
		"reflections_count": 0,
		"beam_count": 0
	}
