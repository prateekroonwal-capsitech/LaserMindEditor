@tool
extends Window
class_name PlaytestDialog

var level_data: LaserLevelData = null
var current_stage_idx: int = 1
var current_stage: LaserStageData = null

var elapsed_total_time: float = 0.0
var current_stage_elapsed: float = 0.0
var universal_time_remaining: float = 60.0
var is_playing: bool = false

var root_vbox: VBoxContainer
var header_hbox: HBoxContainer
var stage_label: Label
var universal_timer_lbl: Label
var stage_timer_lbl: Label
var playtest_canvas: PlaytestCanvas
var message_overlay: PanelContainer
var message_title_lbl: Label
var message_body_lbl: Label
var next_stage_btn: Button
var close_btn: Button

func _init() -> void:
	title = "🎮 Laser Mind — In-Editor Playtest"
	size = Vector2i(720, 840)
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

	var exit_btn := Button.new()
	exit_btn.text = "✕ Exit Playtest"
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
	message_overlay.custom_minimum_size = Vector2(400, 260)
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

	universal_time_remaining = level_data.universal_timer
	elapsed_total_time = 0.0
	current_stage_idx = 1
	is_playing = true
	message_overlay.visible = false

	_load_stage(1)
	popup_centered()

func _process(delta: float) -> void:
	if not is_playing:
		return

	elapsed_total_time += delta
	current_stage_elapsed += delta
	universal_time_remaining -= delta

	if universal_time_remaining <= 0.0:
		universal_time_remaining = 0.0
		_on_game_over_time()

	universal_timer_lbl.text = "⏳ Universal Time: %.1fs" % universal_time_remaining
	stage_timer_lbl.text = "Stage Time: %.1fs" % current_stage_elapsed

func _load_stage(idx: int) -> void:
	current_stage_idx = idx
	current_stage = level_data.get_stage(idx)
	current_stage_elapsed = 0.0
	var total_st: int = level_data.get_stage_count() if level_data != null else 3
	stage_label.text = "STAGE %d / %d" % [idx, total_st]
	message_overlay.visible = false
	is_playing = true

	playtest_canvas.set_stage(current_stage)

func _on_stage_cleared() -> void:
	is_playing = false
	var bonus = current_stage.time_bonus
	universal_time_remaining += bonus

	var total_st: int = level_data.get_stage_count() if level_data != null else LaserLevelData.STAGE_COUNT
	if current_stage_idx < total_st:
		message_title_lbl.text = "STAGE %d COMPLETE! 🎉" % current_stage_idx
		message_body_lbl.text = "Stage Time: %.1fs\nTime Bonus: +%.1fs added to Universal Timer!" % [current_stage_elapsed, bonus]
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
	message_body_lbl.text = "%s\n\nTotal Completion Time: %.1fs\nStars Earned: %d / 3\nCoins Awarded: +%d 🪙\n\nCharacter Screen: ✨ Great Laser Mastery! ✨" % [
		star_str, elapsed_total_time, stars, coins
	]
	next_stage_btn.visible = false

func _on_continue_pressed() -> void:
	var total_st: int = level_data.get_stage_count() if level_data != null else LaserLevelData.STAGE_COUNT
	if current_stage_idx < total_st:
		_load_stage(current_stage_idx + 1)

