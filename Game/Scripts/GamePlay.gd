extends Node2D
class_name GamePlay

const BoardLayoutManager = preload("res://Game/Scripts/board_layout_manager.gd")
const StageTransitioner = preload("res://Game/Scripts/stage_transitioner.gd")
const GameInputController = preload("res://Game/Scripts/game_input_controller.gd")
const ObjectSpawner = preload("res://Game/Scripts/object_spawner.gd")
const GridRenderer = preload("res://Game/Scripts/grid_renderer.gd")
const BeamRenderer = preload("res://Game/Scripts/beam_renderer.gd")
const ProceduralLaserObject = preload("res://Game/Scripts/procedural_object.gd")
const HintDialogClass = preload("res://Game/Scripts/hint_dialog.gd")

@export_group("Level Selection")
@export var level_number: int = 1
@export var current_stage_idx: int = 1

@export_group("Grid Display Settings")
@export var cell_size: Vector2 = Vector2(64, 64)
@export var grid_origin: Vector2 = Vector2(100, 100)

@export_group("Object Scenes (.tscn Prefabs)")
@export var laser_scene: PackedScene
@export var fixed_mirror_scene: PackedScene
@export var movable_mirror_scene: PackedScene
@export var rotatable_mirror_scene: PackedScene
@export var movable_area_scene: PackedScene
@export var rock_scene: PackedScene
@export var ice_scene: PackedScene
@export var splitter_scene: PackedScene
@export var color_glass_scene: PackedScene
@export var color_wall_scene: PackedScene
@export var entry_gate_scene: PackedScene
@export var exit_gate_scene: PackedScene
@export var switch_scene: PackedScene
@export var gate_switch_scene: PackedScene
@export var custom_named_scenes: Dictionary[String, PackedScene] = {}

@export_group("Playtest Mode Visuals")
@export var use_editor_visuals_in_playtest: bool = true

@onready var background: Sprite2D = $Background
@onready var board = get_node_or_null("Board")
@onready var grid_renderer: GridRenderer = $GridLayer
@onready var beam_renderer: BeamRenderer = $BeamLayer
@onready var objects_container: Node2D = $LevelObjects

var current_stage: LaserStageData = null
var level_data: LaserLevelData = null
var simulation_res: Dictionary = {}
var spawned_nodes: Dictionary = {}
var stage_cleared: bool = false
var is_playtest_mode: bool = false

var _transitioner: StageTransitioner = StageTransitioner.new()
var _spawner: ObjectSpawner = ObjectSpawner.new()
var _input_controller: GameInputController = GameInputController.new()
var _clear_flash: ColorRect = null
var hint_dialog: CanvasLayer = null
var ui_layer: CanvasLayer = null
var hint_button: Button = null

func _init() -> void:
	_setup_hint_ui()

func _ready() -> void:
	_init_components()

	get_tree().root.size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()

	if _check_playtest_session():
		return

	if load_level_by_number(level_number, current_stage_idx):
		return

	var all_ids := LevelMigration.get_all_level_ids()
	if not all_ids.is_empty():
		push_warning("GamePlay: Level_%03d not found, loading Level_%03d instead." % [level_number, all_ids[0]])
		load_level_by_number(all_ids[0], 1)
	else:
		push_error("GamePlay: No level files found in res://Game/Data/LaserMindLevels/!")

