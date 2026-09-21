@tool
extends Node2D
class_name BaseLaserObject

var obj_data: LaserObjectData = null
var is_active: bool = false
var radius: float = 26.0

func setup(p_obj: LaserObjectData) -> void:
	obj_data = p_obj
	if obj_data != null:
		rotation_degrees = float(obj_data.rotation_deg)

func set_radius(p_radius: float) -> void:
	radius = p_radius
	var spr = get_node_or_null("Sprite2D")
	if spr is Sprite2D and spr.texture != null:
		var tex_size = spr.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			var target_dim = radius * 2.0
			spr.scale = Vector2(target_dim / tex_size.x, target_dim / tex_size.y)

func on_simulation_updated(_sim_res: Dictionary) -> void:
	pass
