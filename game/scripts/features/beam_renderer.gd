extends Node2D
class_name BeamRenderer

const BoardLayoutManager = preload("res://game/scripts/managers/board_layout_manager.gd")

@export var laser_travel_speed: float = 650.0
@export var laser_head_size: float = 8.0
@export var laser_head_glow: float = 1.0

var segments: Array = []
var grid_origin: Vector2 = Vector2.ZERO
var cell_size: Vector2 = Vector2(64, 64)

# Traversal cursor state
var traversed_distance: float = 0.0
var total_path_distance: float = 0.0
var is_traversing: bool = false
var cached_points: Array[Dictionary] = []

signal animation_completed

func _ready() -> void:
	z_index = 2
	z_as_relative = false

func reset_laser_traversal() -> void:
	traversed_distance = 0.0
	is_traversing = false
	if is_inside_tree():
		queue_redraw()

func clear_beams() -> void:
	segments.clear()
	cached_points.clear()
	total_path_distance = 0.0
	traversed_distance = 0.0
	is_traversing = false
	if is_inside_tree():
		queue_redraw()

func prepare_beams(p_segments: Array, origin: Vector2, cell_sz: Vector2) -> void:
	segments = p_segments
	grid_origin = origin
	cell_size = cell_sz
	_rebuild_cached_points()
	traversed_distance = 0.0
	is_traversing = false
	if is_inside_tree():
		queue_redraw()

func start_traversal(p_segments: Array, origin: Vector2, cell_sz: Vector2) -> void:
	segments = p_segments
	grid_origin = origin
	cell_size = cell_sz
	_rebuild_cached_points()
	traversed_distance = 0.0
	if total_path_distance > 0.0:
		is_traversing = true
	else:
		is_traversing = false
		animation_completed.emit()
	if is_inside_tree():
		queue_redraw()

func force_complete_traversal() -> void:
	traversed_distance = total_path_distance
	is_traversing = false
	animation_completed.emit()
	if is_inside_tree():
		queue_redraw()

func update_beams(p_segments: Array, origin: Vector2, cell_sz: Vector2, animate_shoot: bool = true, preserve_progress: bool = false) -> void:
	segments = p_segments
	grid_origin = origin
	cell_size = cell_sz
	if preserve_progress:
		var old_dist: float = traversed_distance
		_rebuild_cached_points()
		traversed_distance = minf(old_dist, total_path_distance)
		if traversed_distance < total_path_distance:
			is_traversing = true
		else:
			is_traversing = false
			animation_completed.emit()
		if is_inside_tree():
			queue_redraw()
	elif animate_shoot:
		start_traversal(p_segments, origin, cell_sz)
	else:
		prepare_beams(p_segments, origin, cell_sz)

func _rebuild_cached_points() -> void:
	cached_points.clear()
	total_path_distance = 0.0
	var prev_chain_dist: float = 0.0
	for seg in segments:
		var p1: Vector2
		var p2: Vector2
		if seg.has("p1") and seg.has("p2"):
			p1 = seg["p1"]
			p2 = seg["p2"]
		else:
			p1 = BoardLayoutManager.grid_to_world(seg.get("start", Vector2i.ZERO), grid_origin, cell_size)
			p2 = BoardLayoutManager.grid_to_world(seg.get("end", Vector2i.ZERO), grid_origin, cell_size)
		var d: float = p1.distance_to(p2)
		var s_dist: float
		var e_dist: float
		if seg.has("world_start_dist") and seg.has("world_end_dist"):
			s_dist = float(seg.get("world_start_dist", 0.0))
			e_dist = float(seg.get("world_end_dist", 0.0))
		elif seg.has("start_dist") and seg.has("end_dist"):
			s_dist = float(seg.get("start_dist", 0.0)) * cell_size.x
			e_dist = float(seg.get("end_dist", 0.0)) * cell_size.x
		else:
			s_dist = prev_chain_dist
			e_dist = s_dist + d
			prev_chain_dist = e_dist

		if e_dist <= s_dist:
			e_dist = s_dist + d
		total_path_distance = maxf(total_path_distance, e_dist)
		cached_points.append({
			"p1": p1,
			"p2": p2,
			"color": seg.get("color", Color.RED),
			"len": d,
			"start_dist": s_dist,
			"end_dist": e_dist,
			"hit_type": seg.get("hit_type", "")
		})