func _init_components() -> void:
	_setup_clear_flash()
	_setup_hint_ui()

	var prefab_map: Dictionary = {
		LaserObjectData.ObjectType.LASER_SOURCE: laser_scene,
		LaserObjectData.ObjectType.FIXED_MIRROR: fixed_mirror_scene if fixed_mirror_scene != null else movable_mirror_scene,
		LaserObjectData.ObjectType.MOVABLE_MIRROR: movable_mirror_scene if movable_mirror_scene != null else fixed_mirror_scene,
		LaserObjectData.ObjectType.ROTATABLE_MIRROR: rotatable_mirror_scene if rotatable_mirror_scene != null else fixed_mirror_scene,
		LaserObjectData.ObjectType.MOVABLE_AREA: movable_area_scene,
		LaserObjectData.ObjectType.GOAL: load("res://Game/Objects/Scenes/Goal.tscn") if ResourceLoader.exists("res://Game/Objects/Scenes/Goal.tscn") else null,
		LaserObjectData.ObjectType.ROCK: rock_scene,
		LaserObjectData.ObjectType.ICE: ice_scene,
		LaserObjectData.ObjectType.SPLITTER: splitter_scene,
		LaserObjectData.ObjectType.COLOR_GLASS: color_glass_scene,
		LaserObjectData.ObjectType.COLOR_WALL: color_wall_scene,
		LaserObjectData.ObjectType.GATE: entry_gate_scene if entry_gate_scene != null else (load("res://Game/Objects/Scenes/EntryGate.tscn") if ResourceLoader.exists("res://Game/Objects/Scenes/EntryGate.tscn") else null),
		LaserObjectData.ObjectType.EXIT_GATE: exit_gate_scene if exit_gate_scene != null else (load("res://Game/Objects/Scenes/ExitGate.tscn") if ResourceLoader.exists("res://Game/Objects/Scenes/ExitGate.tscn") else null),
		LaserObjectData.ObjectType.SWITCH: switch_scene,
		LaserObjectData.ObjectType.GATE_SWITCH: gate_switch_scene if gate_switch_scene != null else entry_gate_scene,
	}
	_spawner.set_prefabs(prefab_map)
	_spawner.custom_named_scenes = custom_named_scenes
	_spawner.sync_custom_scenes_registry()

	if beam_renderer != null:
		beam_renderer.z_index = 2
		beam_renderer.z_as_relative = false
		if not beam_renderer.animation_completed.is_connected(_on_beam_animation_completed):
			beam_renderer.animation_completed.connect(_on_beam_animation_completed)

	_input_controller.request_quit_game.connect(func(): get_tree().quit())
	_input_controller.request_restart_stage.connect(func(): load_stage(current_stage_idx, true))
	_input_controller.request_load_stage.connect(func(st_num: int): load_stage(st_num, true))
	_input_controller.request_toggle_visuals.connect(_toggle_playtest_visuals)
	_input_controller.request_next_stage.connect(_on_next_stage_requested)
	_input_controller.object_rotated.connect(_on_object_modified)
	_input_controller.object_dragged.connect(_on_object_modified)
	_input_controller.drag_ended.connect(func(): recalculate_simulation(true, true))

func _setup_hint_ui() -> void:
	if hint_dialog == null:
		hint_dialog = HintDialogClass.new()
		add_child(hint_dialog)

	if ui_layer == null:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UILayer"
		ui_layer.layer = 5
		add_child(ui_layer)

	if hint_button == null:
		hint_button = Button.new()
		hint_button.name = "HintButton"
		hint_button.text = "💡 HINT"
		hint_button.custom_minimum_size = Vector2(170, 48)
		hint_button.focus_mode = Control.FOCUS_NONE
		hint_button.mouse_filter = Control.MOUSE_FILTER_STOP

		var btn_norm := StyleBoxFlat.new()
		btn_norm.bg_color = Color(0.16, 0.20, 0.28, 0.92)
		btn_norm.border_color = Color(0.38, 0.70, 1.0, 0.85)
		btn_norm.set_border_width_all(2)
		btn_norm.set_corner_radius_all(24)
		hint_button.add_theme_stylebox_override("normal", btn_norm)

		var btn_hov := StyleBoxFlat.new()
		btn_hov.bg_color = Color(0.22, 0.28, 0.40, 0.95)
		btn_hov.border_color = Color(0.55, 0.85, 1.0, 1.0)
		btn_hov.set_border_width_all(2)
		btn_hov.set_corner_radius_all(24)
		hint_button.add_theme_stylebox_override("hover", btn_hov)

		var btn_press := StyleBoxFlat.new()
		btn_press.bg_color = Color(0.12, 0.15, 0.22, 1.0)
		btn_press.border_color = Color(0.30, 0.55, 0.85, 0.9)
		btn_press.set_border_width_all(2)
		btn_press.set_corner_radius_all(24)
		hint_button.add_theme_stylebox_override("pressed", btn_press)

		var btn_dis := StyleBoxFlat.new()
		btn_dis.bg_color = Color(0.14, 0.16, 0.20, 0.4)
		btn_dis.border_color = Color(0.30, 0.35, 0.42, 0.3)
		btn_dis.set_border_width_all(1)
		btn_dis.set_corner_radius_all(24)
		hint_button.add_theme_stylebox_override("disabled", btn_dis)

		hint_button.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
		hint_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		hint_button.add_theme_color_override("font_disabled_color", Color(0.5, 0.55, 0.62, 0.6))
		hint_button.add_theme_font_size_override("font_size", 16)
		hint_button.pressed.connect(_on_hint_button_pressed)
		ui_layer.add_child(hint_button)

