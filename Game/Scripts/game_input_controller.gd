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

var dragged_object: LaserObjectData = null
var drag_start_cell: Vector2i = Vector2i.ZERO

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
	elif event is InputEventMouseMotion and dragged_object != null:
		var mm := event as InputEventMouseMotion
		_handle_drag(mm.position, current_stage, grid_origin, cell_size)
	elif event is InputEventScreenDrag and dragged_object != null:
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

	var obj = current_stage.get_object_at(cell)
	if obj != null:
		if obj.rotatable:
			obj.rotation_deg = (obj.rotation_deg + 45) % 360
			object_rotated.emit(obj)
		elif obj.movable:
			dragged_object = obj
			drag_start_cell = obj.grid_pos

func _handle_release() -> void:
	if dragged_object != null:
		dragged_object = null
		drag_ended.emit()

func _handle_drag(
	screen_pos: Vector2,
	current_stage: LaserStageData,
	grid_origin: Vector2,
	cell_size: Vector2
) -> void:
	if current_stage == null or dragged_object == null:
		return

	var target_cell := BoardLayoutManager.world_to_grid(screen_pos, grid_origin, cell_size)
	if not current_stage.is_inside_grid(target_cell):
		return

	var existing_obj = current_stage.get_object_at(target_cell)
	if existing_obj == null or existing_obj == dragged_object:
		if ObjectSpawner.has_movable_areas(current_stage):
			if ObjectSpawner.is_cell_in_movable_area(current_stage, target_cell):
				dragged_object.grid_pos = target_cell
				object_dragged.emit(dragged_object)
		else:
			dragged_object.grid_pos = target_cell
			object_dragged.emit(dragged_object)
