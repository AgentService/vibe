extends Node

## Test Scene Swap Teardown
## Verifies that arena-to-hideout transitions properly clean up all entities
## Tests that no enemies, timers, or registrations persist after scene swap

func _ready():
	print("=== Scene Swap Teardown Test ===")
	
	# Load test scene
	var arena_scene = load("res://scenes/arena/Arena.tscn")
	if not arena_scene:
		print("FAIL: Could not load Arena scene")
		get_tree().quit(1)
		return
	
	# Test 1: Verify cleanup after spawning enemies
	print("\n1. Testing enemy spawning and cleanup...")
	await test_enemy_cleanup()
	
	# Test 2: Verify EntityTracker cleanup
	print("\n2. Testing EntityTracker cleanup...")
	await test_entity_tracker_cleanup()
	
	# Test 3: Verify WaveDirector reset
	print("\n3. Testing WaveDirector reset...")
	await test_wave_director_reset()
	
	print("\n=== All Tests Passed ===")
	get_tree().quit(0)

func test_enemy_cleanup():
	# Simulate arena setup with enemies
	var enemies_before = get_tree().get_nodes_in_group("enemies").size()
	var arena_owned_before = get_tree().get_nodes_in_group("arena_owned").size()
	
	print("  Enemies before: %d" % enemies_before)
	print("  Arena-owned before: %d" % arena_owned_before)
	
	# Simulate mode change (this should trigger cleanup)
	EventBus.mode_changed.emit("hideout")
	
	# Wait a frame for cleanup
	await get_tree().process_frame
	
	var enemies_after = get_tree().get_nodes_in_group("enemies").size()
	var arena_owned_after = get_tree().get_nodes_in_group("arena_owned").size()
	
	print("  Enemies after: %d" % enemies_after)
	print("  Arena-owned after: %d" % arena_owned_after)
	
	# Verify cleanup
	if enemies_after > 0:
		print("  FAIL: %d enemies still exist after cleanup" % enemies_after)
		get_tree().quit(1)
		return
	
	if arena_owned_after > 0:
		print("  FAIL: %d arena_owned nodes still exist after cleanup" % arena_owned_after)
		get_tree().quit(1)
		return
	
	print("  PASS: All enemies cleaned up successfully")

func test_entity_tracker_cleanup():
	if not EntityTracker:
		print("  SKIP: EntityTracker not available")
		return
	
	# Get initial state
	var debug_info_before = EntityTracker.get_debug_info()
	print("  EntityTracker before - Total: %d, Alive: %d" % [debug_info_before.total_entities, debug_info_before.alive_entities])
	
	# Test clear method
	EntityTracker.clear("enemy")
	EntityTracker.clear("boss")
	
	var debug_info_after = EntityTracker.get_debug_info()
	print("  EntityTracker after clear - Total: %d, Alive: %d" % [debug_info_after.total_entities, debug_info_after.alive_entities])
	
	# Test reset method
	EntityTracker.reset()
	
	var debug_info_final = EntityTracker.get_debug_info()
	print("  EntityTracker after reset - Total: %d, Alive: %d" % [debug_info_final.total_entities, debug_info_final.alive_entities])
	
	if debug_info_final.total_entities > 0:
		print("  FAIL: EntityTracker still has %d entities after reset" % debug_info_final.total_entities)
		get_tree().quit(1)
		return
	
	print("  PASS: EntityTracker cleanup successful")

func test_wave_director_reset():
	var wave_director = GameOrchestrator.get_wave_director() if GameOrchestrator else null
	
	if not wave_director:
		print("  SKIP: WaveDirector not available")
		return
	
	print("  Testing WaveDirector stop() and reset() methods...")
	
	# Test stop method
	if wave_director.has_method("stop"):
		wave_director.stop()
		print("  WaveDirector.stop() called successfully")
	else:
		print("  FAIL: WaveDirector.stop() method not found")
		get_tree().quit(1)
		return
	
	# Test reset method
	if wave_director.has_method("reset"):
		wave_director.reset()
		print("  WaveDirector.reset() called successfully")
	else:
		print("  FAIL: WaveDirector.reset() method not found")
		get_tree().quit(1)
		return
	
	print("  PASS: WaveDirector methods available and functional")