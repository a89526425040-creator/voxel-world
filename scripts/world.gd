extends Node3D
class_name VoxelWorld

const CHUNK_SIZE := 16
const WORLD_HEIGHT := 48
const VIEW_DISTANCE := 2

const FACES := [
	{"normal": Vector3i(1, 0, 0), "verts": [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)]},
	{"normal": Vector3i(-1, 0, 0), "verts": [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)]},
	{"normal": Vector3i(0, 1, 0), "verts": [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]},
	{"normal": Vector3i(0, -1, 0), "verts": [Vector3(0, 0, 1), Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)]},
	{"normal": Vector3i(0, 0, 1), "verts": [Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)]},
	{"normal": Vector3i(0, 0, -1), "verts": [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]}
]

var noise := FastNoiseLite.new()
var chunks: Dictionary = {}
var chunk_nodes: Dictionary = {}
var block_material := StandardMaterial3D.new()
const SAVE_PATH := "user://world_save.json"


func _ready() -> void:
	add_to_group("voxel_world")
	_setup_environment()
	noise.seed = 481516
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.018
	block_material.vertex_color_use_as_albedo = true
	block_material.roughness = 1.0

	# Generate data first, so chunk borders can hide shared faces correctly.
	for cx in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
		for cz in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
			var key := Vector2i(cx, cz)
			chunks[key] = _generate_chunk_data(key)
			var chunk_node := Node3D.new()
			chunk_node.name = "Chunk_%d_%d" % [cx, cz]
			chunk_node.position = Vector3(cx * CHUNK_SIZE, 0, cz * CHUNK_SIZE)
			add_child(chunk_node)
			chunk_nodes[key] = chunk_node

	_load_world_edits()
	for key in chunks.keys():
		_rebuild_chunk(key)

	var player_script = load("res://scripts/player.gd")
	var player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(player_script)
	add_child(player)
	player.global_position = Vector3(8.0, 38.0, 8.0)


func _setup_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.7
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)


func _generate_chunk_data(key: Vector2i) -> Dictionary:
	var data: Dictionary = {}
	for lx in range(CHUNK_SIZE):
		for lz in range(CHUNK_SIZE):
			var wx := key.x * CHUNK_SIZE + lx
			var wz := key.y * CHUNK_SIZE + lz
			var n := noise.get_noise_2d(float(wx), float(wz))
			var height := clampi(roundi(11.0 + n * 9.0), 3, 27)
			for y in range(height + 1):
				var block_id := 3 # stone
				if y == height:
					block_id = 1 # grass
				elif y >= height - 3:
					block_id = 2 # dirt
				data[Vector3i(lx, y, lz)] = block_id
	return data


func _chunk_key(world_pos: Vector3i) -> Vector2i:
	return Vector2i(
		floori(float(world_pos.x) / CHUNK_SIZE),
		floori(float(world_pos.z) / CHUNK_SIZE)
	)


func _local_pos(world_pos: Vector3i, key: Vector2i) -> Vector3i:
	return Vector3i(
		world_pos.x - key.x * CHUNK_SIZE,
		world_pos.y,
		world_pos.z - key.y * CHUNK_SIZE
	)


func get_block(world_pos: Vector3i) -> int:
	if world_pos.y < 0 or world_pos.y >= WORLD_HEIGHT:
		return 0
	var key := _chunk_key(world_pos)
	if not chunks.has(key):
		return 0
	return int(chunks[key].get(_local_pos(world_pos, key), 0))


func set_block(world_pos: Vector3i, block_id: int) -> bool:
	if world_pos.y < 0 or world_pos.y >= WORLD_HEIGHT:
		return false
	var key := _chunk_key(world_pos)
	if not chunks.has(key):
		return false
	var local := _local_pos(world_pos, key)
	if block_id <= 0:
		chunks[key].erase(local)
	else:
		chunks[key][local] = block_id
	_save_world_edits()

	_rebuild_chunk(key)
	# Rebuild adjacent chunks when an edited block lies on a chunk border.
	if local.x == 0:
		_rebuild_if_loaded(key + Vector2i(-1, 0))
	elif local.x == CHUNK_SIZE - 1:
		_rebuild_if_loaded(key + Vector2i(1, 0))
	if local.z == 0:
		_rebuild_if_loaded(key + Vector2i(0, -1))
	elif local.z == CHUNK_SIZE - 1:
		_rebuild_if_loaded(key + Vector2i(0, 1))
	return true


