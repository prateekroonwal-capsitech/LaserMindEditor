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

	var board_tex: Texture2D = BoardLayoutManager.get_board_texture(current_stage.board_image_path) if not current_stage.board_image_path.is_empty() else null
	var b_cols := current_stage.get_effective_slice_cols()
	var b_rows := current_stage.get_effective_slice_rows()
	var b_margins := current_stage.get_board_margins()

	if board_tex != null and current_stage.has_board_margins():
		var grid_rect := Rect2(grid_origin, Vector2(gw * cell_size.x, gh * cell_size.y))
		BoardLayoutManager.draw_board_ninepatch_frame(
			self,
			board_tex,
			grid_rect,
			b_margins,
			gw,
			gh,
			current_stage.hidden_frame_pieces
		)

	for x in range(gw):
		for y in range(gh):
			var cell_rect := Rect2(grid_origin + Vector2(x * cell_size.x, y * cell_size.y), cell_size)
			var is_even := (x + y) % 2 == 0
			var tint_col := Color(1.0, 1.0, 1.0, 0.04) if is_even else Color(0.0, 0.0, 0.0, 0.04)
			draw_rect(cell_rect, tint_col, true)

			if board_tex != null and current_stage.has_board_tile(Vector2i(x, y)):
				var tc := current_stage.get_board_tile(Vector2i(x, y))
				if tc.x >= 0 and tc.y >= 0:
					var s_rect := BoardLayoutManager.get_tile_src_rect(board_tex, tc.x, tc.y, b_cols, b_rows, b_margins)
					draw_texture_rect_region(board_tex, cell_rect, s_rect)

			if current_stage.show_tile_borders:
				draw_rect(cell_rect, Color(0.35, 0.6, 0.85, 0.22), false, 1.0)

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
