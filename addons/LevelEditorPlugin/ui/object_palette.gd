@tool
extends PanelContainer
class_name ObjectPalette

const SceneDropLineEdit = preload("res://addons/LevelEditorPlugin/ui/scene_drop_line_edit.gd")

signal tool_changed(tool_mode: GridCanvas.ToolMode)
signal palette_item_selected(type: LaserObjectData.ObjectType, rotation_deg: int, color: Color)
signal custom_element_selected(custom_data: Dictionary)
signal custom_elements_updated(elements: Array[Dictionary])

var current_tool_mode: GridCanvas.ToolMode = GridCanvas.ToolMode.SELECT
var selected_type: LaserObjectData.ObjectType = LaserObjectData.ObjectType.FIXED_MIRROR
var selected_rot: int = 0
var selected_color: Color = Color.RED

var tool_buttons: Dictionary = {}
var item_buttons: Dictionary = {}
var rot_spinbox: SpinBox
var color_picker_btn: ColorPickerButton

var custom_elements: Array[Dictionary] = []
var active_custom_index: int = 0
var custom_grid: GridContainer
var custom_buttons: Array[Button] = []
var add_custom_btn: Button
var remove_custom_btn: Button
var custom_name_edit: LineEdit
var custom_scene_edit: SceneDropLineEdit

func _init() -> void:
	custom_minimum_size = Vector2(210, 0)
	_setup_ui()

