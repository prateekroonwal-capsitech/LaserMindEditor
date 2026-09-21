@tool
extends RefCounted
class_name LevelEditorUndoManager

signal history_changed
signal dirty_state_changed(is_dirty: bool)

enum ActionType {
	ADD_OBJECT,
	DELETE_OBJECT,
	MOVE_OBJECT,
	ROTATE_OBJECT,
	MODIFY_OBJECT,
	BATCH_MODIFY,
	RESIZE_GRID,
	STAGE_CONFIG,
	STAGE_SNAPSHOT
}

var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _max_history: int = 100
var _is_dirty: bool = false
var _saved_version: int = 0
var _current_version: int = 0

func commit_action(action: Dictionary) -> void:
	_undo_stack.append(action)
	if _undo_stack.size() > _max_history:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_current_version += 1
	_update_dirty()
	history_changed.emit()

func commit_snapshot(before_stage: LaserStageData, after_stage: LaserStageData) -> void:
	if before_stage == null or after_stage == null:
		return
	commit_action({
		"type": ActionType.STAGE_SNAPSHOT,
		"before": before_stage.duplicate_data(),
		"after": after_stage.duplicate_data(),
		"stage_idx": after_stage.stage_index
	})

func can_undo() -> bool:
	return not _undo_stack.is_empty()

func can_redo() -> bool:
	return not _redo_stack.is_empty()

func peek_undo_stage_idx() -> int:
	if _undo_stack.is_empty():
		return 1
	return _undo_stack[_undo_stack.size() - 1].get("stage_idx", 1)

func peek_redo_stage_idx() -> int:
	if _redo_stack.is_empty():
		return 1
	return _redo_stack[_redo_stack.size() - 1].get("stage_idx", 1)

func undo(stage: LaserStageData) -> bool:
	if _undo_stack.is_empty() or stage == null:
		return false

	var action = _undo_stack.pop_back()
	_redo_stack.append(action)
	_current_version -= 1
	_apply_action(action, stage, true)
	_update_dirty()
	history_changed.emit()
	return true

func redo(stage: LaserStageData) -> bool:
	if _redo_stack.is_empty() or stage == null:
		return false

	var action = _redo_stack.pop_back()
	_undo_stack.append(action)
	_current_version += 1
	_apply_action(action, stage, false)
	_update_dirty()
	history_changed.emit()
	return true

func mark_saved() -> void:
	_saved_version = _current_version
	_update_dirty()

func is_dirty() -> bool:
	return _is_dirty

func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_current_version = 0
	_saved_version = 0
	_is_dirty = false
	dirty_state_changed.emit(false)
	history_changed.emit()

func _update_dirty() -> void:
	var new_dirty = (_current_version != _saved_version)
	if new_dirty != _is_dirty:
		_is_dirty = new_dirty
		dirty_state_changed.emit(_is_dirty)

func _apply_action(action: Dictionary, stage: LaserStageData, is_undo: bool) -> void:
	var type: int = action.get("type", -1)
	match type:
		ActionType.ADD_OBJECT:
			var obj_data: LaserObjectData = action.get("object", null)
			if is_undo:
				stage.remove_object(obj_data)
			else:
				stage.add_object(obj_data)

		ActionType.DELETE_OBJECT:
			var obj_data: LaserObjectData = action.get("object", null)
			if is_undo:
				stage.add_object(obj_data)
			else:
				stage.remove_object(obj_data)

		ActionType.MOVE_OBJECT:
			var obj: LaserObjectData = action.get("object", null)
			var old_pos: Vector2i = action.get("old_pos", Vector2i.ZERO)
			var new_pos: Vector2i = action.get("new_pos", Vector2i.ZERO)
			if obj != null:
				obj.grid_pos = old_pos if is_undo else new_pos

		ActionType.ROTATE_OBJECT:
			var obj: LaserObjectData = action.get("object", null)
			var old_rot: int = action.get("old_rot", 0)
			var new_rot: int = action.get("new_rot", 0)
			if obj != null:
				obj.rotation_deg = old_rot if is_undo else new_rot

		ActionType.MODIFY_OBJECT:
			var obj: LaserObjectData = action.get("object", null)
			var old_dict: Dictionary = action.get("old_state", {})
			var new_dict: Dictionary = action.get("new_state", {})
			var target_dict = old_dict if is_undo else new_dict
			if obj != null and not target_dict.is_empty():
				obj.rotation_deg = target_dict.get("rot", obj.rotation_deg)
				obj.grid_pos = target_dict.get("pos", obj.grid_pos)
				obj.color = target_dict.get("color", obj.color)
				obj.movable = target_dict.get("movable", obj.movable)
				obj.rotatable = target_dict.get("rotatable", obj.rotatable)
				obj.enabled = target_dict.get("enabled", obj.enabled)
				obj.target_id = target_dict.get("target_id", obj.target_id)

		ActionType.RESIZE_GRID:
			var old_w = action.get("old_w", stage.grid_width)
			var old_h = action.get("old_h", stage.grid_height)
			var new_w = action.get("new_w", stage.grid_width)
			var new_h = action.get("new_h", stage.grid_height)
			stage.grid_width = old_w if is_undo else new_w
			stage.grid_height = old_h if is_undo else new_h

		ActionType.STAGE_SNAPSHOT:
			var target_state: LaserStageData = action.get("before") if is_undo else action.get("after")
			if target_state != null and stage != null:
				stage.grid_width = target_state.grid_width
				stage.grid_height = target_state.grid_height
				stage.time_limit = target_state.time_limit
				stage.time_bonus = target_state.time_bonus
				stage.objects.clear()
				for obj in target_state.objects:
					if obj != null:
						stage.objects.append(obj.duplicate_data())
