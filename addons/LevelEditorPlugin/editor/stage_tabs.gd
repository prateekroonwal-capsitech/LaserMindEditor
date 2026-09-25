@tool
extends PanelContainer
class_name StageTabs

signal stage_selected(stage_index: int)
signal stage_copied(stage_index: int)
signal stage_pasted(stage_index: int, before_snapshot: LaserStageData)
signal stage_cleared(stage_index: int, before_snapshot: LaserStageData)
signal stage_added(new_stage_index: int)
signal stage_removed(new_active_index: int)

var current_level: LaserLevelData = null
var active_stage_idx: int = 1

var tabs_container: HBoxContainer
var tab_buttons: Array[Button] = []
var add_stage_btn: Button
var remove_stage_btn: Button
var flow_preview_panel: PanelContainer
var flow_label: Label
var clipboard_stage_data: LaserStageData = null

func _init() -> void:
	custom_minimum_size = Vector2(0, 42)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()

func _setup_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var main_hbox := HBoxContainer.new()
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 8)
	scroll.add_child(main_hbox)

	var lbl := Label.new()
	lbl.text = "STAGES:"
	lbl.add_theme_font_size_override("font_size", 13)
	main_hbox.add_child(lbl)

	tabs_container = HBoxContainer.new()
	tabs_container.add_theme_constant_override("separation", 6)
	main_hbox.add_child(tabs_container)

	add_stage_btn = Button.new()
	add_stage_btn.text = " + Add Stage "
	add_stage_btn.tooltip_text = "Add a new stage to this level"
	add_stage_btn.custom_minimum_size = Vector2(90, 30)
	add_stage_btn.pressed.connect(_on_add_stage_pressed)
	main_hbox.add_child(add_stage_btn)

	remove_stage_btn = Button.new()
	remove_stage_btn.text = " Delete Stage "
	remove_stage_btn.tooltip_text = "Delete currently active stage (level must retain at least 1 stage)"
	remove_stage_btn.custom_minimum_size = Vector2(95, 30)
	remove_stage_btn.pressed.connect(_on_remove_stage_pressed)
	main_hbox.add_child(remove_stage_btn)

	main_hbox.add_child(VSeparator.new())

	var copy_btn := Button.new()
	copy_btn.text = "Copy Stage"
	copy_btn.pressed.connect(_on_copy_stage)
	main_hbox.add_child(copy_btn)

	var paste_btn := Button.new()
	paste_btn.text = "Paste Stage"
	paste_btn.pressed.connect(_on_paste_stage)
	main_hbox.add_child(paste_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear Stage"
	clear_btn.pressed.connect(_on_clear_stage)
	main_hbox.add_child(clear_btn)

	main_hbox.add_child(VSeparator.new())

	flow_label = Label.new()
	flow_label.text = "Stage 1  ➜ [Camera Flow] ➜  Stage 2 ..."
	flow_label.modulate = Color(0.4, 0.9, 1.0)
	flow_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow_label.clip_text = true
	flow_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	main_hbox.add_child(flow_label)

	_rebuild_tabs()

func set_level(level: LaserLevelData) -> void:
	current_level = level
	if current_level != null:
		current_level.ensure_stages()
	active_stage_idx = 1
	_rebuild_tabs()
	_update_flow_text()

func select_stage(stage_idx: int) -> void:
	var max_stages: int = current_level.get_stage_count() if current_level != null else 1
	active_stage_idx = clamp(stage_idx, 1, max_stages)
	_update_tabs()
	stage_selected.emit(active_stage_idx)

func _rebuild_tabs() -> void:
	for btn in tab_buttons:
		btn.queue_free()
	tab_buttons.clear()

	var count: int = current_level.get_stage_count() if current_level != null else 3
	for i in range(1, count + 1):
		var btn := Button.new()
		btn.text = "  Stage %d  " % i
		btn.custom_minimum_size = Vector2(85, 30)
		var idx: int = i
		btn.pressed.connect(func(): select_stage(idx))
		tabs_container.add_child(btn)
		tab_buttons.append(btn)

	if remove_stage_btn != null:
		remove_stage_btn.disabled = (count <= 1)

	_update_tabs()

func _update_tabs() -> void:
	for i in range(tab_buttons.size()):
		var btn = tab_buttons[i]
		var stage_num = i + 1
		if stage_num == active_stage_idx:
			btn.modulate = Color(1.2, 1.2, 0.6)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0)

	if remove_stage_btn != null and current_level != null:
		remove_stage_btn.disabled = (current_level.get_stage_count() <= 1)

func _update_flow_text() -> void:
	if current_level == null:
		return

	var count: int = current_level.get_stage_count()
	var parts: Array[String] = []
	for i in range(1, count + 1):
		var st = current_level.get_stage(i)
		parts.append("Stage %d (%dx%d)" % [i, st.grid_width, st.grid_height])
		if i < count:
			var dir = LaserStageData.DIRECTION_NAMES.get(st.exit_direction, "Right")
			parts.append("➜ [%s Flow] ➜" % dir)

	flow_label.text = " ".join(parts)

func _on_add_stage_pressed() -> void:
	if current_level == null:
		return
	var _new_stage = current_level.add_stage()
	active_stage_idx = current_level.get_stage_count()
	_rebuild_tabs()
	_update_flow_text()
	stage_added.emit(active_stage_idx)
	stage_selected.emit(active_stage_idx)

func _on_remove_stage_pressed() -> void:
	if current_level == null or current_level.get_stage_count() <= 1:
		return
	var removed_idx = active_stage_idx
	if current_level.remove_stage(removed_idx):
		active_stage_idx = clamp(removed_idx, 1, current_level.get_stage_count())
		_rebuild_tabs()
		_update_flow_text()
		stage_removed.emit(active_stage_idx)
		stage_selected.emit(active_stage_idx)

func _on_copy_stage() -> void:
	if current_level != null:
		var st = current_level.get_stage(active_stage_idx)
		clipboard_stage_data = st.duplicate_data()
		stage_copied.emit(active_stage_idx)

func _on_paste_stage() -> void:
	if current_level != null and clipboard_stage_data != null:
		var target_stage = current_level.get_stage(active_stage_idx)
		var snap = target_stage.duplicate_data()
		target_stage.grid_width = clipboard_stage_data.grid_width
		target_stage.grid_height = clipboard_stage_data.grid_height
		target_stage.time_limit = clipboard_stage_data.time_limit
		target_stage.time_bonus = clipboard_stage_data.time_bonus
		target_stage.objects.clear()
		for obj in clipboard_stage_data.objects:
			if obj != null:
				target_stage.objects.append(obj.duplicate_data())
		_update_flow_text()
		stage_pasted.emit(active_stage_idx, snap)

func _on_clear_stage() -> void:
	if current_level != null:
		var target_stage = current_level.get_stage(active_stage_idx)
		var snap = target_stage.duplicate_data()
		target_stage.clear_all_objects()
		stage_cleared.emit(active_stage_idx, snap)
