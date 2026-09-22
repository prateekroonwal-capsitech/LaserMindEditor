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

	for obj in current_stage.objects:
		if obj != null and obj.enabled and obj.type == LaserObjectData.ObjectType.MOVABLE_AREA:
			var cell_rect := Rect2(grid_origin + Vector2(obj.grid_pos.x * cell_size.x, obj.grid_pos.y * cell_size.y), cell_size)
			var col: Color = obj.color if (obj.color != Color(1.0, 0.2, 0.2, 1.0) and obj.color.a > 0.05) else Color(0.18, 0.62, 0.98, 1.0)
			draw_rect(cell_rect.grow(-2), Color(col.r, col.g, col.b, 0.35), true)
			draw_rect(cell_rect.grow(-2), Color(col.r, col.g, col.b, 0.85), false, 2.0)
			var center = cell_rect.get_center()
			var m_rad = cell_size.x * 0.16
			draw_arc(center, m_rad, 0, TAU, 12, col, 1.5)
			draw_line(center - Vector2(m_rad * 0.8, 0), center + Vector2(m_rad * 0.8, 0), col, 1.2)
			draw_line(center - Vector2(0, m_rad * 0.8), center + Vector2(0, m_rad * 0.8), col, 1.2)
