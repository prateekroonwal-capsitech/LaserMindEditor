@tool
extends Window
class_name PlaytestDialog

var level_data: LaserLevelData = null
var current_stage_idx: int = 1
var current_stage: LaserStageData = null
var initial_stage_snapshots: Array[LaserStageData] = []

var elapsed_total_time: float = 0.0
var current_stage_elapsed: float = 0.0
var universal_time_remaining: float = 60.0
var is_playing: bool = false

var root_vbox: VBoxContainer
var header_hbox: HBoxContainer
var stage_label: Label
var universal_timer_lbl: Label
var stage_timer_lbl: Label
var restart_btn: Button
var playtest_canvas: PlaytestCanvas
var message_overlay: PanelContainer
var message_title_lbl: Label
var message_body_lbl: Label
var next_stage_btn: Button
var close_btn: Button

func _init() -> void:
	title = "🎮 Laser Mind — In-Editor Playtest"
	size = Vector2i(760, 860)
	exclusive = true
	transient = true
	close_requested.connect(_on_exit_pressed)
	_setup_ui()

func _setup_ui() -> void:
	root_vbox = VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 6)
	add_child(root_vbox)

	var top_bar := PanelContainer.new()
	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 16)
	top_bar.add_child(top_hbox)

	stage_label = Label.new()
	stage_label.text = "STAGE 1 / 3"
	stage_label.add_theme_font_size_override("font_size", 16)
	stage_label.modulate = Color(1.0, 0.9, 0.4)
	top_hbox.add_child(stage_label)

	universal_timer_lbl = Label.new()
	universal_timer_lbl.text = "⏳ Level Time: 60.0s"
	universal_timer_lbl.add_theme_font_size_override("font_size", 14)
	top_hbox.add_child(universal_timer_lbl)

	stage_timer_lbl = Label.new()
	stage_timer_lbl.text = "Stage Time: 0.0s"
	stage_timer_lbl.modulate = Color(0.7, 0.85, 1.0)
	top_hbox.add_child(stage_timer_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	restart_btn = Button.new()
	restart_btn.text = "🔄 Restart (R)"
	restart_btn.tooltip_text = "Reset current stage to initial state (R)"
	restart_btn.pressed.connect(_on_restart_pressed)
	top_hbox.add_child(restart_btn)

	var exit_btn := Button.new()
	exit_btn.text = "✕ Exit (Esc)"
	exit_btn.tooltip_text = "Close playtest and return to editor (Esc)"
	exit_btn.pressed.connect(_on_exit_pressed)
	top_hbox.add_child(exit_btn)
	root_vbox.add_child(top_bar)

	playtest_canvas = PlaytestCanvas.new()
	playtest_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	playtest_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	playtest_canvas.stage_cleared.connect(_on_stage_cleared)
	root_vbox.add_child(playtest_canvas)

	message_overlay = PanelContainer.new()
	message_overlay.set_anchors_preset(Control.PRESET_CENTER)
	message_overlay.custom_minimum_size = Vector2(420, 280)
	message_overlay.visible = false

	var o_vbox := VBoxContainer.new()
	o_vbox.add_theme_constant_override("separation", 12)
	o_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	message_overlay.add_child(o_vbox)

	message_title_lbl = Label.new()
	message_title_lbl.text = "STAGE COMPLETE!"
	message_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_title_lbl.add_theme_font_size_override("font_size", 20)
	message_title_lbl.modulate = Color(1.0, 0.85, 0.2)
	o_vbox.add_child(message_title_lbl)

	message_body_lbl = Label.new()
	message_body_lbl.text = "+5.0s Time Bonus Awarded!"
	message_body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	o_vbox.add_child(message_body_lbl)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	next_stage_btn = Button.new()
	next_stage_btn.text = "Continue to Next Stage ➜"
	next_stage_btn.custom_minimum_size = Vector2(160, 36)
	next_stage_btn.pressed.connect(_on_continue_pressed)
	btn_hbox.add_child(next_stage_btn)

	close_btn = Button.new()
	close_btn.text = "Back to Editor"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.pressed.connect(_on_exit_pressed)
	btn_hbox.add_child(close_btn)
	o_vbox.add_child(btn_hbox)

	add_child(message_overlay)

func start_playtest(p_level: LaserLevelData) -> void:
	if p_level == null:
		return
	level_data = p_level.duplicate_data()
	level_data.ensure_three_stages()

	initial_stage_snapshots.clear()
	for st in level_data.stages:
		if st != null:
			initial_stage_snapshots.append(st.duplicate_data())
		else:
			initial_stage_snapshots.append(null)

	universal_time_remaining = level_data.universal_timer
	elapsed_total_time = 0.0
	current_stage_idx = 1
	is_playing = true
	message_overlay.visible = false

	_load_stage(1)
	if is_inside_tree():
		popup_centered()
	else:
		show()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not is_playing:
		return
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		if k.keycode == KEY_R and not k.is_command_or_control_pressed():
			_on_restart_pressed()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_ESCAPE:
			_on_exit_pressed()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_playing:
		return

	elapsed_total_time += delta
	current_stage_elapsed += delta
	universal_time_remaining -= delta

	if universal_time_remaining <= 0.0:
		universal_time_remaining = 0.0
		_on_game_over_time()

	universal_timer_lbl.text = "⏳ Level Time: %.1fs" % universal_time_remaining
	stage_timer_lbl.text = "Stage Time: %.1fs" % current_stage_elapsed

var carried_laser_color: Color = Color(-1, -1, -1, -1)
var carried_laser_pos: Vector2i = Vector2i(-999, -999)
var carried_laser_dir: Vector2i = Vector2i.ZERO

func _load_stage(idx: int) -> void:
	current_stage_idx = idx
	current_stage = level_data.get_stage(idx)
	current_stage_elapsed = 0.0
	var total_st: int = level_data.get_stage_count() if level_data != null else 3
	stage_label.text = "STAGE %d / %d" % [idx, total_st]
	message_overlay.visible = false
	is_playing = true

	if idx == 1:
		carried_laser_color = Color(-1, -1, -1, -1)
		carried_laser_pos = Vector2i(-999, -999)
		carried_laser_dir = Vector2i.ZERO

	playtest_canvas.set_stage(current_stage, carried_laser_color, carried_laser_pos, carried_laser_dir, true)

func _on_restart_pressed() -> void:
	if level_data == null:
		return
	if current_stage_idx - 1 >= 0 and current_stage_idx - 1 < initial_stage_snapshots.size():
		var snap = initial_stage_snapshots[current_stage_idx - 1]
		if snap != null:
			current_stage = snap.duplicate_data()
			level_data.stages[current_stage_idx - 1] = current_stage
	current_stage_elapsed = 0.0
	message_overlay.visible = false
	is_playing = true
	playtest_canvas.set_stage(current_stage, carried_laser_color, carried_laser_pos, carried_laser_dir, true)

func _on_stage_cleared() -> void:
	is_playing = false
	var bonus: float = current_stage.time_bonus if current_stage != null else 5.0
	universal_time_remaining += bonus

	if playtest_canvas != null and playtest_canvas.simulation_res != null:
		if playtest_canvas.simulation_res.has("exit_laser_color") and playtest_canvas.simulation_res["exit_laser_color"].a >= 0.0:
			carried_laser_color = playtest_canvas.simulation_res.get("exit_laser_color", Color(1.0, 0.2, 0.2, 1.0))
			var exit_dir: Vector2i = playtest_canvas.simulation_res.get("exit_laser_dir", Vector2i.ZERO)
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

	var total_st: int = level_data.get_stage_count() if level_data != null else LaserLevelData.STAGE_COUNT
	if current_stage_idx < total_st:
		message_title_lbl.text = "STAGE %d COMPLETE! 🎉" % current_stage_idx
		message_body_lbl.text = "Stage Time: %.1fs\nTime Bonus: +%.1fs added to Level Timer!" % [current_stage_elapsed, bonus]
		next_stage_btn.text = "Continue to Stage %d ➜" % (current_stage_idx + 1)
		next_stage_btn.visible = true
	else:
		_show_level_complete_screen()

	message_overlay.visible = true

func _show_level_complete_screen() -> void:
	var stars: int = 1
	if elapsed_total_time <= level_data.star_threshold_3:
		stars = 3
	elif elapsed_total_time <= level_data.star_threshold_2:
		stars = 2

	var coins: int = level_data.coin_reward_1
	if stars == 3: coins = level_data.coin_reward_3
	elif stars == 2: coins = level_data.coin_reward_2

	var star_str = "⭐".repeat(stars)

	message_title_lbl.text = "🏆 LEVEL COMPLETE! 🏆"
	message_body_lbl.text = "%s\n\nTotal Completion Time: %.1fs\nStars Earned: %d / 3\nCoins Awarded: +%d 🪙\n\n✨ Great Laser Mastery! ✨" % [
		star_str, elapsed_total_time, stars, coins
	]
	next_stage_btn.visible = false

func _on_continue_pressed() -> void:
	var total_st: int = level_data.get_stage_count() if level_data != null else LaserLevelData.STAGE_COUNT
	if current_stage_idx < total_st:
		_load_stage(current_stage_idx + 1)
	else:
		_load_stage(1)

func _on_game_over_time() -> void:
	is_playing = false
	message_title_lbl.text = "⏰ TIME'S UP!"
	message_body_lbl.text = "Universal level timer ran out. Would you like to retry?"
	next_stage_btn.text = "Retry Stage 1"
	next_stage_btn.visible = true
	message_overlay.visible = true

func _on_exit_pressed() -> void:
	is_playing = false
	hide()

class PlaytestCanvas extends Control:
	signal stage_cleared

	var stage: LaserStageData = null
	var simulation_res: Dictionary = {}
	var incoming_laser_color: Color = Color(-1, -1, -1, -1)
	var incoming_laser_pos: Vector2i = Vector2i(-999, -999)
	var incoming_laser_dir: Vector2i = Vector2i.ZERO
	var cell_size: float = 48.0
	var zoom_level: float = 1.0
	var pan_offset: Vector2 = Vector2(80, 60)

	var active_object: LaserObjectData = null
	var active_object_start_pos: Vector2i = Vector2i.ZERO
	var pointer_down_screen_pos: Vector2 = Vector2.ZERO
	var is_dragging_active: bool = false
	var win_triggered: bool = false

	const DRAG_THRESHOLD: float = 6.0

	@export var laser_travel_speed: float = 650.0
	@export var laser_head_size: float = 8.0
	@export var laser_head_glow: float = 1.0

	var traversed_distance: float = 0.0
	var total_path_distance: float = 0.0
	var is_traversing: bool = false
	var cached_points: Array[Dictionary] = []

	func reset_laser_traversal() -> void:
		traversed_distance = 0.0
		is_traversing = false
		if is_inside_tree():
			queue_redraw()

	func clear_beams() -> void:
		simulation_res.clear()
		cached_points.clear()
		total_path_distance = 0.0
		traversed_distance = 0.0
		is_traversing = false
		if is_inside_tree():
			queue_redraw()

	func force_complete_traversal() -> void:
		traversed_distance = total_path_distance
		is_traversing = false
		if simulation_res.get("all_goals_satisfied", false) and not win_triggered:
			win_triggered = true
			stage_cleared.emit()
		if is_inside_tree():
			queue_redraw()

	func set_stage(p_stage: LaserStageData, in_color: Color = Color(-1, -1, -1, -1), in_pos: Vector2i = Vector2i(-999, -999), in_dir: Vector2i = Vector2i.ZERO, animate_shoot: bool = true) -> void:
		stage = p_stage
		incoming_laser_color = in_color
		incoming_laser_pos = in_pos
		incoming_laser_dir = in_dir
		win_triggered = false
		active_object = null
		is_dragging_active = false
		recompute(animate_shoot)
		_fit()
		if is_inside_tree():
			queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_fit()
			queue_redraw()

	func _fit() -> void:
		if stage == null:
			return
		var w_px = float(stage.grid_width) * cell_size
		var h_px = float(stage.grid_height) * cell_size
		var zx = (size.x - 80.0) / max(1.0, w_px)
		var zy = (size.y - 80.0) / max(1.0, h_px)
		zoom_level = clamp(min(zx, zy), 0.4, 2.0)
		pan_offset = (size - Vector2(w_px, h_px) * zoom_level) * 0.5
		_rebuild_cached_points()

	func recompute(animate_shoot: bool = false, preserve_progress: bool = false) -> void:
		if stage != null:
			simulation_res = LaserSimulation.simulate_stage(stage, true, incoming_laser_color, incoming_laser_pos, incoming_laser_dir)
			if preserve_progress:
				var old_dist: float = traversed_distance
				_rebuild_cached_points()
				traversed_distance = minf(old_dist, total_path_distance)
				if traversed_distance < total_path_distance:
					is_traversing = true
				else:
					is_traversing = false
					if simulation_res.get("all_goals_satisfied", false) and not win_triggered:
						win_triggered = true
						stage_cleared.emit()
			else:
				_rebuild_cached_points()
				if animate_shoot and total_path_distance > 0.0:
					traversed_distance = 0.0
					is_traversing = true
				else:
					traversed_distance = total_path_distance
					is_traversing = false
					if simulation_res.get("all_goals_satisfied", false) and not win_triggered:
						win_triggered = true
						stage_cleared.emit()
		if is_inside_tree():
			queue_redraw()

	func _rebuild_cached_points() -> void:
		cached_points.clear()
		total_path_distance = 0.0
		if stage == null or simulation_res.is_empty():
			return
		var segments: Array = simulation_res.get("segments", [])
		var c_sz = cell_size * zoom_level
		var prev_chain_dist: float = 0.0
		for seg in segments:
			var s_cell: Vector2i = seg.get("start", Vector2i.ZERO)
			var e_cell: Vector2i = seg.get("end", Vector2i.ZERO)
			var p1 = pan_offset + (Vector2(s_cell) + Vector2(0.5, 0.5)) * c_sz
			var p2 = pan_offset + (Vector2(e_cell) + Vector2(0.5, 0.5)) * c_sz
			var d: float = p1.distance_to(p2)
			var s_dist: float
			var e_dist: float
			if seg.has("start_dist") and seg.has("end_dist"):
				s_dist = float(seg.get("start_dist", 0.0)) * c_sz
				e_dist = float(seg.get("end_dist", 0.0)) * c_sz
			else:
				s_dist = prev_chain_dist
				e_dist = s_dist + d
				prev_chain_dist = e_dist

			if e_dist <= s_dist:
				e_dist = s_dist + d
			total_path_distance = maxf(total_path_distance, e_dist)
			cached_points.append({
				"p1": p1,
				"p2": p2,
				"color": seg.get("color", Color.RED),
				"len": d,
				"start_dist": s_dist,
				"end_dist": e_dist,
				"hit_type": seg.get("hit_type", "")
			})

	func _process(delta: float) -> void:
		if is_traversing:
			var distance_to_move: float = maxf(10.0, laser_travel_speed * zoom_level) * delta
			traversed_distance += distance_to_move
			if traversed_distance >= total_path_distance:
				traversed_distance = total_path_distance
				is_traversing = false
				if simulation_res.get("all_goals_satisfied", false) and not win_triggered:
					win_triggered = true
					stage_cleared.emit()
			if is_inside_tree():
				queue_redraw()

	func _can_drag_object(obj: LaserObjectData) -> bool:
		if obj == null or not obj.enabled:
			return false
		if obj.type in [
			LaserObjectData.ObjectType.LASER_SOURCE,
			LaserObjectData.ObjectType.GATE,
			LaserObjectData.ObjectType.EXIT_GATE,
			LaserObjectData.ObjectType.MOVABLE_AREA
		]:
			return false
		if obj.movable or obj.type == LaserObjectData.ObjectType.MOVABLE_MIRROR:
			return true
		if stage != null and stage.is_cell_in_movable_area(obj.grid_pos):
			return true
		return false

	func _can_rotate_object(obj: LaserObjectData) -> bool:
		if obj == null or not obj.enabled:
			return false
		if obj.rotatable or obj.type == LaserObjectData.ObjectType.ROTATABLE_MIRROR or obj.type == LaserObjectData.ObjectType.SPLITTER:
			return true
		return false

	func _can_interact_with_object(obj: LaserObjectData) -> bool:
		return _can_drag_object(obj) or _can_rotate_object(obj)

	func _is_cell_valid_for_move(target_cell: Vector2i, obj: LaserObjectData) -> bool:
		if stage == null or not stage.is_inside_grid(target_cell):
			return false
		var fg_obj = stage.get_foreground_object_at(target_cell)
		if fg_obj != null and fg_obj != obj:
			return false

		# If stage contains movable areas, movable objects must stay in their assigned area and move orthogonally
		if stage.has_movable_areas():
			if not stage.is_cell_in_object_movable_area(obj, target_cell):
				return false
			if not stage.has_orthogonal_path_in_area(obj, obj.grid_pos, target_cell):
				return false

		return true

	func _handle_pointer_down(pos: Vector2) -> void:
		var local_p = (pos - pan_offset) / (cell_size * zoom_level)
		var cell = Vector2i(int(floor(local_p.x)), int(floor(local_p.y)))
		if stage != null and stage.is_inside_grid(cell):
			var obj = stage.get_foreground_object_at(cell)
			if obj == null:
				obj = stage.get_object_at(cell)
			if obj != null and obj.enabled and _can_interact_with_object(obj):
				if obj.movable_area_id.is_empty():
					var ma = stage.get_movable_area_at(obj.grid_pos)
					if ma != null and not ma.movable_area_id.is_empty():
						obj.movable_area_id = ma.movable_area_id
				active_object = obj
				active_object_start_pos = obj.grid_pos
				pointer_down_screen_pos = pos
				is_dragging_active = false

	func _handle_pointer_motion(pos: Vector2) -> void:
		if active_object == null or stage == null:
			return

		var local_p = (pos - pan_offset) / (cell_size * zoom_level)
		var target_cell = Vector2i(int(floor(local_p.x)), int(floor(local_p.y)))

		if not is_dragging_active:
			if pos.distance_to(pointer_down_screen_pos) >= DRAG_THRESHOLD or target_cell != active_object_start_pos:
				if _can_drag_object(active_object):
					is_dragging_active = true

		if is_dragging_active and _can_drag_object(active_object):
			if target_cell != active_object.grid_pos:
				var old_pos = active_object.grid_pos
				var new_pos = stage.step_object_orthogonally(active_object, target_cell)
				if new_pos != old_pos:
					recompute(true, true)
					queue_redraw()

	func _handle_pointer_up() -> void:
		if active_object != null:
			if not is_dragging_active:
				# Tap / click detected -> Rotate if object is rotatable
				if _can_rotate_object(active_object):
					var step: int = 90 if active_object.type == LaserObjectData.ObjectType.SPLITTER else 45
					active_object.rotation_deg = (active_object.rotation_deg + step) % 360
			active_object = null
			is_dragging_active = false
			recompute(true, true)

	func _gui_input(event: InputEvent) -> void:
		if stage == null or win_triggered:
			return

		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_handle_pointer_down(mb.position)
				else:
					_handle_pointer_up()
				accept_event()

		elif event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			if active_object != null:
				_handle_pointer_motion(mm.position)
				accept_event()

		elif event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			if st.pressed:
				_handle_pointer_down(st.position)
			else:
				_handle_pointer_up()
			accept_event()

		elif event is InputEventScreenDrag:
			var sd := event as InputEventScreenDrag
			if active_object != null:
				_handle_pointer_motion(sd.position)
				accept_event()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.11, 0.14, 1.0))
		if stage == null:
			return

		var c_sz = cell_size * zoom_level
		var gw = stage.grid_width
		var gh = stage.grid_height
		var board_sz := Vector2(float(gw) * c_sz, float(gh) * c_sz)

		# 1. Render Board Visuals (Cell textures, Borders, and Corners with portable default SVGs)
		BoardVisualGenerator.draw_board(
			self,
			stage,
			pan_offset,
			Vector2(c_sz, c_sz),
			zoom_level,
			stage.show_tile_borders,
			Color(0.24, 0.28, 0.36, 0.4)
		)

		# 2. Render Movable Areas
		for obj in stage.objects:
			if obj != null and obj.enabled and obj.type == LaserObjectData.ObjectType.MOVABLE_AREA:
				var center = pan_offset + (Vector2(obj.grid_pos) + Vector2(0.5, 0.5)) * c_sz
				var rad = c_sz * 0.48
				var box = Rect2(center - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
				var is_active_area = false
				if active_object != null and (active_object.movable_area_id == obj.movable_area_id or (active_object.movable_area_id.is_empty() and stage.is_cell_in_object_movable_area(active_object, obj.grid_pos))):
					is_active_area = true
				if is_active_area:
					draw_rect(box.grow(-2 * zoom_level), Color(0.18, 0.65, 1.0, 0.45), true)
					draw_rect(box.grow(-2 * zoom_level), Color(0.5, 0.95, 1.0, 1.0), false, 2.0 * zoom_level)
				else:
					draw_rect(box.grow(-2 * zoom_level), Color(0.12, 0.45, 0.85, 0.30), true)
					draw_rect(box.grow(-2 * zoom_level), Color(0.35, 0.85, 1.0, 0.85), false, 1.5 * zoom_level)

		# 3. Render Objects
		for obj in stage.objects:
			if obj == null or not obj.enabled or obj.type == LaserObjectData.ObjectType.MOVABLE_AREA:
				continue
			var center = pan_offset + (Vector2(obj.grid_pos) + Vector2(0.5, 0.5)) * c_sz
			var rad = c_sz * 0.42

			match obj.type:
				LaserObjectData.ObjectType.LASER_SOURCE:
					# Laser Emitter
					draw_circle(center, rad * 0.75, Color(0.15, 0.18, 0.22))
					draw_circle(center, rad * 0.60, Color(0.28, 0.32, 0.40))
					var rot_rad = deg_to_rad(float(obj.rotation_deg))
					var dir_vec = Vector2.RIGHT.rotated(rot_rad)
					var nozzle = center + dir_vec * (rad * 0.65)
					draw_line(center, nozzle, Color(obj.color.r, obj.color.g, obj.color.b, 0.9), 4.0 * zoom_level, true)
					draw_circle(center, rad * 0.30, obj.color)
					draw_circle(center, rad * 0.15, Color.WHITE)

				LaserObjectData.ObjectType.GOAL:
					# Target / Receiver
					var hit = simulation_res.get("goals_hit", {}).get(obj.grid_pos, false) or simulation_res.get("all_goals_satisfied", false)
					var goal_col = Color(0.2, 1.0, 0.4) if hit else obj.color
					draw_circle(center, rad * 0.75, Color(goal_col.r, goal_col.g, goal_col.b, 0.3))
					draw_arc(center, rad * 0.65, 0, TAU, 32, goal_col, 2.5 * zoom_level, true)
					draw_circle(center, rad * 0.35, goal_col)
					if hit:
						draw_circle(center, rad * 0.20, Color.WHITE)

				LaserObjectData.ObjectType.FIXED_MIRROR:
					var rot_rad = deg_to_rad(float(obj.rotation_deg))
					var p1 = center + Vector2(-rad, -rad).rotated(rot_rad)
					var p2 = center + Vector2(rad, rad).rotated(rot_rad)
					draw_rect(Rect2(center - Vector2(rad, rad) * 0.75, Vector2(rad, rad) * 1.5), Color(0.15, 0.18, 0.24, 0.5))
					draw_line(p1, p2, Color(0.85, 0.92, 1.0), 4.0 * zoom_level)
					draw_circle(p1, 2.0 * zoom_level, Color(0.4, 0.7, 1.0))
					draw_circle(p2, 2.0 * zoom_level, Color(0.4, 0.7, 1.0))

				LaserObjectData.ObjectType.MOVABLE_MIRROR:
					var rot_rad = deg_to_rad(float(obj.rotation_deg))
					var p1 = center + Vector2(-rad, -rad).rotated(rot_rad)
					var p2 = center + Vector2(rad, rad).rotated(rot_rad)
					var box = Rect2(center - Vector2(rad, rad) * 0.75, Vector2(rad, rad) * 1.5)
					draw_rect(box, Color(0.15, 0.35, 0.6, 0.55))
					draw_rect(box, Color(0.3, 0.75, 1.0, 0.9), false, 1.5 * zoom_level)
					draw_line(p1, p2, Color(0.9, 0.95, 1.0), 4.0 * zoom_level)

				LaserObjectData.ObjectType.ROTATABLE_MIRROR:
					var rot_rad = deg_to_rad(float(obj.rotation_deg))
					var p1 = center + Vector2(-rad, -rad).rotated(rot_rad)
					var p2 = center + Vector2(rad, rad).rotated(rot_rad)
					draw_arc(center, rad * 0.72, 0, TAU, 32, Color(0.4, 0.75, 1.0, 0.5), 1.5 * zoom_level, true)
					draw_line(p1, p2, Color(0.9, 0.95, 1.0), 4.0 * zoom_level)
					draw_circle(center, 2.0 * zoom_level, Color(1.0, 0.85, 0.2))

				LaserObjectData.ObjectType.ROCK:
					draw_circle(center, rad * 0.75, Color(0.38, 0.36, 0.34))
					draw_circle(center + Vector2(-rad * 0.2, -rad * 0.2), rad * 0.45, Color(0.48, 0.45, 0.42))

				LaserObjectData.ObjectType.ICE:
					var box = Rect2(center - Vector2(rad, rad) * 0.7, Vector2(rad, rad) * 1.4)
					draw_rect(box, Color(0.35, 0.75, 0.95, 0.65))
					draw_rect(box, Color(0.75, 0.92, 1.0, 0.9), false, 1.5 * zoom_level)
					draw_line(center + Vector2(-rad * 0.4, -rad * 0.4), center + Vector2(rad * 0.4, rad * 0.4), Color(1.0, 1.0, 1.0, 0.5), 1.5 * zoom_level)

				LaserObjectData.ObjectType.SPLITTER:
					var rot_rad = deg_to_rad(float(obj.rotation_deg))
					draw_arc(center, rad * 0.72, 0, TAU, 32, Color(0.8, 0.4, 0.9, 0.6), 1.5 * zoom_level, true)
					var p1 = center + Vector2(-rad * 0.6, -rad * 0.6).rotated(rot_rad)
					var p2 = center + Vector2(rad * 0.6, rad * 0.6).rotated(rot_rad)
					draw_line(p1, p2, Color(0.95, 0.8, 1.0), 4.0 * zoom_level)
					draw_circle(center, rad * 0.25, Color(0.9, 0.5, 1.0))

				LaserObjectData.ObjectType.COLOR_GLASS:
					var box = Rect2(center - Vector2(rad, rad) * 0.7, Vector2(rad, rad) * 1.4)
					draw_rect(box, Color(obj.color.r, obj.color.g, obj.color.b, 0.55), true)
					draw_rect(box, Color(obj.color.r, obj.color.g, obj.color.b, 1.0), false, 1.5 * zoom_level)

				LaserObjectData.ObjectType.COLOR_WALL:
					var box = Rect2(center - Vector2(rad, rad) * 0.7, Vector2(rad, rad) * 1.4)
					draw_rect(box, obj.color)
					draw_rect(box, Color.WHITE, false, 1.0 * zoom_level)

				LaserObjectData.ObjectType.GATE:
					var hit = simulation_res.get("switches_hit", {}).is_empty() == false
					var box = Rect2(center - Vector2(rad, rad) * 0.7, Vector2(rad, rad) * 1.4)
					draw_rect(box, Color(0.08, 0.35, 0.15, 0.9) if hit else Color(0.35, 0.08, 0.08, 0.9), true)
					draw_rect(box, Color(0.2, 0.9, 0.4) if hit else Color(0.9, 0.3, 0.3), false, 2.0 * zoom_level)
					draw_circle(center, rad * 0.25, Color.WHITE)
					draw_circle(center, rad * 0.16, Color(0.2, 0.9, 0.4) if hit else Color(0.9, 0.2, 0.2))

				LaserObjectData.ObjectType.EXIT_GATE:
					var hit = simulation_res.get("exit_gates_hit", {}).get(obj.grid_pos, false)
					var box = Rect2(center - Vector2(rad, rad) * 0.7, Vector2(rad, rad) * 1.4)
					draw_rect(box, Color(0.1, 0.8, 0.5) if hit else Color(0.08, 0.35, 0.25), true)
					draw_rect(box, Color(0.4, 1.0, 0.7) if hit else Color(0.2, 0.8, 0.5), false, 2.0 * zoom_level)
					draw_line(center + Vector2(0, rad * 0.3), center + Vector2(0, -rad * 0.3), Color.WHITE, 2.0 * zoom_level)
					draw_line(center + Vector2(0, -rad * 0.3), center + Vector2(-rad * 0.25, 0), Color.WHITE, 2.0 * zoom_level)
					draw_line(center + Vector2(0, -rad * 0.3), center + Vector2(rad * 0.25, 0), Color.WHITE, 2.0 * zoom_level)

				LaserObjectData.ObjectType.SWITCH, LaserObjectData.ObjectType.GATE_SWITCH:
					var hit = simulation_res.get("switches_hit", {}).get(obj.grid_pos, false)
					draw_circle(center, rad * 0.65, Color.GREEN if hit else Color.ORANGE)
					draw_circle(center, rad * 0.35, Color.WHITE if hit else Color(0.3, 0.15, 0.0))

				LaserObjectData.ObjectType.CUSTOM:
					draw_rect(Rect2(center - Vector2(rad, rad) * 0.7, Vector2(rad, rad) * 1.4), obj.color)
					draw_circle(center, rad * 0.4, Color.WHITE)

		# 4. Render Laser Beams & Glow ABOVE Objects with progressive traversal
		if not cached_points.is_empty() and total_path_distance > 0.0:
			if traversed_distance <= 0.0:
				if is_traversing and not cached_points.is_empty():
					var first_seg: Dictionary = cached_points[0]
					_draw_laser_head(first_seg["p1"], first_seg["color"], 1.0)
				return

			var active_heads: Array[Dictionary] = []

			for data in cached_points:
				var p1: Vector2 = data["p1"]
				var p2: Vector2 = data["p2"]
				var b_color: Color = data["color"]
				var s_dist: float = float(data["start_dist"])
				var e_dist: float = float(data["end_dist"])
				var seg_len: float = float(data["len"])
				if seg_len <= 0.0 or e_dist <= s_dist:
					continue

				if traversed_distance >= e_dist:
					draw_line(p1, p2, Color(b_color.r, b_color.g, b_color.b, 0.35), 7.0 * zoom_level, true)
					draw_line(p1, p2, Color(b_color.r, b_color.g, b_color.b, 0.85), 3.5 * zoom_level, true)
					draw_line(p1, p2, Color.WHITE, 1.4 * zoom_level, true)
					draw_circle(p1, 2.5 * zoom_level, Color.WHITE)
					draw_circle(p2, 2.5 * zoom_level, Color.WHITE)
				elif traversed_distance > s_dist:
					var t: float = clampf((traversed_distance - s_dist) / (e_dist - s_dist), 0.0, 1.0)
					var tip: Vector2 = p1.lerp(p2, t)
					draw_line(p1, tip, Color(b_color.r, b_color.g, b_color.b, 0.35), 7.0 * zoom_level, true)
					draw_line(p1, tip, Color(b_color.r, b_color.g, b_color.b, 0.85), 3.5 * zoom_level, true)
					draw_line(p1, tip, Color.WHITE, 1.4 * zoom_level, true)
					draw_circle(p1, 2.5 * zoom_level, Color.WHITE)
					active_heads.append({"pos": tip, "color": b_color})
				else:
					pass

			for h in active_heads:
				_draw_laser_head(h["pos"], h["color"])

			if not is_traversing and active_heads.is_empty() and not cached_points.is_empty():
				for data in cached_points:
					var h_type: String = str(data.get("hit_type", ""))
					if h_type in ["goal", "exit_gate", "blocker", "boundary", "color_wall_blocked", "gate_closed", "custom", "switch"]:
						_draw_laser_head(data["p2"], data["color"], 0.75)

	func _draw_laser_head(pos: Vector2, c: Color, scale_mod: float = 1.0) -> void:
		var h_sz: float = (cell_size * zoom_level * 0.14) * scale_mod * laser_head_size / 8.0
		var pulse: float = 1.0 + 0.12 * sin(float(Time.get_ticks_msec()) * 0.012)
		var eff_sz: float = h_sz * pulse

		# 1. Outer diffuse glow
		draw_circle(pos, eff_sz * 2.2 * laser_head_glow, Color(c.r, c.g, c.b, 0.32))
		# 2. Main color head
		draw_circle(pos, eff_sz * 1.3, Color(c.r, c.g, c.b, 0.85))
		# 3. Bright white core
		draw_circle(pos, eff_sz * 0.65, Color.WHITE)
		# 4. Small cross flare / spark
		var flare_len: float = eff_sz * 1.8
		draw_line(pos - Vector2(flare_len, 0), pos + Vector2(flare_len, 0), Color(1.0, 1.0, 1.0, 0.8), 1.5 * zoom_level)
		draw_line(pos - Vector2(0, flare_len), pos + Vector2(0, flare_len), Color(1.0, 1.0, 1.0, 0.8), 1.5 * zoom_level)

