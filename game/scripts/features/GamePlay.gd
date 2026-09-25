extends Node2D
class_name GamePlay

const BoardLayoutManager = preload("res://game/scripts/managers/board_layout_manager.gd")
const StageTransitionController = preload("res://game/scripts/controllers/stage_transition_controller.gd")
const GameInputController = preload("res://game/scripts/controllers/game_input_controller.gd")
const ObjectSpawner = preload("res://game/scripts/features/object_spawner.gd")
const GridRenderer = preload("res://game/scripts/features/grid_renderer.gd")
const BeamRenderer = preload("res://game/scripts/features/beam_renderer.gd")
const ProceduralLaserObject = preload("res://game/scripts/features/procedural_object.gd")
const HintDialogClass = preload("res://game/scripts/features/hint_dialog.gd")

@export_group("Level Selection")
@export var level_number: int = 1
@export var current_stage_idx: int = 1

@export_group("Stage Transition Timing")
## How far before Exit Gate (in world pixels) the camera starts moving toward next stage
@export var transition_start_distance: float = 300.0:
	set(val):
		transition_start_distance = val
		if _transition_controller != null:
			_transition_controller.transition_start_distance = val

## Laser traversal speed in world pixels per second
@export var laser_travel_speed: float = 650.0:
	set(val):
		laser_travel_speed = val
		if _transition_controller != null:
			_transition_controller.laser_travel_speed = val
		if beam_renderer != null:
			beam_renderer.laser_travel_speed = val

## Optional camera lead offset (in world pixels)
@export var transition_camera_lead: float = 0.0:
	set(val):
		transition_camera_lead = val
		if _transition_controller != null:
			_transition_controller.transition_camera_lead = val

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
var object_to_stage_idx: Dictionary = {}
var stage_cleared: bool = false
var is_playtest_mode: bool = false

# Continuous World Layout Data
# Each element: {"index": int, "stage": LaserStageData, "origin": Vector2, "cell_size": Vector2, "camera_pos": Vector2}
var stage_world_data: Array[Dictionary] = []

var camera: Camera2D = null
var _cam_tween: Tween = null
var _spawner: ObjectSpawner = ObjectSpawner.new()
var _input_controller: GameInputController = GameInputController.new()
var _transition_controller: StageTransitionController = StageTransitionController.new()
var _clear_flash: ColorRect = null
var hint_dialog: CanvasLayer = null
var ui_layer: CanvasLayer = null
var bg_layer: CanvasLayer = null
var hint_button: Button = null

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
		push_error("GamePlay: No level files found in res://game/data/LaserMindLevels/!")

