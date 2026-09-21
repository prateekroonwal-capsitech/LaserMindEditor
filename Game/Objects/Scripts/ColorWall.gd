@tool
extends BaseLaserObject
class_name ColorWall

func setup(p_obj: LaserObjectData) -> void:
	super.setup(p_obj)
	var spr = get_node_or_null("Sprite2D")
	if spr is Sprite2D and obj_data != null and obj_data.color != Color.WHITE:
		spr.modulate = obj_data.color
