extends CharacterBody3D

const MOVE_SPEED := 6.5
const JUMP_VELOCITY := 5.5
const REACH := 7.0
const MOUSE_SENSITIVITY := 0.0022

var camera: Camera3D
var pitch := 0.0
var selected_block := 3
var world: VoxelWorld
var info_label: Label


func _ready() -> void:
	_create_input_actions()
	_create_body()
	_create_hud()
	world = get_tree().get_first_node_in_group("voxel_world") as VoxelWorld
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _create_input_actions() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)


func _add_key_action(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)


func _create_body() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position.y = 1.62
	camera.current = true
	add_child(camera)


func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	info_label = Label.new()
	info_label.position = Vector2(16, 14)
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.add_theme_color_override("font_color", Color.WHITE)
	info_label.text = ""
	layer.add_child(info_label)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-7, -15)
	crosshair.add_theme_font_size_override("font_size", 26)
	crosshair.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(crosshair)
	_update_hud()


func _update_hud() -> void:
	if info_label:
		info_label.text = "WASD — движение | Space — прыжок | Esc — курсор\nЛКМ — убрать блок | ПКМ — поставить блок | 1–5 — выбор блока\nВыбран блок: %s" % _block_name(selected_block)


func _block_name(block_id: int) -> String:
	match block_id:
		1: return "трава"
		2: return "земля"
		3: return "камень"
		4: return "песок"
		5: return "дерево"
		_: return "неизвестно"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
		camera.rotation.x = pitch

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			KEY_1:
				selected_block = 1
				_update_hud()
			KEY_2:
				selected_block = 2
				_update_hud()
			KEY_3:
				selected_block = 3
				_update_hud()
			KEY_4:
				selected_block = 4
				_update_hud()
			KEY_5:
				selected_block = 5
				_update_hud()

	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_edit_target(false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_edit_target(true)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * MOVE_SPEED
		velocity.z = direction.z * MOVE_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED)
		velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED)

	move_and_slide()


func _edit_target(place_block: bool) -> void:
	if world == null:
		return
	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * REACH)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var hit_position: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var target: Vector3i
	if place_block:
		target = Vector3i(
			floori(hit_position.x + normal.x * 0.01),
			floori(hit_position.y + normal.y * 0.01),
			floori(hit_position.z + normal.z * 0.01)
		)
		# Do not place a block inside the player's body.
		if global_position.distance_to(Vector3(target) + Vector3.ONE * 0.5) < 1.2:
			return
		world.set_block(target, selected_block)
	else:
		target = Vector3i(
			floori(hit_position.x - normal.x * 0.01),
			floori(hit_position.y - normal.y * 0.01),
			floori(hit_position.z - normal.z * 0.01)
		)
		world.set_block(target, 0)
