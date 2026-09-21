extends Node2D
class_name GridRenderer

var current_stage: LaserStageData = null
var grid_origin: Vector2 = Vector2.ZERO
var cell_size: Vector2 = Vector2(64, 64)

func update_grid(stage: LaserStageData, origin: Vector2, cell_sz: Vector2) -> void:
	current_stage = stage
	grid_origin = origin
	cell_size = cell_sz
	queue_redraw()

func _draw() -> void:
	if current_stage == null:
		return

	var gw := current_stage.grid_width
	var gh := current_stage.grid_height

	for x in range(gw):
		for y in range(gh):
			var cell_rect := Rect2(grid_origin + Vector2(x * cell_size.x, y * cell_size.y), cell_size)
			var is_even := (x + y) % 2 == 0
			var tint_col := Color(1.0, 1.0, 1.0, 0.04) if is_even else Color(0.0, 0.0, 0.0, 0.04)
			draw_rect(cell_rect, tint_col, true)
			draw_rect(cell_rect, Color(0.35, 0.6, 0.85, 0.22), false, 1.0)
