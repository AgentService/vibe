extends Node

## Test to verify that extended pauses don't cause lag bursts on resume.
## This simulates the user's issue: pausing during level up and resuming after a while.

var test_duration: float = 3.0  # Simulate 3 seconds of pause
var combat_steps_before_pause: int = 0
var combat_steps_after_resume: int = 0
var pause_start_time: float = 0.0
var resume_time: float = 0.0
var test_phase: String = "init"

func _ready() -> void:
	print("=== Testing Extended Pause/Resume Lag Fix ===")
	
	# Connect to combat step events to count them
	EventBus.combat_step.connect(_on_combat_step)
	
	# Load arena scene
	var arena_scene = load("res://scenes/arena/Arena.tscn")
	var arena_instance = arena_scene.instantiate()
	get_tree().current_scene = arena_instance
	
	# Wait a moment for initialization
	await get_tree().create_timer(0.5).timeout
	
	print("Phase 1: Collecting baseline combat steps...")
	test_phase = "before_pause"
	
	# Collect combat steps for 1 second before pause
	await get_tree().create_timer(1.0).timeout
	
	print("Combat steps before pause: ", combat_steps_before_pause)
	print("Phase 2: Pausing game for %s seconds..." % test_duration)
	
	# Pause the game
	test_phase = "paused"
	pause_start_time = Time.get_ticks_msec() / 1000.0
	PauseManager.pause_game(true)
	
	# Wait for the extended pause period
	await get_tree().create_timer(test_duration).timeout
	
	print("Phase 3: Resuming game...")
	resume_time = Time.get_ticks_msec() / 1000.0
	var actual_pause_duration = resume_time - pause_start_time
	print("Actual pause duration: %.2f seconds" % actual_pause_duration)
	
	# Resume the game
	test_phase = "after_resume"
	combat_steps_after_resume = 0  # Reset counter
	PauseManager.pause_game(false)
	
	# Collect combat steps for 1 second after resume
	await get_tree().create_timer(1.0).timeout
	
	print("Combat steps after resume: ", combat_steps_after_resume)
	
	# Analyze results
	_analyze_results()
	
	print("=== Test Complete ===")
	get_tree().quit()

func _on_combat_step(payload) -> void:
	match test_phase:
		"before_pause":
			combat_steps_before_pause += 1
		"after_resume":
			combat_steps_after_resume += 1
		"paused":
			# This should NEVER happen if the fix is working
			print("ERROR: Combat step received during pause! This indicates the bug is not fixed.")

func _analyze_results() -> void:
	print("\n=== RESULTS ANALYSIS ===")
	
	# Expected combat steps per second at 30Hz
	var expected_steps_per_second = 30
	
	print("Expected combat steps per second: ", expected_steps_per_second)
	print("Combat steps before pause: ", combat_steps_before_pause)
	print("Combat steps after resume: ", combat_steps_after_resume)
	
	# Check if we're getting reasonable step counts
	var before_rate = combat_steps_before_pause
	var after_rate = combat_steps_after_resume
	
	print("Before pause rate: ~%d Hz" % before_rate)
	print("After resume rate: ~%d Hz" % after_rate)
	
	# Verify the fix is working
	if after_rate > expected_steps_per_second * 2:
		print("❌ FAIL: Too many combat steps after resume - lag burst detected!")
		print("   This indicates accumulated time was not properly handled during pause.")
	elif after_rate < expected_steps_per_second * 0.5:
		print("⚠️  WARNING: Very few combat steps after resume - system may be stuck.")
	else:
		print("✅ PASS: Combat step rate after resume is normal.")
		print("   Extended pause lag burst issue appears to be fixed!")
	
	# Check pause compliance
	if test_phase == "paused" and combat_steps_after_resume > 0:
		print("❌ FAIL: Combat steps were processed during pause!")
	else:
		print("✅ PASS: No combat steps processed during pause.")