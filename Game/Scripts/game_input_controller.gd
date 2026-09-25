extends RefCounted
class_name GameInputController

const BoardLayoutManager = preload("res://Game/Scripts/board_layout_manager.gd")
const ObjectSpawner = preload("res://Game/Scripts/object_spawner.gd")

signal request_restart_stage()
signal request_load_stage(stage_num: int)
signal request_toggle_visuals()
signal request_quit_game()
signal request_next_stage()
signal object_rotated(obj: LaserObjectData)
signal object_dragged(obj: LaserObjectData)
signal drag_ended()

var candidate_object: LaserObjectData = null
var candidate_start_pos: Vector2 = Vector2.ZERO
var candidate_start_cell: Vector2i = Vector2i.ZERO
var is_actively_dragging: bool = false
var dragged_object: LaserObjectData = null
var drag_start_cell: Vector2i = Vector2i.ZERO

const DRAG_THRESHOLD: float = 8.0

func handle_input(
	event: InputEvent,
	current_stage: LaserStageData,
	grid_origin: Vector2,
	cell_size: Vector2,
	is_playtest_mode: bool,
	is_transitioning: bool,
	stage_cleared: bool
) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		var k := event as InputEventKey
		match k.keycode:
			KEY_ESCAPE:
				if is_playtest_mode:
					request_quit_game.emit()
			KEY_R:
				request_restart_stage.emit()
			KEY_V:
				if is_playtest_mode:
					request_toggle_visuals.emit()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				var target_num: int = k.keycode - KEY_1 + 1
				request_load_stage.emit(target_num)

	if is_transitioning:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_handle_press(mb.position, current_stage, grid_origin, cell_size, stage_cleared)
			else:
				_handle_release()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_handle_press(st.position, current_stage, grid_origin, cell_size, stage_cleared)
		else:
			_handle_release()
	elif event is InputEventMouseMotion and candidate_object != null:
		var mm := event as InputEventMouseMotion
		_handle_drag(mm.position, current_stage, grid_origin, cell_size)
	elif event is InputEventScreenDrag and candidate_object != null:
		var sd := event as InputEventScreenDrag
		_handle_drag(sd.position, current_stage, grid_origin, cell_size)

func _handle_press(
	screen_pos: Vector2,
	current_stage: LaserStageData,
	grid_origin: Vector2,
	cell_size: Vector2,
	stage_cleared: bool
) -> void:
	if stage_cleared:
		request_next_stage.emit()
		return

	if current_stage == null:
		return

	var cell := BoardLayoutManager.world_to_grid(screen_pos, grid_origin, cell_size)
	if not current_stage.is_inside_grid(cell):
		return

	var obj = current_stage.get_foreground_object_at(cell) if current_stage.has_method("get_foreground_object_at") else current_stage.get_object_at(cell)
	if obj != null:
		if obj.movable_area_id.is_empty():
			var ma = current_stage.get_movable_area_at(obj.grid_pos)
			if ma != null and not ma.movable_area_id.is_empty():
				obj.movable_area_id = ma.movable_area_id
		candidate_object = obj
		candidate_start_pos = screen_pos
		candidate_start_cell = obj.grid_pos
		is_actively_dragging = false
		dragged_object = null

func _handle_release() -> void:
	if is_actively_dragging:
		drag_ended.emit()
	elif candidate_object != null:
		if candidate_object.rotatable or candidate_object.type == LaserObjectData.ObjectType.ROTATABLE_MIRROR or candidate_object.type == LaserObjectData.ObjectType.SPLITTER:
			var step: int = 90 if candidate_object.type == LaserObjectData.ObjectType.SPLITTER else 45
			candidate_object.rotation_deg = (candidate_object.rotation_deg + step) % 360
			object_rotated.emit(candidate_object)

	candidate_object = null
	dragged_object = null
	is_actively_dragging = false

func _handle_drag(
	screen_pos: Vector2,
	current_stage: LaserStageData,
	grid_origin: Vector2,
	cell_size: Vector2
) -> void:
	if current_stage == null or candidate_object == null:
		return

	var target_cell := BoardLayoutManager.world_to_grid(screen_pos, grid_origin, cell_size)
	if not is_actively_dragging:
		if screen_pos.distance_to(candidate_start_pos) >= DRAG_THRESHOLD or target_cell != candidate_start_cell:
			var can_move = candidate_object.type not in [
				LaserObjectData.ObjectType.LASER_SOURCE,
				LaserObjectData.ObjectType.GATE,
				LaserObjectData.ObjectType.EXIT_GATE,
				LaserObjectData.ObjectType.GOAL,
				LaserObjectData.ObjectType.MOVABLE_AREA
			] and (
				candidate_object.movable or
				candidate_object.type == LaserObjectData.ObjectType.MOVABLE_MIRROR or
				not candidate_object.movable_area_id.is_empty() or
				current_stage.get_movable_area_at(candidate_object.grid_pos) != null
			)
			if not can_move:
				return
			if candidate_object.movable_area_id.is_empty():
				var ma = current_stage.get_movable_area_at(candidate_object.grid_pos)
				if ma != null and not ma.movable_area_id.is_empty():
					candidate_object.movable_area_id = ma.movable_area_id
			is_actively_dragging = true
			dragged_object = candidate_object

	if is_actively_dragging and dragged_object != null and target_cell != dragged_object.grid_pos:
		var old_pos := dragged_object.grid_pos
		var new_pos := current_stage.step_object_orthogonally(dragged_object, target_cell)
		if new_pos != old_pos:
			object_dragged.emit(dragged_object)
