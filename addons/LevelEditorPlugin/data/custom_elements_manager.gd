@tool
class_name CustomElementsManager

const SAVE_PATH: String = "res://Game/Data/custom_elements.json"

static func load_elements() -> Array[Dictionary]:
	var elements: Array[Dictionary] = []
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var text = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(text) == OK and json.data is Array:
				for item in json.data:
					if item is Dictionary:
						elements.append({
							"id": str(item.get("id", "custom_%d" % (elements.size() + 1))),
							"name": str(item.get("name", "Custom %d" % (elements.size() + 1))),
							"scene_path": str(item.get("scene_path", "")),
							"color": Color.from_string(str(item.get("color", "#f09020")), Color(0.95, 0.6, 0.2)),
							"index": int(item.get("index", elements.size()))
						})
	return elements

static func save_elements(elements: Array[Dictionary]) -> void:
	if elements.is_empty():
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(SAVE_PATH)
		return

	var raw_arr: Array = []
	for i in range(elements.size()):
		var e = elements[i]
		raw_arr.append({
			"id": e.get("id", "custom_%d" % (i + 1)),
			"name": e.get("name", ""),
			"scene_path": e.get("scene_path", ""),
			"color": e.get("color", Color.ORANGE).to_html(false),
			"index": i
		})
	var dir = SAVE_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(raw_arr, "\t"))
		file.close()

static func add_new_element(elements: Array[Dictionary]) -> Dictionary:
	var new_idx: int = elements.size()
	var new_id: String = "custom_%d" % (new_idx + 1)
	var new_name: String = "Custom %d" % (new_idx + 1)
	var palette_colors: Array[Color] = [
		Color(0.95, 0.6, 0.2),
		Color(0.85, 0.3, 0.85),
		Color(0.2, 0.8, 0.9),
		Color(0.5, 0.9, 0.4),
		Color(0.95, 0.85, 0.2),
		Color(0.6, 0.4, 0.95),
		Color(0.95, 0.35, 0.35),
		Color(0.35, 0.95, 0.8)
	]
	var col: Color = palette_colors[new_idx % palette_colors.size()]
	var elem: Dictionary = {
		"id": new_id,
		"name": new_name,
		"scene_path": "",
		"color": col,
		"index": new_idx
	}
	elements.append(elem)
	save_elements(elements)
	return elem

static func remove_element(elements: Array[Dictionary], index: int) -> bool:
	if elements.is_empty():
		return false
	if index >= 0 and index < elements.size():
		elements.remove_at(index)
		for i in range(elements.size()):
			elements[i]["index"] = i
		save_elements(elements)
		return true
	return false

static func get_element_by_name(elements: Array[Dictionary], elem_name: String) -> Dictionary:
	for e in elements:
		if str(e.get("name", "")) == elem_name:
			return e
	return {}

static func update_element_name(elements: Array[Dictionary], idx: int, new_name: String) -> bool:
	if idx >= 0 and idx < elements.size():
		elements[idx]["name"] = new_name
		save_elements(elements)
		return true
	return false
