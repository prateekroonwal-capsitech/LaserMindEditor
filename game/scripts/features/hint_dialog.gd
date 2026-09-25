@tool
extends CanvasLayer
class_name HintDialog

signal opened
signal closed

var current_stage: LaserStageData = null
var is_active: bool = false

var overlay: Control
var dim_bg: ColorRect
var card: Control
var close_btn: Button

var card_rect: Rect2 = Rect2()
var grid_card_origin: Vector2 = Vector2.ZERO
var cell_card_size: Vector2 = Vector2.ZERO

func _init() -> void:
	layer = 25
	visible = false
	_setup_ui()

func _setup_ui() -> void:
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	dim_bg = ColorRect.new()
	dim_bg.name = "DimBackground"
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.65)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim_bg)

	card = Control.new()
	card.name = "Card"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.draw.connect(_on_card_draw)
	overlay.add_child(card)

	close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "✕"
	close_btn.flat = false
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.92, 0.94, 0.97, 0.95)
	btn_normal.set_corner_radius_all(18)
	btn_normal.border_color = Color(0.75, 0.80, 0.88, 0.8)
	btn_normal.set_border_width_all(1)
	close_btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(1.0, 0.4, 0.4, 0.95)
	btn_hover.set_corner_radius_all(18)
	btn_hover.border_color = Color(0.9, 0.2, 0.2, 1.0)
	btn_hover.set_border_width_all(1)
	close_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.8, 0.2, 0.2, 1.0)
	btn_pressed.set_corner_radius_all(18)
	close_btn.add_theme_stylebox_override("pressed", btn_pressed)

	close_btn.add_theme_color_override("font_color", Color(0.3, 0.35, 0.45))
	close_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	close_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(close_hint)
	overlay.add_child(close_btn)

func open_hint(stage: LaserStageData) -> void:
	current_stage = stage
	is_active = true
	visible = true

	_recalculate_layout()

	if is_inside_tree():
		dim_bg.modulate.a = 0.0
		card.modulate.a = 0.0
		card.scale = Vector2(0.88, 0.88)
		close_btn.modulate.a = 0.0

		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(dim_bg, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(close_btn, "modulate:a", 1.0, 0.2)
	else:
		dim_bg.modulate.a = 1.0
		card.modulate.a = 1.0
		card.scale = Vector2.ONE
		close_btn.modulate.a = 1.0

	card.queue_redraw()
	opened.emit()

func close_hint() -> void:
	if not is_active:
		return
	is_active = false

	if is_inside_tree():
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(dim_bg, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(card, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(card, "scale", Vector2(0.9, 0.9), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(close_btn, "modulate:a", 0.0, 0.12)
		tw.chain().tween_callback(func():
			visible = false
			closed.emit()
		)
	else:
		visible = false
		closed.emit()

func is_open() -> bool:
	return is_active and visible

func _recalculate_layout() -> void:
	var vp_size: Vector2 = overlay.get_viewport_rect().size if overlay.is_inside_tree() else Vector2(1080, 1920)
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2(1080, 1920)

	var gw: int = current_stage.grid_width if current_stage != null else 6
	var gh: int = current_stage.grid_height if current_stage != null else 10
	gw = max(1, gw)
	gh = max(1, gh)

	var max_w: float = minf(vp_size.x * 0.86, 880.0)
	var max_h: float = minf(vp_size.y * 0.80, 1300.0)

	var cell_dim: float = minf(max_w / float(gw), max_h / float(gh))
	cell_dim = maxf(cell_dim, 20.0)
	cell_card_size = Vector2(cell_dim, cell_dim)

	var card_w: float = float(gw) * cell_dim
	var card_h: float = float(gh) * cell_dim

	var card_x: float = (vp_size.x - card_w) * 0.5
	var card_y: float = (vp_size.y - card_h) * 0.5

	card_rect = Rect2(card_x, card_y, card_w, card_h)
	grid_card_origin = Vector2.ZERO

	card.position = Vector2(card_x, card_y)
	card.size = Vector2(card_w, card_h)
	card.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)

	if close_btn != null:
		close_btn.position = Vector2(card_x + card_w - 44.0, card_y + 10.0)

func _on_card_draw() -> void:
	if current_stage == null:
		return

	var c_sz := card.size

	# 1. Subtle drop shadow
	for s_idx in range(4):
		var s_rect := Rect2(Vector2(2 + s_idx * 2, 4 + s_idx * 2), c_sz)
		card.draw_rect(s_rect, Color(0.0, 0.0, 0.0, 0.07 - s_idx * 0.014), true)

	# 2. Plain White Page Background (Exact Grid Proportions, No Grid Lines)
	var page_rect := Rect2(Vector2.ZERO, c_sz)
	card.draw_rect(page_rect, Color(0.98, 0.98, 1.0, 1.0), true)
	card.draw_rect(page_rect, Color(0.80, 0.84, 0.90, 1.0), false, 2.0)

	# 3. Clean Continuous Laser Path (No checkpoint markers, no start/end circles, no diamonds)
	var pts: Array[Vector2i] = current_stage.hint_path_points
	if pts.is_empty():
		var font: Font = ThemeDB.fallback_font
		var no_hint_txt := "No Hint Available"
		card.draw_string(font, Vector2(0, c_sz.y * 0.5), no_hint_txt, HORIZONTAL_ALIGNMENT_CENTER, int(c_sz.x), 16, Color(0.55, 0.60, 0.70))
		return

	var h_col: Color = current_stage.hint_laser_color
	var h_op: float = clampf(current_stage.hint_laser_opacity, 0.0, 1.0)
	var base_width: float = maxf(1.0, current_stage.hint_laser_width)
	var scale_factor: float = cell_card_size.x / 48.0
	var eff_width: float = maxf(2.0, base_width * scale_factor)
	var eff_col := Color(h_col.r, h_col.g, h_col.b, h_col.a * h_op)

	# Draw multi-layer continuous laser line
	if pts.size() >= 2:
		for i in range(pts.size() - 1):
			var p1 := _grid_to_card(pts[i])
			var p2 := _grid_to_card(pts[i + 1])

			# Outer glow
			card.draw_line(p1, p2, Color(eff_col.r, eff_col.g, eff_col.b, eff_col.a * 0.35), eff_width * 2.2, true)
			# Main laser beam
			card.draw_line(p1, p2, eff_col, eff_width, true)
			# Bright inner core
			card.draw_line(p1, p2, Color(1.0, 1.0, 1.0, eff_col.a * 0.9), maxf(1.0, eff_width * 0.35), true)
	elif pts.size() == 1:
		var p_center := _grid_to_card(pts[0])
		card.draw_circle(p_center, eff_width * 0.8, eff_col)

func _grid_to_card(pt: Vector2i) -> Vector2:
	return (Vector2(pt) + Vector2(0.5, 0.5)) * cell_card_size
