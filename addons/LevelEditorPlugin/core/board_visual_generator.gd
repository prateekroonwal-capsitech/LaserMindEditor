@tool
extends RefCounted
class_name BoardVisualGenerator

enum TileType {
	MIDDLE = 0,
	EDGE = 1,
	CORNER = 2
}

# Minimal Default Demo Assets (bundled inside portable plugin)
const DEFAULT_CELL_DEMO_PATH: String = "res://addons/LevelEditorPlugin/assets/default/cells/demo_cell_01.svg"
const DEFAULT_BORDER_DEMO_PATH: String = "res://addons/LevelEditorPlugin/assets/default/borders/demo_border_01.svg"
const DEFAULT_CORNER_DEMO_PATH: String = "res://addons/LevelEditorPlugin/assets/default/corners/demo_corner_01.svg"

# Optional fallback paths for backwards compatibility
const DEFAULT_CELL_A_PATH: String = "res://addons/LevelEditorPlugin/assets/default/cells/demo_cell_01.svg"
const DEFAULT_BORDER_H_PATH: String = "res://addons/LevelEditorPlugin/assets/default/borders/demo_border_01.svg"
const DEFAULT_BORDER_V_PATH: String = "res://addons/LevelEditorPlugin/assets/default/borders/demo_border_01.svg"
const DEFAULT_BORDER_CORNER_PATH: String = "res://addons/LevelEditorPlugin/assets/default/corners/demo_corner_01.svg"

static var _texture_cache: Dictionary = {}

static func clear_texture_cache() -> void:
	_texture_cache.clear()

static func resolve_asset_in_library(stage: LaserStageData, lib_name: String, asset_ref: String) -> String:
	var trimmed := asset_ref.strip_edges()
	if stage != null:
		stage.ensure_default_visual_libraries()
		var lib: Array[Dictionary] = []
		match lib_name:
			"cell": lib = stage.cell_assets
			"border": lib = stage.border_assets
			"corner": lib = stage.corner_assets

		# 1. Search library for exact ID, display name, full path, or file name
		for item in lib:
			var i_id: String = str(item.get("id", "")).strip_edges()
			var i_name: String = str(item.get("name", "")).strip_edges()
			var i_path: String = str(item.get("path", "")).strip_edges()
			if not trimmed.is_empty():
				if i_id == trimmed or i_name == trimmed or i_path == trimmed or i_path.get_file() == trimmed:
					return i_path

		# 2. Authoritative Fallback for Cell Images:
		# If the stage has configured cell_assets, any legacy/empty/unmatched reference
		# MUST map to the primary configured cell asset! This ensures that selecting Logo.png
		# immediately and authoritatively renders Logo.png across all cells using that visual.
		if lib_name == "cell" and not lib.is_empty():
			return str(lib[0].get("path", ""))

		# 3. For border or corner, if trimmed matches border_1 / corner_1 default, return first
		if lib_name == "border" and not lib.is_empty() and (trimmed == "border_1" or trimmed.is_empty()):
			return str(lib[0].get("path", ""))
		if lib_name == "corner" and not lib.is_empty() and (trimmed == "corner_1" or trimmed.is_empty()):
			return str(lib[0].get("path", ""))

	# 4. Check direct file path on disk or in project
	if not trimmed.is_empty():
		if trimmed.begins_with("res://") or FileAccess.file_exists(trimmed):
			return trimmed

	# 5. Minimal demo fallback
	match lib_name:
		"cell":
			return _get_configured_or_default("cell_demo", DEFAULT_CELL_DEMO_PATH)
		"border":
			return _get_configured_or_default("border_demo", DEFAULT_BORDER_DEMO_PATH)
		"corner":
			return _get_configured_or_default("corner_demo", DEFAULT_CORNER_DEMO_PATH)
	return ""

static func _get_configured_or_default(setting_key: String, default_path: String) -> String:
	var proj_key := "laser_editor/assets/" + setting_key
	if ProjectSettings.has_setting(proj_key):
		var custom: String = str(ProjectSettings.get_setting(proj_key, "")).strip_edges()
		if not custom.is_empty() and (ResourceLoader.exists(custom) or FileAccess.file_exists(custom)):
			return custom
	return default_path

static func get_cell_asset_texture(stage: LaserStageData, asset_ref: String) -> Texture2D:
	var path := resolve_asset_in_library(stage, "cell", asset_ref)
	if not path.is_empty():
		var tex := get_texture(path)
		if tex != null:
			return tex
	return get_texture(DEFAULT_CELL_DEMO_PATH)

static func get_cell_visual_texture(asset_ref: String, stage: LaserStageData = null) -> Texture2D:
	return get_cell_asset_texture(stage, asset_ref)

