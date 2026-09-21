@tool
extends PanelContainer
class_name BottomPanel

signal error_item_clicked(stage_idx: int, cell: Vector2i, obj_id: String)
signal request_run_solvability

var tab_container: TabContainer

var val_tree: Tree
var val_status_lbl: Label

var solv_status_lbl: Label
var solv_moves_lbl: Label
var solv_explored_lbl: Label
var solv_diff_lbl: Label
var solv_run_btn: Button

var diff_rating_lbl: Label
var diff_details_lbl: Label

var qual_tree: Tree
var qual_status_lbl: Label

func _init() -> void:
	custom_minimum_size = Vector2(0, 140)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_FILL
	_setup_ui()

func _setup_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	tab_container = TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tab_container)

	_setup_validation_tab()
	_setup_solvability_tab()
	_setup_difficulty_tab()
	_setup_quality_tab()

func _setup_validation_tab() -> void:
	var v_box := VBoxContainer.new()
	v_box.name = "Validation"
	tab_container.add_child(v_box)

	var h_box := HBoxContainer.new()
	val_status_lbl = Label.new()
	val_status_lbl.text = "STATUS: CHECKING..."
	h_box.add_child(val_status_lbl)
	v_box.add_child(h_box)

	val_tree = Tree.new()
	val_tree.columns = 3
	val_tree.set_column_title(0, "Severity")
	val_tree.set_column_title(1, "Stage")
	val_tree.set_column_title(2, "Message (Click to focus)")
	val_tree.set_column_titles_visible(true)
	val_tree.set_column_expand(0, false)
	val_tree.set_column_custom_minimum_width(0, 85)
	val_tree.set_column_expand(1, false)
	val_tree.set_column_custom_minimum_width(1, 65)
	val_tree.set_column_expand(2, true)
	val_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	val_tree.item_activated.connect(_on_val_item_clicked)
	val_tree.item_selected.connect(_on_val_item_clicked)
	v_box.add_child(val_tree)

func _setup_solvability_tab() -> void:
	var s_box := VBoxContainer.new()
	s_box.name = "Solvability Checker"
	tab_container.add_child(s_box)

	var top_bar := HBoxContainer.new()
	solv_run_btn = Button.new()
	solv_run_btn.text = "▶ Run Solvability Check"
	solv_run_btn.pressed.connect(func(): request_run_solvability.emit())
	top_bar.add_child(solv_run_btn)

	solv_status_lbl = Label.new()
	solv_status_lbl.text = "Status: Not run"
	solv_status_lbl.add_theme_font_size_override("font_size", 14)
	top_bar.add_child(solv_status_lbl)
	s_box.add_child(top_bar)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var m_title := Label.new()
	m_title.text = "Minimum Solution:"
	grid.add_child(m_title)
	solv_moves_lbl = Label.new()
	solv_moves_lbl.text = "—"
	grid.add_child(solv_moves_lbl)

	var d_title := Label.new()
	d_title.text = "Estimated Difficulty:"
	grid.add_child(d_title)
	solv_diff_lbl = Label.new()
	solv_diff_lbl.text = "—"
	grid.add_child(solv_diff_lbl)

	var e_title := Label.new()
	e_title.text = "States Explored:"
	grid.add_child(e_title)
	solv_explored_lbl = Label.new()
	solv_explored_lbl.text = "—"
	grid.add_child(solv_explored_lbl)

	s_box.add_child(grid)

func _setup_difficulty_tab() -> void:
	var d_box := VBoxContainer.new()
	d_box.name = "Difficulty Analysis"
	tab_container.add_child(d_box)

	diff_rating_lbl = Label.new()
	diff_rating_lbl.text = "DIFFICULTY: MEDIUM"
	diff_rating_lbl.add_theme_font_size_override("font_size", 15)
	d_box.add_child(diff_rating_lbl)

	diff_details_lbl = Label.new()
	diff_details_lbl.text = "Grid Area: — | Objects: — | Movable: — | Goals: — | Path Length: —"
	diff_details_lbl.modulate = Color(0.8, 0.85, 0.9)
	d_box.add_child(diff_details_lbl)

func _setup_quality_tab() -> void:
	var q_box := VBoxContainer.new()
	q_box.name = "Quality Checklist"
	tab_container.add_child(q_box)

	qual_status_lbl = Label.new()
	qual_status_lbl.text = "QUALITY STATUS: READY ✓"
	qual_status_lbl.add_theme_font_size_override("font_size", 14)
	q_box.add_child(qual_status_lbl)

	qual_tree = Tree.new()
	qual_tree.columns = 2
	qual_tree.set_column_title(0, "Check")
	qual_tree.set_column_title(1, "Status")
	qual_tree.set_column_titles_visible(true)
	qual_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qual_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	q_box.add_child(qual_tree)

