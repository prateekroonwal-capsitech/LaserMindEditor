@tool
extends RefCounted
class_name SolvabilityChecker

enum Status {
	SOLVABLE,
	UNSOLVABLE,
	CHECK_INCOMPLETE
}

const MAX_SEARCH_STATES: int = 1500

static func check_stage_solvability(stage: LaserStageData, budget: int = MAX_SEARCH_STATES) -> Dictionary:
	if stage == null:
		return {
			"status": Status.UNSOLVABLE,
			"status_text": "UNSOLVABLE",
			"min_moves": -1,
			"states_explored": 0,
			"difficulty": "Unknown",
			"message": "Stage data is null."
		}

	var initial_sim := LaserSimulation.simulate_stage(stage)
	if initial_sim["all_goals_satisfied"]:
		return {
			"status": Status.SOLVABLE,
			"status_text": "SOLVABLE ✓",
			"min_moves": 0,
			"states_explored": 1,
			"difficulty": "Trivial",
			"message": "Solved in initial layout (0 moves required)."
		}

	var dynamic_indices: Array[int] = []
	for i in range(stage.objects.size()):
		var obj = stage.objects[i]
		if obj != null and (obj.movable or obj.rotatable):
			dynamic_indices.append(i)

	if dynamic_indices.is_empty():
		return {
			"status": Status.UNSOLVABLE,
			"status_text": "UNSOLVABLE ✗",
			"min_moves": -1,
			"states_explored": 1,
			"difficulty": "Impossible",
			"message": "No movable or rotatable elements to change puzzle state."
		}

	var working_stage := stage.duplicate_data()

	var queue: Array[Dictionary] = []
	var visited: Dictionary = {}

	var initial_state_data: Array[Dictionary] = []
	for idx in dynamic_indices:
		var o: LaserObjectData = working_stage.objects[idx]
		initial_state_data.append({
			"idx": idx,
			"pos": o.grid_pos,
			"rot": o.rotation_deg
		})

	var initial_key = _encode_state(initial_state_data)
	visited[initial_key] = true
	queue.append({
		"moves": 0,
		"state_data": initial_state_data
	})

	var states_explored: int = 0
	var found_solution: bool = false
	var min_moves: int = -1

	while not queue.is_empty():
		states_explored += 1
		if states_explored > budget:
			return {
				"status": Status.CHECK_INCOMPLETE,
				"status_text": "CHECK INCOMPLETE ⚠",
				"min_moves": -1,
				"states_explored": states_explored,
				"difficulty": "Complex",
				"message": "Puzzle complexity exceeded search budget (%d states explored)." % states_explored
			}

		var current = queue.pop_front()
		var cur_moves: int = current["moves"]
		var cur_data: Array[Dictionary] = current["state_data"]

		_apply_state(working_stage, cur_data)

		var sim := LaserSimulation.simulate_stage(working_stage)
		if sim["all_goals_satisfied"]:
			found_solution = true
			min_moves = cur_moves
			break

		var occupied_cells: Dictionary = {}
		for obj in working_stage.objects:
			if obj != null:
				occupied_cells[obj.grid_pos] = true

		for d_i in range(cur_data.size()):
			var item = cur_data[d_i]
			var o_idx: int = item["idx"]
			var obj: LaserObjectData = working_stage.objects[o_idx]

			if obj.rotatable:
				for rot_delta in [90, 180, 270]:
					var next_rot = (item["rot"] + rot_delta) % 360
					var next_data: Array[Dictionary] = cur_data.duplicate(true)
					next_data[d_i]["rot"] = next_rot
					var n_key = _encode_state(next_data)
					if not visited.has(n_key):
						visited[n_key] = true
						queue.append({
							"moves": cur_moves + 1,
							"state_data": next_data
						})

			if obj.movable:
				var cur_pos: Vector2i = item["pos"]
				var deltas: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
				for delta in deltas:
					var next_pos = cur_pos + delta
					if working_stage.is_inside_grid(next_pos) and not occupied_cells.has(next_pos):
						var next_data: Array[Dictionary] = cur_data.duplicate(true)
						next_data[d_i]["pos"] = next_pos
						var n_key = _encode_state(next_data)
						if not visited.has(n_key):
							visited[n_key] = true
							queue.append({
								"moves": cur_moves + 1,
								"state_data": next_data
							})

	if found_solution:
		var diff_rating = "Easy"
		if min_moves > 8: diff_rating = "Expert"
		elif min_moves > 5: diff_rating = "Hard"
		elif min_moves > 2: diff_rating = "Medium"

		return {
			"status": Status.SOLVABLE,
			"status_text": "SOLVABLE ✓",
			"min_moves": min_moves,
			"states_explored": states_explored,
			"difficulty": diff_rating,
			"message": "Minimum Solution: %d moves (Explored %d states)." % [min_moves, states_explored]
		}

	return {
		"status": Status.UNSOLVABLE,
		"status_text": "UNSOLVABLE ✗",
		"min_moves": -1,
		"states_explored": states_explored,
		"difficulty": "Unsolvable",
		"message": "No valid solution found after exhausting %d states." % states_explored
	}

static func _encode_state(state_data: Array[Dictionary]) -> String:
	var parts: PackedStringArray = []
	for item in state_data:
		var p: Vector2i = item["pos"]
		parts.append("%d:%d,%d:%d" % [item["idx"], p.x, p.y, item["rot"]])
	return ";".join(parts)

static func _apply_state(stage: LaserStageData, state_data: Array[Dictionary]) -> void:
	for item in state_data:
		var idx: int = item["idx"]
		if idx < stage.objects.size() and stage.objects[idx] != null:
			stage.objects[idx].grid_pos = item["pos"]
			stage.objects[idx].rotation_deg = item["rot"]
