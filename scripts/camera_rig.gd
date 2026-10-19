extends Node3D
class_name CameraRig
## Third-person camera: smooth follow, mouse look, speed-based FOV and screen shake.
## The rig sits at the hero's shoulders; a SpringArm3D keeps the camera out of walls.

const BASE_FOV := 72.0
const MAX_FOV_BONUS := 22.0
const FOLLOW_SHARPNESS := 14.0
const ARM_LENGTH := 6.5
const SHOULDER_OFFSET := Vector3(0.9, 0.5, 0.0)   # over the right shoulder, so the hero never blocks the crosshair
const PITCH_MIN := -1.35
const PITCH_MAX := 1.0

var target: CharacterBody3D
var yaw := 0.0
var pitch := -0.2
var camera: Camera3D

var _spring: SpringArm3D
var _trauma := 0.0
var _time := 0.0


func _ready() -> void:
	_spring = SpringArm3D.new()
	_spring.spring_length = ARM_LENGTH
	_spring.margin = 0.4
	_spring.position = SHOULDER_OFFSET
	_spring.collision_mask = Layers.BUILDINGS | Layers.STREET
	add_child(_spring)
	camera = Camera3D.new()
	camera.fov = BASE_FOV
	camera.near = 0.1
	camera.far = 450.0
	_spring.add_child(camera)
	camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if target == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := event as InputEventMouseMotion
	if motion:
		var turn := deg_to_rad(Settings.mouse_sensitivity)
		yaw -= motion.relative.x * turn
		pitch = clampf(pitch - motion.relative.y * turn, PITCH_MIN, PITCH_MAX)


func _process(delta: float) -> void:
	_time += delta
	if target:
		var goal := target.global_position + Vector3(0.0, 1.6, 0.0)
		global_position = global_position.lerp(goal, 1.0 - exp(-FOLLOW_SHARPNESS * delta))
		var speed := target.velocity.length()
		var fov_goal := BASE_FOV + clampf((speed - 12.0) / 40.0, 0.0, 1.0) * MAX_FOV_BONUS
		camera.fov = lerpf(camera.fov, fov_goal, 1.0 - exp(-4.0 * delta))
	rotation = Vector3(pitch, yaw, 0.0)

	_trauma = maxf(_trauma - delta * 1.6, 0.0)
	var shake := _trauma * _trauma
	camera.h_offset = sin(_time * 47.0) * 0.35 * shake
	camera.v_offset = cos(_time * 53.0) * 0.35 * shake


## 0..1; shake strength is trauma squared, so small hits stay subtle.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Direction through the centre of the screen (where the crosshair is).
func aim_direction() -> Vector3:
	return -camera.global_basis.z


## Camera heading on the ground plane, for WASD.
func yaw_basis() -> Basis:
	return Basis(Vector3.UP, yaw)
