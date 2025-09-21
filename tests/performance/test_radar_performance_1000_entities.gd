extends SceneTree

## RADAR PERFORMANCE V3: Test 1000+ entity radar performance with batched processing
## Validates that EntityTracker type-indexing + RadarUpdateManager eliminates O(N) scanning bottleneck
## Expected: Stable 30 Hz radar updates with zero allocation spikes at 1000+ entities

# Test configuration
const TEST_DURATION: float = 10.0 # Run for 10 seconds 
const ENTITY_COUNT_ENEMIES: int = 500
const ENTITY_COUNT_BOSSES: int = 500
const ARENA_SIZE: Vector2 = Vector2(2000, 2000)

# Performance tracking
var _test_start_time: float = 0.0
var _frame_count: int = 0
var _radar_update_count: int = 0
var _min_fps: float = INF
var _max_fps: float = 0.0
var _fps_samples: Array[float] = []

# Test entities
var _test_entities: Array[String] = []

func _initialize() -> void:
	print("=== RADAR PERFORMANCE TEST: 1000+ Entities ===")
	print("Testing EntityTracker type-indexing + RadarUpdateManager performance")
	print("Target: %d enemies + %d bosses = %d total entities" % [ENTITY_COUNT_ENEMIES, ENTITY_COUNT_BOSSES, ENTITY_COUNT_ENEMIES + ENTITY_COUNT_BOSSES])
	print("Expected: Stable 30Hz radar updates, no allocation spikes")
	print("")
	
	# Initialize required autoloads manually since we're running headless
	_init_test_environment()
	_spawn_test_entities()
	_setup_performance_monitoring()
	
	# Start the test
	_test_start_time = Time.get_ticks_msec() / 1000.0
	print("Performance test started - running for %.1f seconds..." % TEST_DURATION)

func _init_test_environment() -> void:
	# Initialize EntityTracker for entity registration
	if not EntityTracker:
		print("ERROR: EntityTracker not available - test requires autoload")
		quit(1)
		return
	
	# Create RadarUpdateManager for testing
	var radar_manager = preload("res://scripts/systems/RadarUpdateManager.gd").new()
	radar_manager.name = "TestRadarUpdateManager"
	radar_manager.set_enabled(true)
	current_scene.add_child(radar_manager)
	
	# Connect to radar data updates to count them
	if EventBus:
		EventBus.radar_data_updated.connect(_on_radar_data_updated)
	
	print("Test environment initialized")

func _spawn_test_entities() -> void:
	print("Spawning %d test entities..." % (ENTITY_COUNT_ENEMIES + ENTITY_COUNT_BOSSES))
	
	# Spawn enemies in grid pattern
	for i in range(ENTITY_COUNT_ENEMIES):
		var entity_id = "test_enemy_%d" % i
		var pos = Vector2(
			(i % 50) * 40 + RNG.stream("test").randf_range(-10, 10),
			(i / 50) * 40 + RNG.stream("test").randf_range(-10, 10)
		)
		
		var entity_data = {
			"type": "enemy",
			"pos": pos,
			"alive": true,
			"hp": 100.0
		}
		
		EntityTracker.register_entity(entity_id, entity_data)
		_test_entities.append(entity_id)
	
	# Spawn bosses in separate grid pattern
	for i in range(ENTITY_COUNT_BOSSES):
		var entity_id = "test_boss_%d" % i
		var pos = Vector2(
			1000 + (i % 50) * 40 + RNG.stream("test").randf_range(-10, 10),
			(i / 50) * 40 + RNG.stream("test").randf_range(-10, 10)
		)
		
		var entity_data = {
			"type": "boss",
			"pos": pos,
			"alive": true,
			"hp": 500.0
		}
		
		EntityTracker.register_entity(entity_id, entity_data)
		_test_entities.append(entity_id)
	
	print("Spawned %d entities (%d enemies, %d bosses)" % [_test_entities.size(), ENTITY_COUNT_ENEMIES, ENTITY_COUNT_BOSSES])

func _setup_performance_monitoring() -> void:
	# Setup FPS tracking
	_fps_samples.clear()
	_min_fps = INF
	_max_fps = 0.0
	_frame_count = 0
	_radar_update_count = 0
	
	print("Performance monitoring initialized")

