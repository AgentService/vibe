extends Node2D

## Isolated wave director test - enemy wave spawning and management.
## Tests wave progression, enemy spawning patterns, and wave timing.

@onready var enemy_multimesh: MultiMeshInstance2D = $EnemyMultiMesh
@onready var info_label: Label = $UILayer/HUD/InfoLabel

var wave_director: WaveDirector

func _ready():
	print("=== WaveDirector_Isolated Test Started ===")
	print("Controls: Space to start/next wave, R to reset, 1-3 for manual spawn")
	
	_setup_wave_system()
	_setup_enemy_multimesh()

func _setup_wave_system():
	wave_director = WaveDirector.new()
	add_child(wave_director)
	
	# Connect to wave events
	if wave_director.has_signal("wave_started"):
		wave_director.wave_started.connect(_on_wave_started)
	if wave_director.has_signal("wave_completed"):
		wave_director.wave_completed.connect(_on_wave_completed)
	if wave_director.has_signal("enemy_spawned"):
		wave_director.enemy_spawned.connect(_on_enemy_spawned)
	
	# Connect to wave director enemy updates
	if wave_director.has_signal("enemies_updated"):
		wave_director.enemies_updated.connect(_on_enemies_updated)

func _setup_enemy_multimesh():
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = 0
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(16, 16)
	multimesh.mesh = quad_mesh
	
	# Red enemy texture
	var texture = ImageTexture.new()
	var image = Image.create(16, 16, false, Image.FORMAT_RGB8)
	image.fill(Color.RED)
	texture.set_image(image)
	enemy_multimesh.texture = texture
	
	enemy_multimesh.multimesh = multimesh

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_start_or_next_wave()
			KEY_R:
				_reset_waves()
			KEY_1:
				_spawn_test_enemy("basic")
			KEY_2:
				_spawn_test_enemy("fast")
			KEY_3:
				_spawn_test_enemy("tank")
			KEY_T:
				_test_entity_registration()
			KEY_C:
				_test_clear_all()
			KEY_D:
				_debug_entity_tracker()

func _start_or_next_wave():
	if wave_director.has_method("start_next_wave"):
		wave_director.start_next_wave()
		print("Starting next wave")
	elif wave_director.has_method("start_wave"):
		wave_director.start_wave()
		print("Starting wave")

func _reset_waves():
	if wave_director.has_method("reset_waves"):
		wave_director.reset_waves()
	print("Waves reset")

func _spawn_test_enemy(enemy_type: String):
	# Spawn enemy at random position around circle
	var angle = randf() * TAU
	var radius = 200 + randf() * 100
	var spawn_pos = Vector2.from_angle(angle) * radius
	
	# Manual spawn through wave director V2 system
	print("Manual enemy spawn requested: ", enemy_type, " at ", spawn_pos)

func _on_wave_started(wave_number: int):
	print("Wave ", wave_number, " started")

func _on_wave_completed(wave_number: int):
	print("Wave ", wave_number, " completed")

func _on_enemy_spawned(enemy_data: Dictionary):
	print("Enemy spawned: ", enemy_data.get("type", "unknown"))

func _on_enemies_updated(alive_enemies: Array):
	enemy_multimesh.multimesh.instance_count = alive_enemies.size()
	
	for i in range(alive_enemies.size()):
		var enemy = alive_enemies[i]
		var transform = Transform2D()
		if enemy.has("pos"):
			transform.origin = enemy["pos"]
		elif enemy.has("position"):
			transform.origin = enemy["position"]
		enemy_multimesh.multimesh.set_instance_transform_2d(i, transform)

func _update_info_display():
	var enemy_count = 0
	var current_wave = 0
	var wave_status = "Idle"
	
	if wave_director and wave_director.has_method("get_alive_enemies"):
		enemy_count = wave_director.get_alive_enemies().size()
	
	if wave_director:
		if wave_director.has_method("get_current_wave"):
			current_wave = wave_director.get_current_wave()
		if wave_director.has_method("get_wave_status"):
			wave_status = str(wave_director.get_wave_status())
	
	info_label.text = "Wave Director Test\n"
	info_label.text += "Space: Start/Next wave\n"
	info_label.text += "R: Reset waves\n"
	info_label.text += "1-3: Manual spawn\n"
	info_label.text += "T: Test registration\n"
	info_label.text += "C: Test clear-all\n"
	info_label.text += "D: Debug EntityTracker\n\n"
	info_label.text += "Current wave: " + str(current_wave) + "\n"
	info_label.text += "Wave status: " + wave_status + "\n"
	info_label.text += "Active enemies: " + str(enemy_count)

