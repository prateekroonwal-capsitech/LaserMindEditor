extends RefCounted
class_name BoardLayoutManager

static func stage_has_custom_position(stage: LaserStageData) -> bool:
	if stage == null:
		return false
	return stage.stage_screen_position.x > -9000.0 and stage.stage_screen_position.y > -9000.0

static func compute_auto_center(
	stage: LaserStageData,
	vp_size: Vector2,
	is_playtest_mode: bool
) -> Dictionary:
	var top_offset: float = 120.0 if is_playtest_mode else 80.0
	var bottom_offset: float = 90.0
	var side_padding: float = 32.0
	var frame_pad: float = 52.0

	var avail_w: float = maxf(100.0, vp_size.x - ((side_padding + frame_pad) * 2.0))
	var avail_h: float = maxf(100.0, vp_size.y - top_offset - bottom_offset - (frame_pad * 2.0))

	var cell_dim: float = minf(avail_w / float(stage.grid_width), avail_h / float(stage.grid_height))
	cell_dim = maxf(cell_dim, 24.0)
	var cell_sz := Vector2(cell_dim, cell_dim)

	var total_w: float = float(stage.grid_width) * cell_sz.x
	var total_h: float = float(stage.grid_height) * cell_sz.y

	var origin_x: float = (vp_size.x - total_w) * 0.5
	var origin_y: float = top_offset + frame_pad + (avail_h - total_h) * 0.5

	return {
		"grid_origin": Vector2(origin_x, origin_y),
		"cell_size": cell_sz,
		"board_pos": Vector2(origin_x, origin_y) - Vector2(frame_pad, frame_pad),
		"board_size": Vector2(total_w + (frame_pad * 2.0), total_h + (frame_pad * 2.0))
	}

static func compute_board_rect(grid_origin: Vector2, cell_size: Vector2, grid_width: int, grid_height: int) -> Rect2:
	var frame_pad: float = 52.0
	var total_w: float = float(grid_width) * cell_size.x
	var total_h: float = float(grid_height) * cell_size.y
	return Rect2(
		grid_origin - Vector2(frame_pad, frame_pad),
		Vector2(total_w + (frame_pad * 2.0), total_h + (frame_pad * 2.0))
	)

static func grid_to_world(grid_pos: Vector2i, grid_origin: Vector2, cell_size: Vector2) -> Vector2:
	return grid_origin + Vector2(
		(float(grid_pos.x) + 0.5) * cell_size.x,
		(float(grid_pos.y) + 0.5) * cell_size.y
	)

static func world_to_grid(world_pos: Vector2, grid_origin: Vector2, cell_size: Vector2) -> Vector2i:
	var local = world_pos - grid_origin
	return Vector2i(
		int(floor(local.x / cell_size.x)),
		int(floor(local.y / cell_size.y))
	)

static func scale_background_to_viewport(bg: Sprite2D, vp_size: Vector2) -> void:
	if bg != null and bg.texture != null:
		var tex_sz: Vector2 = bg.texture.get_size()
		if tex_sz.x > 0 and tex_sz.y > 0:
			bg.scale = Vector2(vp_size.x / tex_sz.x, vp_size.y / tex_sz.y)
