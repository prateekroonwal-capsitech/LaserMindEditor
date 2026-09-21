extends Node2D
class_name BeamRenderer

const BoardLayoutManager = preload("res://Game/Scripts/board_layout_manager.gd")

var segments: Array = []
var grid_origin: Vector2 = Vector2.ZERO
var cell_size: Vector2 = Vector2(64, 64)

var anim_progress: float = 1.0
var current_tween: Tween = null
var duration: float = 0.85

func _exit_tree() -> void:
	if current_tween != null and current_tween.is_valid():
		current_tween.kill()

func update_beams(p_segments: Array, origin: Vector2, cell_sz: Vector2, animate_shoot: bool = false) -> void:
	segments = p_segments
	grid_origin = origin
	cell_size = cell_sz

	if animate_shoot and not segments.is_empty() and is_inside_tree():
		anim_progress = 0.0
		if current_tween != null and current_tween.is_valid():
			current_tween.kill()
		current_tween = create_tween()
		current_tween.tween_property(self, "anim_progress", 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		anim_progress = 1.0

	queue_redraw()

func _process(_delta: float) -> void:
	if anim_progress < 1.0:
		queue_redraw()

func _draw() -> void:
	if segments.is_empty():
		return

	var pts: Array[Dictionary] = []
	var total_len: float = 0.0
	for seg in segments:
		var p1 := BoardLayoutManager.grid_to_world(seg.get("start", Vector2i.ZERO), grid_origin, cell_size)
		var p2 := BoardLayoutManager.grid_to_world(seg.get("end", Vector2i.ZERO), grid_origin, cell_size)
		var d: float = p1.distance_to(p2)
		total_len += d
		pts.append({"p1": p1, "p2": p2, "color": seg.get("color", Color.RED), "len": d})

	if total_len <= 0.0:
		return

	var target_dist: float = total_len * anim_progress
	var cur_dist: float = 0.0

	for data in pts:
		var p1: Vector2 = data["p1"]
		var p2: Vector2 = data["p2"]
		var c: Color = data["color"]
		var seg_len: float = float(data["len"])
		if seg_len <= 0.0:
			continue

		if cur_dist + seg_len <= target_dist:
			_draw_beam_line(p1, p2, c)
			cur_dist += seg_len
		elif cur_dist < target_dist:
			var t: float = clampf((target_dist - cur_dist) / seg_len, 0.0, 1.0)
			var tip: Vector2 = p1.lerp(p2, t)
			_draw_beam_line(p1, tip, c)
			draw_circle(tip, cell_size.x * 0.10, Color.WHITE)
			break
		else:
			break

func _draw_beam_line(p1: Vector2, p2: Vector2, c: Color) -> void:
	draw_line(p1, p2, Color(c.r, c.g, c.b, 0.35), cell_size.x * 0.18, true)
	draw_line(p1, p2, c, cell_size.x * 0.08, true)
	draw_line(p1, p2, Color.WHITE, cell_size.x * 0.03, true)
