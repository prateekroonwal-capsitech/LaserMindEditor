@tool
extends EditorPlugin

var main_panel_instance: Control

func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		return

	var scene: PackedScene = preload("res://addons/LevelEditorPlugin/editor/editor_main.tscn")
	main_panel_instance = scene.instantiate() as Control
	main_panel_instance.name = "Laser Mind Editor"
	main_panel_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_panel_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL

	EditorInterface.get_editor_main_screen().add_child(main_panel_instance)
	_make_visible(false)

func _exit_tree() -> void:
	if main_panel_instance != null:
		main_panel_instance.queue_free()
		main_panel_instance = null

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if main_panel_instance != null:
		main_panel_instance.visible = visible

func _get_plugin_name() -> String:
	return "⚡ Laser Mind Editor"

func _get_plugin_icon() -> Texture2D:
	if EditorInterface != null and EditorInterface.get_editor_theme() != null:
		return EditorInterface.get_editor_theme().get_icon("RayCast2D", "EditorIcons")
	return null
