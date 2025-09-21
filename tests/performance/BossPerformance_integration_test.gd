extends Node

## Boss Performance Integration Test
## Tests BossUpdateManager with actual boss scenes to validate the complete system
## Verifies centralized processing, batch updates, and performance characteristics

var test_boss_scenes: Array = []
var test_duration: float = 10.0  # Test for 10 seconds
var start_time: float
var frame_count: int = 0
var total_fps: float = 0.0

func _ready() -> void:
	print("=== Boss Performance Integration Test ===")
	
	# Wait for autoloads to initialize
	await get_tree().create_timer(0.5).timeout
	
	print("Creating test bosses...")
	
	# Spawn multiple BananaLord bosses for testing
	var boss_count = 50  # Start with 50 for integration test, can scale up
	for i in range(boss_count):
		var boss_scene = preload("res://scenes/bosses/BananaLord.tscn")
		var boss = boss_scene.instantiate()
		
		# Position bosses in a grid
		var x = (i % 10) * 100  # 10 bosses per row
		var y = (i / 10) * 100
		boss.global_position = Vector2(x, y)
		
		add_child(boss)
		test_boss_scenes.append(boss)
	
	print("Created %d boss instances" % boss_count)
	
	# Check BossUpdateManager state
	await get_tree().create_timer(0.5).timeout  # Let bosses register
	var debug_info = BossUpdateManager.get_debug_info()
	print("BossUpdateManager state: %s" % debug_info)
	
	if debug_info.registered_bosses != boss_count:
		print("FAIL: Expected %d registered bosses, got %d" % [boss_count, debug_info.registered_bosses])
		get_tree().quit(1)
		return
	
	print("SUCCESS: All bosses registered with BossUpdateManager")
	print("Starting performance test for %.1f seconds..." % test_duration)
	
	start_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
	frame_count = 0
	total_fps = 0.0

func _process(delta: float) -> void:
	if start_time <= 0:
		return  # Test not started yet
	
	frame_count += 1
	var current_fps = 1.0 / delta
	total_fps += current_fps
	
	var current_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
	var elapsed = current_time - start_time
	
	# Progress indicator every 2 seconds
	if int(elapsed) % 2 == 0 and int(elapsed) != int(elapsed - delta):
		print("Test progress: %.1fs / %.1fs - Current FPS: %.1f" % [elapsed, test_duration, current_fps])
		
		# Show BossUpdateManager debug info periodically
		var debug_info = BossUpdateManager.get_debug_info()
		print("  Manager state - Bosses: %d, Queue: %d/%d, Pool: %d" % [
			debug_info.registered_bosses,
			debug_info.queue_count,
			debug_info.queue_capacity,
			debug_info.pool_available
		])
	
	if elapsed >= test_duration:
		_finish_test()

func _finish_test() -> void:
	var avg_fps = total_fps / frame_count
	
	print("\n=== Test Results ===")
	print("Test duration: %.1f seconds" % test_duration)
	print("Total frames: %d" % frame_count)
	print("Average FPS: %.1f" % avg_fps)
	print("Boss count: %d" % test_boss_scenes.size())
	
	# Final BossUpdateManager state
	var debug_info = BossUpdateManager.get_debug_info()
	print("Final BossUpdateManager state: %s" % debug_info)
	
	# Performance criteria for success
	var min_acceptable_fps = 30.0  # Should maintain at least 30 FPS
	
	if avg_fps >= min_acceptable_fps:
		print("SUCCESS: Performance test passed - %.1f FPS >= %.1f FPS minimum" % [avg_fps, min_acceptable_fps])
		get_tree().quit(0)
	else:
		print("FAIL: Performance test failed - %.1f FPS < %.1f FPS minimum" % [avg_fps, min_acceptable_fps])
		get_tree().quit(1)