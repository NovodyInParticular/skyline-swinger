extends CanvasLayer
class_name GameUI
## Every screen, built in code: title, HUD with crosshair, pause menu, game over, and a toast line.

signal start_requested
signal resume_requested
signal restart_requested
signal title_requested

const TEAL := Color(0.1, 0.82, 0.76)
const ORANGE := Color(1.0, 0.52, 0.15)
const SOFT := Color(0.8, 0.84, 0.9)
const CONTROLS := "Mouse  look        Hold LMB  grapple        WASD  steer / pump / walk\nSpace  jump        Q / E  reel in / out        Shift  air dash\nEsc  pause        M  mute        R  restart after a fall"


## Centre-screen reticle; turns orange when the grapple would hit something.
class Crosshair extends Control:
	var active := false:
		set(value):
			if value != active:
				active = value
				queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var col := Color(1.0, 0.55, 0.15) if active else Color(1.0, 1.0, 1.0, 0.65)
		draw_arc(c, 10.0, 0.0, TAU, 32, col, 2.0, true)
		draw_circle(c, 2.0, col)
		if active:
			for i in 4:
				var d := Vector2.RIGHT.rotated(i * PI / 2.0)
				draw_line(c + d * 14.0, c + d * 20.0, col, 2.0, true)


var _title: Control
var _hud: Control
var _pause: Control
var _game_over: Control
var _start_button: Button
var _resume_button: Button
var _restart_button: Button
var _title_best: Label
var _score_label: Label
var _best_label: Label
var _speed_label: Label
var _dash_bar: ProgressBar
var _crosshair: Crosshair
var _toast: Label
var _toast_time := 0.0
var _go_reason: Label
var _go_score: Label
var _go_best: Label
var _go_record: Label
var _sensitivity: HSlider
var _volume: HSlider
var _mute: CheckButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_build_title()
	_build_pause()
	_build_game_over()
	_build_toast()
	_show_only(null)


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.4, 0.0, 1.0)


func show_title(best: int) -> void:
	_show_only(_title)
	_title_best.text = "Best score: %d" % best
	_start_button.grab_focus()


func show_hud() -> void:
	_show_only(_hud)


func show_pause() -> void:
	_pause.visible = true
	_sensitivity.set_value_no_signal(Settings.mouse_sensitivity)
	_volume.set_value_no_signal(Settings.volume)
	_mute.set_pressed_no_signal(Settings.muted)
	_resume_button.grab_focus()


func hide_pause() -> void:
	_pause.visible = false


func show_game_over(score: int, best: int, new_record: bool, reason: String) -> void:
	_pause.visible = false
	_game_over.visible = true
	_crosshair.visible = false
	_go_reason.text = reason
	_go_score.text = "Score: %d" % score
	_go_best.text = "Best: %d" % best
	_go_record.visible = new_record
	_restart_button.grab_focus()


func update_hud(score: int, best: int, speed: float, dash_ready: float, aim_valid: bool) -> void:
	_score_label.text = "Score  %d" % score
	_best_label.text = "Best  %d" % best
	_speed_label.text = "%d km/h" % int(speed * 3.6)
	_dash_bar.value = dash_ready
	_crosshair.active = aim_valid


func toast(text: String) -> void:
	_toast.text = text
	_toast_time = 1.6
	_toast.modulate.a = 1.0


func _show_only(screen: Control) -> void:
	for s: Control in [_title, _hud, _pause, _game_over]:
		s.visible = s == screen
	_crosshair.visible = screen == _hud


# --- Screens -------------------------------------------------------------------

func _build_title() -> void:
	_title = _screen(Color(0.0, 0.0, 0.03, 0.35))
	var box := _panel(_title)
	box.add_child(_label("SKYLINE SWINGER", 60, TEAL))
	box.add_child(_label("Grapple. Swing. Never touch the street.", 20, SOFT))
	_start_button = _button("Start run", func() -> void: start_requested.emit())
	box.add_child(_start_button)
	box.add_child(_button("Quit", func() -> void: get_tree().quit()))
	_title_best = _label("", 18, ORANGE)
	box.add_child(_title_best)
	box.add_child(_label(CONTROLS, 14, SOFT))


