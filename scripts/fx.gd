class_name Fx
## One-shot glowing particle bursts (grapple hits, orb pickups, landings).

static var _materials := {}


static func burst(parent: Node, at: Vector3, color: Color, amount: int = 24, speed: float = 9.0) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = _material(color)

	var particles := CPUParticles3D.new()
	particles.mesh = mesh
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.8
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0.0, -14.0, 0.0)
	particles.damping_min = 1.0
	particles.damping_max = 3.0
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	parent.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	parent.get_tree().create_timer(1.5).timeout.connect(particles.queue_free)


static func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 4.0
		_materials[key] = mat
	return _materials[key]
