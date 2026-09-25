@tool
extends RefCounted
class_name BoardLayoutHelper

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

static var _texture_cache: Dictionary = {}

static func get_board_texture(path: String) -> Texture2D:
	if path.strip_edges().is_empty():
		return null
	var clean_path := path.strip_edges()
	if _texture_cache.has(clean_path) and is_instance_valid(_texture_cache[clean_path]):
		return _texture_cache[clean_path]
	var tex: Texture2D = null
	if clean_path.begins_with("res://"):
		if ResourceLoader.exists(clean_path):
			tex = ResourceLoader.load(clean_path, "", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
	elif FileAccess.file_exists(clean_path):
		var img := Image.new()
		var err := img.load(clean_path)
		if err == OK:
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_texture_cache[clean_path] = tex
	return tex

static func get_tile_src_rect(tex: Texture2D, tx: int, ty: int, cols: int, rows: int, margins: Vector4i = Vector4i.ZERO) -> Rect2:
	if tex == null or cols <= 0 or rows <= 0:
		return Rect2()
	var sz := tex.get_size()
	var inner_x := float(margins.x)
	var inner_y := float(margins.y)
	var inner_w := maxf(1.0, sz.x - float(margins.x + margins.z))
	var inner_h := maxf(1.0, sz.y - float(margins.y + margins.w))

	var x1 := inner_x + (float(tx) * inner_w / float(cols))
	var x2 := inner_x + (float(tx + 1) * inner_w / float(cols))
	var y1 := inner_y + (float(ty) * inner_h / float(rows))
	var y2 := inner_y + (float(ty + 1) * inner_h / float(rows))
	return Rect2(float(round(x1)), float(round(y1)), float(max(1, round(x2 - x1))), float(max(1, round(y2 - y1))))

static func auto_detect_board_margins(tex: Texture2D) -> Vector4i:
	if tex == null:
		return Vector4i.ZERO
	var img := tex.get_image()
	if img == null:
		return Vector4i.ZERO
	if img.is_compressed():
		img = img.duplicate()
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	if w < 20 or h < 20:
		return Vector4i.ZERO

	var mid_y := h / 2
	var mid_x := w / 2

	var left := 0
	for x in range(w / 3):
		var c := img.get_pixel(x, mid_y)
		if c.g > c.r + 0.08 and c.g > c.b + 0.08:
			left = x
			break

	var right := 0
	for x in range(w - 1, w - 1 - (w / 3), -1):
		var c := img.get_pixel(x, mid_y)
		if c.g > c.r + 0.08 and c.g > c.b + 0.08:
			right = (w - 1) - x
			break

	var top := 0
	for y in range(h / 3):
		var c := img.get_pixel(mid_x, y)
		if c.g > c.r + 0.08 and c.g > c.b + 0.08:
			top = y
			break

	var bottom := 0
	for y in range(h - 1, h - 1 - (h / 3), -1):
		var c := img.get_pixel(mid_x, y)
		if c.g > c.r + 0.08 and c.g > c.b + 0.08:
			bottom = (h - 1) - y
			break

	return Vector4i(left, top, right, bottom)

static func get_frame_piece_rects(grid_rect: Rect2, margins: Vector4i, tex_size: Vector2, grid_w: int, grid_h: int) -> Dictionary:
	var rects: Dictionary = {}
	if margins == Vector4i.ZERO or tex_size.x <= 0 or tex_size.y <= 0:
		return rects

	var L := float(margins.x)
	var T := float(margins.y)
	var R := float(margins.z)
	var B := float(margins.w)
	var inner_w := maxf(1.0, tex_size.x - L - R)
	var inner_h := maxf(1.0, tex_size.y - T - B)

	var scale_x := grid_rect.size.x / inner_w
	var scale_y := grid_rect.size.y / inner_h

	var f_left := L * scale_x
	var f_top := T * scale_y
	var f_right := R * scale_x
	var f_bottom := B * scale_y

	var gw: int = maxi(1, grid_w)
	var gh: int = maxi(1, grid_h)
	var cell_w := grid_rect.size.x / float(gw)
	var cell_h := grid_rect.size.y / float(gh)

	rects["C_TL"] = Rect2(grid_rect.position.x - f_left, grid_rect.position.y - f_top, f_left, f_top)
	rects["C_TR"] = Rect2(grid_rect.position.x + grid_rect.size.x, grid_rect.position.y - f_top, f_right, f_top)
	rects["C_BL"] = Rect2(grid_rect.position.x - f_left, grid_rect.position.y + grid_rect.size.y, f_left, f_bottom)
	rects["C_BR"] = Rect2(grid_rect.position.x + grid_rect.size.x, grid_rect.position.y + grid_rect.size.y, f_right, f_bottom)

	for x in range(gw):
		rects["T_%d" % x] = Rect2(grid_rect.position.x + float(x) * cell_w, grid_rect.position.y - f_top, cell_w, f_top)
		rects["B_%d" % x] = Rect2(grid_rect.position.x + float(x) * cell_w, grid_rect.position.y + grid_rect.size.y, cell_w, f_bottom)

	for y in range(gh):
		rects["L_%d" % y] = Rect2(grid_rect.position.x - f_left, grid_rect.position.y + float(y) * cell_h, f_left, cell_h)
		rects["R_%d" % y] = Rect2(grid_rect.position.x + grid_rect.size.x, grid_rect.position.y + float(y) * cell_h, f_right, cell_h)

	return rects

static func get_frame_piece_at_point(
	point: Vector2,
	grid_rect: Rect2,
	margins: Vector4i,
	tex_size: Vector2,
	grid_w: int,
	grid_h: int
) -> String:
	var rects := get_frame_piece_rects(grid_rect, margins, tex_size, grid_w, grid_h)
	for key in rects.keys():
		var r: Rect2 = rects[key]
		if r.has_point(point):
			return str(key)
	return ""