func _init_components() -> void:
	_setup_camera()
	_setup_background_layer()
	_setup_clear_flash()
	_setup_hint_ui()

	_transition_controller.transition_start_distance = transition_start_distance
	_transition_controller.laser_travel_speed = laser_travel_speed
	_transition_controller.transition_camera_lead = transition_camera_lead

	var prefab_map: Dictionary = {
		LaserObjectData.ObjectType.LASER_SOURCE: laser_scene,
		LaserObjectData.ObjectType.FIXED_MIRROR: fixed_mirror_scene if fixed_mirror_scene != null else movable_mirror_scene,
		LaserObjectData.ObjectType.MOVABLE_MIRROR: movable_mirror_scene if movable_mirror_scene != null else fixed_mirror_scene,
		LaserObjectData.ObjectType.ROTATABLE_MIRROR: rotatable_mirror_scene if rotatable_mirror_scene != null else fixed_mirror_scene,
		LaserObjectData.ObjectType.MOVABLE_AREA: movable_area_scene,
		LaserObjectData.ObjectType.GOAL: load("res://game/scenes/gameplay/Goal.tscn") if ResourceLoader.exists("res://game/scenes/gameplay/Goal.tscn") else null,
		LaserObjectData.ObjectType.ROCK: rock_scene,
		LaserObjectData.ObjectType.ICE: ice_scene,
		LaserObjectData.ObjectType.SPLITTER: splitter_scene,
		LaserObjectData.ObjectType.COLOR_GLASS: color_glass_scene,
		LaserObjectData.ObjectType.COLOR_WALL: color_wall_scene,
		LaserObjectData.ObjectType.GATE: entry_gate_scene if entry_gate_scene != null else (load("res://game/scenes/gameplay/EntryGate.tscn") if ResourceLoader.exists("res://game/scenes/gameplay/EntryGate.tscn") else null),
		LaserObjectData.ObjectType.EXIT_GATE: exit_gate_scene if exit_gate_scene != null else (load("res://game/scenes/gameplay/ExitGate.tscn") if ResourceLoader.exists("res://game/scenes/gameplay/ExitGate.tscn") else null),
		LaserObjectData.ObjectType.SWITCH: switch_scene,
		LaserObjectData.ObjectType.GATE_SWITCH: gate_switch_scene if gate_switch_scene != null else entry_gate_scene,
	}
	_spawner.set_prefabs(prefab_map)
	_spawner.custom_named_scenes = custom_named_scenes
	_spawner.sync_custom_scenes_registry()

	if grid_renderer == null:
		grid_renderer = get_node_or_null("GridLayer") as GridRenderer
	if grid_renderer == null:
		grid_renderer = GridRenderer.new()
		grid_renderer.name = "GridLayer"
		add_child(grid_renderer)

	if beam_renderer == null:
		beam_renderer = get_node_or_null("BeamLayer") as BeamRenderer
	if beam_renderer == null:
		beam_renderer = BeamRenderer.new()
		beam_renderer.name = "BeamLayer"
		add_child(beam_renderer)

	if beam_renderer != null:
		beam_renderer.laser_travel_speed = laser_travel_speed
		beam_renderer.z_index = 2
		beam_renderer.z_as_relative = false
		if not beam_renderer.animation_completed.is_connected(_on_beam_animation_completed):
			beam_renderer.animation_completed.connect(_on_beam_animation_completed)

	_input_controller.request_quit_game.connect(func(): get_tree().quit())
	_input_controller.request_restart_stage.connect(func(): load_stage(current_stage_idx, true))
	_input_controller.request_load_stage.connect(func(st_num: int): load_stage(st_num, true))
	_input_controller.request_toggle_visuals.connect(_toggle_playtest_visuals)
	_input_controller.object_rotated.connect(_on_object_modified)
	_input_controller.object_dragged.connect(_on_object_modified)
	_input_controller.drag_ended.connect(func(): recalculate_simulation(true, true))

func _setup_camera() -> void:
	if camera == null:
		camera = get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
		add_child(camera)
	else:
		camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT

func _setup_background_layer() -> void:
	if bg_layer == null:
		bg_layer = CanvasLayer.new()
		bg_layer.name = "BackgroundLayer"
		bg_layer.layer = -10
		add_child(bg_layer)
	if background != null and background.get_parent() != bg_layer:
		background.get_parent().remove_child(background)
		bg_layer.add_child(background)

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

	var st_idx := current_stage_idx - 1
	var st_origin := grid_origin
	var st_cell_sz := cell_size
	if st_idx >= 0 and st_idx < stage_world_data.size():
		st_cell_sz = stage_world_data[st_idx].get("cell_size", cell_size)

	# In fixed screen UI, compute screen board position
	var auto_layout := BoardLayoutManager.compute_auto_center(current_stage, vp_size, is_playtest_mode)
	var screen_origin: Vector2 = auto_layout["grid_origin"]
	var rect := BoardLayoutManager.compute_board_rect(screen_origin, st_cell_sz, current_stage.grid_width, current_stage.grid_height)
	var board_bottom: float = rect.position.y + rect.size.y
	var btn_w: float = 170.0
	var btn_h: float = 48.0

	var bx: float = (vp_size.x - btn_w) * 0.5
	var by: float = board_bottom + 18.0
	by = clampf(by, board_bottom + 8.0, maxf(board_bottom + 8.0, vp_size.y - btn_h - 20.0))

	hint_button.position = Vector2(bx, by)

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

