@tool
extends BaseLaserObject
class_name LaserExitGate

var is_hit: bool = false

func on_simulation_updated(sim_res: Dictionary) -> void:
	if obj_data != null:
		is_hit = sim_res.get("exit_gates_hit", {}).get(obj_data.grid_pos, false)
		var spr = get_node_or_null("Sprite2D")
		if spr is Sprite2D:
			spr.modulate = Color(1.5, 2.2, 1.6, 1.0) if is_hit else Color.WHITE
