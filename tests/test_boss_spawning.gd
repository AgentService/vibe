extends SceneTree

## Boss Spawning and Clear-All Test
## Tests boss registration with EntityTracker and unified clear-all via damage pipeline

func _initialize():
	print("=== Boss Spawning and Clear-All Test ===")
	
	# Wait for autoloads to initialize
	await process_frame
	await process_frame
	
	# Test boss spawning registration
	await test_boss_registration()
	
	# Test boss clear-all via damage pipeline
	await test_boss_clear_all()
	
	print("=== Boss Test Complete ===")
	quit()

func test_boss_registration():
	print("\n--- Testing Boss Registration ---")
	
	# Get initial state
	var initial_debug := EntityTracker.get_debug_info()
	print("Initial EntityTracker state: %d alive entities (%s)" % [initial_debug.alive_entities, str(initial_debug.types)])
	
	# Create a temporary scene to spawn boss in
	var test_scene := Node2D.new()
	current_scene.add_child(test_scene)
	
	# Test boss spawning via WaveDirector special boss path
	var wave_director := WaveDirector.new()
	test_scene.add_child(wave_director)
	
	# Create a test boss EnemyType for spawning
	var boss_type := EnemyType.new()
	boss_type.id = "test_ancient_lich"
	boss_type.is_special_boss = true
	boss_type.boss_scene = preload("res://scenes/bosses/AncientLich.tscn")
	boss_type.health = 300.0
	boss_type.xp_value = 100
	
	# Spawn the boss
	var spawn_pos := Vector2(100, 100)
	wave_director._spawn_special_boss(boss_type, spawn_pos)
	
	# Wait for registration
	await process_frame
	await process_frame
	
	# Check registration
	var post_spawn_debug := EntityTracker.get_debug_info()
	var boss_count := EntityTracker.get_entities_by_type("boss").size()
	
	print("Post-spawn state: %d alive entities (%s)" % [post_spawn_debug.alive_entities, str(post_spawn_debug.types)])
	print("Boss entities found: %d" % boss_count)
	
	if boss_count >= 1:
		print("✓ PASS: Boss registered in EntityTracker")
	else:
		print("✗ FAIL: Boss not found in EntityTracker")
	
	# Clean up
	test_scene.queue_free()

func test_boss_clear_all():
	print("\n--- Testing Boss Clear-All via Damage Pipeline ---")
	
	# Create another test scene
	var test_scene := Node2D.new()
	current_scene.add_child(test_scene)
	
	# Spawn a boss directly using scene instantiation (simulating V2 boss spawn)
	var boss_scene := preload("res://scenes/bosses/AncientLich.tscn")
	var boss_instance := boss_scene.instantiate()
	test_scene.add_child(boss_instance)
	boss_instance.global_position = Vector2(200, 200)
	
	# Wait for boss to register itself
	await process_frame
	await process_frame
	
	# Get pre-clear state
	var pre_clear_debug := EntityTracker.get_debug_info()
	var initial_boss_count := EntityTracker.get_entities_by_type("boss").size()
	
	print("Pre-clear state: %d alive entities (%s)" % [pre_clear_debug.alive_entities, str(pre_clear_debug.types)])
	print("Initial boss count: %d" % initial_boss_count)
	
	if initial_boss_count == 0:
		print("✗ FAIL: No bosses to test clear-all with")
		test_scene.queue_free()
		return
	
	# Use DebugManager unified clear-all
	if DebugManager and DebugManager.has_method("clear_all_entities"):
		print("Calling DebugManager.clear_all_entities()...")
		DebugManager.clear_all_entities()
		
		# Wait for damage processing (more frames for boss death animation)
		for i in range(5):
			await process_frame
		
		# Check post-clear state  
		var post_clear_debug := EntityTracker.get_debug_info()
		var remaining_bosses := EntityTracker.get_entities_by_type("boss").size()
		
		print("Post-clear state: %d alive entities (%s)" % [post_clear_debug.alive_entities, str(post_clear_debug.types)])
		print("Remaining bosses: %d" % remaining_bosses)
		
		# Validation
		if remaining_bosses == 0:
			print("✓ PASS: All bosses cleared via damage pipeline")
		else:
			print("✗ FAIL: %d bosses still remain after clear-all" % remaining_bosses)
	else:
		print("✗ FAIL: DebugManager.clear_all_entities() not available")
	
	# Clean up
	test_scene.queue_free()
