@tool
extends BaseLaserObject
class_name LaserGateWithSwitch

var is_active_gate: bool = false

func on_simulation_updated(sim_res: Dictionary) -> void:
	if obj_data != null:
		var switches_hit: Dictionary = sim_res.get("switches_hit", {})
		is_active_gate = switches_hit.get(obj_data.grid_pos, false)
		var spr = get_node_or_null("Sprite2D")
		if spr is Sprite2D:
			spr.modulate = Color(0.6, 1.2, 0.8) if is_active_gate else Color.WHITE
