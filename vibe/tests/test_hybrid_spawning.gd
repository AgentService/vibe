extends Node

## Test script for hybrid enemy spawning system
## Tests both pooled and scene-based enemy spawning
## Run headlessly to validate implementation

var wave_director: WaveDirector
var enemy_registry: EnemyRegistry

func _ready() -> void:
	print("=== HYBRID SPAWNING SYSTEM TEST ===")
	
	# Create and setup systems
	enemy_registry = EnemyRegistry.new()
	add_child(enemy_registry)
	
	# Wait for enemy types to load
	if enemy_registry.enemy_types_loaded.is_connected(_on_enemy_types_loaded):
		enemy_registry.enemy_types_loaded.disconnect(_on_enemy_types_loaded)
	enemy_registry.enemy_types_loaded.connect(_on_enemy_types_loaded)
	
	# Start the test after a brief delay for setup
	get_tree().create_timer(1.0).timeout.connect(_run_tests)

func _on_enemy_types_loaded() -> void:
	print("Enemy types loaded: " + str(enemy_registry.get_total_types()))

func _run_tests() -> void:
	print("\n--- Test 1: Enemy Type Loading ---")
	_test_enemy_type_loading()
	
	print("\n--- Test 2: Wave Pool Filtering ---")
	_test_wave_pool_filtering()
	
	print("\n--- Test 3: Manual Boss Spawning API ---")
	_test_manual_boss_spawning()
	
	print("\n--- Test 4: Hybrid Spawn Logic ---")
	_test_hybrid_spawn_logic()
	
	print("\n=== ALL TESTS COMPLETED ===")
	await get_tree().process_frame
	get_tree().quit()

func _test_enemy_type_loading() -> void:
	print("Total enemy types loaded: " + str(enemy_registry.get_total_types()))
	
	# Test regular enemy loading
	var regular_knight = enemy_registry.get_enemy_type("knight_regular")
	if regular_knight:
		print("✓ Regular knight loaded: " + regular_knight.display_name)
		print("  - Spawn weight: " + str(regular_knight.spawn_weight))
		print("  - Is special boss: " + str(regular_knight.is_special_boss))
	else:
		print("✗ Regular knight not found")
	
	# Test boss enemy loading
	var boss_knight = enemy_registry.get_enemy_type("knight_boss")
	if boss_knight:
		print("✓ Boss knight loaded: " + boss_knight.display_name)
		print("  - Spawn weight: " + str(boss_knight.spawn_weight))
		print("  - Is special boss: " + str(boss_knight.is_special_boss))
	else:
		print("✗ Boss knight not found")
	
	# Test special boss loading
	var dragon_lord = enemy_registry.get_enemy_type("dragon_lord")
	if dragon_lord:
		print("✓ Dragon Lord loaded: " + dragon_lord.display_name)
		print("  - Spawn weight: " + str(dragon_lord.spawn_weight))
		print("  - Is special boss: " + str(dragon_lord.is_special_boss))
		print("  - Boss scene: " + str(dragon_lord.boss_scene != null))
		print("  - Boss spawn method: " + dragon_lord.boss_spawn_method)
	else:
		print("✗ Dragon Lord not found")

func _test_wave_pool_filtering() -> void:
	print("Testing wave pool filtering...")
	
	# Force rebuild wave pool
	enemy_registry._wave_pool_dirty = true
	
	# Test random spawning - should not include special bosses
	var test_iterations = 20
	var spawned_types = {}
	
	for i in range(test_iterations):
		var random_enemy = enemy_registry.get_random_enemy_type("waves")
		if random_enemy:
			if not random_enemy.id in spawned_types:
				spawned_types[random_enemy.id] = 0
			spawned_types[random_enemy.id] += 1
	
	print("Random spawn results (" + str(test_iterations) + " iterations):")
	for enemy_id in spawned_types.keys():
		var enemy_type = enemy_registry.get_enemy_type(enemy_id)
		print("  " + enemy_id + ": " + str(spawned_types[enemy_id]) + " times" + 
			  " (special_boss: " + str(enemy_type.is_special_boss) + 
			  ", weight: " + str(enemy_type.spawn_weight) + ")")
	
	# Verify no special bosses were spawned randomly
	if "dragon_lord" in spawned_types:
		print("✗ ERROR: Dragon Lord appeared in random spawning!")
	else:
		print("✓ Dragon Lord correctly excluded from random spawning")

func _test_manual_boss_spawning() -> void:
	print("Testing manual boss spawning API...")
	
	# Create minimal wave director for API testing
	wave_director = WaveDirector.new()
	add_child(wave_director)
	wave_director.set_enemy_registry(enemy_registry)
	
	# Test spawning regular enemy by ID
	var success_regular = wave_director.spawn_boss_by_id("knight_regular", Vector2(100, 100))
	print("Regular enemy spawn result: " + str(success_regular))
	
	# Test spawning special boss by ID
	var success_special = wave_director.spawn_boss_by_id("dragon_lord", Vector2(200, 200))
	print("Special boss spawn result: " + str(success_special))
	
	# Test spawning non-existent enemy
	var success_invalid = wave_director.spawn_boss_by_id("non_existent", Vector2(300, 300))
	print("Invalid enemy spawn result: " + str(success_invalid))
	
	# Test batch spawning
	var spawn_data = [
		{"id": "knight_boss", "pos": Vector2(150, 150)},
		{"id": "dragon_lord", "pos": Vector2(250, 250)}
	]
	wave_director.spawn_event_enemies(spawn_data)
	print("Batch spawn completed")

func _test_hybrid_spawn_logic() -> void:
	print("Testing hybrid spawn logic...")
	
	if not wave_director:
		print("✗ Wave director not available")
		return
	
	# Test _spawn_from_type with regular enemy
	var regular_enemy = enemy_registry.get_enemy_type("knight_regular")
	if regular_enemy:
		print("Testing pooled spawn with: " + regular_enemy.id)
		wave_director._spawn_from_type(regular_enemy, Vector2(400, 400))
		print("✓ Pooled spawn completed")
	
	# Test _spawn_from_type with special boss
	var special_boss = enemy_registry.get_enemy_type("dragon_lord")
	if special_boss:
		print("Testing scene spawn with: " + special_boss.id)
		wave_director._spawn_from_type(special_boss, Vector2(500, 500))
		print("✓ Scene spawn completed")
	
	print("Hybrid spawn logic tests completed")