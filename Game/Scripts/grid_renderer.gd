extends Node2D
class_name GridRenderer

const BoardVisualGenerator = preload("res://Game/Scripts/board_visual_generator.gd")

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

	BoardVisualGenerator.draw_board(
		self,
		current_stage,
		grid_origin,
		cell_size,
		1.0,
		current_stage.show_tile_borders,
		Color(0.35, 0.6, 0.85, 0.22)
	)
