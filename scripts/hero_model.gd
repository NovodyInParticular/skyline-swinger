extends Node3D
class_name HeroModel
## The original hero, built from primitives: teal suit with orange trim and a glowing visor.
## Feet sit at the origin and the hero faces -Z.

const TEAL := Color(0.07, 0.6, 0.58)
const ORANGE := Color(1.0, 0.47, 0.1)
const DARK := Color(0.05, 0.07, 0.09)

var _right_arm: Node3D
var _left_arm: Node3D
var _right_leg: Node3D
var _left_leg: Node3D
var _hand: Node3D
var _walk_phase := 0.0


func _ready() -> void:
	var teal := _material(TEAL, 0.0)
	var orange := _material(ORANGE, 1.4)
	var dark := _material(DARK, 0.0)

	# Torso, head, visor
	_part(self, _capsule(0.27, 0.95), Vector3(0.0, 1.12, 0.0), teal)
	_part(self, _sphere(0.21), Vector3(0.0, 1.78, 0.0), teal)
	_part(self, _box(Vector3(0.34, 0.1, 0.06)), Vector3(0.0, 1.8, -0.18), orange)
	_part(self, _box(Vector3(0.3, 0.05, 0.3)), Vector3(0.0, 1.97, 0.0), dark)
	# Trim: belt, chest emblem (an original diamond), shoulder pads
	var belt := CylinderMesh.new()
	belt.top_radius = 0.285
	belt.bottom_radius = 0.285
	belt.height = 0.08
	_part(self, belt, Vector3(0.0, 0.78, 0.0), orange)
	var emblem := _part(self, _box(Vector3(0.15, 0.15, 0.03)), Vector3(0.0, 1.3, -0.26), orange)
	emblem.rotation.z = PI / 4.0
	for side in [-1.0, 1.0]:
		_part(self, _box(Vector3(0.17, 0.06, 0.22)), Vector3(0.33 * side, 1.52, 0.0), orange)

	# Legs hang along -Y from hip pivots
	_left_leg = _limb_pivot(Vector3(-0.13, 0.8, 0.0))
	_right_leg = _limb_pivot(Vector3(0.13, 0.8, 0.0))
	for leg in [_left_leg, _right_leg]:
		_part(leg, _capsule(0.11, 0.8), Vector3(0.0, -0.38, 0.0), teal)
		_part(leg, _box(Vector3(0.18, 0.14, 0.27)), Vector3(0.0, -0.74, -0.03), orange)

	# Arms point along -Z from shoulder pivots, so look_at() aims them at the grapple anchor
	_left_arm = _limb_pivot(Vector3(-0.37, 1.45, 0.0))
	_right_arm = _limb_pivot(Vector3(0.37, 1.45, 0.0))
	for arm in [_left_arm, _right_arm]:
		var upper := _part(arm, _capsule(0.085, 0.7), Vector3(0.0, 0.0, -0.3), teal)
		upper.rotation.x = PI / 2.0
		_part(arm, _sphere(0.1), Vector3(0.0, 0.0, -0.66), orange)
		arm.rotation.x = -PI / 2.0
	_hand = Node3D.new()
	_hand.position = Vector3(0.0, 0.0, -0.7)
	_right_arm.add_child(_hand)


## Where the grapple line leaves the hero.
func hand_position() -> Vector3:
	return _hand.global_position


func update_pose(delta: float, velocity: Vector3, grappling: bool, anchor: Vector3, on_floor: bool) -> void:
	var flat := Vector2(velocity.x, velocity.z)
	var speed := flat.length()
	if speed > 0.8:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), 1.0 - exp(-10.0 * delta))
	var lean := 0.0 if on_floor else clampf(speed / 45.0, 0.0, 0.45)
	rotation.x = lerpf(rotation.x, -lean, 1.0 - exp(-6.0 * delta))

	var blend := 1.0 - exp(-12.0 * delta)
	if on_floor and speed > 0.5:
		_walk_phase += delta * speed * 1.4
		var swing := sin(_walk_phase) * clampf(speed / 9.0, 0.0, 1.0) * 0.8
		_left_leg.rotation.x = swing
		_right_leg.rotation.x = -swing
		_left_arm.rotation.x = -PI / 2.0 - swing * 0.8
	elif on_floor:
		_left_leg.rotation.x = lerpf(_left_leg.rotation.x, 0.0, blend)
		_right_leg.rotation.x = lerpf(_right_leg.rotation.x, 0.0, blend)
		_left_arm.rotation.x = lerpf(_left_arm.rotation.x, -PI / 2.0, blend)
	else:
		# Airborne: knees up, free arm thrown back
		_left_leg.rotation.x = lerpf(_left_leg.rotation.x, 0.6, blend)
		_right_leg.rotation.x = lerpf(_right_leg.rotation.x, -0.25, blend)
		_left_arm.rotation.x = lerpf(_left_arm.rotation.x, -PI / 2.0 - 0.9, blend)

	if grappling:
		var to_anchor := anchor - _right_arm.global_position
		if to_anchor.length() > 0.1:
			var up := Vector3.UP
			if absf(to_anchor.normalized().dot(up)) > 0.98:
				up = global_basis.z
			_right_arm.look_at(anchor, up)
	else:
		_right_arm.rotation = _right_arm.rotation.lerp(Vector3(-PI / 2.0, 0.0, 0.0), blend)


func _limb_pivot(at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	return pivot


func _part(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 4
	return mesh


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _material(color: Color, glow: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.45
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat
