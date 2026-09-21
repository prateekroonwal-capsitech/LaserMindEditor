@tool
extends RefCounted
class_name DifficultyAnalyzer

static func analyze_stage(stage: LaserStageData) -> Dictionary:
	if stage == null:
		return _empty_analysis()

	var metrics: Dictionary = {
		"grid_w": stage.grid_width,
		"grid_h": stage.grid_height,
		"grid_area": stage.grid_width * stage.grid_height,
		"object_count": 0,
		"mirror_count": 0,
		"movable_mirror_count": 0,
		"rotatable_mirror_count": 0,
		"goal_count": 0,
		"blocker_count": 0,
		"splitter_count": 0,
		"color_mechanics_count": 0,
		"logic_mechanics_count": 0,
		"path_length": 0,
		"reflections": 0,
		"solution_moves": 0,
		"difficulty_score": 0,
		"rating": "EASY"
	}

	for obj in stage.objects:
		if obj == null:
			continue
		metrics["object_count"] += 1
		match obj.type:
			LaserObjectData.ObjectType.FIXED_MIRROR:
				metrics["mirror_count"] += 1
			LaserObjectData.ObjectType.MOVABLE_MIRROR:
				metrics["mirror_count"] += 1
				metrics["movable_mirror_count"] += 1
			LaserObjectData.ObjectType.ROTATABLE_MIRROR:
				metrics["mirror_count"] += 1
				metrics["rotatable_mirror_count"] += 1
			LaserObjectData.ObjectType.GOAL:
				metrics["goal_count"] += 1
			LaserObjectData.ObjectType.ROCK, LaserObjectData.ObjectType.ICE:
				metrics["blocker_count"] += 1
			LaserObjectData.ObjectType.SPLITTER:
				metrics["splitter_count"] += 1
			LaserObjectData.ObjectType.COLOR_GLASS, LaserObjectData.ObjectType.COLOR_WALL:
				metrics["color_mechanics_count"] += 1
			LaserObjectData.ObjectType.GATE, LaserObjectData.ObjectType.SWITCH, LaserObjectData.ObjectType.GATE_SWITCH, LaserObjectData.ObjectType.CUSTOM, LaserObjectData.ObjectType.EXIT_GATE:
				metrics["logic_mechanics_count"] += 1

	var sim := LaserSimulation.simulate_stage(stage)
	metrics["path_length"] = sim["total_path_length"]
	metrics["reflections"] = sim["reflections_count"]

	var solv := SolvabilityChecker.check_stage_solvability(stage, 250)
	if solv["status"] == SolvabilityChecker.Status.SOLVABLE and solv["min_moves"] >= 0:
		metrics["solution_moves"] = solv["min_moves"]

	var score: float = 0.0
	score += float(metrics["grid_area"]) * 0.1
	score += float(metrics["object_count"]) * 1.5
	score += float(metrics["movable_mirror_count"]) * 4.0
	score += float(metrics["rotatable_mirror_count"]) * 3.0
	score += float(metrics["goal_count"] - 1) * 3.0
	score += float(metrics["splitter_count"]) * 4.0
	score += float(metrics["color_mechanics_count"]) * 3.5
	score += float(metrics["logic_mechanics_count"]) * 4.0
	score += float(metrics["solution_moves"]) * 5.0
	score += float(metrics["reflections"]) * 1.2

	metrics["difficulty_score"] = int(score)

	if score >= 60.0:
		metrics["rating"] = "EXPERT"
	elif score >= 40.0:
		metrics["rating"] = "HARD"
	elif score >= 22.0:
		metrics["rating"] = "MEDIUM"
	else:
		metrics["rating"] = "EASY"

	return metrics

static func analyze_level(level: LaserLevelData) -> Dictionary:
	if level == null:
		return {"level_rating": "UNKNOWN", "stages": []}

	var stage_results: Array[Dictionary] = []
	var total_score: int = 0

	for s in level.stages:
		var res := analyze_stage(s)
		stage_results.append(res)
		total_score += res["difficulty_score"]

	var avg_score = float(total_score) / max(1, stage_results.size())
	var rating = "EASY"
	if avg_score >= 55.0:
		rating = "EXPERT"
	elif avg_score >= 38.0:
		rating = "HARD"
	elif avg_score >= 20.0:
		rating = "MEDIUM"

	if not level.manual_difficulty_override.is_empty():
		rating = level.manual_difficulty_override.to_upper()

	return {
		"level_rating": rating,
		"average_score": int(avg_score),
		"stage_results": stage_results
	}

static func _empty_analysis() -> Dictionary:
	return {
		"grid_w": 0, "grid_h": 0, "grid_area": 0,
		"object_count": 0, "mirror_count": 0,
		"movable_mirror_count": 0, "rotatable_mirror_count": 0,
		"goal_count": 0, "blocker_count": 0,
		"splitter_count": 0, "color_mechanics_count": 0,
		"logic_mechanics_count": 0, "path_length": 0,
		"reflections": 0, "solution_moves": 0,
		"difficulty_score": 0, "rating": "EASY"
	}
