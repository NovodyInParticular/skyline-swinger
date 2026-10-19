extends CharacterBody3D
class_name Player
## The hero: rooftop running, grapple swinging on a rope-length constraint, reeling and air dash.
## Swing tuning lives in the constants below.

signal died(reason: String)
signal grapple_attached(point: Vector3, normal: Vector3)
signal landed_hard(impact_speed: float)

const GRAVITY := 26.0
const WALK_SPEED := 9.0
const WALK_ACCEL := 70.0
const AIR_ACCEL := 8.0            # steering while falling freely
const SWING_ACCEL := 18.0         # WASD pumping while on the rope
const JUMP_VELOCITY := 11.0
const MAX_ROPE := 60.0
const MIN_ROPE := 3.0
const REEL_SPEED := 16.0
const ROPE_STIFFNESS := 0.25      # share of rope overshoot corrected per physics step
const RELEASE_BOOST := 2.5        # small upward kick when letting go
const DASH_SPEED := 18.0
const DASH_COOLDOWN := 1.2
const MAX_SPEED := 75.0
const HARD_LANDING_SPEED := 17.0
const GRAPPLE_RETRY := 0.12       # holding the button keeps trying to latch on
const ROPE_POINT := Vector3(0.0, 1.3, 0.0)   # where the rope pulls on the body

var camera_rig: CameraRig
var alive := true
var grappling := false
var anchor := Vector3.ZERO
var rope_length := 0.0
var aim_valid := false
var distance_travelled := 0.0
var dash_timer := 0.0

var _retry_timer := 0.0
var _was_on_floor := false
var _last_position := Vector3.ZERO
var _model: HeroModel
var _line: MeshInstance3D


func _ready() -> void:
	collision_layer = Layers.PLAYER
	collision_mask = Layers.BUILDINGS | Layers.STREET
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)
	_model = HeroModel.new()
	add_child(_model)
	_line = _make_line()
	add_child(_line)
	_last_position = global_position


func _physics_process(delta: float) -> void:
	if not alive:
		return
	dash_timer = maxf(dash_timer - delta, 0.0)
	aim_valid = not grappling and not _aim_hit().is_empty()
	_handle_grapple_input(delta)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := camera_rig.yaw_basis() * Vector3(input.x, 0.0, input.y)
	var on_floor := is_on_floor()

	if on_floor:
		var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * WALK_SPEED, WALK_ACCEL * delta)
		velocity.x = flat.x
		velocity.z = flat.z
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			Sfx.play("jump")
	else:
		velocity.y -= GRAVITY * delta
		if grappling:
			# Pump: only the part of the input across the rope adds energy to the swing
			var rope_dir := (anchor - global_position - ROPE_POINT).normalized()
			velocity += (wish - rope_dir * wish.dot(rope_dir)) * SWING_ACCEL * delta
		else:
			velocity += wish * AIR_ACCEL * delta
		if Input.is_action_just_pressed("dash") and dash_timer <= 0.0:
			_dash()

	if grappling:
		_apply_rope(delta)

	velocity = velocity.limit_length(MAX_SPEED)
	var fall_speed := -velocity.y
	move_and_slide()
	_check_contacts(fall_speed)

	var moved := global_position - _last_position
	distance_travelled += Vector2(moved.x, moved.z).length()
	_last_position = global_position


func _process(delta: float) -> void:
	_model.update_pose(delta, velocity, grappling and alive, anchor, is_on_floor())
	_update_line()


## 0..1, full when the dash is ready.
func dash_ready() -> float:
	return 1.0 - dash_timer / DASH_COOLDOWN


func die(reason: String) -> void:
	if not alive:
		return
	alive = false
	grappling = false
	_line.visible = false
	velocity = Vector3.ZERO
	died.emit(reason)


func release_grapple() -> void:
	if not grappling:
		return
	grappling = false
	if velocity.y > -5.0:
		velocity.y += RELEASE_BOOST
	Sfx.play("release")


func _handle_grapple_input(delta: float) -> void:
	if Input.is_action_pressed("grapple"):
		if grappling:
			return
		var fresh_press := Input.is_action_just_pressed("grapple")
		_retry_timer -= delta
		if fresh_press or _retry_timer <= 0.0:
			_retry_timer = GRAPPLE_RETRY
			_try_grapple(fresh_press)
	elif grappling:
		release_grapple()


func _try_grapple(fresh_press: bool) -> void:
	var hit := _aim_hit()
	if fresh_press:
		Sfx.play("fire")
	if hit.is_empty():
		if fresh_press:
			Sfx.play("miss")
		return
	grappling = true
	anchor = hit.position
	rope_length = clampf(anchor.distance_to(global_position + ROPE_POINT), MIN_ROPE, MAX_ROPE)
	Sfx.play("attach")
	grapple_attached.emit(anchor, hit.normal)


## Raycast through the crosshair. Starts level with the hero (so walls behind them are ignored)
## and only counts building surfaces within MAX_ROPE of the hero.
func _aim_hit() -> Dictionary:
	var from := camera_rig.camera.global_position
	var dir := camera_rig.aim_direction()
	var body := global_position + ROPE_POINT
	from += dir * maxf((body - from).dot(dir), 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * MAX_ROPE, Layers.BUILDINGS)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var point: Vector3 = hit.position
	if point.distance_to(body) > MAX_ROPE:
		return {}
	return hit


func _apply_rope(delta: float) -> void:
	if Input.is_action_pressed("reel_in"):
		rope_length = maxf(rope_length - REEL_SPEED * delta, MIN_ROPE)
	if Input.is_action_pressed("reel_out"):
		rope_length = minf(rope_length + REEL_SPEED * delta, MAX_ROPE)
	var offset := global_position + ROPE_POINT - anchor
	var dist := offset.length()
	if dist < 1.0:
		release_grapple()
		return
	if dist < rope_length:
		return   # slack rope: free fall
	var out := offset / dist
	var outward := velocity.dot(out)
	if outward > 0.0:
		velocity -= out * outward   # the rope cancels motion away from the anchor
	velocity -= out * (dist - rope_length) / delta * ROPE_STIFFNESS   # pull back to length (also reels in)


func _dash() -> void:
	var dir := camera_rig.aim_direction()
	dir.y = clampf(dir.y, -0.25, 0.45)
	dir = dir.normalized()
	if velocity.y < 0.0:
		velocity.y *= 0.3
	velocity += dir * DASH_SPEED
	dash_timer = DASH_COOLDOWN
	Sfx.play("dash")
	camera_rig.add_trauma(0.15)


func _check_contacts(fall_speed: float) -> void:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is Node and (collider as Node).is_in_group("street"):
			die("You hit the street")
			return
	if global_position.y < 0.2:
		die("You hit the street")
		return
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and fall_speed > HARD_LANDING_SPEED:
		landed_hard.emit(fall_speed)
		Sfx.play("land")
	_was_on_floor = on_floor


func _make_line() -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.03
	mesh.bottom_radius = 0.03
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.0, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2)
	mat.emission_energy_multiplier = 5.0
	var line := MeshInstance3D.new()
	line.mesh = mesh
	line.material_override = mat
	line.top_level = true
	line.visible = false
	return line


## Stretches the unit cylinder from the hand to the anchor.
func _update_line() -> void:
	if not grappling or not alive:
		_line.visible = false
		return
	var from := _model.hand_position()
	var span := anchor - from
	var length := span.length()
	if length < 0.01:
		return
	var y := span / length
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 0.0001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	_line.global_transform = Transform3D(Basis(x, y * length, z), from + span * 0.5)
	_line.visible = true