func _on_viewport_resized() -> void:
	var vp_sz: Vector2 = get_viewport_rect().size
	if background != null:
		BoardLayoutManager.scale_background_to_viewport(background, vp_sz)

	if level_data != null:
		_build_stage_world()
		_reposition_spawned_objects()
		_update_renderers()
		if camera != null and current_stage_idx - 1 >= 0 and current_stage_idx - 1 < stage_world_data.size():
			camera.position = stage_world_data[current_stage_idx - 1]["camera_pos"]
	_update_hint_button()
	if hint_dialog != null and hint_dialog.is_open():
		hint_dialog._recalculate_layout()
		hint_dialog.card.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if hint_dialog != null and hint_dialog.is_open():
		return

	# Convert screen touch/mouse position to camera world space position
	var world_event: InputEvent = event
	var cam_offset := camera.position if camera != null and is_inside_tree() else Vector2.ZERO

	if event is InputEventMouseButton:
		var mb := event.duplicate() as InputEventMouseButton
		mb.position = event.position + cam_offset
		world_event = mb
	elif event is InputEventMouseMotion:
		var mm := event.duplicate() as InputEventMouseMotion
		mm.position = event.position + cam_offset
		world_event = mm
	elif event is InputEventScreenTouch:
		var st := event.duplicate() as InputEventScreenTouch
		st.position = event.position + cam_offset
		world_event = st
	elif event is InputEventScreenDrag:
		var sd := event.duplicate() as InputEventScreenDrag
		sd.position = event.position + cam_offset
		world_event = sd

	var is_cam_moving := (_cam_tween != null and _cam_tween.is_valid() and _cam_tween.is_running())
	_input_controller.handle_input(
		world_event,
		current_stage,
		grid_origin,
		cell_size,
		is_playtest_mode,
		is_cam_moving,
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

# --- CONTINUOUS MULTI-STAGE WORLD GENERATION ---

func load_level_by_number(p_level_num: int, p_stage_num: int = 1) -> bool:
	level_number = max(1, p_level_num)
	var loaded: LaserLevelData = LevelMigration.load_laser_level(level_number)
	if loaded != null:
		level_data = loaded
		_build_stage_world()
		_spawn_all_world_objects()
		load_stage(p_stage_num)
		return true
	else:
		push_error("GamePlay: Failed to load valid LaserLevelData for Level %d" % level_number)
		return false

func _build_stage_world() -> void:
	if level_data == null:
		return

	stage_world_data.clear()
	var vp_size: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1080, 1920)
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2(1080, 1920)

	var stages := level_data.stages
	if stages.is_empty():
		return

	# 1. Compute Base Origin for Stage 1 (Centered in default screen)
	var st0 := stages[0]
	var origin_0: Vector2
	var cell_sz_0: Vector2
	if BoardLayoutManager.stage_has_custom_position(st0):
		origin_0 = st0.stage_screen_position
		var auto_0 := BoardLayoutManager.compute_auto_center(st0, vp_size, is_playtest_mode)
		cell_sz_0 = auto_0["cell_size"]
	else:
		var auto_0 := BoardLayoutManager.compute_auto_center(st0, vp_size, is_playtest_mode)
		origin_0 = auto_0["grid_origin"]
		cell_sz_0 = auto_0["cell_size"]

	stage_world_data.append({
		"index": 1,
		"stage": st0,
		"origin": origin_0,
		"cell_size": cell_sz_0,
		"camera_pos": Vector2.ZERO
	})

	# 2. Position all subsequent stages relative to previous stages in continuous world
	for i in range(1, stages.size()):
		var st := stages[i]
		if st == null:
			continue
		var st_idx := i + 1
		var origin_i: Vector2
		var cell_sz_i: Vector2

		var auto_i := BoardLayoutManager.compute_auto_center(st, vp_size, is_playtest_mode)
		cell_sz_i = auto_i["cell_size"]

		if BoardLayoutManager.stage_has_custom_position(st):
			origin_i = st.stage_screen_position
		else:
			var prev_data := stage_world_data[i - 1]
			var prev_origin: Vector2 = prev_data["origin"]
			var prev_st: LaserStageData = prev_data["stage"]
			var prev_cell_sz: Vector2 = prev_data["cell_size"]

			var step_x := maxf(vp_size.x, float(prev_st.grid_width) * prev_cell_sz.x + 300.0)
			var step_y := maxf(vp_size.y, float(prev_st.grid_height) * prev_cell_sz.y + 300.0)

			match st.stage_transition_direction:
				LaserStageData.TransitionDir.RIGHT:
					origin_i = prev_origin + Vector2(step_x, 0.0)
				LaserStageData.TransitionDir.LEFT:
					origin_i = prev_origin + Vector2(-step_x, 0.0)
				LaserStageData.TransitionDir.DOWN:
					origin_i = prev_origin + Vector2(0.0, step_y)
				LaserStageData.TransitionDir.UP:
					origin_i = prev_origin + Vector2(0.0, -step_y)
				_:
					origin_i = prev_origin + Vector2(step_x, 0.0)

		var cam_pos_i := origin_i - origin_0
		stage_world_data.append({
			"index": st_idx,
			"stage": st,
			"origin": origin_i,
			"cell_size": cell_sz_i,
			"camera_pos": cam_pos_i
		})