func _on_hint_button_pressed() -> void:
	if current_stage != null and hint_dialog != null:
		hint_dialog.open_hint(current_stage)

func _update_hint_button() -> void:
	if hint_button == null:
		_setup_hint_ui()
	if hint_button == null:
		return

	var has_hint := current_stage != null and current_stage.hint_enabled and not current_stage.hint_path_points.is_empty()
	hint_button.disabled = not has_hint
	hint_button.modulate = Color(1.0, 1.0, 1.0, 1.0) if has_hint else Color(0.65, 0.65, 0.65, 0.6)
	hint_button.tooltip_text = "View Laser Hint Path" if has_hint else "No hint available for this stage"

	if current_stage == null:
		return

	var vp_size: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1080, 1920)
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2(1080, 1920)
	var rect := BoardLayoutManager.compute_board_rect(grid_origin, cell_size, current_stage.grid_width, current_stage.grid_height)
	var board_bottom: float = rect.position.y + rect.size.y
	var btn_w: float = 170.0
	var btn_h: float = 48.0

	var bx: float = (vp_size.x - btn_w) * 0.5
	var by: float = board_bottom + 18.0
	by = clampf(by, board_bottom + 8.0, maxf(board_bottom + 8.0, vp_size.y - btn_h - 20.0))

	hint_button.position = Vector2(bx, by)

func _on_viewport_resized() -> void:
	var vp_sz: Vector2 = get_viewport_rect().size
	BoardLayoutManager.scale_background_to_viewport(background, vp_sz)

	if current_stage != null:
		_auto_center_grid(current_stage)
		_reposition_spawned_objects()
		_update_renderers()
	_update_hint_button()
	if hint_dialog != null and hint_dialog.is_open():
		hint_dialog._recalculate_layout()
		hint_dialog.card.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if hint_dialog != null and hint_dialog.is_open():
		return
	_input_controller.handle_input(
		event,
		current_stage,
		grid_origin,
		cell_size,
		is_playtest_mode,
		_transitioner.is_active(),
		stage_cleared
	)

func _check_playtest_session() -> bool:
	var session_path := "user://laser_mind_playtest.json"
	if not FileAccess.file_exists(session_path):
		return false

	var file := FileAccess.open(session_path, FileAccess.READ)
	if file == null:
		return false

	var text := file.get_as_text()
	file.close()
	DirAccess.remove_absolute(session_path)

	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return false

	var dict: Dictionary = json.data
	if not dict.get("playtest_active", false):
		return false

	is_playtest_mode = true
	var p_level_id: int = int(dict.get("level_id", 1))
	var p_stage_idx: int = int(dict.get("stage_idx", 1))
	load_level_by_number(p_level_id, p_stage_idx)
	return true