func _process(_delta):
	_update_info_display()

# Test entity registration validation for goblin registration task
func _test_entity_registration():
	print("=== Testing Entity Registration ===")
	
	# Clear any existing entities first
	if wave_director and wave_director.has_method("clear_all_enemies"):
		wave_director.clear_all_enemies()
	
	await get_tree().process_frame  # Wait for cleanup
	
	# Get initial state
	var initial_debug := EntityTracker.get_debug_info()
	print("Initial EntityTracker state: %d alive entities (%s)" % [initial_debug.alive_entities, str(initial_debug.types)])
	
	# Spawn several goblins manually through WaveDirector V2 spawn 
	var spawn_count = 5
	for i in range(spawn_count):
		_spawn_test_enemy("basic")
		await get_tree().process_frame  # Allow registration
	
	await get_tree().process_frame  # Final processing frame
	
	# Check if all goblins registered correctly 
	var post_spawn_debug := EntityTracker.get_debug_info()
	var enemy_count := EntityTracker.get_entities_by_type("enemy").size()
	
	print("Post-spawn EntityTracker state: %d alive (%s)" % [post_spawn_debug.alive_entities, str(post_spawn_debug.types)])
	print("Enemy entities found: %d" % enemy_count)
	
	# Validation
	if enemy_count == spawn_count:
		print("✓ PASS: All %d goblins registered in EntityTracker" % spawn_count)
	else:
		print("✗ FAIL: Expected %d goblins, found %d in EntityTracker" % [spawn_count, enemy_count])

# Test unified clear-all functionality
func _test_clear_all():
	print("=== Testing Clear-All via Damage Pipeline ===")
	
	# First spawn some entities to clear
	var spawn_count = 3
	for i in range(spawn_count):
		_spawn_test_enemy("basic")
		await get_tree().process_frame
	
	await get_tree().process_frame
	
	# Get pre-clear state
	var pre_clear_debug := EntityTracker.get_debug_info()
	print("Pre-clear state: %d alive entities (%s)" % [pre_clear_debug.alive_entities, str(pre_clear_debug.types)])
	
	# Use DebugManager unified clear-all
	if DebugManager and DebugManager.has_method("clear_all_entities"):
		print("Calling DebugManager.clear_all_entities()...")
		DebugManager.clear_all_entities()
		
		# Wait for damage processing
		await get_tree().process_frame
		await get_tree().process_frame  # Additional frame for sync
		
		# Check post-clear state
		var post_clear_debug := EntityTracker.get_debug_info()
		var remaining_enemies := EntityTracker.get_entities_by_type("enemy").size()
		
		print("Post-clear state: %d alive entities (%s)" % [post_clear_debug.alive_entities, str(post_clear_debug.types)])
		print("Remaining enemies: %d" % remaining_enemies)
		
		# Validation
		if remaining_enemies == 0:
			print("✓ PASS: All enemies cleared via damage pipeline")
		else:
			print("✗ FAIL: %d enemies still remain after clear-all" % remaining_enemies)
	else:
		print("✗ FAIL: DebugManager.clear_all_entities() not available")

# Debug EntityTracker state
func _debug_entity_tracker():
	print("=== EntityTracker Debug Info ===")
	var debug_info := EntityTracker.get_debug_info()
	print("Total entities: %d" % debug_info.total_entities)
	print("Alive entities: %d" % debug_info.alive_entities)
	print("Types breakdown: %s" % str(debug_info.types))
	print("Spatial grid cells: %d" % debug_info.spatial_grid_cells)
	
	# List all alive entities
	var all_alive := EntityTracker.get_alive_entities()
	print("All alive entity IDs:")
	for entity_id in all_alive:
		var entity_data := EntityTracker.get_entity(entity_id)
		print("  - %s (type: %s, pos: %s)" % [entity_id, entity_data.get("type", "unknown"), entity_data.get("pos", Vector2.ZERO)])