func _spawn_all_world_objects() -> void:
	clear_current_stage()
	object_to_stage_idx.clear()

	_spawner.custom_named_scenes = custom_named_scenes
	var use_proc := (is_playtest_mode and use_editor_visuals_in_playtest)

	for item in stage_world_data:
		var st_idx: int = item["index"]
		var st: LaserStageData = item["stage"]
		var st_origin: Vector2 = item["origin"]
		var st_cell_sz: Vector2 = item["cell_size"]

		for obj in st.objects:
			if obj != null and obj.enabled and obj.type not in [
				LaserObjectData.ObjectType.MOVABLE_AREA,
				LaserObjectData.ObjectType.GATE,
				LaserObjectData.ObjectType.EXIT_GATE,
				LaserObjectData.ObjectType.LASER_SOURCE,
				LaserObjectData.ObjectType.GOAL
			]:
				var use_p := (use_proc and obj.type != LaserObjectData.ObjectType.CUSTOM)
				var grid_to_world_fn := func(gpos: Vector2i) -> Vector2:
					return BoardLayoutManager.grid_to_world(gpos, st_origin, st_cell_sz)
				var instance := _spawner.spawn_object(obj, st_origin, st_cell_sz, use_p, grid_to_world_fn)
				if instance is CanvasItem:
					(instance as CanvasItem).z_index = 1
				if objects_container != null:
					objects_container.add_child(instance)
				else:
					add_child(instance)
				spawned_nodes[obj.id] = instance
				object_to_stage_idx[obj.id] = st_idx

func _get_scene_for_object(obj_data: LaserObjectData) -> PackedScene:
	_spawner.custom_named_scenes = custom_named_scenes
	return _spawner.get_scene_for_object(obj_data)

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

func load_stage(stage_num: int, animate_laser: bool = true) -> void:
	if level_data == null:
		push_error("GamePlay: No LaserLevelData assigned!")
		return

	if stage_world_data.is_empty():
		_build_stage_world()
		_spawn_all_world_objects()

	var max_stages: int = level_data.get_stage_count() if level_data != null else 1
	current_stage_idx = clampi(stage_num, 1, max_stages)
	current_stage = level_data.get_stage(current_stage_idx)
	if current_stage == null:
		push_error("GamePlay: Stage %d not found in level!" % current_stage_idx)
		return

	var st_data: Dictionary = {}
	if current_stage_idx - 1 >= 0 and current_stage_idx - 1 < stage_world_data.size():
		st_data = stage_world_data[current_stage_idx - 1]
		grid_origin = st_data["origin"]
		cell_size = st_data["cell_size"]
		if camera != null and is_inside_tree():
			camera.position = st_data["camera_pos"]

	if current_stage_idx == 1:
		carried_laser_color = Color(-1, -1, -1, -1)
		carried_laser_pos = Vector2i(-999, -999)
		carried_laser_dir = Vector2i.ZERO
	else:
		# Infer carried position from entry gate of this stage
		var eg_obj: LaserObjectData = null
		for obj in current_stage.objects:
			if obj != null and obj.enabled and obj.type == LaserObjectData.ObjectType.GATE:
				eg_obj = obj
				break
		if eg_obj != null:
			carried_laser_pos = eg_obj.grid_pos
			var e_dir = eg_obj.get_direction_vector()
			carried_laser_dir = e_dir if e_dir != Vector2i.ZERO else LaserSimulation._infer_inward_direction(eg_obj.grid_pos, current_stage.grid_width, current_stage.grid_height)
		elif current_stage.entry_point != Vector2i(-1, -1):
			carried_laser_pos = current_stage.entry_point

	stage_cleared = false
	traversal_state = TraversalState.NORMAL

	print("--- Loaded Level %d | Stage %d (Grid: %dx%d) [Continuous World] ---" % [
		level_data.level_id, current_stage_idx, current_stage.grid_width, current_stage.grid_height
	])

	_apply_board_layout()
	_update_renderers()
	recalculate_simulation(animate_laser)
	_update_hint_button()

