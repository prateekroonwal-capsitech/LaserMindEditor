extends RefCounted
class_name ObjectSpawner

const BoardLayoutManager = preload("res://Game/Scripts/board_layout_manager.gd")
const ProceduralLaserObject = preload("res://Game/Scripts/procedural_object.gd")

var prefabs: Dictionary = {}
var custom_named_scenes: Dictionary[String, PackedScene] = {}

func set_prefabs(p_prefabs: Dictionary) -> void:
	prefabs = p_prefabs

func sync_custom_scenes_registry() -> void:
	var reg_elems = CustomElementsManager.load_elements()
	for elem in reg_elems:
		var r_name := str(elem.get("name", "")).strip_edges()
		var r_path := str(elem.get("scene_path", "")).strip_edges()
		if not r_name.is_empty() and not custom_named_scenes.has(r_name):
			if not r_path.is_empty() and ResourceLoader.exists(r_path):
				var scn = load(r_path)
				if scn is PackedScene:
					custom_named_scenes[r_name] = scn

func get_scene_for_object(obj_data: LaserObjectData) -> PackedScene:
	if obj_data == null:
		return null

	if obj_data.type == LaserObjectData.ObjectType.CUSTOM:
		var c_name: String = str(obj_data.properties.get("custom_name", "")).strip_edges()
		if not c_name.is_empty():
			if custom_named_scenes.has(c_name) and custom_named_scenes[c_name] != null:
				return custom_named_scenes[c_name]
			for k in custom_named_scenes.keys():
				if str(k).strip_edges().nocasecmp_to(c_name) == 0 and custom_named_scenes[k] != null:
					return custom_named_scenes[k]

		var custom_path: String = str(obj_data.properties.get("scene_path", "")).strip_edges()
		if not custom_path.is_empty() and ResourceLoader.exists(custom_path):
			return load(custom_path)

		var all_elems = CustomElementsManager.load_elements()
		for elem in all_elems:
			var el_name := str(elem.get("name", "")).strip_edges()
			if not c_name.is_empty() and el_name.nocasecmp_to(c_name) == 0:
				var sp = str(elem.get("scene_path", "")).strip_edges()
				if not sp.is_empty() and ResourceLoader.exists(sp):
					return load(sp)

		var c_idx: int = int(obj_data.properties.get("custom_index", 0))
		if c_idx >= 0 and c_idx < all_elems.size():
			var sp2 = str(all_elems[c_idx].get("scene_path", "")).strip_edges()
			if not sp2.is_empty() and ResourceLoader.exists(sp2):
				return load(sp2)
		return null

	return prefabs.get(obj_data.type, null)

func spawn_object(
	obj_data: LaserObjectData,
	grid_origin: Vector2,
	cell_size: Vector2,
	use_procedural: bool,
	grid_to_world_fn: Callable
) -> Node:
	var prefab: PackedScene = null if use_procedural else get_scene_for_object(obj_data)
	var instance: Node

	if prefab != null:
		instance = prefab.instantiate()
		if instance is Node2D:
			var node_2d := instance as Node2D
			node_2d.position = BoardLayoutManager.grid_to_world(obj_data.grid_pos, grid_origin, cell_size)
			node_2d.rotation_degrees = float(obj_data.rotation_deg)

		if instance.has_method("setup"):
			instance.setup(obj_data)
		elif instance.has_method("initialize"):
			instance.initialize(obj_data)

		if instance is BaseLaserObject:
			(instance as BaseLaserObject).set_radius(cell_size.x * 0.42)

		if instance is CanvasItem and obj_data.type in [
			LaserObjectData.ObjectType.COLOR_GLASS,
			LaserObjectData.ObjectType.COLOR_WALL
		]:
			(instance as CanvasItem).modulate = obj_data.color
	else:
		var proc_node := ProceduralLaserObject.new()
		proc_node.setup(obj_data, cell_size, grid_to_world_fn)
		instance = proc_node

	return instance

func update_node_transform(
	node: Node,
	obj_data: LaserObjectData,
	grid_origin: Vector2,
	cell_size: Vector2
) -> void:
	if not is_instance_valid(node) or obj_data == null:
		return

	if node is ProceduralLaserObject:
		(node as ProceduralLaserObject).update_cell_size(cell_size)
		(node as ProceduralLaserObject).sync_transform()
	elif node is Node2D:
		node.position = BoardLayoutManager.grid_to_world(obj_data.grid_pos, grid_origin, cell_size)
		node.rotation_degrees = float(obj_data.rotation_deg)
		if node is BaseLaserObject:
			(node as BaseLaserObject).set_radius(cell_size.x * 0.42)

static func has_movable_areas(stage: LaserStageData) -> bool:
	return stage != null and stage.has_movable_areas()

static func is_cell_in_movable_area(stage: LaserStageData, cell: Vector2i) -> bool:
	return stage != null and stage.is_cell_in_movable_area(cell)