func _rebuild_if_loaded(key: Vector2i) -> void:
	if chunks.has(key):
		_rebuild_chunk(key)


func _rebuild_chunk(key: Vector2i) -> void:
	var data: Dictionary = chunks[key]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for local_value in data.keys():
		var local: Vector3i = local_value
		var block_id: int = int(data[local])
		var world_pos := Vector3i(key.x * CHUNK_SIZE + local.x, local.y, key.y * CHUNK_SIZE + local.z)

		for face in FACES:
			var normal: Vector3i = face["normal"]
			if get_block(world_pos + normal) != 0:
				continue

			var face_color := _block_color(block_id, normal)
			var verts: Array = face["verts"]
			var points := [
				Vector3(local.x, local.y, local.z) + verts[0],
				Vector3(local.x, local.y, local.z) + verts[1],
				Vector3(local.x, local.y, local.z) + verts[2],
				Vector3(local.x, local.y, local.z) + verts[3]
			]
			surface.set_color(face_color)
			surface.set_normal(Vector3(normal))
			surface.add_vertex(points[0])
			surface.add_vertex(points[1])
			surface.add_vertex(points[2])
			surface.add_vertex(points[0])
			surface.add_vertex(points[2])
			surface.add_vertex(points[3])

	var mesh_instance: MeshInstance3D = chunk_nodes[key].get_node_or_null("Mesh")
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		chunk_nodes[key].add_child(mesh_instance)
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = block_material

	var old_body := chunk_nodes[key].get_node_or_null("Collision")
	if old_body:
		chunk_nodes[key].remove_child(old_body)
		old_body.free()

	if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		var body := StaticBody3D.new()
		body.name = "Collision"
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = mesh_instance.mesh.create_trimesh_shape()
		body.add_child(collision_shape)
		chunk_nodes[key].add_child(body)


func _block_color(block_id: int, normal: Vector3i) -> Color:
	match block_id:
		1:
			return Color(0.28, 0.62, 0.20) if normal.y == 1 else Color(0.36, 0.48, 0.22)
		2:
			return Color(0.43, 0.27, 0.14)
		3:
			return Color(0.48, 0.49, 0.51)
		4:
			return Color(0.82, 0.74, 0.48)
		5:
			return Color(0.38, 0.23, 0.12)
		_:
			return Color.WHITE



func _save_world_edits() -> void:
	var edits: Dictionary = {}
	for key in chunks.keys():
		var chunk_data: Dictionary = chunks[key]
		for local_value in chunk_data.keys():
			var local: Vector3i = local_value
			# Only persist differences from generated terrain in a future save format.
			# This first version stores the edited voxel set for a reliable prototype save.
			var world_pos := Vector3i(key.x * CHUNK_SIZE + local.x, local.y, key.y * CHUNK_SIZE + local.z)
			edits["%d,%d,%d" % [world_pos.x, world_pos.y, world_pos.z]] = int(chunk_data[local])
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(edits))


func _load_world_edits() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	# This is a full voxel snapshot. Replace generated chunks with the saved snapshot.
	for chunk_key in chunks.keys():
		chunks[chunk_key].clear()
	for position_key in parsed.keys():
		var parts := String(position_key).split(",")
		if parts.size() != 3:
			continue
		var world_pos := Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
		var key := _chunk_key(world_pos)
		if not chunks.has(key):
			continue
		var block_id := int(parsed[position_key])
		if block_id > 0:
			chunks[key][_local_pos(world_pos, key)] = block_id
