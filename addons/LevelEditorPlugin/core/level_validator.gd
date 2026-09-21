@tool
extends RefCounted
class_name LevelValidator

enum Severity {
	ERROR,
	WARNING,
	INFO
}

static func validate_level(level: LaserLevelData) -> Dictionary:
	var items: Array[Dictionary] = []
	var error_count: int = 0
	var warning_count: int = 0

	if level == null:
		items.append({
			"severity": Severity.ERROR,
			"stage": 0,
			"cell": Vector2i(-1, -1),
			"obj_id": "",
			"message": "Level data is null."
		})
		return _build_result(items)

	if level.stages.is_empty():
		items.append({
			"severity": Severity.ERROR,
			"stage": 0,
			"cell": Vector2i(-1, -1),
			"obj_id": "",
			"message": "Level must have at least 1 stage."
		})
		error_count += 1

	if level.universal_timer <= 0.0:
		items.append({
			"severity": Severity.ERROR,
			"stage": 0,
			"cell": Vector2i(-1, -1),
			"obj_id": "",
			"message": "Universal timer must be greater than 0s."
		})
		error_count += 1

	if level.star_threshold_3 <= 0.0 or level.star_threshold_2 <= level.star_threshold_3 or level.star_threshold_1 <= level.star_threshold_2:
		items.append({
			"severity": Severity.ERROR,
			"stage": 0,
			"cell": Vector2i(-1, -1),
			"obj_id": "",
			"message": "Star thresholds invalid: Must satisfy 3-Star < 2-Star < 1-Star (current: %.1f < %.1f < %.1f)." % [
				level.star_threshold_3, level.star_threshold_2, level.star_threshold_1
			]
		})
		error_count += 1

	if level.star_threshold_1 > level.universal_timer:
		items.append({
			"severity": Severity.WARNING,
			"stage": 0,
			"cell": Vector2i(-1, -1),
			"obj_id": "",
			"message": "1-Star threshold (%.1fs) exceeds universal timer (%.1fs)." % [level.star_threshold_1, level.universal_timer]
		})
		warning_count += 1

	var stage_complexities: Array[int] = []

	for s_idx in range(level.stages.size()):
		var st: LaserStageData = level.stages[s_idx]
		var stage_num: int = s_idx + 1

		if st == null:
			items.append({
				"severity": Severity.ERROR,
				"stage": stage_num,
				"cell": Vector2i(-1, -1),
				"obj_id": "",
				"message": "Stage %d is null." % stage_num
			})
			error_count += 1
			continue

		if st.grid_width < 3 or st.grid_height < 3:
			items.append({
				"severity": Severity.ERROR,
				"stage": stage_num,
				"cell": Vector2i(-1, -1),
				"obj_id": "",
				"message": "Stage %d grid too small (%dx%d, min is 3x3)." % [stage_num, st.grid_width, st.grid_height]
			})
			error_count += 1

		if st.time_limit <= 0.0:
			items.append({
				"severity": Severity.WARNING,
				"stage": stage_num,
				"cell": Vector2i(-1, -1),
				"obj_id": "",
				"message": "Stage %d time limit should be > 0s." % stage_num
			})
			warning_count += 1

		if st.entry_point != Vector2i(-1, -1) and not st.is_inside_grid(st.entry_point):
			items.append({
				"severity": Severity.ERROR,
				"stage": stage_num,
				"cell": st.entry_point,
				"obj_id": "",
				"message": "Stage %d entry point %s is out of grid bounds." % [stage_num, st.entry_point]
			})
			error_count += 1

		if st.exit_point != Vector2i(-1, -1) and not st.is_inside_grid(st.exit_point):
			items.append({
				"severity": Severity.ERROR,
				"stage": stage_num,
				"cell": st.exit_point,
				"obj_id": "",
				"message": "Stage %d exit point %s is out of grid bounds." % [stage_num, st.exit_point]
			})
			error_count += 1

		var occupied: Dictionary = {}
		var laser_count: int = 0
		var goal_count: int = 0
		var goals: Array[LaserObjectData] = []
		var switches: Array[LaserObjectData] = []
		var gates: Array[LaserObjectData] = []

		for obj in st.objects:
			if obj == null:
				continue

			if not st.is_inside_grid(obj.grid_pos):
				items.append({
					"severity": Severity.ERROR,
					"stage": stage_num,
					"cell": obj.grid_pos,
					"obj_id": obj.id,
					"message": "Stage %d: %s at %s is out of grid bounds." % [stage_num, LaserObjectData.TYPE_NAMES.get(obj.type, "Object"), obj.grid_pos]
				})
				error_count += 1

			if obj.type != LaserObjectData.ObjectType.MOVABLE_AREA:
				if occupied.has(obj.grid_pos):
					var other: LaserObjectData = occupied[obj.grid_pos]
					items.append({
						"severity": Severity.ERROR,
						"stage": stage_num,
						"cell": obj.grid_pos,
						"obj_id": obj.id,
						"message": "Stage %d: Object overlap at %s between %s and %s." % [
							stage_num, obj.grid_pos, LaserObjectData.TYPE_NAMES.get(obj.type, "Object"), LaserObjectData.TYPE_NAMES.get(other.type, "Object")
						]
					})
					error_count += 1
				else:
					occupied[obj.grid_pos] = obj

			match obj.type:
				LaserObjectData.ObjectType.LASER_SOURCE:
					laser_count += 1
				LaserObjectData.ObjectType.GOAL, LaserObjectData.ObjectType.EXIT_GATE:
					goal_count += 1
					goals.append(obj)
				LaserObjectData.ObjectType.SWITCH, LaserObjectData.ObjectType.GATE_SWITCH:
					switches.append(obj)
				LaserObjectData.ObjectType.GATE:
					gates.append(obj)

		var has_laser_entry: bool = (laser_count > 0 or (stage_num > 1 and not gates.is_empty()) or (st.entry_point != Vector2i(-1, -1) and st.is_inside_grid(st.entry_point)))
		if not has_laser_entry:
			items.append({
				"severity": Severity.WARNING,
				"stage": stage_num,
				"cell": Vector2i(-1, -1),
				"obj_id": "",
				"message": "Stage %d has no Laser object placed." % stage_num
			})

		for sw in switches:
			if not sw.target_id.is_empty():
				var target_found: bool = false
				for g in gates:
					if g.id == sw.target_id:
						target_found = true
						break
				if not target_found:
					items.append({
						"severity": Severity.WARNING,
						"stage": stage_num,
						"cell": sw.grid_pos,
						"obj_id": sw.id,
						"message": "Stage %d: Switch target '%s' does not match any gate." % [stage_num, sw.target_id]
					})
					warning_count += 1

		var sim_res := LaserSimulation.simulate_stage(st)
		for g in goals:
			if not sim_res["goals_hit"].get(g.grid_pos, false):
				items.append({
					"severity": Severity.INFO,
					"stage": stage_num,
					"cell": g.grid_pos,
					"obj_id": g.id,
					"message": "Stage %d: Goal at %s is not energized in initial layout." % [stage_num, g.grid_pos]
				})

		var complexity = st.objects.size() * 2 + st.grid_width + st.grid_height
		stage_complexities.append(complexity)

	if stage_complexities.size() >= 3:
		if stage_complexities[2] < stage_complexities[0] - 4:
			items.append({
				"severity": Severity.WARNING,
				"stage": 3,
				"cell": Vector2i(-1, -1),
				"obj_id": "",
				"message": "Progression warning: Stage 3 complexity (%d) is significantly lower than Stage 1 (%d)." % [
					stage_complexities[2], stage_complexities[0]
				]
			})
			warning_count += 1

	return _build_result(items)

static func _build_result(items: Array[Dictionary]) -> Dictionary:
	var error_count: int = 0
	var warning_count: int = 0
	var info_count: int = 0

	for item in items:
		match item["severity"]:
			Severity.ERROR: error_count += 1
			Severity.WARNING: warning_count += 1
			Severity.INFO: info_count += 1

	var is_valid = (error_count == 0)
	var status_text = "VALID" if is_valid else "INVALID (%d errors)" % error_count

	return {
		"is_valid": is_valid,
		"status_text": status_text,
		"error_count": error_count,
		"warning_count": warning_count,
		"info_count": info_count,
		"items": items
	}