func _setup_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var header := Label.new()
	header.text = "🎨 PALETTE & TOOLS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	vbox.add_child(header)

	var tool_grid := _create_section(vbox, "EDIT TOOLS")
	_add_tool_btn(tool_grid, "Select (V)", GridCanvas.ToolMode.SELECT)
	_add_tool_btn(tool_grid, "Paint (B)", GridCanvas.ToolMode.PAINT)
	_add_tool_btn(tool_grid, "Move", GridCanvas.ToolMode.MOVE)
	_add_tool_btn(tool_grid, "Rotate (R)", GridCanvas.ToolMode.ROTATE)
	_add_tool_btn(tool_grid, "Erase (E)", GridCanvas.ToolMode.ERASE)

	var prop_hbox := HBoxContainer.new()
	prop_hbox.add_theme_constant_override("separation", 6)
	var rot_lbl := Label.new()
	rot_lbl.text = "Rot°:"
	rot_lbl.add_theme_font_size_override("font_size", 12)
	prop_hbox.add_child(rot_lbl)

	rot_spinbox = SpinBox.new()
	rot_spinbox.min_value = 0
	rot_spinbox.max_value = 315
	rot_spinbox.step = 45
	rot_spinbox.value = selected_rot
	rot_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rot_spinbox.value_changed.connect(_on_rot_changed)
	prop_hbox.add_child(rot_spinbox)

	color_picker_btn = ColorPickerButton.new()
	color_picker_btn.color = selected_color
	color_picker_btn.custom_minimum_size = Vector2(34, 26)
	color_picker_btn.color_changed.connect(_on_color_changed)
	prop_hbox.add_child(color_picker_btn)
	vbox.add_child(prop_hbox)

	var basic_grid := _create_section(vbox, "MIRRORS & AREAS")
	_add_item_btn(basic_grid, "🪞 Fixed Mirror", LaserObjectData.ObjectType.FIXED_MIRROR)
	_add_item_btn(basic_grid, "↔️ Movable Mirror", LaserObjectData.ObjectType.MOVABLE_MIRROR)
	_add_item_btn(basic_grid, "🔄 Rotatable Mirror", LaserObjectData.ObjectType.ROTATABLE_MIRROR)
	_add_item_btn(basic_grid, "🟦 Movable Area", LaserObjectData.ObjectType.MOVABLE_AREA)

	var block_grid := _create_section(vbox, "BLOCKERS & BEAM")
	_add_item_btn(block_grid, "🪨 Rock", LaserObjectData.ObjectType.ROCK)
	_add_item_btn(block_grid, "🧊 Ice", LaserObjectData.ObjectType.ICE)
	_add_item_btn(block_grid, "🔱 Splitter", LaserObjectData.ObjectType.SPLITTER)
	_add_item_btn(block_grid, "🪟 Color Glass", LaserObjectData.ObjectType.COLOR_GLASS)
	_add_item_btn(block_grid, "🧱 Color Wall", LaserObjectData.ObjectType.COLOR_WALL)
	_add_item_btn(block_grid, "🔴 Laser", LaserObjectData.ObjectType.LASER_SOURCE)

	var logic_grid := _create_section(vbox, "LOGIC")
	_add_item_btn(logic_grid, "🚪 Entry Gate", LaserObjectData.ObjectType.GATE)
	_add_item_btn(logic_grid, "🚪 Exit Gate", LaserObjectData.ObjectType.EXIT_GATE)
	_add_item_btn(logic_grid, "🔘 Switch", LaserObjectData.ObjectType.SWITCH)
	_add_item_btn(logic_grid, "⚡ Gate with switch", LaserObjectData.ObjectType.GATE_SWITCH)

	custom_grid = _create_section(vbox, "CUSTOM ELEMENTS")

	var custom_action_hbox := HBoxContainer.new()
	custom_action_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(custom_action_hbox)

	add_custom_btn = Button.new()
	add_custom_btn.text = " ➕ Add Element "
	add_custom_btn.tooltip_text = "Add a new custom element to the palette"
	add_custom_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_custom_btn.custom_minimum_size = Vector2(0, 30)
	add_custom_btn.pressed.connect(_on_add_custom_element_pressed)
	custom_action_hbox.add_child(add_custom_btn)

	remove_custom_btn = Button.new()
	remove_custom_btn.text = " 🗑️ Delete "
	remove_custom_btn.tooltip_text = "Delete currently selected custom element"
	remove_custom_btn.custom_minimum_size = Vector2(70, 30)
	remove_custom_btn.pressed.connect(_on_remove_custom_element_pressed)
	custom_action_hbox.add_child(remove_custom_btn)

	var elem_detail_vbox := VBoxContainer.new()
	elem_detail_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(elem_detail_vbox)

	var name_row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = "Name:"
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_row.add_child(name_lbl)
	custom_name_edit = LineEdit.new()
	custom_name_edit.placeholder_text = "Custom Name (e.g. Bomb)"
	custom_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_name_edit.text_changed.connect(_on_custom_name_edited)
	name_row.add_child(custom_name_edit)
	elem_detail_vbox.add_child(name_row)

	var scene_row := HBoxContainer.new()
	var scene_lbl := Label.new()
	scene_lbl.text = "Scene:"
	scene_lbl.add_theme_font_size_override("font_size", 11)
	scene_row.add_child(scene_lbl)
	custom_scene_edit = SceneDropLineEdit.new()
	custom_scene_edit.placeholder_text = "Drag .tscn file or browse"
	custom_scene_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_scene_edit.tooltip_text = "Drag & drop a .tscn file here or click 📁 to browse"
	custom_scene_edit.text_changed.connect(_on_custom_scene_edited)
	custom_scene_edit.scene_dropped.connect(_on_custom_scene_dropped)
	scene_row.add_child(custom_scene_edit)

	var browse_btn := Button.new()
	browse_btn.text = "📁"
	browse_btn.tooltip_text = "Browse scene file (.tscn)"
	browse_btn.custom_minimum_size = Vector2(28, 0)
	browse_btn.pressed.connect(_on_browse_scene_pressed)
	scene_row.add_child(browse_btn)
	elem_detail_vbox.add_child(scene_row)

	_load_and_rebuild_custom_elements()
	_update_tool_highlights()
	_update_item_highlights()

func _create_section(parent: Control, title: String) -> GridContainer:
	var sec_lbl := Label.new()
	sec_lbl.text = "— " + title + " —"
	sec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sec_lbl.add_theme_font_size_override("font_size", 11)
	sec_lbl.modulate = Color(0.7, 0.75, 0.85)
	parent.add_child(sec_lbl)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	return grid

func _add_tool_btn(parent: Control, text: String, mode: GridCanvas.ToolMode) -> void:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 30)
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(func():
		select_tool(mode)
	)
	parent.add_child(btn)
	tool_buttons[mode] = btn

func _add_item_btn(parent: Control, text: String, type: LaserObjectData.ObjectType) -> void:
	var btn := Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 30)
	btn.add_theme_font_size_override("font_size", 12)
	btn.clip_text = true
	btn.pressed.connect(func():
		select_item(type)
	)
	parent.add_child(btn)
	item_buttons[type] = btn