# --- CONTINUOUS MULTI-STAGE SIMULATION & BEAM GENERATION ---

var stage_transition_intervals: Array[Dictionary] = []
var triggered_exit_stages: Dictionary = {}
var is_final_goal_reached: bool = false

func _process(_delta: float) -> void:
	if beam_renderer == null:
		return

	var d: float = beam_renderer.traversed_distance

	# 1. Update Camera Position Synchronized with Laser Traversal using StageTransitionController
	if camera != null and not stage_world_data.is_empty():
		var default_cam: Vector2 = stage_world_data[0]["camera_pos"]
		var st_state: Dictionary = _transition_controller.compute_state(d, default_cam)

		var target_cam: Vector2 = st_state["camera_pos"]
		var active_st_idx: int = st_state["active_stage_idx"]

		if st_state["is_transitioning"]:
			traversal_state = TraversalState.TRANSITIONING
		else:
			traversal_state = TraversalState.NORMAL

		if _cam_tween == null or not _cam_tween.is_valid():
			camera.position = target_cam

		# 2. Asynchronous Stage Exit Feedback (Non-blocking green glow/flash)
		for trans in stage_transition_intervals:
			var from_st: int = trans["from_stage"]
			if d >= trans["exit_dist"] and not triggered_exit_stages.has(from_st):
				triggered_exit_stages[from_st] = true
				_play_stage_exit_flash(from_st, trans["exit_world_pos"])

		# 3. Synchronize Current Stage Metadata when laser enters next stage
		if current_stage_idx != active_st_idx:
			current_stage_idx = active_st_idx
			if active_st_idx - 1 >= 0 and active_st_idx - 1 < stage_world_data.size():
				var item := stage_world_data[active_st_idx - 1]
				current_stage = item["stage"]
				grid_origin = item["origin"]
				cell_size = item["cell_size"]
				_update_hint_button()
				_apply_board_layout()
				print("🎉 Laser entered Stage %d in Continuous World!" % active_st_idx)

