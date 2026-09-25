extends RefCounted
class_name StageTransitionController

# =========================================================================
# CENTRALIZED STAGE TRANSITION & TIMING CONFIGURATION
# =========================================================================
# 1. How far before the Exit Gate (in world pixels) should camera/world movement begin?
#    - 0.0: Transition begins exactly when laser strikes Exit Gate.
#    - 300.0: Transition begins 300px before Exit Gate (early cinematic lead-in).
@export var transition_start_distance: float = 300.0

# 2. Laser traversal speed in world pixels per second.
#    Determines traversal duration across stages and inter-stage transition gaps:
#    transition_duration = transition_distance / laser_travel_speed
@export var laser_travel_speed: float = 650.0

# 3. Optional camera lead offset (in world pixels) ahead of the laser head
@export var transition_camera_lead: float = 0.0

# Active transition intervals across the continuous world
# Each element: {
#   "from_stage": int,
#   "to_stage": int,
#   "exit_dist": float,
#   "entry_dist": float,
#   "from_cam_pos": Vector2,
#   "to_cam_pos": Vector2,
#   "exit_world_pos": Vector2,
#   "entry_world_pos": Vector2,
#   "color": Color
# }
var transition_intervals: Array[Dictionary] = []

func clear() -> void:
	transition_intervals.clear()

func set_transition_intervals(intervals: Array[Dictionary]) -> void:
	transition_intervals = intervals

func add_transition_interval(
	from_st: int,
	to_st: int,
	exit_d: float,
	entry_d: float,
	from_cam: Vector2,
	to_cam: Vector2,
	exit_pos: Vector2,
	entry_pos: Vector2,
	laser_col: Color
) -> void:
	transition_intervals.append({
		"from_stage": from_st,
		"to_stage": to_st,
		"exit_dist": exit_d,
		"entry_dist": entry_d,
		"from_cam_pos": from_cam,
		"to_cam_pos": to_cam,
		"exit_world_pos": exit_pos,
		"entry_world_pos": entry_pos,
		"color": laser_col
	})

## Computes the synchronized camera position and transition state from laser traversed distance
func compute_state(traversed_dist: float, default_cam_pos: Vector2) -> Dictionary:
	var target_cam: Vector2 = default_cam_pos
	var active_st: int = 1
	var is_trans: bool = false
	var progress: float = 0.0
	var cur_trans: Dictionary = {}

	for trans in transition_intervals:
		var exit_d: float = trans["exit_dist"]
		var entry_d: float = trans["entry_dist"]
		var from_cam: Vector2 = trans["from_cam_pos"]
		var to_cam: Vector2 = trans["to_cam_pos"]
		var to_st: int = trans["to_stage"]
		var from_st: int = trans["from_stage"]

		# The transition window starts `transition_start_distance` pixels before Exit Gate
		var start_d: float = maxf(0.0, exit_d - transition_start_distance)
		var end_d: float = entry_d

		if traversed_dist < start_d:
			# Laser is before the transition window
			target_cam = from_cam
			active_st = from_st
			break
		elif traversed_dist >= start_d and traversed_dist < end_d:
			# Laser is in transition window!
			var span: float = maxf(1.0, end_d - start_d)
			var t: float = clampf((traversed_dist - start_d) / span, 0.0, 1.0)
			# Smooth cubic S-curve
			var s: float = t * t * (3.0 - 2.0 * t)
			target_cam = from_cam.lerp(to_cam, s)
			active_st = from_st if t < 0.5 else to_st
			is_trans = true
			progress = t
			cur_trans = trans
			break
		else:
			# Laser has reached or passed to_st
			target_cam = to_cam
			active_st = to_st

	return {
		"camera_pos": target_cam,
		"active_stage_idx": active_st,
		"is_transitioning": is_trans,
		"transition_progress": progress,
		"current_transition": cur_trans
	}

## Returns the physical duration (in seconds) for a given transition based on laser_travel_speed
func calculate_transition_duration(trans: Dictionary) -> float:
	var start_d: float = maxf(0.0, float(trans.get("exit_dist", 0.0)) - transition_start_distance)
	var end_d: float = float(trans.get("entry_dist", 0.0))
	var distance: float = maxf(0.0, end_d - start_d)
	return distance / maxf(10.0, laser_travel_speed)