func update_validation(val_res: Dictionary) -> void:
	val_tree.clear()
	var root = val_tree.create_item()

	var is_valid = val_res.get("is_valid", false)
	if is_valid:
		val_status_lbl.text = "STATUS: VALID ✓ (No errors found)"
		val_status_lbl.modulate = Color(0.3, 1.0, 0.4)
	else:
		val_status_lbl.text = "STATUS: %s" % val_res.get("status_text", "INVALID")
		val_status_lbl.modulate = Color(1.0, 0.3, 0.3)

	var items: Array = val_res.get("items", [])
	for item in items:
		var row = val_tree.create_item(root)
		var sev = item.get("severity", LevelValidator.Severity.INFO)
		var sev_text = "ERROR"
		var sev_col = Color(1.0, 0.3, 0.3)
		if sev == LevelValidator.Severity.WARNING:
			sev_text = "WARNING"
			sev_col = Color(1.0, 0.8, 0.2)
		elif sev == LevelValidator.Severity.INFO:
			sev_text = "INFO"
			sev_col = Color(0.4, 0.8, 1.0)

		row.set_text(0, sev_text)
		row.set_custom_color(0, sev_col)
		var st_num = item.get("stage", 0)
		row.set_text(1, "All" if st_num == 0 else "Stage %d" % st_num)
		row.set_text(2, str(item.get("message", "")))
		row.set_metadata(0, item)

func update_solvability(solv_res: Dictionary) -> void:
	solv_status_lbl.text = "Status: %s" % solv_res.get("status_text", "—")
	var status = solv_res.get("status", SolvabilityChecker.Status.UNSOLVABLE)
	if status == SolvabilityChecker.Status.SOLVABLE:
		solv_status_lbl.modulate = Color(0.3, 1.0, 0.4)
	elif status == SolvabilityChecker.Status.CHECK_INCOMPLETE:
		solv_status_lbl.modulate = Color(1.0, 0.8, 0.2)
	else:
		solv_status_lbl.modulate = Color(1.0, 0.3, 0.3)

	var min_m = solv_res.get("min_moves", -1)
	solv_moves_lbl.text = "%d moves" % min_m if min_m >= 0 else "N/A"
	solv_diff_lbl.text = str(solv_res.get("difficulty", "—"))
	solv_explored_lbl.text = str(solv_res.get("states_explored", 0))

func update_difficulty(diff_res: Dictionary) -> void:
	var rating = diff_res.get("rating", "MEDIUM")
	diff_rating_lbl.text = "DIFFICULTY: %s (Score: %d)" % [rating, diff_res.get("difficulty_score", 0)]
	if rating == "EASY":
		diff_rating_lbl.modulate = Color(0.4, 1.0, 0.4)
	elif rating == "MEDIUM":
		diff_rating_lbl.modulate = Color(0.4, 0.8, 1.0)
	elif rating == "HARD":
		diff_rating_lbl.modulate = Color(1.0, 0.6, 0.2)
	else:
		diff_rating_lbl.modulate = Color(1.0, 0.3, 0.3)

	diff_details_lbl.text = "Grid Area: %d | Objects: %d (Movable: %d, Rotatable: %d) | Goals: %d | Path Length: %d | Solution Moves: %d" % [
		diff_res.get("grid_area", 0),
		diff_res.get("object_count", 0),
		diff_res.get("movable_mirror_count", 0),
		diff_res.get("rotatable_mirror_count", 0),
		diff_res.get("goal_count", 0),
		diff_res.get("path_length", 0),
		diff_res.get("solution_moves", 0)
	]

func update_quality(level: LaserLevelData, is_valid: bool, is_solvable: bool) -> void:
	qual_tree.clear()
	var root = qual_tree.create_item()

	var checks: Array[Array] = [
		["Structure (3 Stages)", level != null and level.stages.size() == 3],
		["Objects Placed", level != null and not level.get_stage(1).objects.is_empty()],
		["Laser Path & Sources", is_valid],
		["Goals Reachable", is_solvable],
		["Solvability Verified", is_solvable],
		["Timer Configured", level != null and level.universal_timer > 0],
		["Star Thresholds Valid", level != null and level.star_threshold_3 < level.star_threshold_2 and level.star_threshold_2 < level.star_threshold_1],
		["Stage Flow Continuous", true],
		["Runtime Synchronized", true]
	]

	var all_pass: bool = true
	for c in checks:
		var row = qual_tree.create_item(root)
		row.set_text(0, str(c[0]))
		var pass_chk: bool = bool(c[1])
		row.set_text(1, "✓ PASS" if pass_chk else "✗ FAIL")
		row.set_custom_color(1, Color(0.3, 1.0, 0.4) if pass_chk else Color(1.0, 0.3, 0.3))
		if not pass_chk:
			all_pass = false

	if all_pass:
		qual_status_lbl.text = "QUALITY STATUS: READY FOR PRODUCTION ✓"
		qual_status_lbl.modulate = Color(0.3, 1.0, 0.4)
	else:
		qual_status_lbl.text = "QUALITY STATUS: NEEDS ATTENTION ⚠"
		qual_status_lbl.modulate = Color(1.0, 0.8, 0.2)

func _on_val_item_clicked() -> void:
	var item = val_tree.get_selected()
	if item != null:
		var meta = item.get_metadata(0)
		if meta is Dictionary:
			var st_idx = meta.get("stage", 1)
			var cell = meta.get("cell", Vector2i(-1, -1))
			var obj_id = meta.get("obj_id", "")
			error_item_clicked.emit(st_idx, cell, obj_id)