func recalculate_simulation(animate_shoot: bool = true, preserve_progress: bool = false) -> void:
	if level_data == null or stage_world_data.is_empty():
		if current_stage != null:
			simulation_res = LaserSimulation.simulate_stage(current_stage, true)
			_redraw_beams(animate_shoot, preserve_progress)
		return

	stage_transition_intervals.clear()
	_transition_controller.clear()
	if not preserve_progress:
		triggered_exit_stages.clear()
	is_final_goal_reached = false

	var all_world_segments: Array[Dictionary] = []
	var c_color: Color = Color(-1, -1, -1, -1)
	var c_pos: Vector2i = Vector2i(-999, -999)
	var c_dir: Vector2i = Vector2i.ZERO
	var cumulative_world_dist: float = 0.0

	var total_stages: int = stage_world_data.size()
	var any_exit_hit: bool = false

	for k in range(total_stages):
		var item := stage_world_data[k]
		var st_num: int = item["index"]
		var st: LaserStageData = item["stage"]
		var st_origin: Vector2 = item["origin"]
		var st_cell_sz: Vector2 = item["cell_size"]
		var st_cam_pos: Vector2 = item["camera_pos"]

		var sim: Dictionary
		if k == 0:
			sim = LaserSimulation.simulate_stage(st, true)
		else:
			if c_pos == Vector2i(-999, -999) and st.entry_point == Vector2i(-1, -1):
				# Previous stage didn't send laser to this stage
				break
			sim = LaserSimulation.simulate_stage(st, true, c_color, c_pos, c_dir)

		if st_num == current_stage_idx:
			simulation_res = sim

		var segs: Array = sim.get("segments", [])
		var stage_max_rel_dist: float = 0.0

		# Convert stage grid segments to world coordinate segments with precise cumulative distances
		for seg in segs:
			var p1 := BoardLayoutManager.grid_to_world(seg.get("start", Vector2i.ZERO), st_origin, st_cell_sz)
			var p2 := BoardLayoutManager.grid_to_world(seg.get("end", Vector2i.ZERO), st_origin, st_cell_sz)
			var s_rel: float = float(seg.get("start_dist", 0.0)) * st_cell_sz.x
			var e_rel: float = float(seg.get("end_dist", 0.0)) * st_cell_sz.x
			var w_s_dist: float = cumulative_world_dist + s_rel
			var w_e_dist: float = cumulative_world_dist + e_rel
			stage_max_rel_dist = maxf(stage_max_rel_dist, e_rel)

			all_world_segments.append({
				"p1": p1,
				"p2": p2,
				"start": seg.get("start", Vector2i.ZERO),
				"end": seg.get("end", Vector2i.ZERO),
				"world_start_dist": w_s_dist,
				"world_end_dist": w_e_dist,
				"color": seg.get("color", Color.RED),
				"hit_type": seg.get("hit_type", ""),
				"hit_pos": seg.get("hit_pos", Vector2i.ZERO),
				"stage_idx": st_num
			})

		# Check if stage reached Exit Gate
		var exit_hit: bool = sim.get("is_exit_satisfied", false)
		var hit_col: Color = sim.get("exit_laser_color", Color(1.0, 0.2, 0.2, 1.0))
		var exit_d: Vector2i = sim.get("exit_laser_dir", Vector2i.ZERO)
		var exit_rel_dist: float = stage_max_rel_dist

		for s in segs:
			if s.get("hit_type", "") == "exit_gate":
				exit_hit = true
				hit_col = s.get("color", hit_col)
				exit_d = s.get("dir", Vector2i.ZERO)
				exit_rel_dist = float(s.get("end_dist", stage_max_rel_dist)) * st_cell_sz.x
				break

		# Check if goal was satisfied on final stage or terminal stage
		if k == total_stages - 1 or k + 1 >= total_stages:
			if sim.get("all_goals_satisfied", false):
				is_final_goal_reached = true
		elif not exit_hit and sim.get("all_goals_satisfied", false):
			is_final_goal_reached = true

		if exit_hit:
			any_exit_hit = true
			stage_cleared = true
			traversal_state = TraversalState.EXIT_REACHED
			carried_laser_color = hit_col
			carried_laser_dir = exit_d

		if exit_hit and k + 1 < total_stages:
			var next_item := stage_world_data[k + 1]
			var next_st: LaserStageData = next_item["stage"]
			var next_origin: Vector2 = next_item["origin"]
			var next_cell_sz: Vector2 = next_item["cell_size"]
			var next_cam_pos: Vector2 = next_item["camera_pos"]

			# Find Exit Gate world position in current stage
			var exit_grid_pos: Vector2i = Vector2i(-1, -1)
			for obj in st.objects:
				if obj != null and obj.enabled and obj.type == LaserObjectData.ObjectType.EXIT_GATE:
					exit_grid_pos = obj.grid_pos
					break
			if exit_grid_pos == Vector2i(-1, -1):
				exit_grid_pos = st.exit_point

			# Find Entry Gate world position in next stage
			var entry_grid_pos: Vector2i = Vector2i(-1, -1)
			var eg_obj: LaserObjectData = null
			for obj in next_st.objects:
				if obj != null and obj.enabled and obj.type == LaserObjectData.ObjectType.GATE:
					eg_obj = obj
					entry_grid_pos = obj.grid_pos
					break
			if entry_grid_pos == Vector2i(-1, -1):
				entry_grid_pos = next_st.entry_point

			var p_exit_world := BoardLayoutManager.grid_to_world(exit_grid_pos, st_origin, st_cell_sz)
			var p_entry_world := BoardLayoutManager.grid_to_world(entry_grid_pos, next_origin, next_cell_sz)
			var trans_len: float = p_exit_world.distance_to(p_entry_world)

			var w_exit_dist: float = cumulative_world_dist + exit_rel_dist
			var w_entry_dist: float = w_exit_dist + trans_len

			# Continuous laser transition segment across the world gap
			all_world_segments.append({
				"p1": p_exit_world,
				"p2": p_entry_world,
				"world_start_dist": w_exit_dist,
				"world_end_dist": w_entry_dist,
				"color": hit_col,
				"hit_type": "stage_transition",
				"from_stage": st_num,
				"to_stage": next_item["index"]
			})

			stage_transition_intervals.append({
				"from_stage": st_num,
				"to_stage": next_item["index"],
				"exit_dist": w_exit_dist,
				"entry_dist": w_entry_dist,
				"from_cam_pos": st_cam_pos,
				"to_cam_pos": next_cam_pos,
				"exit_world_pos": p_exit_world,
				"entry_world_pos": p_entry_world,
				"color": hit_col
			})

			cumulative_world_dist = w_entry_dist
			c_color = hit_col
			c_pos = entry_grid_pos
			if eg_obj != null:
				var edir = eg_obj.get_direction_vector()
				c_dir = edir if edir != Vector2i.ZERO else (exit_d if exit_d != Vector2i.ZERO else LaserSimulation._infer_inward_direction(eg_obj.grid_pos, next_st.grid_width, next_st.grid_height))
			else:
				c_dir = exit_d
		else:
			# Laser did not cross this exit gate
			c_pos = Vector2i(-999, -999)

	var all_cleared = simulation_res.get("all_goals_satisfied", false)
	if not all_cleared and not any_exit_hit and not is_final_goal_reached:
		stage_cleared = false

	_transition_controller.set_transition_intervals(stage_transition_intervals)

	if beam_renderer != null:
		beam_renderer.update_beams(all_world_segments, grid_origin, cell_size, animate_shoot, preserve_progress)

	for id in spawned_nodes:
		var node = spawned_nodes[id]
		if is_instance_valid(node) and node.has_method("on_simulation_updated"):
			node.on_simulation_updated(simulation_res)