static func get_border_asset_texture(stage: LaserStageData, asset_ref: String) -> Texture2D:
	var path := resolve_asset_in_library(stage, "border", asset_ref)
	if path.is_empty():
		return null
	var tex := get_texture(path)
	if tex != null:
		return tex
	return get_texture(DEFAULT_BORDER_DEMO_PATH)

static func get_corner_asset_texture(stage: LaserStageData, asset_ref: String) -> Texture2D:
	var path := resolve_asset_in_library(stage, "corner", asset_ref)
	if path.is_empty():
		return null
	var tex := get_texture(path)
	if tex != null:
		return tex
	return get_texture(DEFAULT_CORNER_DEMO_PATH)

static func get_border_texture(stage: LaserStageData, border_type: String) -> Texture2D:
	match border_type:
		"C", "corner":
			return get_corner_asset_texture(stage, "corner_1")
		_:
			return get_border_asset_texture(stage, "border_1")

static func get_texture(path: String) -> Texture2D:
	var clean := path.strip_edges()
	if clean.is_empty():
		return null
	if _texture_cache.has(clean) and is_instance_valid(_texture_cache[clean]):
		return _texture_cache[clean]

	var tex: Texture2D = null
	if clean.begins_with("res://"):
		if ResourceLoader.exists(clean):
			tex = ResourceLoader.load(clean, "", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
		if tex == null and FileAccess.file_exists(clean):
			var img := Image.load_from_file(clean)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	elif FileAccess.file_exists(clean):
		var img := Image.load_from_file(clean)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)

	if tex != null:
		_texture_cache[clean] = tex
	return tex

static func get_cell_visual(stage: LaserStageData, cell: Vector2i) -> Dictionary:
	if stage == null or not stage.is_inside_grid(cell):
		return {
			"type": -1,
			"asset": "",
			"rotation": 0.0,
			"texture": null
		}

	if stage.has_cell_visual(cell):
		var vis: Dictionary = stage.get_cell_visual(cell)
		var asset_name: String = str(vis.get("asset", ""))
		var rot_deg: float = float(vis.get("rotation", 0.0))
		var tex: Texture2D = get_cell_asset_texture(stage, asset_name)
		return {
			"type": 0,
			"asset": asset_name,
			"rotation": rot_deg,
			"texture": tex
		}

	return {
		"type": -1,
		"asset": "",
		"rotation": 0.0,
		"texture": null
	}

static func draw_cell_visual(
	canvas: CanvasItem,
	cell_rect: Rect2,
	texture: Texture2D,
	rot_deg: float,
	arg5 = false,
	arg6 = false,
	arg7 = Color.WHITE
) -> void:
	if canvas == null or texture == null:
		return
	var tex_sz := texture.get_size()
	if tex_sz.x <= 0 or tex_sz.y <= 0:
		return

	var mirror_x: bool = false
	var mirror_y: bool = false
	var modulate: Color = Color.WHITE

	if arg5 is Color:
		modulate = arg5
	else:
		mirror_x = bool(arg5)
		if arg6 is Color:
			modulate = arg6
		else:
			mirror_y = bool(arg6)
			if arg7 is Color:
				modulate = arg7

	var center := cell_rect.get_center()
	var base_scale := Vector2(cell_rect.size.x / tex_sz.x, cell_rect.size.y / tex_sz.y)
	var final_scale := Vector2(
		-base_scale.x if mirror_x else base_scale.x,
		-base_scale.y if mirror_y else base_scale.y
	)
	var rad := deg_to_rad(rot_deg)

	canvas.draw_set_transform(center, rad, final_scale)
	canvas.draw_texture(texture, -tex_sz * 0.5, modulate)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func get_perimeter_border_rect(origin: Vector2, cell_size: Vector2, grid_width: int, grid_height: int, side: String, index: int) -> Rect2:
	var grid_left := origin.x
	var grid_top := origin.y
	var grid_right := origin.x + float(grid_width) * cell_size.x
	var grid_bottom := origin.y + float(grid_height) * cell_size.y

	match side.to_lower():
		"top":
			return Rect2(grid_left + float(index) * cell_size.x, grid_top - cell_size.y, cell_size.x, cell_size.y)
		"bottom":
			return Rect2(grid_left + float(index) * cell_size.x, grid_bottom, cell_size.x, cell_size.y)
		"left":
			return Rect2(grid_left - cell_size.x, grid_top + float(index) * cell_size.y, cell_size.x, cell_size.y)
		"right":
			return Rect2(grid_right, grid_top + float(index) * cell_size.y, cell_size.x, cell_size.y)
		_:
			return Rect2(origin, cell_size)

