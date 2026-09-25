@tool
extends BaseLaserObject
class_name LaserSwitch

var is_pressed: bool = false

func on_simulation_updated(sim_res: Dictionary) -> void:
	if obj_data != null:
		var switches_hit: Dictionary = sim_res.get("switches_hit", {})
		is_pressed = switches_hit.get(obj_data.grid_pos, false)
		var spr = get_node_or_null("Sprite2D")
		if spr is Sprite2D:
			spr.modulate = Color(0.4, 1.2, 0.5) if is_pressed else Color.WHITE