func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)

	var stats := VBoxContainer.new()
	stats.position = Vector2(24.0, 16.0)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(stats)
	_score_label = _label("", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_best_label = _label("", 18, ORANGE, HORIZONTAL_ALIGNMENT_LEFT)
	_speed_label = _label("", 18, TEAL, HORIZONTAL_ALIGNMENT_LEFT)
	for l in [_score_label, _best_label, _speed_label]:
		stats.add_child(l)

	var hint := _label("Esc pause  ·  M mute", 14, SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hint.offset_left = -320.0
	hint.offset_right = -20.0
	hint.offset_top = 18.0
	_hud.add_child(hint)

	_crosshair = Crosshair.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_box(_crosshair, Vector2(48.0, 48.0), Vector2.ZERO)
	add_child(_crosshair)   # outside _hud so it can be hidden on its own

	var dash_label := _label("DASH", 12, SOFT)
	_center_box(dash_label, Vector2(220.0, 16.0), Vector2(0.0, 0.0))
	dash_label.anchor_top = 1.0
	dash_label.anchor_bottom = 1.0
	dash_label.offset_top = -74.0
	dash_label.offset_bottom = -58.0
	_hud.add_child(dash_label)
	_dash_bar = ProgressBar.new()
	_dash_bar.max_value = 1.0
	_dash_bar.show_percentage = false
	_dash_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_box(_dash_bar, Vector2(220.0, 10.0), Vector2.ZERO)
	_dash_bar.anchor_top = 1.0
	_dash_bar.anchor_bottom = 1.0
	_dash_bar.offset_top = -52.0
	_dash_bar.offset_bottom = -42.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = ORANGE
	fill.set_corner_radius_all(4)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1.0, 1.0, 1.0, 0.12)
	back.set_corner_radius_all(4)
	_dash_bar.add_theme_stylebox_override("fill", fill)
	_dash_bar.add_theme_stylebox_override("background", back)
	_hud.add_child(_dash_bar)


func _build_pause() -> void:
	_pause = _screen(Color(0.0, 0.0, 0.03, 0.55))
	var box := _panel(_pause)
	box.add_child(_label("PAUSED", 44, TEAL))
	_sensitivity = _slider_row(box, "Mouse sensitivity", 0.03, 1.0, 0.01)
	_sensitivity.value_changed.connect(_on_sensitivity_changed)
	_volume = _slider_row(box, "Volume", 0.0, 1.0, 0.01)
	_volume.value_changed.connect(_on_volume_changed)
	_mute = CheckButton.new()
	_mute.text = "Mute (M)"
	_mute.add_theme_font_size_override("font_size", 18)
	_mute.toggled.connect(_on_mute_toggled)
	box.add_child(_mute)
	_resume_button = _button("Resume", func() -> void: resume_requested.emit())
	box.add_child(_resume_button)
	box.add_child(_button("Quit to title", func() -> void: title_requested.emit()))


func _build_game_over() -> void:
	_game_over = _screen(Color(0.08, 0.0, 0.02, 0.55))
	var box := _panel(_game_over)
	box.add_child(_label("RUN OVER", 48, ORANGE))
	_go_reason = _label("", 20, SOFT)
	_go_score = _label("", 30, Color.WHITE)
	_go_best = _label("", 20, TEAL)
	_go_record = _label("New high score!", 22, ORANGE)
	for l in [_go_reason, _go_score, _go_best, _go_record]:
		box.add_child(l)
	_restart_button = _button("Restart  (R)", func() -> void: restart_requested.emit())
	box.add_child(_restart_button)
	box.add_child(_button("Title screen", func() -> void: title_requested.emit()))


func _build_toast() -> void:
	_toast = _label("", 22, Color.WHITE)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -200.0
	_toast.offset_right = 200.0
	_toast.offset_top = 70.0
	_toast.modulate.a = 0.0
	add_child(_toast)


func _on_sensitivity_changed(value: float) -> void:
	Settings.mouse_sensitivity = value
	Settings.save_settings()


func _on_volume_changed(value: float) -> void:
	Settings.volume = value
	Settings.apply_audio()
	Settings.save_settings()


func _on_mute_toggled(on: bool) -> void:
	if on != Settings.muted:
		Settings.toggle_mute()


# --- Builders --------------------------------------------------------------------

func _screen(dim: Color) -> Control:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = dim
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(shade)
	add_child(screen)
	return screen


func _panel(screen: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.08, 0.88)
	style.border_color = ORANGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(28.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	return box


func _label(text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280.0, 44.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(func() -> void: Sfx.play("click"))
	button.pressed.connect(on_pressed)
	return button


func _slider_row(parent: Container, text: String, min_value: float, max_value: float, step: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := _label(text, 18, SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	label.custom_minimum_size = Vector2(190.0, 0.0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.custom_minimum_size = Vector2(240.0, 24.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	parent.add_child(row)
	return slider


## Anchors `control` to the screen centre with the given size and offset.
func _center_box(control: Control, box_size: Vector2, offset: Vector2) -> void:
	control.anchor_left = 0.5
	control.anchor_right = 0.5
	control.anchor_top = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = offset.x - box_size.x * 0.5
	control.offset_right = offset.x + box_size.x * 0.5
	control.offset_top = offset.y - box_size.y * 0.5
	control.offset_bottom = offset.y + box_size.y * 0.5
