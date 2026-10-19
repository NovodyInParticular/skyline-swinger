extends Area3D
class_name Orb
## A glowing energy orb that bobs in place. Touching it scores points.

const PICKUP_RADIUS := 1.5

static var _mesh: SphereMesh

var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	collision_layer = Layers.ORBS
	collision_mask = Layers.PLAYER
	monitorable = false
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = 0.5
		_mesh.height = 1.0
		_mesh.radial_segments = 12
		_mesh.rings = 6
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 1.0, 0.75)
		mat.emission_enabled = true
		mat.emission = Color(0.3, 1.0, 0.8)
		mat.emission_energy_multiplier = 4.0
		_mesh.material = mat
	var visual := MeshInstance3D.new()
	visual.mesh = _mesh
	add_child(visual)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = PICKUP_RADIUS
	shape.shape = sphere
	add_child(shape)
	_base_y = position.y
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 2.0) * 0.4
	rotate_y(delta * 1.5)


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player and player.alive:
		get_tree().call_group("game", "on_orb_collected", global_position)
		queue_free()