static func get_outer_corner_rect(origin: Vector2, cell_size: Vector2, grid_width: int, grid_height: int, corner: String) -> Rect2:
	var grid_left := origin.x
	var grid_top := origin.y
	var grid_right := origin.x + float(grid_width) * cell_size.x
	var grid_bottom := origin.y + float(grid_height) * cell_size.y

	match corner.to_lower():
		"top_left":
			return Rect2(grid_left - cell_size.x, grid_top - cell_size.y, cell_size.x, cell_size.y)
		"top_right":
			return Rect2(grid_right, grid_top - cell_size.y, cell_size.x, cell_size.y)
		"bottom_left":
			return Rect2(grid_left - cell_size.x, grid_bottom, cell_size.x, cell_size.y)
		"bottom_right":
			return Rect2(grid_right, grid_bottom, cell_size.x, cell_size.y)
		_:
			return Rect2(origin, cell_size)

static func get_border_pieces(
	stage: LaserStageData,
	origin: Vector2,
	cell_size: Vector2
) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	if stage == null:
		return pieces

	stage.ensure_default_visual_libraries()

	# 1. Painted Outer Perimeter Border Segments
	for k in stage.border_visuals.keys():
		var bv = stage.border_visuals[k]
		if not (bv is Dictionary):
			continue
		var side := str(bv.get("side", "top")).to_lower()
		var index := int(bv.get("index", 0))
		var asset_id := str(bv.get("asset", ""))
		var rot_deg := float(bv.get("rotation", 0.0))
		if asset_id.is_empty():
			continue

		var rect := get_perimeter_border_rect(origin, cell_size, stage.grid_width, stage.grid_height, side, index)
		pieces.append({
			"type": "border",
			"side": side,
			"index": index,
			"asset": asset_id,
			"rect": rect,
			"rotation": rot_deg,
			"mirror_x": false,
			"mirror_y": false
		})

	# 2. Painted Outer 4 Corners
	for k in stage.corner_visuals.keys():
		var cv = stage.corner_visuals[k]
		if not (cv is Dictionary):
			continue
		var corner := str(cv.get("corner", k)).to_lower()
		var asset_id := str(cv.get("asset", ""))
		var rot_deg := float(cv.get("rotation", 0.0))
		var mx := bool(cv.get("mirror_x", false))
		var my := bool(cv.get("mirror_y", false))
		if asset_id.is_empty():
			continue

		var rect := get_outer_corner_rect(origin, cell_size, stage.grid_width, stage.grid_height, corner)
		pieces.append({
			"type": "corner",
			"corner": corner,
			"asset": asset_id,
			"rect": rect,
			"rotation": rot_deg,
			"mirror_x": mx,
			"mirror_y": my
		})

	return pieces

static func draw_borders(
	canvas: CanvasItem,
	stage: LaserStageData,
	origin: Vector2,
	cell_size: Vector2,
	_zoom: float = 1.0
) -> void:
	if canvas == null or stage == null or not stage.border_enabled:
		return

	var pieces := get_border_pieces(stage, origin, cell_size)
	for p in pieces:
		var tex: Texture2D = null
		if str(p.get("type", "")) == "corner":
			tex = get_corner_asset_texture(stage, str(p.get("asset", "")))
		else:
			tex = get_border_asset_texture(stage, str(p.get("asset", "")))

		if tex != null:
			draw_cell_visual(
				canvas,
				p["rect"],
				tex,
				float(p.get("rotation", 0.0)),
				bool(p.get("mirror_x", false)),
				bool(p.get("mirror_y", false))
			)

static func draw_board(
	canvas: CanvasItem,
	stage: LaserStageData,
	origin: Vector2,
	cell_size: Vector2,
	zoom: float = 1.0,
	show_borders: bool = true,
	border_col: Color = Color(0.24, 0.27, 0.33, 0.35)
) -> void:
	if canvas == null or stage == null:
		return

	var gw := stage.grid_width
	var gh := stage.grid_height

	# 1. Render Logical Grid Cell Backgrounds & Visuals
	for y in range(gh):
		for x in range(gw):
			var cell := Vector2i(x, y)
			var cell_rect := Rect2(origin + Vector2(float(x) * cell_size.x, float(y) * cell_size.y), cell_size)

			# Base cell background tint
			var is_even := (x + y) % 2 == 0
			var bg_col := Color(0.18, 0.20, 0.25, 1.0) if is_even else Color(0.15, 0.17, 0.21, 1.0)
			canvas.draw_rect(cell_rect, bg_col)

			# Cell Visuals: If placed in this cell, draw it with arbitrary rotation
			if stage.has_cell_visual(cell):
				var visual := get_cell_visual(stage, cell)
				var tex: Texture2D = visual.get("texture", null)
				var rot: float = float(visual.get("rotation", 0.0))
				if tex != null:
					draw_cell_visual(canvas, cell_rect, tex, rot)

			if show_borders:
				canvas.draw_rect(cell_rect, border_col, false, 1.0)

	# 2. Render Independent Border Visuals around the outside of the grid
	if stage.border_enabled:
		draw_borders(canvas, stage, origin, cell_size, zoom)
