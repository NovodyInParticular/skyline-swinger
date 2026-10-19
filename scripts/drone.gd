extends Node3D
class_name Drone
## A hunter drone: flies straight at the hero (through buildings) with smoothed steering.
## Catching the hero ends the run.

const CATCH_DISTANCE := 1.7
const GIVE_UP_DISTANCE := 260.0
const TURN_SHARPNESS := 2.2

var target: Player
var speed := 10.0

var _velocity := Vector3.ZERO
var _rotors: Array[Node3D] = []


func _ready() -> void:
	var metal := _material(Color(0.12, 0.13, 0.16), 0.0)
	var red := _material(Color(1.0, 0.12, 0.08), 5.0)
	_part(_box(Vector3(1.1, 0.32, 1.1)), Vector3.ZERO, metal)
	_part(_sphere(0.2), Vector3(0.0, 0.0, -0.58), red)
	_part(_box(Vector3(0.5, 0.06, 0.5)), Vector3(0.0, -0.2, 0.0), red)
	for corner in [Vector3(0.62, 0.18, 0.62), Vector3(-0.62, 0.18, 0.62), Vector3(0.62, 0.18, -0.62), Vector3(-0.62, 0.18, -0.62)]:
		var rotor := CylinderMesh.new()
		rotor.top_radius = 0.36
		rotor.bottom_radius = 0.36
		rotor.height = 0.03
		_rotors.append(_part(rotor, corner, metal))
	Sfx.play("drone")


func _physics_process(delta: float) -> void:
	for rotor in _rotors:
		rotor.rotate_y(delta * 40.0)
	if target == null or not is_instance_valid(target) or not target.alive:
		_velocity = _velocity.lerp(Vector3.UP * 2.0, 1.0 - exp(-delta))
		global_position += _velocity * delta
		return
	var to_target := target.global_position + Vector3(0.0, 1.0, 0.0) - global_position
	var dist := to_target.length()
	if dist < CATCH_DISTANCE:
		target.die("A drone caught you")
		return
	if dist > GIVE_UP_DISTANCE:
		queue_free()
		return
	_velocity = _velocity.lerp(to_target / dist * speed, 1.0 - exp(-TURN_SHARPNESS * delta))
	global_position += _velocity * delta
	var heading := _velocity.normalized()
	if _velocity.length() > 0.5 and absf(heading.y) < 0.98:
		look_at(global_position + heading, Vector3.UP)


func _part(mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	add_child(instance)
	return instance


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


func _material(color: Color, glow: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.6
	mat.roughness = 0.4
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat
