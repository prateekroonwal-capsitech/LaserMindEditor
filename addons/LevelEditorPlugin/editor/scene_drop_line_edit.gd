@tool
class_name SceneDropLineEdit
extends LineEdit

signal scene_dropped(scene_path: String)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not editable:
		return false
	var path := _extract_scene_path(data)
	return not path.is_empty()

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var path := _extract_scene_path(data)
	if not path.is_empty():
		text = path
		text_changed.emit(path)
		scene_dropped.emit(path)

func _extract_scene_path(data: Variant) -> String:
	if data is Dictionary:
		var d_type: String = str(data.get("type", ""))
		if d_type == "files":
			var files = data.get("files", [])
			if files is Array or files is PackedStringArray:
				for f in files:
					var s: String = str(f)
					if s.ends_with(".tscn") or s.ends_with(".scn"):
						return s
		elif d_type == "resource":
			var res = data.get("resource", null)
			if res is Resource and not res.resource_path.is_empty():
				var rp: String = res.resource_path
				if rp.ends_with(".tscn") or rp.ends_with(".scn"):
					return rp
	elif data is String:
		var s := data as String
		if s.ends_with(".tscn") or s.ends_with(".scn"):
			return s
	return ""