func load_level_by_number(p_level_num: int, p_stage_num: int = 1) -> bool:
	level_number = max(1, p_level_num)
	var loaded: LaserLevelData = LevelMigration.load_laser_level(level_number)
	if loaded != null:
		level_data = loaded
		load_stage(p_stage_num)
		return true
	else:
		push_error("GamePlay: Failed to load valid LaserLevelData for Level %d" % level_number)
		return false

enum TraversalState {
	NORMAL,
	EXIT_REACHED,
	TRANSITIONING,
	ENTERING_STAGE,
	COMPLETED
}

var traversal_state: TraversalState = TraversalState.NORMAL
var carried_laser_color: Color = Color(-1, -1, -1, -1)
var carried_laser_pos: Vector2i = Vector2i(-999, -999)
var carried_laser_dir: Vector2i = Vector2i.ZERO

func load_stage(stage_num: int, animate_laser: bool = true) -> void:
	if level_data == null:
		push_error("GamePlay: No LaserLevelData assigned!")
		return

	var max_stages: int = level_data.get_stage_count() if level_data != null else 1
	current_stage_idx = clamp(stage_num, 1, max_stages)
	current_stage = level_data.get_stage(current_stage_idx)
	if current_stage == null:
		push_error("GamePlay: Stage %d not found in level!" % current_stage_idx)
		return

	if current_stage_idx == 1:
		carried_laser_color = Color(-1, -1, -1, -1)
		carried_laser_pos = Vector2i(-999, -999)
		carried_laser_dir = Vector2i.ZERO

	stage_cleared = false
	clear_current_stage()
	_auto_center_grid(current_stage)

	print("--- Loaded Level %d | Stage %d (Grid: %dx%d) ---" % [
		level_data.level_id, current_stage_idx, current_stage.grid_width, current_stage.grid_height
	])

	# Spawn active puzzle objects on foreground layer (z = 1)
	# Editor/design-time objects (Movable Area, Laser Source, Goal, Entry/Exit Gates) are invisible in actual game
	for obj in current_stage.objects:
		if obj != null and obj.enabled and obj.type not in [
			LaserObjectData.ObjectType.MOVABLE_AREA,
			LaserObjectData.ObjectType.GATE,
			LaserObjectData.ObjectType.EXIT_GATE,
			LaserObjectData.ObjectType.LASER_SOURCE,
			LaserObjectData.ObjectType.GOAL
		]:
			_spawn_and_register(obj, 1)

	recalculate_simulation(animate_laser)
	_redraw_grid()
	_update_hint_button()

func _spawn_and_register(obj: LaserObjectData, z_idx: int) -> void:
	var node := _spawn_object(obj)
	if node is CanvasItem:
		(node as CanvasItem).z_index = z_idx

func _spawn_object(obj_data: LaserObjectData) -> Node:
	var use_proc := (is_playtest_mode and use_editor_visuals_in_playtest)
	var use_p := (use_proc and obj_data.type != LaserObjectData.ObjectType.CUSTOM)
	_spawner.custom_named_scenes = custom_named_scenes
	var instance := _spawner.spawn_object(obj_data, grid_origin, cell_size, use_p, grid_to_world)
	if objects_container != null:
		objects_container.add_child(instance)
	else:
		add_child(instance)
	spawned_nodes[obj_data.id] = instance
	return instance

func _get_scene_for_object(obj_data: LaserObjectData) -> PackedScene:
	_spawner.custom_named_scenes = custom_named_scenes
	return _spawner.get_scene_for_object(obj_data)

func recalculate_simulation(animate_shoot: bool = true, preserve_progress: bool = false) -> void:
	if current_stage == null:
		return

	if current_stage_idx == 1:
		simulation_res = LaserSimulation.simulate_stage(current_stage, true)
	else:
		simulation_res = LaserSimulation.simulate_stage(current_stage, true, carried_laser_color, carried_laser_pos, carried_laser_dir)

	var all_cleared = simulation_res.get("all_goals_satisfied", false)

	if not animate_shoot or not is_inside_tree() or beam_renderer == null:
		if all_cleared and not stage_cleared:
			_check_and_trigger_stage_clear()
	else:
		if not all_cleared:
			stage_cleared = false

	_redraw_beams(animate_shoot, preserve_progress)

	for id in spawned_nodes:
		var node = spawned_nodes[id]
		if is_instance_valid(node) and node.has_method("on_simulation_updated"):
			node.on_simulation_updated(simulation_res)

