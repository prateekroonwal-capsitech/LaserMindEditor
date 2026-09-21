extends Node2D
class_name ProceduralLaserObject

var obj_data: LaserObjectData = null
var cell_size: Vector2 = Vector2(64, 64)
var is_switch_on: bool = false
var get_world_pos_fn: Callable

func setup(p_obj: LaserObjectData, p_cell_size: Vector2, p_get_world_pos: Callable) -> void:
	obj_data = p_obj
	cell_size = p_cell_size
	get_world_pos_fn = p_get_world_pos
	sync_transform()
	queue_redraw()

func update_cell_size(new_cell_size: Vector2) -> void:
	cell_size = new_cell_size
	queue_redraw()

func sync_transform() -> void:
	if obj_data != null and get_world_pos_fn.is_valid():
		position = get_world_pos_fn.call(obj_data.grid_pos)
		queue_redraw()

func on_simulation_updated(sim_res: Dictionary) -> void:
	if obj_data == null:
		return
	if obj_data.type in [LaserObjectData.ObjectType.SWITCH, LaserObjectData.ObjectType.GATE_SWITCH]:
		is_switch_on = sim_res.get("switches_hit", {}).get(obj_data.grid_pos, false)
		queue_redraw()

func _draw() -> void:
	if obj_data == null:
		return

	var rad := cell_size.x * 0.42

	match obj_data.type:
		LaserObjectData.ObjectType.LASER_SOURCE:
			draw_circle(Vector2.ZERO, rad * 0.8, Color(0.25, 0.28, 0.35))
			draw_circle(Vector2.ZERO, rad * 0.5, obj_data.color)
			draw_circle(Vector2.ZERO, rad * 0.2, Color.WHITE)
			var rot_rad = deg_to_rad(float(obj_data.rotation_deg))
			var p_tip = Vector2(rad * 1.1, 0).rotated(rot_rad)
			draw_line(Vector2.ZERO, p_tip, obj_data.color, 3.5)

		LaserObjectData.ObjectType.MOVABLE_AREA:
			var r_sz = rad * 1.8
			var box = Rect2(-Vector2(r_sz, r_sz) * 0.5, Vector2(r_sz, r_sz))
			draw_rect(box.grow(-2), Color(0.12, 0.45, 0.75, 0.35), true)
			draw_rect(box.grow(-2), Color(0.35, 0.85, 1.0, 0.8), false, 1.5)
			var m_rad = rad * 0.35
			draw_arc(Vector2.ZERO, m_rad, 0, TAU, 12, Color(0.35, 0.85, 1.0, 0.6), 1.2)
			draw_line(Vector2(-m_rad, 0), Vector2(m_rad, 0), Color(0.35, 0.85, 1.0, 0.6), 1.0)
			draw_line(Vector2(0, -m_rad), Vector2(0, m_rad), Color(0.35, 0.85, 1.0, 0.6), 1.0)

		LaserObjectData.ObjectType.FIXED_MIRROR:
			var rot_rad = deg_to_rad(float(obj_data.rotation_deg))
			var p1 = Vector2(-rad, -rad).rotated(rot_rad)
			var p2 = Vector2(rad, rad).rotated(rot_rad)
			draw_line(p1, p2, Color(0.3, 0.6, 0.9, 0.5), 6.0)
			draw_line(p1, p2, Color(0.85, 0.95, 1.0), 2.5)

		LaserObjectData.ObjectType.MOVABLE_MIRROR:
			var r_sz = rad * 1.6
			var box = Rect2(-Vector2(r_sz, r_sz) * 0.5, Vector2(r_sz, r_sz))
			draw_rect(box, Color(0.2, 0.3, 0.4, 0.6), true)
			draw_rect(box, Color(0.4, 0.7, 1.0, 0.8), false, 1.5)
			var rot_rad = deg_to_rad(float(obj_data.rotation_deg))
			var p1 = Vector2(-rad, -rad).rotated(rot_rad)
			var p2 = Vector2(rad, rad).rotated(rot_rad)
			draw_line(p1, p2, Color(0.9, 0.95, 1.0), 3.0)

		LaserObjectData.ObjectType.ROTATABLE_MIRROR:
			draw_arc(Vector2.ZERO, rad * 0.85, 0, TAU, 16, Color(0.5, 0.8, 0.3, 0.7), 1.5)
			var rot_rad = deg_to_rad(float(obj_data.rotation_deg))
			var p1 = Vector2(-rad * 0.7, -rad * 0.7).rotated(rot_rad)
			var p2 = Vector2(rad * 0.7, rad * 0.7).rotated(rot_rad)
			draw_line(p1, p2, Color(0.9, 1.0, 0.9), 3.0)

		LaserObjectData.ObjectType.ROCK:
			var pts: PackedVector2Array = [
				Vector2(-rad, -rad * 0.6),
				Vector2(rad * 0.2, -rad),
				Vector2(rad, -rad * 0.4),
				Vector2(rad * 0.8, rad * 0.8),
				Vector2(-rad * 0.5, rad),
				Vector2(-rad * 0.9, rad * 0.2)
			]
			draw_colored_polygon(pts, Color(0.45, 0.42, 0.4))
			draw_polyline(pts, Color(0.3, 0.28, 0.26), 1.5)

		LaserObjectData.ObjectType.ICE:
			var r_sz = rad * 1.5
			var box = Rect2(-Vector2(r_sz, r_sz) * 0.5, Vector2(r_sz, r_sz))
			draw_rect(box, Color(0.4, 0.8, 0.95, 0.65), true)
			draw_rect(box, Color(0.8, 0.95, 1.0, 0.9), false, 1.5)

		LaserObjectData.ObjectType.SPLITTER:
			draw_circle(Vector2.ZERO, rad * 0.85, Color(0.3, 0.25, 0.4))
			var rot_rad = deg_to_rad(float(obj_data.rotation_deg))
			var bar1 = Vector2(-rad * 0.6, -rad * 0.3).rotated(rot_rad)
			var bar2 = Vector2(rad * 0.6, -rad * 0.3).rotated(rot_rad)
			var stem = Vector2(0, rad * 0.6).rotated(rot_rad)
			draw_line(bar1, bar2, Color(0.8, 0.5, 1.0), 3.0)
			draw_line(Vector2.ZERO, stem, Color(0.8, 0.5, 1.0), 3.0)

		LaserObjectData.ObjectType.COLOR_GLASS:
			var r_sz = rad * 1.4
			var box = Rect2(-Vector2(r_sz, r_sz) * 0.5, Vector2(r_sz, r_sz))
			draw_rect(box, Color(obj_data.color.r, obj_data.color.g, obj_data.color.b, 0.55), true)
			draw_rect(box, Color.WHITE, false, 1.5)

		LaserObjectData.ObjectType.COLOR_WALL:
			var r_sz = rad * 1.6
			var box = Rect2(-Vector2(r_sz, r_sz) * 0.5, Vector2(r_sz, r_sz))
			draw_rect(box, Color(obj_data.color.r * 0.7, obj_data.color.g * 0.7, obj_data.color.b * 0.7, 1.0), true)
			draw_rect(box, Color(obj_data.color.r, obj_data.color.g, obj_data.color.b, 1.0), false, 2.5)

		LaserObjectData.ObjectType.GATE:
			var r_sz = rad * 1.5
			var box = Rect2(-Vector2(r_sz, r_sz) * 0.5, Vector2(r_sz, r_sz))
			draw_rect(box, Color(0.35, 0.08, 0.08, 0.85), true)
			draw_rect(box, Color(0.9, 0.25, 0.25), false, 2.0)
			var door_w = r_sz * 0.5
			var door_h = r_sz * 0.7
			var door_rect = Rect2(-door_w * 0.5, r_sz * 0.5 - door_h, door_w, door_h)
			draw_rect(door_rect, Color(0.18, 0.04, 0.04, 0.95), true)
			draw_line(door_rect.position, door_rect.position + door_rect.size, Color(1.0, 0.6, 0.6, 0.7), 1.5)
			draw_line(Vector2(door_rect.position.x + door_rect.size.x, door_rect.position.y), Vector2(door_rect.position.x, door_rect.position.y + door_rect.size.y), Color(1.0, 0.6, 0.6, 0.7), 1.5)
			draw_circle(Vector2(0, -rad * 0.1), rad * 0.2, Color.WHITE)
			draw_circle(Vector2(0, -rad * 0.1), rad * 0.12, Color(0.9, 0.2, 0.2))

		LaserObjectData.ObjectType.EXIT_GATE:
			var r_sz = rad * 1.5
			var box = Rect2(-Vector2(r_sz, r_sz) * 0.5, Vector2(r_sz, r_sz))
			draw_rect(box, Color(0.08, 0.35, 0.25, 0.85), true)
			draw_rect(box, Color(0.2, 0.8, 0.5), false, 2.0)
			var door_w = r_sz * 0.5
			var door_h = r_sz * 0.7
			var door_rect = Rect2(-door_w * 0.5, r_sz * 0.5 - door_h, door_w, door_h)
			draw_rect(door_rect, Color(0.02, 0.15, 0.1, 0.95), true)
			var arr_start = Vector2(0, rad * 0.25)
			var arr_end = Vector2(0, -rad * 0.25)
			draw_line(arr_start, arr_end, Color.WHITE, 2.0)
			draw_line(arr_end, arr_end + Vector2(-rad * 0.2, rad * 0.2), Color.WHITE, 2.0)
			draw_line(arr_end, arr_end + Vector2(rad * 0.2, rad * 0.2), Color.WHITE, 2.0)

		LaserObjectData.ObjectType.SWITCH:
			var s_col = Color(0.3, 1.0, 0.5) if is_switch_on else Color(0.7, 0.7, 0.3)
			draw_circle(Vector2.ZERO, rad * 0.7, s_col)
			draw_arc(Vector2.ZERO, rad * 0.85, 0, TAU, 12, Color.WHITE, 1.5)

		LaserObjectData.ObjectType.GATE_SWITCH:
			draw_rect(Rect2(-Vector2(rad, rad) * 0.6, Vector2(rad, rad) * 1.2), Color(0.6, 0.4, 0.2))
			draw_circle(Vector2.ZERO, rad * 0.4, Color.GOLD)

		LaserObjectData.ObjectType.CUSTOM:
			var r_sz = rad * 1.4
			var box = Rect2(-Vector2(r_sz, r_sz) * 0.5, Vector2(r_sz, r_sz))
			draw_rect(box, Color(obj_data.color.r * 0.4, obj_data.color.g * 0.4, obj_data.color.b * 0.4, 0.8), true)
			draw_rect(box, obj_data.color, false, 2.0)
			var pts: PackedVector2Array = [
				Vector2(0, -rad * 0.6),
				Vector2(rad * 0.6, 0),
				Vector2(0, rad * 0.6),
				Vector2(-rad * 0.6, 0)
			]
			draw_colored_polygon(pts, obj_data.color)
			draw_polyline(pts, Color.WHITE, 1.5)

	var font := ThemeDB.fallback_font
	var name_str = ""
	if obj_data.type == LaserObjectData.ObjectType.CUSTOM:
		name_str = str(obj_data.properties.get("custom_name", ""))
	if name_str.is_empty():
		name_str = LaserObjectData.TYPE_SHORT_NAMES.get(obj_data.type, "")
	draw_string(font, Vector2(-rad, rad + 11), name_str, HORIZONTAL_ALIGNMENT_CENTER, int(rad * 2), 10, Color(0.85, 0.85, 0.85, 0.75))