func _process(delta: float) -> void:
	if is_traversing:
		var distance_to_move: float = maxf(10.0, laser_travel_speed) * delta
		traversed_distance += distance_to_move
		if traversed_distance >= total_path_distance:
			traversed_distance = total_path_distance
			is_traversing = false
			animation_completed.emit()
		if is_inside_tree():
			queue_redraw()

func _calculate_total_length() -> float:
	_rebuild_cached_points()
	return total_path_distance

func _draw() -> void:
	if cached_points.is_empty() or total_path_distance <= 0.0:
		return

	if traversed_distance <= 0.0:
		if is_traversing and not cached_points.is_empty():
			var first_seg: Dictionary = cached_points[0]
			_draw_laser_head(first_seg["p1"], first_seg["color"], 1.0)
		return

	var active_heads: Array[Dictionary] = []

	for data in cached_points:
		var p1: Vector2 = data["p1"]
		var p2: Vector2 = data["p2"]
		var c: Color = data["color"]
		var s_dist: float = float(data["start_dist"])
		var e_dist: float = float(data["end_dist"])
		var seg_len: float = float(data["len"])
		if seg_len <= 0.0 or e_dist <= s_dist:
			continue

		if traversed_distance >= e_dist:
			# Fully traversed segment
			_draw_beam_line(p1, p2, c)
		elif traversed_distance > s_dist:
			# Partially traversed segment (active moving laser branch!)
			var t: float = clampf((traversed_distance - s_dist) / (e_dist - s_dist), 0.0, 1.0)
			var tip: Vector2 = p1.lerp(p2, t)
			_draw_beam_line(p1, tip, c)
			active_heads.append({"pos": tip, "color": c})
		else:
			# Untraversed future segments remain completely invisible!
			pass

	# Draw moving laser heads at all active branch tips simultaneously
	for h in active_heads:
		_draw_laser_head(h["pos"], h["color"], 1.0)

	# When finished traversing all segments, draw resting glow at terminal segment endpoints
	if not is_traversing and active_heads.is_empty() and not cached_points.is_empty():
		for data in cached_points:
			var h_type: String = str(data.get("hit_type", ""))
			if h_type in ["goal", "exit_gate", "blocker", "boundary", "color_wall_blocked", "gate_closed", "custom", "switch"]:
				_draw_laser_head(data["p2"], data["color"], 0.75)

func _draw_beam_line(p1: Vector2, p2: Vector2, c: Color) -> void:
	draw_line(p1, p2, Color(c.r, c.g, c.b, 0.35), cell_size.x * 0.18, true)
	draw_line(p1, p2, c, cell_size.x * 0.08, true)
	draw_line(p1, p2, Color.WHITE, cell_size.x * 0.03, true)

func _draw_laser_head(pos: Vector2, c: Color, scale_mod: float = 1.0) -> void:
	var h_sz: float = (cell_size.x * 0.14) * scale_mod * laser_head_size / 8.0
	var pulse: float = 1.0 + 0.12 * sin(float(Time.get_ticks_msec()) * 0.012)
	var eff_sz: float = h_sz * pulse

	# 1. Outer diffuse glow
	draw_circle(pos, eff_sz * 2.2 * laser_head_glow, Color(c.r, c.g, c.b, 0.32))
	# 2. Main color head
	draw_circle(pos, eff_sz * 1.3, Color(c.r, c.g, c.b, 0.85))
	# 3. Bright white core
	draw_circle(pos, eff_sz * 0.65, Color.WHITE)
	# 4. Small cross flare / spark
	var flare_len: float = eff_sz * 1.8
	draw_line(pos - Vector2(flare_len, 0), pos + Vector2(flare_len, 0), Color(1.0, 1.0, 1.0, 0.8), 1.5)
	draw_line(pos - Vector2(0, flare_len), pos + Vector2(0, flare_len), Color(1.0, 1.0, 1.0, 0.8), 1.5)