func _on_beam_animation_completed() -> void:
	if simulation_res.get("all_goals_satisfied", false) and not stage_cleared:
		_check_and_trigger_stage_clear()

func _check_and_trigger_stage_clear() -> void:
	stage_cleared = true
	traversal_state = TraversalState.EXIT_REACHED
	if simulation_res.has("exit_laser_color") and simulation_res["exit_laser_color"].a >= 0.0:
		carried_laser_color = simulation_res.get("exit_laser_color", Color(1.0, 0.2, 0.2, 1.0))
		var exit_dir: Vector2i = simulation_res.get("exit_laser_dir", Vector2i.ZERO)
		carried_laser_dir = exit_dir
		if level_data != null and current_stage_idx < level_data.get_stage_count():
			var next_st: LaserStageData = level_data.get_stage(current_stage_idx + 1)
			if next_st != null:
				var eg_obj: LaserObjectData = null
				for obj in next_st.objects:
					if obj != null and obj.enabled and obj.type == LaserObjectData.ObjectType.GATE:
						eg_obj = obj
						break
				if eg_obj != null:
					carried_laser_pos = eg_obj.grid_pos
					var e_dir = eg_obj.get_direction_vector()
					carried_laser_dir = e_dir if e_dir != Vector2i.ZERO else (exit_dir if exit_dir != Vector2i.ZERO else LaserSimulation._infer_inward_direction(eg_obj.grid_pos, next_st.grid_width, next_st.grid_height))
				elif next_st.entry_point != Vector2i(-1, -1):
					carried_laser_pos = next_st.entry_point
	_on_stage_cleared()

func _on_stage_cleared() -> void:
	var max_stages: int = level_data.get_stage_count() if level_data != null else 1
	if current_stage_idx < max_stages:
		print("🎉 STAGE %d REACHED EXIT! Laser advancing to Stage %d..." % [current_stage_idx, current_stage_idx + 1])
		_play_clear_flash()
		var tw = create_tween()
		tw.tween_interval(0.4)
		tw.tween_callback(func():
			if stage_cleared and not _transitioner.is_active():
				next_stage()
		)
	else:
		traversal_state = TraversalState.COMPLETED
		print("🏆 FINAL TARGET REACHED! Level %d Complete!" % (level_data.level_id if level_data != null else level_number))
		_play_clear_flash()
		var tw = create_tween()
		tw.tween_interval(0.8)
		tw.tween_callback(func():
			next_level()
		)

func _setup_clear_flash() -> void:
	if _clear_flash != null:
		return
	_clear_flash = ColorRect.new()
	_clear_flash.color = Color(0.3, 1.0, 0.4, 0.0)
	_clear_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clear_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_flash.z_index = 100
	add_child(_clear_flash)

func _play_clear_flash() -> void:
	if _clear_flash == null or not is_inside_tree():
		return
	_clear_flash.color = Color(0.3, 1.0, 0.4, 0.0)
	var tw = create_tween()
	tw.tween_property(_clear_flash, "color", Color(0.3, 1.0, 0.4, 0.55), 0.15)
	tw.tween_property(_clear_flash, "color", Color(0.3, 1.0, 0.4, 0.0), 0.5)

func _on_next_stage_requested() -> void:
	if stage_cleared:
		next_stage()

func next_stage() -> void:
	var max_stages: int = level_data.get_stage_count() if level_data != null else 1
	if current_stage_idx < max_stages:
		_transition_to_stage(current_stage_idx + 1)
	else:
		next_level()

