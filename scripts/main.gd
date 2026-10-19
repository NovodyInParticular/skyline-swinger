extends Node3D
## Game flow: title, run, pause, game over. Owns the night environment, city, camera, hero,
## drones and UI. Run with `-- --autotest` for a scripted headless smoke test.

enum State { TITLE, PLAYING, PAUSED, GAME_OVER }

const ORB_POINTS := 50
const FIRST_DRONE_AT := 12.0
const MAX_DRONES := 7

var state := State.TITLE
var city: City
var rig: CameraRig
var player: Player
var ui: GameUI
var orbs_collected := 0
var elapsed := 0.0

var _drones: Node3D
var _drone_timer := FIRST_DRONE_AT
var _autotest := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps Esc working while the world is paused
	add_to_group("game")
	randomize()
	_build_environment()

	city = City.new()
	city.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(city)
	city.generate_around(City.SPAWN_POS)

	rig = CameraRig.new()
	rig.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(rig)

	_drones = Node3D.new()
	_drones.name = "Drones"
	_drones.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_drones)

	ui = preload("res://ui/ui.tscn").instantiate() as GameUI
	add_child(ui)
	ui.start_requested.connect(start_game)
	ui.resume_requested.connect(resume_game)
	ui.restart_requested.connect(restart)
	ui.title_requested.connect(go_to_title)

	_autotest = OS.get_cmdline_user_args().has("--autotest")
	if Settings.skip_title or _autotest:
		Settings.skip_title = false
		start_game()
	else:
		rig.global_position = City.SPAWN_POS + Vector3(0.0, 25.0, 0.0)
		rig.pitch = -0.3
		ui.show_title(Settings.high_score)
	if _autotest:
		_run_autotest()


func _process(delta: float) -> void:
	match state:
		State.TITLE:
			rig.yaw += delta * 0.08
		State.PLAYING:
			elapsed += delta
			city.update_around(player.global_position)
			_update_drones(delta)
			var s := score()
			ui.update_hud(s, maxi(Settings.high_score, s), player.velocity.length(), player.dash_ready(), player.aim_valid)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			pause_game()
		elif state == State.PAUSED:
			resume_game()
	elif event.is_action_pressed("mute"):
		Settings.toggle_mute()
		ui.toast("Sound off" if Settings.muted else "Sound on")
	elif event.is_action_pressed("restart") and state == State.GAME_OVER:
		restart()
	elif state == State.PLAYING and event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # e.g. after alt-tabbing back in


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAYING and not _autotest:
		pause_game()


func score() -> int:
	if player == null:
		return 0
	return int(player.distance_travelled) + orbs_collected * ORB_POINTS


func start_game() -> void:
	if state == State.PLAYING:
		return
	state = State.PLAYING
	player = preload("res://scenes/player.tscn").instantiate() as Player
	player.camera_rig = rig
	player.position = City.SPAWN_POS + Vector3(0.0, 0.05, 0.0)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.died.connect(_on_player_died)
	player.grapple_attached.connect(_on_grapple_attached)
	player.landed_hard.connect(_on_landed_hard)
	rig.target = player
	rig.global_position = player.global_position + Vector3(0.0, 1.6, 0.0)
	rig.yaw = 0.0
	rig.pitch = -0.15
	ui.show_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.play("start")


func pause_game() -> void:
	state = State.PAUSED
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_pause()


func resume_game() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	get_tree().paused = false
	ui.hide_pause()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func restart() -> void:
	Settings.skip_title = true
	_reload()


func go_to_title() -> void:
	Settings.skip_title = false
	_reload()


func _reload() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()


## Called by orbs through the "game" group.
func on_orb_collected(at: Vector3) -> void:
	orbs_collected += 1
	Fx.burst(self, at, Color(0.3, 1.0, 0.8), 32, 10.0)
	Sfx.play("orb")


func _on_grapple_attached(point: Vector3, _normal: Vector3) -> void:
	Fx.burst(self, point, Color(1.0, 0.55, 0.15), 16, 6.0)


func _on_landed_hard(impact_speed: float) -> void:
	rig.add_trauma(clampf(impact_speed / 45.0, 0.25, 0.7))
	Fx.burst(self, player.global_position, Color(0.6, 0.65, 0.75), 18, 5.0)


func _on_player_died(reason: String) -> void:
	state = State.GAME_OVER
	Sfx.play("game_over")
	rig.add_trauma(0.8)
	var final_score := score()
	var record := Settings.submit_score(final_score)
	ui.show_game_over(final_score, maxi(Settings.high_score, final_score), record, reason)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Drones: more of them, faster and more often as the run goes on -----------------