func _play_stage_exit_flash(stage_idx: int, exit_pos: Vector2) -> void:
	print("🎉 Laser crossed Stage %d Exit Gate at %s!" % [stage_idx, exit_pos])
	stage_cleared = true
	if _clear_flash != null and is_inside_tree():
		var tw = create_tween()
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_QUAD)
		tw.tween_property(_clear_flash, "color", Color(0.2, 1.0, 0.4, 0.22), 0.08)
		tw.tween_property(_clear_flash, "color", Color(0.2, 1.0, 0.4, 0.0), 0.25)

func _on_beam_animation_completed() -> void:
	if is_final_goal_reached and traversal_state != TraversalState.COMPLETED:
		traversal_state = TraversalState.COMPLETED
		print("🏆 FINAL TARGET REACHED! Level %d Complete!" % (level_data.level_id if level_data != null else level_number))
		_play_clear_flash()
		if is_inside_tree():
			var tw = create_tween()
			tw.tween_interval(0.8)
			tw.tween_callback(func():
				next_level()
			)

func _check_and_trigger_stage_clear() -> void:
	stage_cleared = true
	traversal_state = TraversalState.EXIT_REACHED

func pan_camera_to_stage(target_stage_idx: int, duration: float = 0.7) -> void:
	if level_data == null or stage_world_data.is_empty():
		return

	var idx: int = clampi(target_stage_idx, 1, stage_world_data.size())
	current_stage_idx = idx
	current_stage = stage_world_data[idx - 1]["stage"]
	grid_origin = stage_world_data[idx - 1]["origin"]
	cell_size = stage_world_data[idx - 1]["cell_size"]
	var target_cam_pos: Vector2 = stage_world_data[idx - 1]["camera_pos"]

	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()

	if duration > 0.0 and camera != null and is_inside_tree():
		_cam_tween = create_tween()
		_cam_tween.set_ease(Tween.EASE_IN_OUT)
		_cam_tween.set_trans(Tween.TRANS_CUBIC)
		_cam_tween.tween_property(camera, "position", target_cam_pos, duration)
		_cam_tween.tween_callback(func():
			_apply_board_layout()
			_update_hint_button()
		)
	else:
		if camera != null:
			camera.position = target_cam_pos
		_apply_board_layout()
		_update_hint_button()

