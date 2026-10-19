extends Node
## Autoload "Settings": input map, player options and the high score, saved to user://.

const SAVE_PATH := "user://settings.cfg"

var mouse_sensitivity := 0.2   # degrees of camera turn per pixel of mouse movement
var volume := 0.8              # master volume, 0..1
var muted := false
var high_score := 0
## Set by Restart so the reloaded scene skips the title screen.
var skip_title := false
## Off during the automated test run so it never touches the real save file.
var persist := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_cmdline_user_args().has("--autotest"):
		persist = false
	_setup_input()
	load_settings()
	apply_audio()


func _setup_input() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_key("jump", KEY_SPACE)
	_bind_key("reel_in", KEY_Q)
	_bind_key("reel_out", KEY_E)
	_bind_key("dash", KEY_SHIFT)
	_bind_key("mute", KEY_M)
	_bind_key("pause", KEY_ESCAPE)
	_bind_key("restart", KEY_R)
	_bind_mouse("grapple", MOUSE_BUTTON_LEFT)


func _bind_key(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)


func _bind_mouse(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if not persist or cfg.load(SAVE_PATH) != OK:
		return
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	volume = cfg.get_value("audio", "volume", volume)
	muted = cfg.get_value("audio", "muted", muted)
	high_score = cfg.get_value("score", "high_score", high_score)


func save_settings() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("score", "high_score", high_score)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Could not save settings to %s (error %d)" % [SAVE_PATH, err])


func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, muted)


func toggle_mute() -> void:
	muted = not muted
	apply_audio()
	save_settings()


## Records a finished run's score. Returns true when it beats the high score.
func submit_score(score: int) -> bool:
	if score <= high_score:
		return false
	high_score = score
	save_settings()
	return true