func _load_and_rebuild_custom_elements() -> void:
	custom_elements = CustomElementsManager.load_elements()
	_rebuild_custom_buttons()
	if not custom_elements.is_empty():
		select_custom_element(0)
	else:
		if custom_name_edit != null:
			custom_name_edit.text = ""
			custom_name_edit.editable = false
		if custom_scene_edit != null:
			custom_scene_edit.text = ""
			custom_scene_edit.editable = false

func _rebuild_custom_buttons() -> void:
	for btn in custom_buttons:
		btn.queue_free()
	custom_buttons.clear()

	for i in range(custom_elements.size()):
		var elem = custom_elements[i]
		var btn := Button.new()
		btn.text = "✨ " + str(elem.get("name", "Custom %d" % (i + 1)))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 30)
		btn.add_theme_font_size_override("font_size", 12)
		btn.clip_text = true
		var idx = i
		btn.pressed.connect(func():
			select_custom_element(idx)
		)
		custom_grid.add_child(btn)
		custom_buttons.append(btn)

	if remove_custom_btn != null:
		remove_custom_btn.disabled = custom_elements.is_empty()

	_update_item_highlights()

func select_tool(mode: GridCanvas.ToolMode) -> void:
	current_tool_mode = mode
	_update_tool_highlights()
	tool_changed.emit(mode)

func select_item(type: LaserObjectData.ObjectType) -> void:
	if type == LaserObjectData.ObjectType.CUSTOM:
		if not custom_elements.is_empty():
			select_custom_element(active_custom_index)
			return
	selected_type = type
	if type == LaserObjectData.ObjectType.MOVABLE_AREA:
		if selected_color == Color.RED or selected_color == Color(1.0, 0.2, 0.2, 1.0):
			selected_color = Color(0.2, 0.65, 1.0, 1.0)
			if color_picker_btn != null:
				color_picker_btn.color = selected_color
	if custom_name_edit != null:
		custom_name_edit.editable = false
	if custom_scene_edit != null:
		custom_scene_edit.editable = false
	_update_item_highlights()
	select_tool(GridCanvas.ToolMode.PAINT)
	palette_item_selected.emit(selected_type, selected_rot, selected_color)

func select_custom_element(idx: int) -> void:
	if custom_elements.is_empty():
		return
	active_custom_index = clamp(idx, 0, custom_elements.size() - 1)
	var elem = custom_elements[active_custom_index]
	selected_type = LaserObjectData.ObjectType.CUSTOM
	selected_color = elem.get("color", Color(0.95, 0.6, 0.2))
	if color_picker_btn != null:
		color_picker_btn.color = selected_color

	if custom_name_edit != null:
		custom_name_edit.editable = true
		custom_name_edit.text = str(elem.get("name", "Custom %d" % (active_custom_index + 1)))
	if custom_scene_edit != null:
		custom_scene_edit.editable = true
		custom_scene_edit.text = str(elem.get("scene_path", ""))

	_update_item_highlights()
	select_tool(GridCanvas.ToolMode.PAINT)
	custom_element_selected.emit(elem)
	palette_item_selected.emit(selected_type, selected_rot, selected_color)

func _on_custom_name_edited(new_text: String) -> void:
	if active_custom_index >= 0 and active_custom_index < custom_elements.size():
		var final_name := new_text.strip_edges()
		custom_elements[active_custom_index]["name"] = final_name if not final_name.is_empty() else ("Custom %d" % (active_custom_index + 1))
		CustomElementsManager.save_elements(custom_elements)
		if active_custom_index < custom_buttons.size():
			custom_buttons[active_custom_index].text = "✨ " + custom_elements[active_custom_index]["name"]
		custom_element_selected.emit(custom_elements[active_custom_index])
		custom_elements_updated.emit(custom_elements)

func _on_custom_scene_edited(new_path: String) -> void:
	if active_custom_index >= 0 and active_custom_index < custom_elements.size():
		custom_elements[active_custom_index]["scene_path"] = new_path.strip_edges()
		CustomElementsManager.save_elements(custom_elements)
		custom_element_selected.emit(custom_elements[active_custom_index])
		custom_elements_updated.emit(custom_elements)

