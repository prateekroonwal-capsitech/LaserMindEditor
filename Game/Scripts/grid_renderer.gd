extends Node2D
class_name GridRenderer

const BoardVisualGenerator = preload("res://Game/Scripts/board_visual_generator.gd")

var current_stage: LaserStageData = null
var grid_origin: Vector2 = Vector2.ZERO
var cell_size: Vector2 = Vector2(64, 64)
var stages_data: Array = []

func update_grid(stage: LaserStageData, origin: Vector2, cell_sz: Vector2) -> void:
	current_stage = stage
	grid_origin = origin
	cell_size = cell_sz
	stages_data = [{
		"stage": stage,
		"origin": origin,
		"cell_size": cell_sz
	}]
	queue_redraw()

func update_all_stages(stages_list: Array) -> void:
	stages_data = stages_list
	if not stages_list.is_empty():
		current_stage = stages_list[0].get("stage", null)
		grid_origin = stages_list[0].get("origin", Vector2.ZERO)
		cell_size = stages_list[0].get("cell_size", Vector2(64, 64))
	queue_redraw()

func _draw() -> void:
	if stages_data.is_empty() and current_stage != null:
		stages_data = [{
			"stage": current_stage,
			"origin": grid_origin,
			"cell_size": cell_size
		}]

	for item in stages_data:
		var st: LaserStageData = item.get("stage", null)
		var origin: Vector2 = item.get("origin", Vector2.ZERO)
		var cell_sz: Vector2 = item.get("cell_size", Vector2(64, 64))
		if st != null:
			BoardVisualGenerator.draw_board(
				self,
				st,
				origin,
				cell_sz,
				1.0,
				st.show_tile_borders,
				Color(0.35, 0.6, 0.85, 0.22)
			)

