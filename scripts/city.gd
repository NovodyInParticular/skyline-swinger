extends Node3D
class_name City
## Procedural city: a grid of streets with one box building per cell, built in chunks
## around the player and freed when far away. Chunk contents come from a seeded RNG,
## so a chunk always rebuilds the same way within a run.

const CELL := 34.0                 # street pitch; buildings are 16-24 m wide, streets 10+ m
const CELLS := 4                   # cells per chunk side
const CHUNK := CELL * CELLS
const LOAD_RADIUS := 2             # chunks kept around the player (5x5)
const UNLOAD_RADIUS := 3
const SPAWN_HEIGHT := 60.0
const SPAWN_SIZE := 22.0
const SPAWN_POS := Vector3(CELL * 0.5, SPAWN_HEIGHT, CELL * 0.5)   # roof of the start building

var world_seed := 0
var _chunks := {}                  # Vector2i -> Node3D
var _pending: Array[Vector2i] = []
var _noise := FastNoiseLite.new()
var _box := BoxMesh.new()
var _street_mesh := PlaneMesh.new()
var _building_material := ShaderMaterial.new()
var _street_material := ShaderMaterial.new()
var _antenna_mesh := CylinderMesh.new()
var _beacon_mesh := SphereMesh.new()


func _ready() -> void:
	world_seed = randi()
	_noise.seed = world_seed
	_noise.frequency = 0.0035
	_building_material.shader = preload("res://shaders/building.gdshader")
	_street_material.shader = preload("res://shaders/street.gdshader")
	_street_material.set_shader_parameter("cell_size", CELL)
	_street_mesh.size = Vector2(CHUNK, CHUNK)
	_antenna_mesh.top_radius = 0.12
	_antenna_mesh.bottom_radius = 0.2
	_antenna_mesh.height = 8.0
	_antenna_mesh.material = _glow_material(Color(0.15, 0.15, 0.18), 0.0)
	_beacon_mesh.radius = 0.35
	_beacon_mesh.height = 0.7
	_beacon_mesh.material = _glow_material(Color(1.0, 0.1, 0.1), 6.0)


## Builds every chunk around `at` right away (used at start).
func generate_around(at: Vector3) -> void:
	var center := _chunk_of(at)
	for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dz in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var key := center + Vector2i(dx, dz)
			if not _chunks.has(key):
				_build_chunk(key)


## Call every frame: queues missing chunks (building one per frame, nearest first) and frees far ones.
func update_around(at: Vector3) -> void:
	var center := _chunk_of(at)
	for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dz in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var key := center + Vector2i(dx, dz)
			if not _chunks.has(key) and not _pending.has(key):
				_pending.append(key)
	_pending = _pending.filter(func(k: Vector2i) -> bool: return _ring(k, center) <= LOAD_RADIUS)
	if not _pending.is_empty():
		_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return (a - center).length_squared() < (b - center).length_squared())
		var next: Vector2i = _pending.pop_front()
		if not _chunks.has(next):
			_build_chunk(next)
	for key: Vector2i in _chunks.keys():
		if _ring(key, center) > UNLOAD_RADIUS:
			(_chunks[key] as Node).queue_free()
			_chunks.erase(key)


func chunk_count() -> int:
	return _chunks.size()


func _chunk_of(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK))


func _ring(key: Vector2i, center: Vector2i) -> int:
	return maxi(absi(key.x - center.x), absi(key.y - center.y))


func _build_chunk(key: Vector2i) -> void:
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [key.x, key.y]
	add_child(root)
	_chunks[key] = root
	var origin := Vector3(key.x * CHUNK, 0.0, key.y * CHUNK)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, key.x, key.y])
	_add_street(root, origin)

	for i in CELLS:
		for j in CELLS:
			var cell := Vector2i(key.x * CELLS + i, key.y * CELLS + j)
			var base := origin + Vector3((i + 0.5) * CELL, 0.0, (j + 0.5) * CELL)
			if cell == Vector2i.ZERO:
				_add_building(root, base, Vector3(SPAWN_SIZE, SPAWN_HEIGHT, SPAWN_SIZE), rng)
				continue
			var district := (_noise.get_noise_2d(base.x, base.z) + 1.0) * 0.5
			var height := clampf(lerpf(16.0, 100.0, district) * rng.randf_range(0.6, 1.25), 12.0, 120.0)
			var size := Vector3(rng.randf_range(16.0, 24.0), height, rng.randf_range(16.0, 24.0))
			_add_building(root, base, size, rng)
			if height > 40.0 and rng.randf() < 0.3:
				var tower := Vector3(size.x * 0.55, rng.randf_range(10.0, 30.0), size.z * 0.55)
				_add_building(root, base + Vector3(0.0, height, 0.0), tower, rng)

	# Orbs float over the streets (cell borders), between the buildings
	for n in rng.randi_range(2, 4):
		var line := rng.randi_range(0, CELLS - 1) * CELL
		var along := rng.randf_range(0.1, 0.9) * CHUNK
		var orb := Orb.new()
		if rng.randf() < 0.5:
			orb.position = origin + Vector3(line, 0.0, along)
		else:
			orb.position = origin + Vector3(along, 0.0, line)
		orb.position.y = rng.randf_range(12.0, 45.0)
		root.add_child(orb)


func _add_street(root: Node3D, origin: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.STREET
	body.collision_mask = 0
	body.add_to_group("street")
	body.position = origin + Vector3(CHUNK * 0.5, -0.5, CHUNK * 0.5)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CHUNK, 1.0, CHUNK)
	shape.shape = box
	body.add_child(shape)
	var surface := MeshInstance3D.new()
	surface.mesh = _street_mesh
	surface.material_override = _street_material
	surface.position.y = 0.5
	body.add_child(surface)
	root.add_child(body)


## `base` is the centre of the building's footprint at its bottom.
func _add_building(root: Node3D, base: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.BUILDINGS
	body.collision_mask = 0
	body.add_to_group("building")
	body.position = base + Vector3(0.0, size.y * 0.5, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _box
	mesh.material_override = _building_material
	mesh.scale = size
	body.add_child(mesh)
	root.add_child(body)

	if base.y + size.y > 75.0 and rng.randf() < 0.5:
		var top := base + Vector3(0.0, size.y, 0.0)
		var antenna := MeshInstance3D.new()
		antenna.mesh = _antenna_mesh
		antenna.position = top + Vector3(0.0, 4.0, 0.0)
		root.add_child(antenna)
		var beacon := MeshInstance3D.new()
		beacon.mesh = _beacon_mesh
		beacon.position = top + Vector3(0.0, 8.2, 0.0)
		root.add_child(beacon)


func _glow_material(color: Color, glow: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat
