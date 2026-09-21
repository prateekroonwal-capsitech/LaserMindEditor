@tool
extends BaseLaserObject
class_name CustomObject

func setup(p_obj: LaserObjectData) -> void:
	super.setup(p_obj)
	if obj_data != null and has_node("Sprite2D"):
		$Sprite2D.modulate = obj_data.color

func on_simulation_updated(sim_res: Dictionary) -> void:
	pass