func _transition_to_stage(target_stage_idx: int) -> void:
	if _transitioner.is_active() or level_data == null or not is_inside_tree():
		return

	var next_st: LaserStageData = level_data.get_stage(target_stage_idx)
	if next_st == null:
		return

	traversal_state = TraversalState.TRANSITIONING

	var target_origin: Vector2
	if BoardLayoutManager.stage_has_custom_position(next_st):
		target_origin = next_st.stage_screen_position
	else:
		var layout = BoardLayoutManager.compute_auto_center(next_st, get_viewport_rect().size, is_playtest_mode)
		target_origin = layout["grid_origin"]

	var vp_size := get_viewport_rect().size
	var slide_dir := next_st.stage_transition_direction

	if beam_renderer != null:
		beam_renderer.clear_beams()

	_transitioner.transition(
		self,
		slide_dir,
		grid_origin,
		target_origin,
		vp_size,
		func(new_origin: Vector2):
			grid_origin = new_origin
			_apply_board_layout()
			_reposition_spawned_objects()
			_redraw_grid(),
		func():
			# Midway: prepare next stage while offscreen, laser remains hidden at length 0
			load_stage(target_stage_idx, false),
		func():
			# Transition completed: Next stage is in place, laser enters smoothly from Entry Gate
			_apply_board_layout()
			_reposition_spawned_objects()
			_redraw_grid()
			traversal_state = TraversalState.ENTERING_STAGE
			_redraw_beams(true)
	)

func next_level() -> void:
	if not load_level_by_number(level_number + 1, 1):
		print("🏆 All levels cleared! Restarting from Level 1...")
		load_level_by_number(1, 1)

func restart_level() -> void:
	load_stage(1)

func _auto_center_grid(stage: LaserStageData) -> void:
	if not is_inside_tree() or stage == null:
		return

	var layout = BoardLayoutManager.compute_auto_center(stage, get_viewport_rect().size, is_playtest_mode)
	cell_size = layout["cell_size"]

	if BoardLayoutManager.stage_has_custom_position(stage):
		grid_origin = stage.stage_screen_position
	else:
		grid_origin = layout["grid_origin"]

	_apply_board_layout()

func _apply_board_layout() -> void:
	if current_stage == null:
		return
	if board != null:
		var rect := BoardLayoutManager.compute_board_rect(grid_origin, cell_size, current_stage.grid_width, current_stage.grid_height)
		board.position = rect.position
		board.size = rect.size
	_update_hint_button()

func _reposition_spawned_objects() -> void:
	if current_stage == null:
		return
	for obj in current_stage.objects:
		if obj != null and spawned_nodes.has(obj.id):
			_spawner.update_node_transform(spawned_nodes[obj.id], obj, grid_origin, cell_size)

func _on_object_modified(obj: LaserObjectData) -> void:
	if spawned_nodes.has(obj.id):
		_spawner.update_node_transform(spawned_nodes[obj.id], obj, grid_origin, cell_size)
	recalculate_simulation(true, true)

func _toggle_playtest_visuals() -> void:
	if is_playtest_mode:
		use_editor_visuals_in_playtest = not use_editor_visuals_in_playtest
		load_stage(current_stage_idx)

func _update_renderers() -> void:
	_redraw_grid()
	_redraw_beams()

func _redraw_grid() -> void:
	if grid_renderer != null:
		grid_renderer.update_grid(current_stage, grid_origin, cell_size)

func _redraw_beams(animate_shoot: bool = true, preserve_progress: bool = false) -> void:
	if beam_renderer != null:
		beam_renderer.update_beams(simulation_res.get("segments", []), grid_origin, cell_size, animate_shoot, preserve_progress)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return BoardLayoutManager.grid_to_world(grid_pos, grid_origin, cell_size)


func world_to_grid(world_pos: Vector2) -> Vector2i:
	return BoardLayoutManager.world_to_grid(world_pos, grid_origin, cell_size)

func clear_current_stage() -> void:
	for id in spawned_nodes.keys():
		var node = spawned_nodes[id]
		if is_instance_valid(node):
			node.queue_free()
	spawned_nodes.clear()