func _on_game_over_time() -> void:
	is_playing = false
	message_title_lbl.text = "⏰ TIME'S UP!"
	message_body_lbl.text = "Universal timer ran out. Would you like to retry?"
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
	var cell_size: float = 48.0
	var zoom_level: float = 1.0
	var pan_offset: Vector2 = Vector2(80, 60)

	var dragged_object: LaserObjectData = null
	var drag_start_cell: Vector2i = Vector2i.ZERO
	var win_triggered: bool = false

	func set_stage(p_stage: LaserStageData) -> void:
		stage = p_stage
		win_triggered = false
		recompute()
		_fit()
		queue_redraw()

	func _fit() -> void:
		if stage == null:
			return
		var w_px = float(stage.grid_width) * cell_size
		var h_px = float(stage.grid_height) * cell_size
		var zx = (size.x - 80.0) / max(1.0, w_px)
		var zy = (size.y - 80.0) / max(1.0, h_px)
		zoom_level = clamp(min(zx, zy), 0.4, 1.8)
		pan_offset = (size - Vector2(w_px, h_px) * zoom_level) * 0.5

	func recompute() -> void:
		if stage != null:
			simulation_res = LaserSimulation.simulate_stage(stage)
			if simulation_res.get("all_goals_satisfied", false) and not win_triggered:
				win_triggered = true
				stage_cleared.emit()
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if stage == null or win_triggered:
			return

		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			var local_p = (mb.position - pan_offset) / (cell_size * zoom_level)
			var cell = Vector2i(int(floor(local_p.x)), int(floor(local_p.y)))

			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					if stage.is_inside_grid(cell):
						var obj = stage.get_object_at(cell)
						if obj != null:
							if obj.rotatable:
								obj.rotation_deg = (obj.rotation_deg + 45) % 360
								recompute()
							elif obj.movable:
								dragged_object = obj
								drag_start_cell = obj.grid_pos
				else:
					dragged_object = null
					recompute()

		elif event is InputEventMouseMotion and dragged_object != null:
			var mm := event as InputEventMouseMotion
			var local_p = (mm.position - pan_offset) / (cell_size * zoom_level)
			var target_cell = Vector2i(int(floor(local_p.x)), int(floor(local_p.y)))
			if stage.is_inside_grid(target_cell) and stage.get_object_at(target_cell) == null:
				dragged_object.grid_pos = target_cell
				recompute()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.13, 0.16, 1.0))
		if stage == null:
			return

		var c_sz = cell_size * zoom_level
		var gw = stage.grid_width
		var gh = stage.grid_height

		for x in range(gw):
			for y in range(gh):
				var cell_rect := Rect2(pan_offset + Vector2(x, y) * c_sz, Vector2(c_sz, c_sz))
				var is_even := (x + y) % 2 == 0
				draw_rect(cell_rect, Color(0.19, 0.22, 0.27) if is_even else Color(0.16, 0.18, 0.23))
				draw_rect(cell_rect, Color(0.26, 0.3, 0.38, 0.4), false, 1.0)

		var segments: Array = simulation_res.get("segments", [])
		for seg in segments:
			var s_cell: Vector2i = seg["start"]
			var e_cell: Vector2i = seg["end"]
			var b_color: Color = seg["color"]
			var p1 = pan_offset + (Vector2(s_cell) + Vector2(0.5, 0.5)) * c_sz
			var p2 = pan_offset + (Vector2(e_cell) + Vector2(0.5, 0.5)) * c_sz
			draw_line(p1, p2, Color(b_color.r, b_color.g, b_color.b, 0.4), 6.0 * zoom_level, true)
			draw_line(p1, p2, Color.WHITE, 1.8 * zoom_level, true)

		for obj in stage.objects:
			if obj == null or not obj.enabled:
				continue
			var center = pan_offset + (Vector2(obj.grid_pos) + Vector2(0.5, 0.5)) * c_sz
			var rad = c_sz * 0.42

			match obj.type:
				LaserObjectData.ObjectType.MOVABLE_AREA:
					var r_sz = rad * 1.8
					var box = Rect2(center - Vector2(r_sz, r_sz) * 0.5, Vector2(r_sz, r_sz))
					draw_rect(box.grow(-2), Color(0.12, 0.45, 0.75, 0.35), true)
					draw_rect(box.grow(-2), Color(0.35, 0.85, 1.0, 0.8), false, 1.5 * zoom_level)

				LaserObjectData.ObjectType.FIXED_MIRROR, LaserObjectData.ObjectType.MOVABLE_MIRROR, LaserObjectData.ObjectType.ROTATABLE_MIRROR:
					if obj.movable:
						draw_rect(Rect2(center - Vector2(rad, rad) * 0.8, Vector2(rad, rad) * 1.6), Color(0.2, 0.4, 0.6, 0.5))
					var rot_rad = deg_to_rad(float(obj.rotation_deg))
					var p1 = center + Vector2(-rad, -rad).rotated(rot_rad)
					var p2 = center + Vector2(rad, rad).rotated(rot_rad)
					draw_line(p1, p2, Color(0.9, 0.95, 1.0), 3.0 * zoom_level)

				LaserObjectData.ObjectType.ROCK:
					draw_circle(center, rad * 0.8, Color(0.4, 0.38, 0.36))

				LaserObjectData.ObjectType.ICE:
					draw_rect(Rect2(center - Vector2(rad, rad) * 0.7, Vector2(rad, rad) * 1.4), Color(0.4, 0.8, 1.0, 0.7))

				LaserObjectData.ObjectType.SPLITTER:
					draw_circle(center, rad * 0.8, Color(0.5, 0.3, 0.6))

				LaserObjectData.ObjectType.COLOR_GLASS:
					draw_rect(Rect2(center - Vector2(rad, rad) * 0.7, Vector2(rad, rad) * 1.4), Color(obj.color.r, obj.color.g, obj.color.b, 0.6))

				LaserObjectData.ObjectType.COLOR_WALL:
					draw_rect(Rect2(center - Vector2(rad, rad) * 0.7, Vector2(rad, rad) * 1.4), obj.color)

				LaserObjectData.ObjectType.GATE:
					var box = Rect2(center - Vector2(rad, rad) * 0.7, Vector2(rad, rad) * 1.4)
					draw_rect(box, Color(0.35, 0.08, 0.08, 0.9), true)
					draw_rect(box, Color(0.9, 0.3, 0.3), false, 2.0)
					draw_circle(center, rad * 0.25, Color.WHITE)
					draw_circle(center, rad * 0.16, Color(0.9, 0.2, 0.2))

				LaserObjectData.ObjectType.EXIT_GATE:
					var hit = simulation_res.get("exit_gates_hit", {}).get(obj.grid_pos, false)
					var box = Rect2(center - Vector2(rad, rad) * 0.7, Vector2(rad, rad) * 1.4)
					draw_rect(box, Color(0.1, 0.8, 0.5) if hit else Color(0.08, 0.35, 0.25), true)
					draw_rect(box, Color(0.4, 1.0, 0.7) if hit else Color(0.2, 0.8, 0.5), false, 2.0)
					draw_line(center + Vector2(0, rad * 0.3), center + Vector2(0, -rad * 0.3), Color.WHITE, 2.0)
					draw_line(center + Vector2(0, -rad * 0.3), center + Vector2(-rad * 0.25, 0), Color.WHITE, 2.0)
					draw_line(center + Vector2(0, -rad * 0.3), center + Vector2(rad * 0.25, 0), Color.WHITE, 2.0)

				LaserObjectData.ObjectType.SWITCH, LaserObjectData.ObjectType.GATE_SWITCH:
					var hit = simulation_res.get("switches_hit", {}).get(obj.grid_pos, false)
					draw_circle(center, rad * 0.6, Color.GREEN if hit else Color.ORANGE)

				LaserObjectData.ObjectType.CUSTOM:
					draw_rect(Rect2(center - Vector2(rad, rad) * 0.7, Vector2(rad, rad) * 1.4), obj.color)
					draw_circle(center, rad * 0.4, Color.WHITE)
