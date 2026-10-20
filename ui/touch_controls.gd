extends Control
class_name TouchControls
## On-screen controls for phones: a floating move stick on the left half, drag-to-look on the
## right half, and round buttons. Grapple is tap-to-fire / tap-to-let-go so the thumb stays free.

const STICK_RADIUS := 90.0
const STICK_DEAD_ZONE := 0.15
const LOOK_SCALE := 0.6           # times Settings.mouse_sensitivity, per screen pixel dragged
const GRAPPLE_TRY_TIME := 0.25    # how long a grapple tap keeps trying to latch on
const PAD_SLOP := 1.25            # touches this far past a button's edge still count
const ORANGE := Color(1.0, 0.52, 0.15)
const TEAL := Color(0.1, 0.82, 0.76)


## A round button placed relative to a screen corner: centre = size * anchor + offset.
class Pad:
	var action: StringName
	var label: String
	var radius: float
	var anchor: Vector2
	var offset: Vector2
	var finger := -1

	func _init(p_action: StringName, p_label: String, p_radius: float, p_anchor: Vector2, p_offset: Vector2) -> void:
		action = p_action
		label = p_label
		radius = p_radius
		anchor = p_anchor
		offset = p_offset

	func centre(area: Vector2) -> Vector2:
		return area * anchor + offset


var _pads: Array[Pad] = []
var _grapple: Pad
var _active := false
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_vector := Vector2.ZERO
var _look_finger := -1
var _grapple_held := false
var _grapple_try := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grapple = Pad.new("grapple", "GRAPPLE", 72.0, Vector2.ONE, Vector2(-150.0, -150.0))
	_pads = [
		_grapple,
		Pad.new("jump", "JUMP", 50.0, Vector2.ONE, Vector2(-300.0, -85.0)),
		Pad.new("dash", "DASH", 44.0, Vector2.ONE, Vector2(-120.0, -320.0)),
		Pad.new("reel_in", "IN", 36.0, Vector2.ONE, Vector2(-290.0, -235.0)),
		Pad.new("reel_out", "OUT", 36.0, Vector2.ONE, Vector2(-395.0, -150.0)),
		Pad.new("pause", "II", 30.0, Vector2(1.0, 0.0), Vector2(-70.0, 60.0)),
	]


func _process(delta: float) -> void:
	var game := get_tree().get_first_node_in_group("game")
	var playing: bool = game != null and game.is_playing()
	if playing != _active:
		_set_active(playing)
	if not _active:
		return
	if _grapple_held:
		if game.player.grappling:
			_grapple_try = 0.0   # latched: stays held until the next tap
		else:
			_grapple_try -= delta
			if _grapple_try <= 0.0:   # missed, or the rope came off
				_release_grapple()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	var touch := event as InputEventScreenTouch
	if touch:
		if touch.pressed:
			_on_touch_down(touch.index, touch.position)
		else:
			_on_touch_up(touch.index)
		get_viewport().set_input_as_handled()
		return
	var drag := event as InputEventScreenDrag
	if drag:
		if drag.index == _stick_finger:
			var pull := drag.position - _stick_origin
			if pull.length() > STICK_RADIUS:   # floating stick: the base follows the thumb
				_stick_origin = drag.position - pull.normalized() * STICK_RADIUS
				pull = drag.position - _stick_origin
			_set_stick(pull / STICK_RADIUS)
		elif drag.index == _look_finger:
			var rig: CameraRig = get_tree().get_first_node_in_group("game").rig
			rig.look(drag.relative * LOOK_SCALE)
		get_viewport().set_input_as_handled()


func _on_touch_down(finger: int, pos: Vector2) -> void:
	for pad in _pads:
		if pad.finger == -1 and pos.distance_to(pad.centre(size)) <= pad.radius * PAD_SLOP:
			pad.finger = finger
			_pad_pressed(pad)
			return
	if pos.x < size.x * 0.5:
		if _stick_finger == -1:
			_stick_finger = finger
			_stick_origin = pos
			_set_stick(Vector2.ZERO)
	elif _look_finger == -1:
		_look_finger = finger


func _on_touch_up(finger: int) -> void:
	for pad in _pads:
		if pad.finger == finger:
			pad.finger = -1
			if pad.action != &"grapple" and pad.action != &"pause":
				Input.action_release(pad.action)
			return
	if finger == _stick_finger:
		_stick_finger = -1
		_set_stick(Vector2.ZERO)
	elif finger == _look_finger:
		_look_finger = -1


func _pad_pressed(pad: Pad) -> void:
	match pad.action:
		&"grapple":
			if _grapple_held:
				_release_grapple()
			else:
				_grapple_held = true
				_grapple_try = GRAPPLE_TRY_TIME
				Input.action_press("grapple")
		&"pause":
			pad.finger = -1
			get_tree().get_first_node_in_group("game").pause_game()
		_:
			Input.action_press(pad.action)


func _release_grapple() -> void:
	_grapple_held = false
	_grapple_try = 0.0
	Input.action_release("grapple")


func _set_stick(value: Vector2) -> void:
	_stick_vector = value.limit_length(1.0)
	var v := _stick_vector if _stick_vector.length() > STICK_DEAD_ZONE else Vector2.ZERO
	_set_axis("move_left", "move_right", v.x)
	_set_axis("move_forward", "move_back", v.y)


func _set_axis(negative: StringName, positive: StringName, value: float) -> void:
	for pair in [[negative, -value], [positive, value]]:
		if pair[1] > 0.0:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


## Turning off (pause, game over) lets go of everything a finger was holding.
func _set_active(on: bool) -> void:
	_active = on
	for pad in _pads:
		if pad.finger != -1 and pad.action != &"pause":
			Input.action_release(pad.action)
		pad.finger = -1
	_stick_finger = -1
	_look_finger = -1
	_set_stick(Vector2.ZERO)
	_release_grapple()
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	if _stick_finger != -1:
		draw_circle(_stick_origin, STICK_RADIUS, Color(1.0, 1.0, 1.0, 0.08))
		draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.35), 2.0, true)
		draw_circle(_stick_origin + _stick_vector * STICK_RADIUS, 34.0, Color(TEAL, 0.55))
	else:   # ghost stick where the thumb usually goes
		draw_arc(Vector2(150.0, size.y - 150.0), STICK_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.15), 2.0, true)

	var font := ThemeDB.fallback_font
	for pad in _pads:
		var c := pad.centre(size)
		var lit := pad.finger != -1 or (pad == _grapple and _grapple_held)
		draw_circle(c, pad.radius, Color(ORANGE, 0.6) if lit else Color(0.0, 0.0, 0.0, 0.35))
		draw_arc(c, pad.radius, 0.0, TAU, 48, ORANGE if pad == _grapple else Color(1.0, 1.0, 1.0, 0.6), 2.5, true)
		var font_size := 18 if pad.radius > 40.0 else 14
		var width := font.get_string_size(pad.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, c + Vector2(-width * 0.5, font_size * 0.35), pad.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
