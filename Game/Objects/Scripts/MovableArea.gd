@tool
extends BaseLaserObject
class_name LaserMovableArea

func setup(p_obj: LaserObjectData) -> void:
	super.setup(p_obj)
	if obj_data != null:
		modulate = obj_data.color if obj_data.color.a > 0.05 else Color(0.2, 0.65, 1.0)

func set_radius(p_radius: float) -> void:
	radius = p_radius
	var spr = get_node_or_null("Sprite2D")
	if spr is Sprite2D and spr.texture != null:
		spr.scale = Vector2.ONE * (radius * 2.35 / spr.texture.get_size().x)