func _update_drones(delta: float) -> void:
	_drone_timer -= delta
	if _drone_timer > 0.0:
		return
	_drone_timer = maxf(9.0 - elapsed / 20.0, 2.5)
	var allowed := mini(1 + int(elapsed / 25.0), MAX_DRONES)
	if _drones.get_child_count() < allowed:
		_spawn_drone()


func _spawn_drone() -> void:
	var drone := Drone.new()
	drone.target = player
	drone.speed = minf(9.0 + elapsed / 8.0, 26.0)
	var angle := randf() * TAU
	drone.position = player.global_position + Vector3(cos(angle) * 75.0, randf_range(10.0, 25.0), sin(angle) * 75.0)
	_drones.add_child(drone)


# --- Night environment ---------------------------------------------------------------

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.015, 0.02, 0.07)
	sky_material.sky_horizon_color = Color(0.32, 0.1, 0.3)
	sky_material.sky_curve = 0.12
	sky_material.ground_horizon_color = Color(0.18, 0.06, 0.16)
	sky_material.ground_bottom_color = Color(0.01, 0.01, 0.02)
	sky_material.sun_angle_max = 3.0
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.1, 0.28)
	env.fog_density = 0.0065
	env.fog_sky_affect = 0.35
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.55
	moon.rotation_degrees = Vector3(-38.0, 35.0, 0.0)
	moon.shadow_enabled = false
	add_child(moon)


# --- Automated smoke test (godot --headless -- --autotest) ----------------------------

func _run_autotest() -> void:
	var report := func(msg: String) -> void: print("[autotest] ", msg)
	await _wait(0.6)
	report.call("spawned at %s, chunks=%d, on_floor=%s" % [player.global_position, city.chunk_count(), player.is_on_floor()])

	_press("move_forward", 0.3)
	await _wait(0.35)
	_press("jump", 0.05)
	await _wait(0.1)

	# Find a direction where the crosshair hits a building, then grapple and swing
	var found := false
	for yaw_step in 8:
		for pitch in [0.15, 0.0, -0.3, -0.6, -0.9]:
			rig.yaw = yaw_step * TAU / 8.0
			rig.pitch = pitch
			await get_tree().physics_frame
			await get_tree().physics_frame
			var hit := player._aim_hit()
			if not hit.is_empty() and (hit.position as Vector3).distance_to(player.global_position) > 15.0:
				found = true   # a neighbouring building, not our own roof
				break
		if found:
			break
	report.call("aim found=%s yaw=%.2f pitch=%.2f" % [found, rig.yaw, rig.pitch])
	Input.action_press("grapple")
	await _wait(0.3)
	report.call("grappling=%s rope=%.1f anchor=%s" % [player.grappling, player.rope_length, player.anchor])
	_press("move_forward", 1.2)
	var top_speed := 0.0
	for i in 78:   # ~1.3 s of swinging
		await get_tree().physics_frame
		top_speed = maxf(top_speed, player.velocity.length())
	report.call("swing top speed=%.1f m/s, rope=%.1f, alive=%s" % [top_speed, player.rope_length, player.alive])
	_press("reel_in", 0.4)
	await _wait(0.45)
	_press("reel_out", 0.2)
	await _wait(0.25)
	Input.action_release("grapple")
	await _wait(0.1)
	_press("dash", 0.05)
	await _wait(0.6)
	report.call("after swing: pos=%s speed=%.1f distance=%.1f alive=%s" % [player.global_position, player.velocity.length(), player.distance_travelled, player.alive])

	if player.alive:
		var orb := Orb.new()
		orb.position = player.global_position + Vector3(0.0, 1.0, 0.0)
		add_child(orb)
		await _wait(0.2)
		_spawn_drone()
		await _wait(0.3)
	report.call("orbs=%d drones=%d score=%d" % [orbs_collected, _drones.get_child_count(), score()])

	if state == State.PLAYING:
		pause_game()
		await _wait(0.1)
		resume_game()
	Settings.toggle_mute()
	Settings.toggle_mute()
	ui.toast("autotest")

	if player.alive:
		player.die("autotest finished")
	await _wait(0.3)
	# The run is over, so only the test drives streaming now: move far away and back
	for i in 40:
		city.update_around(Vector3(700.0, 0.0, 700.0))
		await get_tree().process_frame
	report.call("chunks after streaming far away=%d" % city.chunk_count())
	report.call("state=%s score=%d" % [State.keys()[state], score()])
	print("[autotest] OK")
	get_tree().quit()


func _press(action: String, seconds: float) -> void:
	Input.action_press(action)
	get_tree().create_timer(seconds).timeout.connect(func() -> void: Input.action_release(action))


func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout
