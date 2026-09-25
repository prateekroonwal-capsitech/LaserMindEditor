@tool
extends BaseLaserObject
class_name LaserEntryGate

var is_open: bool = false
var is_emitting: bool = false

func on_simulation_updated(sim_res: Dictionary) -> void:
	if obj_data != null:
		var segments: Array = sim_res.get("segments", [])
		var closed = false
		is_emitting = false
		for seg in segments:
			if seg.get("hit_type", "") == "gate_closed" and seg.get("hit_pos", Vector2i(-1, -1)) == obj_data.grid_pos:
				closed = true
			if seg.get("start", Vector2i(-1, -1)) == obj_data.grid_pos:
				is_emitting = true
		is_open = not closed
		var spr = get_node_or_null("Sprite2D")
		if spr is Sprite2D:
			if is_emitting:
				spr.modulate = Color(1.3, 1.1, 1.1, 1.0)
			elif is_open:
				spr.modulate = Color(0.4, 0.9, 1.0, 0.4)
			else:
				spr.modulate = Color.WHITE
