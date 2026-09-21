@tool
extends RefCounted
class_name LevelMigration

const LEGACY_DIR: String = "res://Game/Data/Levels/"
const LASER_MIND_DIR: String = "res://Game/Data/LaserMindLevels/"
const LASER_TRES_PATTERN: String = "res://Game/Data/LaserMindLevels/Level_%03d.tres"
const LASER_JSON_PATTERN: String = "res://Game/Data/LaserMindLevels/Level_%03d.json"
const LEGACY_PATTERN: String = "res://Game/Data/Levels/Level_%03d.tres"

static func ensure_directories() -> void:
	if not DirAccess.dir_exists_absolute("res://Game/Data/LaserMindLevels/"):
		DirAccess.make_dir_recursive_absolute("res://Game/Data/LaserMindLevels/")

static func load_laser_level(level_id: int) -> LaserLevelData:
	ensure_directories()
	var path_tres := LASER_TRES_PATTERN % level_id
	var path_json := LASER_JSON_PATTERN % level_id

	var tres_exists := ResourceLoader.exists(path_tres)
	var json_exists := FileAccess.file_exists(path_json)

	if tres_exists and json_exists:
		var tres_time := FileAccess.get_modified_time(path_tres)
		var json_time := FileAccess.get_modified_time(path_json)
		if json_time > tres_time:
			var json_lvl := _load_json_level(path_json)
			if json_lvl != null:
				return json_lvl
		var res = ResourceLoader.load(path_tres, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is LaserLevelData:
			res.ensure_three_stages()
			return res
	elif json_exists:
		var json_lvl := _load_json_level(path_json)
		if json_lvl != null:
			return json_lvl
	elif tres_exists:
		var res = ResourceLoader.load(path_tres, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is LaserLevelData:
			res.ensure_three_stages()
			return res

	var path_legacy := LEGACY_PATTERN % level_id
	if ResourceLoader.exists(path_legacy):
		var leg_res = ResourceLoader.load(path_legacy, "", ResourceLoader.CACHE_MODE_IGNORE)
		if leg_res != null and (leg_res.has_method("get_all_emitters") or "emitters" in leg_res):
			return LaserLevelData.from_legacy_level_data(leg_res)

	return null

static func load_level_from_path(file_path: String) -> LaserLevelData:
	ensure_directories()
	if file_path.ends_with(".json"):
		return _load_json_level(file_path)
	elif file_path.ends_with(".tres") or file_path.ends_with(".res"):
		var res = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is LaserLevelData:
			res.ensure_three_stages()
			return res
		elif res != null and (res.has_method("get_all_emitters") or "emitters" in res):
			return LaserLevelData.from_legacy_level_data(res)
	return null

static func _load_json_level(path_json: String) -> LaserLevelData:
	if FileAccess.file_exists(path_json):
		var file = FileAccess.open(path_json, FileAccess.READ)
		if file != null:
			var text = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(text) == OK and json.data is Dictionary:
				var lvl = LaserLevelData.from_dict(json.data)
				if lvl != null:
					lvl.ensure_three_stages()
					return lvl
	return null

static func save_laser_level(lvl: LaserLevelData, custom_tres_path: String = "", custom_json_path: String = "") -> Error:
	ensure_directories()
	if lvl == null:
		return ERR_INVALID_DATA
	lvl.ensure_three_stages()
	var err_tres := save_laser_level_tres(lvl, custom_tres_path)
	var err_json := export_laser_level_json(lvl, custom_json_path)
	if err_tres != OK:
		return err_tres
	return err_json

static func save_laser_level_tres(lvl: LaserLevelData, custom_path: String = "") -> Error:
	ensure_directories()
	if lvl == null:
		return ERR_INVALID_DATA
	lvl.ensure_three_stages()
	var path = custom_path
	if path.is_empty():
		path = LASER_TRES_PATTERN % lvl.level_id
	return ResourceSaver.save(lvl, path)

static func export_laser_level_json(lvl: LaserLevelData, custom_path: String = "") -> Error:
	ensure_directories()
	if lvl == null:
		return ERR_INVALID_DATA
	lvl.ensure_three_stages()
	var path = custom_path
	if path.is_empty():
		path = LASER_JSON_PATTERN % lvl.level_id
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var json_str = JSON.stringify(lvl.to_dict(), "\t")
	file.store_string(json_str)
	file.close()
	return OK

static func get_all_level_ids() -> Array[int]:
	ensure_directories()
	var ids: Dictionary = {}

	var dir = DirAccess.open("res://Game/Data/LaserMindLevels/")
	if dir != null:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while not fname.is_empty():
			if not dir.current_is_dir() and (fname.ends_with(".tres") or fname.ends_with(".json")):
				var num = _extract_number(fname)
				if num > 0:
					ids[num] = true
			fname = dir.get_next()
		dir.list_dir_end()

	var leg_dir = DirAccess.open("res://Game/Data/Levels/")
	if leg_dir != null:
		leg_dir.list_dir_begin()
		var fname = leg_dir.get_next()
		while not fname.is_empty():
			if not leg_dir.current_is_dir() and fname.ends_with(".tres"):
				var num = _extract_number(fname)
				if num > 0:
					ids[num] = true
			fname = leg_dir.get_next()
		leg_dir.list_dir_end()

	var result: Array[int] = []
	for k in ids.keys():
		result.append(int(k))
	result.sort()
	return result

static func _extract_number(s: String) -> int:
	var regex = RegEx.new()
	regex.compile("\\d+")
	var m = regex.search(s)
	if m != null:
		return int(m.get_string())
	return 0