func _on_custom_scene_dropped(new_path: String) -> void:
	if active_custom_index >= 0 and active_custom_index < custom_elements.size():
		var clean_path := new_path.strip_edges()
		custom_elements[active_custom_index]["scene_path"] = clean_path
		if custom_scene_edit != null and custom_scene_edit.text != clean_path:
			custom_scene_edit.text = clean_path
		var cur_name: String = str(custom_elements[active_custom_index].get("name", "")).strip_edges()
		if cur_name.is_empty() or cur_name.begins_with("Custom ") or cur_name == "Custom":
			var base_name := clean_path.get_file().get_basename()
			if not base_name.is_empty():
				custom_elements[active_custom_index]["name"] = base_name
				if custom_name_edit != null:
					custom_name_edit.text = base_name
				if active_custom_index < custom_buttons.size():
					custom_buttons[active_custom_index].text = "✨ " + base_name
		CustomElementsManager.save_elements(custom_elements)
		custom_element_selected.emit(custom_elements[active_custom_index])
		custom_elements_updated.emit(custom_elements)

func _on_browse_scene_pressed() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.add_filter("*.tscn, *.scn", "Godot Scene Files")
	fd.title = "Select Custom Scene"
	fd.file_selected.connect(func(path: String):
		_on_custom_scene_dropped(path)
		fd.queue_free()
	)
	fd.canceled.connect(func(): fd.queue_free())
	add_child(fd)
	fd.popup_centered(Vector2(600, 400))

func reload_custom_elements() -> void:
	custom_elements = CustomElementsManager.load_elements()
	if active_custom_index >= custom_elements.size():
		active_custom_index = max(0, custom_elements.size() - 1)
	_rebuild_custom_buttons()
	if not custom_elements.is_empty():
		select_custom_element(active_custom_index)
	else:
		if custom_name_edit != null:
			custom_name_edit.text = ""
			custom_name_edit.editable = false
		if custom_scene_edit != null:
			custom_scene_edit.text = ""
			custom_scene_edit.editable = false

func _on_add_custom_element_pressed() -> void:
	var _new_elem = CustomElementsManager.add_new_element(custom_elements)
	active_custom_index = custom_elements.size() - 1
	_rebuild_custom_buttons()
	select_custom_element(active_custom_index)
	custom_elements_updated.emit(custom_elements)

func _on_remove_custom_element_pressed() -> void:
	if custom_elements.is_empty():
		return
	if CustomElementsManager.remove_element(custom_elements, active_custom_index):
		if custom_elements.is_empty():
			active_custom_index = 0
			_rebuild_custom_buttons()
			if custom_name_edit != null:
				custom_name_edit.text = ""
				custom_name_edit.editable = false
			if custom_scene_edit != null:
				custom_scene_edit.text = ""
				custom_scene_edit.editable = false
			select_item(LaserObjectData.ObjectType.ROCK)
		else:
			active_custom_index = clamp(active_custom_index, 0, custom_elements.size() - 1)
			_rebuild_custom_buttons()
			select_custom_element(active_custom_index)
		custom_elements_updated.emit(custom_elements)

func _on_rot_changed(val: float) -> void:
	selected_rot = int(val)
	palette_item_selected.emit(selected_type, selected_rot, selected_color)

func _on_color_changed(col: Color) -> void:
	selected_color = col
	if selected_type == LaserObjectData.ObjectType.CUSTOM and active_custom_index < custom_elements.size():
		custom_elements[active_custom_index]["color"] = col
		CustomElementsManager.save_elements(custom_elements)
		custom_elements_updated.emit(custom_elements)
	palette_item_selected.emit(selected_type, selected_rot, selected_color)

func _update_tool_highlights() -> void:
	for mode in tool_buttons.keys():
		var btn: Button = tool_buttons[mode]
		if mode == current_tool_mode:
			btn.modulate = Color(1.2, 1.2, 0.6)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0)

func _update_item_highlights() -> void:
	for type in item_buttons.keys():
		var btn: Button = item_buttons[type]
		if type == selected_type and current_tool_mode == GridCanvas.ToolMode.PAINT and selected_type != LaserObjectData.ObjectType.CUSTOM:
			btn.modulate = Color(0.8, 1.2, 0.8)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0)

	for i in range(custom_buttons.size()):
		var btn = custom_buttons[i]
		if selected_type == LaserObjectData.ObjectType.CUSTOM and i == active_custom_index and current_tool_mode == GridCanvas.ToolMode.PAINT:
			btn.modulate = Color(1.2, 1.2, 0.6)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0)

	if remove_custom_btn != null:
		remove_custom_btn.disabled = custom_elements.is_empty()
