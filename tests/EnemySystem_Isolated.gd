extends Node2D

## Isolated enemy system test - enemy spawning with WaveDirector.
## Tests enemy spawning, management, and rendering with MultiMesh visualization.

@onready var enemy_multimesh: MultiMeshInstance2D = $EnemyMultiMesh
@onready var info_label: Label = $UILayer/HUD/InfoLabel
@onready var camera: Camera2D = $Camera2D

var wave_director: WaveDirector
var max_enemies: int = 50  # Reduced for better testing
var grid_size: int = 10  # 10x5 = 50 enemies
var enemy_spacing: float = 32.0  # Smaller spacing
var base_enemy_scale: float = 0.8  # Base scale for all enemies

func _ready():
	print("=== EnemySystem_Isolated Test Started ===")
	print("Controls: Space to spawn grid, R to clear all, 1-4 spawn specific types")
	
	_setup_camera()
	_setup_enemy_system()
	_setup_enemy_multimesh()

func _setup_camera():
	# Set up camera for proper viewing
	camera.zoom = Vector2(0.8, 0.8)  # Slight zoom out to see more enemies
	camera.position = Vector2(400, 300)  # Center on play area
	print("Camera positioned at", camera.position, "with zoom", camera.zoom)

func _setup_enemy_system():
	# Create EnemyRegistry first (WaveDirector depends on it)
	var enemy_registry = EnemyRegistry.new()
	add_child(enemy_registry)
	
	# Create WaveDirector and inject EnemyRegistry
	wave_director = WaveDirector.new()
	add_child(wave_director)
	wave_director.set_enemy_registry(enemy_registry)
	
	# Connect signals for visual updates
	if wave_director.has_signal("enemies_updated"):
		wave_director.enemies_updated.connect(_update_enemy_visuals)
	
	print("EnemySystem setup complete with WaveDirector")

func _update_enemy_visuals(alive_enemies: Array = []):
	if alive_enemies.is_empty():
		alive_enemies = wave_director.get_alive_enemies()
	_update_multimesh_from_entities(alive_enemies)


func _setup_enemy_multimesh():
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = 0
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(16, 16)  # Smaller quad size
	multimesh.mesh = quad_mesh
	
	# Create colored enemy texture (orange base color for better visibility)
	var texture = ImageTexture.new()
	var image = Image.create(16, 16, false, Image.FORMAT_RGB8)  # Smaller base size
	image.fill(Color.ORANGE)
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
	
	var enemy_types = ["knight_regular", "knight_swarm", "knight_elite", "knight_boss"]
	# Center the grid around camera position (400, 300)
	var grid_width = grid_size * enemy_spacing
	var grid_height = (max_enemies / grid_size) * enemy_spacing
	var center_offset = Vector2(grid_width * 0.5, grid_height * 0.5)
	var base_pos = Vector2(400, 300)  # Camera center
	
	for i in range(max_enemies):
		var grid_x = i % grid_size
		var grid_y = i / grid_size
		
		var spawn_pos = base_pos + Vector2(
			grid_x * enemy_spacing - center_offset.x,
			grid_y * enemy_spacing - center_offset.y
		)
		
		# Cycle through enemy types
		var enemy_type_id = enemy_types[i % enemy_types.size()]
		_spawn_enemy_at(spawn_pos, enemy_type_id)
	
	await get_tree().process_frame
	_update_enemy_visuals()
	var alive_count = wave_director.get_alive_enemies().size()
	print("Spawned ", alive_count, " enemies")

func _spawn_enemy_type(type_id: String):
	var mouse_pos = get_global_mouse_position()
	_spawn_enemy_at(mouse_pos, type_id)
	await get_tree().process_frame
	_update_enemy_visuals()
	print("Spawned ", type_id, " at mouse position")

func _spawn_enemy_at(pos: Vector2, enemy_type_id: String):
	if wave_director.has_method("spawn_enemy_at"):
		var success = wave_director.spawn_enemy_at(pos, enemy_type_id)
		if not success:
			print("Failed to spawn enemy: ", enemy_type_id, " at ", pos)
	else:
		print("WaveDirector missing spawn_enemy_at method")

func _clear_all_enemies():
	# Clear all enemies from WaveDirector
	for enemy in wave_director.enemies:
		enemy.alive = false
	# Mark cache as dirty so get_alive_enemies() updates
	wave_director._cache_dirty = true
	_update_enemy_visuals()
	print("Cleared all enemies")

func _update_multimesh_from_entities(alive_enemies: Array):
	enemy_multimesh.multimesh.instance_count = alive_enemies.size()
	
	for i in range(alive_enemies.size()):
		var enemy = alive_enemies[i]
		var transform = Transform2D()
		transform.origin = enemy.pos
		
		# Use consistent base scale with slight variation by enemy type
		var type_scale_modifier = _get_type_scale_modifier(enemy.type_id)
		var final_scale = base_enemy_scale * type_scale_modifier
		transform = transform.scaled(Vector2(final_scale, final_scale))
		
		enemy_multimesh.multimesh.set_instance_transform_2d(i, transform)

func _process(_delta):
	_update_info_display()

func _update_info_display():
	var alive_enemies = wave_director.get_alive_enemies() if wave_director else []
	var total_enemies = wave_director.enemies.size() if wave_director else 0
	var enemy_types_count = {}
	
	# Count enemies by type
	for enemy in alive_enemies:
		var type = enemy.type_id
		enemy_types_count[type] = enemy_types_count.get(type, 0) + 1
	
	info_label.text = "Enemy System Test\n"
	info_label.text += "Space: Spawn 300 enemy grid\n"
	info_label.text += "R: Clear all enemies\n"
	info_label.text += "1-4: Spawn specific types\n\n"
	info_label.text += "Total enemies: " + str(alive_enemies.size()) + "/" + str(max_enemies) + "\n"
	info_label.text += "Pool size: " + str(total_enemies) + "\n\n"
	
	for type in enemy_types_count.keys():
		info_label.text += "  " + type + ": " + str(enemy_types_count[type]) + "\n"

func _get_type_scale_modifier(type_id: String) -> float:
	# Return different scale modifiers for different enemy types
	match type_id:
		"knight_regular":
			return 1.0
		"knight_swarm":
			return 0.8
		"knight_elite":
			return 1.2
		"knight_boss":
			return 1.5
		_:
			return 1.0