func next_stage() -> void:
	var max_stages: int = stage_world_data.size() if not stage_world_data.is_empty() else 1
	if current_stage_idx < max_stages:
		pan_camera_to_stage(current_stage_idx + 1)
	else:
		next_level()

func next_level() -> void:
	if not load_level_by_number(level_number + 1, 1):
		print("🏆 All levels cleared! Restarting from Level 1...")
		load_level_by_number(1, 1)

func restart_level() -> void:
	load_stage(1)

func _setup_clear_flash() -> void:
	if _clear_flash != null:
		return
	_clear_flash = ColorRect.new()
	_clear_flash.color = Color(0.3, 1.0, 0.4, 0.0)
	_clear_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clear_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_flash.z_index = 100
	if ui_layer != null:
		ui_layer.add_child(_clear_flash)
	else:
		add_child(_clear_flash)

func _play_clear_flash() -> void:
	if _clear_flash == null or not is_inside_tree():
		return
	_clear_flash.color = Color(0.3, 1.0, 0.4, 0.0)
	var tw = create_tween()
	tw.tween_property(_clear_flash, "color", Color(0.3, 1.0, 0.4, 0.55), 0.15)
	tw.tween_property(_clear_flash, "color", Color(0.3, 1.0, 0.4, 0.0), 0.5)

func _apply_board_layout() -> void:
	if current_stage == null:
		return
	if board != null:
		var rect := BoardLayoutManager.compute_board_rect(grid_origin, cell_size, current_stage.grid_width, current_stage.grid_height)
		board.position = rect.position
		board.size = rect.size
	_update_hint_button()

func _reposition_spawned_objects() -> void:
	for item in stage_world_data:
		var st_idx: int = item["index"]
		var st: LaserStageData = item["stage"]
		var st_origin: Vector2 = item["origin"]
		var st_cell_sz: Vector2 = item["cell_size"]

		for obj in st.objects:
			if obj != null and spawned_nodes.has(obj.id):
				_spawner.update_node_transform(spawned_nodes[obj.id], obj, st_origin, st_cell_sz)

func _on_object_modified(obj: LaserObjectData) -> void:
	var st_idx: int = object_to_stage_idx.get(obj.id, current_stage_idx)
	var st_origin := grid_origin
	var st_cell_sz := cell_size
	if st_idx - 1 >= 0 and st_idx - 1 < stage_world_data.size():
		st_origin = stage_world_data[st_idx - 1]["origin"]
		st_cell_sz = stage_world_data[st_idx - 1]["cell_size"]

	if spawned_nodes.has(obj.id):
		_spawner.update_node_transform(spawned_nodes[obj.id], obj, st_origin, st_cell_sz)
	recalculate_simulation(true, true)

func _toggle_playtest_visuals() -> void:
	if is_playtest_mode:
		use_editor_visuals_in_playtest = not use_editor_visuals_in_playtest
		_spawn_all_world_objects()
		_update_renderers()
		recalculate_simulation(false)

func _update_renderers() -> void:
	_redraw_grid()
	_redraw_beams()

func _redraw_grid() -> void:
	if grid_renderer != null:
		if not stage_world_data.is_empty():
			grid_renderer.update_all_stages(stage_world_data)
		else:
			grid_renderer.update_grid(current_stage, grid_origin, cell_size)

func _redraw_beams(animate_shoot: bool = true, preserve_progress: bool = false) -> void:
	if beam_renderer != null:
		recalculate_simulation(animate_shoot, preserve_progress)

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
	object_to_stage_idx.clear()