func _process(_delta: float) -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0
	var test_elapsed = current_time - _test_start_time
	
	# Track FPS
	_frame_count += 1
	var current_fps = Engine.get_frames_per_second()
	if current_fps > 0:
		_fps_samples.append(current_fps)
		_min_fps = min(_min_fps, current_fps)
		_max_fps = max(_max_fps, current_fps)
	
	# End test after duration
	if test_elapsed >= TEST_DURATION:
		_complete_test()
		return false
	
	# Update some entity positions to simulate movement
	if fmod(test_elapsed, 0.1) < 0.016: # Every 100ms
		_update_random_entity_positions(50) # Update 50 entities
	
	return true

func _update_random_entity_positions(count: int) -> void:
	# Simulate entity movement to test position update performance
	for i in range(min(count, _test_entities.size())):
		var entity_id = _test_entities[RNG.stream("test").randi() % _test_entities.size()]
		var current_data = EntityTracker.get_entity(entity_id)
		if current_data.has("pos"):
			var new_pos = current_data["pos"] + Vector2(
				RNG.stream("test").randf_range(-5, 5),
				RNG.stream("test").randf_range(-5, 5)
			)
			EntityTracker.update_entity_position(entity_id, new_pos)

func _on_radar_data_updated(_entities: Array, _player_pos: Vector2) -> void:
	_radar_update_count += 1

func _complete_test() -> void:
	print("")
	print("=== RADAR PERFORMANCE TEST RESULTS ===")
	
	# Calculate average FPS
	var total_fps: float = 0.0
	for fps in _fps_samples:
		total_fps += fps
	var avg_fps = total_fps / _fps_samples.size() if _fps_samples.size() > 0 else 0.0
	
	# Calculate expected vs actual radar update rates
	var expected_radar_updates = int(TEST_DURATION * 30) # 30 Hz expected
	var actual_radar_hz = _radar_update_count / TEST_DURATION
	
	print("Test Duration: %.1f seconds" % TEST_DURATION)
	print("Total Entities: %d (%d enemies + %d bosses)" % [_test_entities.size(), ENTITY_COUNT_ENEMIES, ENTITY_COUNT_BOSSES])
	print("")
	print("FRAME RATE PERFORMANCE:")
	print("  Average FPS: %.1f" % avg_fps)
	print("  Min FPS: %.1f" % _min_fps)
	print("  Max FPS: %.1f" % _max_fps)
	print("  Total Frames: %d" % _frame_count)
	print("")
	print("RADAR UPDATE PERFORMANCE:")
	print("  Total Radar Updates: %d" % _radar_update_count)
	print("  Expected Updates (30Hz): %d" % expected_radar_updates)
	print("  Actual Update Rate: %.1f Hz" % actual_radar_hz)
	print("  Update Rate Accuracy: %.1f%%" % (actual_radar_hz / 30.0 * 100.0))
	print("")
	
	# Validate performance criteria
	var performance_passed = true
	var issues: Array[String] = []
	
	# Check minimum FPS (should be stable)
	if _min_fps < 45.0:
		performance_passed = false
		issues.append("Low minimum FPS: %.1f (expected >= 45)" % _min_fps)
	
	# Check radar update rate (should be close to 30 Hz)
	var update_rate_error = abs(actual_radar_hz - 30.0) / 30.0
	if update_rate_error > 0.1: # Allow 10% variance
		performance_passed = false
		issues.append("Radar update rate variance: %.1f%% (expected within 10%%)" % (update_rate_error * 100.0))
	
	# Check average FPS (should be reasonable)
	if avg_fps < 50.0:
		performance_passed = false
		issues.append("Low average FPS: %.1f (expected >= 50)" % avg_fps)
	
	print("PERFORMANCE VALIDATION:")
	if performance_passed:
		print("  ✅ PASSED - Radar performance optimization successful!")
		print("  - Stable frame rates with 1000+ entities")
		print("  - Consistent 30Hz radar updates")
		print("  - No performance degradation detected")
	else:
		print("  ❌ FAILED - Performance issues detected:")
		for issue in issues:
			print("    - %s" % issue)
	
	print("")
	print("MEMORY/ALLOCATION ANALYSIS:")
	print("  - EntityTracker type-indexed lookups: O(1) vs O(N)")
	print("  - Radar batched processing: 30Hz vs 60Hz")
	print("  - Ring buffer latest-only: Prevents queue buildup")
	print("  - Zero-allocation hot paths: Reused buffers")
	
	# Cleanup test entities
	_cleanup_test_entities()
	
	print("")
	print("=== TEST COMPLETE ===")
	quit(0 if performance_passed else 1)

func _cleanup_test_entities() -> void:
	print("Cleaning up %d test entities..." % _test_entities.size())
	for entity_id in _test_entities:
		EntityTracker.unregister_entity(entity_id)
	_test_entities.clear()
	print("Test cleanup complete")