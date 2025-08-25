extends Node2D

## Isolated enemy system test - enemy spawning with 300 enemies in grid pattern.
## Tests enemy registry, spawning, and rendering with MultiMesh visualization.

@onready var enemy_multimesh: MultiMeshInstance2D = $EnemyMultiMesh
@onready var info_label: Label = $UILayer/HUD/InfoLabel

var enemy_registry: EnemyRegistry
var enemies: Array = []
var max_enemies: int = 300
var grid_size: int = 20  # 20x15 = 300 enemies
var enemy_spacing: float = 50.0

func _ready():
	print("=== EnemySystem_Isolated Test Started ===")
	print("Controls: Space to spawn grid, R to clear all, 1-4 spawn specific types")
	
	_setup_enemy_system()
	_setup_enemy_multimesh()

func _setup_enemy_system():
	enemy_registry = EnemyRegistry.new()
	add_child(enemy_registry)
	
	# Wait for enemy types to load, then provide fallback
	if enemy_registry.has_signal("enemy_types_loaded"):
		enemy_registry.enemy_types_loaded.connect(_on_enemy_types_loaded)
	else:
		# Immediate setup if no signal
		_setup_fallback_enemies()

func _on_enemy_types_loaded():
	print("Enemy types loaded from registry")
	var loaded_types = enemy_registry.enemy_types.keys()
	print("Available enemy types: ", loaded_types)

func _setup_fallback_enemies():
	# Fallback enemy types if registry fails
	if enemy_registry.enemy_types.is_empty():
		print("Using fallback enemy definitions")
		enemy_registry.enemy_types = {
			"knight_regular": _create_fallback_enemy("knight_regular", 1.0, Color.RED),
			"knight_swarm": _create_fallback_enemy("knight_swarm", 0.8, Color.ORANGE),
			"knight_elite": _create_fallback_enemy("knight_elite", 1.2, Color.PURPLE),
			"knight_boss": _create_fallback_enemy("knight_boss", 1.5, Color.DARK_RED)
		}

func _create_fallback_enemy(id: String, size: float, color: Color) -> Dictionary:
	return {
		"id": id,
		"size": size,
		"spawn_weight": 1.0,
		"color": color,
		"health": 100.0 * size,
		"speed": 100.0 / size
	}

func _setup_enemy_multimesh():
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = 0
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(24, 24)
	multimesh.mesh = quad_mesh
	
	# Default enemy texture (will be tinted per enemy type)
	var texture = ImageTexture.new()
	var image = Image.create(24, 24, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	texture.set_image(image)
	enemy_multimesh.texture = texture
	
	enemy_multimesh.multimesh = multimesh

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_spawn_enemy_grid()
			KEY_R:
				_clear_all_enemies()
			KEY_1:
				_spawn_enemy_type("knight_regular")
			KEY_2:
				_spawn_enemy_type("knight_swarm")
			KEY_3:
				_spawn_enemy_type("knight_elite")
			KEY_4:
				_spawn_enemy_type("knight_boss")

func _spawn_enemy_grid():
	print("Spawning ", max_enemies, " enemies in grid pattern...")
	_clear_all_enemies()
	
	var available_types = enemy_registry.enemy_types.keys()
	if available_types.is_empty():
		print("No enemy types available!")
		return
	
	var center_offset = Vector2(grid_size * enemy_spacing * 0.5, grid_size * 0.75 * enemy_spacing * 0.5)
	
	for i in range(max_enemies):
		var grid_x = i % grid_size
		var grid_y = i / grid_size
		
		var spawn_pos = Vector2(
			grid_x * enemy_spacing - center_offset.x,
			grid_y * enemy_spacing - center_offset.y
		)
		
		# Cycle through enemy types
		var enemy_type_id = available_types[i % available_types.size()]
		_spawn_enemy_at(spawn_pos, enemy_type_id)
	
	_update_multimesh()
	print("Spawned ", enemies.size(), " enemies")

func _spawn_enemy_type(type_id: String):
	var mouse_pos = get_global_mouse_position()
	_spawn_enemy_at(mouse_pos, type_id)
	_update_multimesh()
	print("Spawned ", type_id, " at mouse position")

func _spawn_enemy_at(pos: Vector2, enemy_type_id: String):
	var enemy_type = enemy_registry.enemy_types.get(enemy_type_id, null)
	if not enemy_type:
		print("Unknown enemy type: ", enemy_type_id)
		return
	
	var enemy_data = {
		"id": "enemy_" + str(Time.get_unix_time_from_system()) + "_" + str(randf()),
		"type": enemy_type_id,
		"pos": pos,
		"alive": true,
		"health": enemy_type.get("health", 100.0),
		"max_health": enemy_type.get("health", 100.0),
		"size": enemy_type.get("size", 1.0),
		"color": enemy_type.get("color", Color.RED),
		"spawn_time": Time.get_time_dict_from_system()
	}
	
	enemies.append(enemy_data)

func _clear_all_enemies():
	enemies.clear()
	_update_multimesh()
	print("Cleared all enemies")

func _update_multimesh():
	var alive_enemies = enemies.filter(func(e): return e["alive"])
	enemy_multimesh.multimesh.instance_count = alive_enemies.size()
	
	for i in range(alive_enemies.size()):
		var enemy = alive_enemies[i]
		var transform = Transform2D()
		transform.origin = enemy["pos"]
		
		# Scale based on enemy size
		var size = enemy.get("size", 1.0)
		transform = transform.scaled(Vector2(size, size))
		
		enemy_multimesh.multimesh.set_instance_transform_2d(i, transform)
		
		# Set color if supported
		if enemy_multimesh.multimesh.has_method("set_instance_color"):
			var color = enemy.get("color", Color.RED)
			enemy_multimesh.multimesh.set_instance_color(i, color)

func _process(_delta):
	_update_info_display()

func _update_info_display():
	var alive_enemies = enemies.filter(func(e): return e["alive"])
	var enemy_types_count = {}
	
	# Count enemies by type
	for enemy in alive_enemies:
		var type = enemy["type"]
		enemy_types_count[type] = enemy_types_count.get(type, 0) + 1
	
	var available_types = enemy_registry.enemy_types.keys()
	
	info_label.text = "Enemy System Test\n"
	info_label.text += "Space: Spawn 300 enemy grid\n"
	info_label.text += "R: Clear all enemies\n"
	info_label.text += "1-4: Spawn specific types\n\n"
	info_label.text += "Total enemies: " + str(alive_enemies.size()) + "/" + str(max_enemies) + "\n"
	info_label.text += "Available types: " + str(available_types.size()) + "\n"
	
	for type in enemy_types_count.keys():
		info_label.text += "  " + type + ": " + str(enemy_types_count[type]) + "\n"