@tool
extends BaseLaserObject
class_name LaserEmitterObject

@onready var sprite: Sprite2D = $Sprite2D

func setup(p_obj: LaserObjectData) -> void:
	super.setup(p_obj)
	if obj_data != null and sprite != null:
		sprite.modulate = obj_data.color if obj_data.color != Color.WHITE else Color.WHITE
