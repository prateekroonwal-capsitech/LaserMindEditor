@tool
extends BaseLaserObject
class_name LaserGate

var is_open: bool = false

func on_simulation_updated(sim_res: Dictionary) -> void:
	if obj_data != null:
		var segments: Array = sim_res.get("segments", [])
		var closed = false
		for seg in segments:
			if seg.get("hit_type", "") == "gate_closed" and seg.get("hit_pos", Vector2i(-1, -1)) == obj_data.grid_pos:
				closed = true
				break
		is_open = not closed
		var spr = get_node_or_null("Sprite2D")
		if spr is Sprite2D:
			spr.modulate = Color(0.4, 0.9, 1.0, 0.3) if is_open else Color.WHITE
