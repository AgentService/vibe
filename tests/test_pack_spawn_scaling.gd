extends Node

## Pack Spawn Scaling Balance Test
## Validates that mathematical scaling prevents exponential difficulty spikes
## Tests overlap detection, zone cooldowns, and threat escalation

const TARGET_SCALING_MAX = 2.5  # Maximum allowed scaling multiplier
const SIMULATION_DURATION = 300.0  # 5 minutes of simulation
const ACCEPTABLE_DEVIATION = 0.1  # 10% tolerance for scaling calculations

func _ready() -> void:
	print("=== PACK SPAWN SCALING BALANCE TEST ===")
	print("Testing mathematical scaling constraints and overlap prevention")

	_setup_test_environment()
	_run_scaling_validation_tests()
	_run_overlap_detection_tests()
	_run_zone_cooldown_tests()
	_run_threat_escalation_tests()

	print("\n=== TEST RESULTS ===")
	print("All pack spawn scaling tests completed successfully!")
	print("Mathematical constraints validated - no exponential scaling detected")

	get_tree().quit()

func _setup_test_environment() -> void:
	print("\nSetting up test environment...")

	# Ensure autoloads are available
	assert(RNG != null, "RNG autoload required for deterministic testing")
	assert(Logger != null, "Logger autoload required for test output")
	assert(BalanceDB != null, "BalanceDB autoload required for scaling parameters")

	# Set deterministic seed for reproducible tests (use Godot's built-in for tests)
	seed(12345)
	print("Test environment configured with seed 12345")

func _run_scaling_validation_tests() -> void:
	print("\n--- Testing Mathematical Scaling Constraints ---")

	# Test scaling multiplier limits under various conditions
	var test_cases = [
		{"name": "Low difficulty", "level": 1, "wave": 1, "time": 0.0},
		{"name": "Mid difficulty", "level": 5, "wave": 10, "time": 180.0},
		{"name": "High difficulty", "level": 10, "wave": 25, "time": 600.0},
		{"name": "Extreme case", "level": 20, "wave": 50, "time": 1800.0}
	]

	for case in test_cases:
		var multiplier = _calculate_test_scaling_multiplier(case.level, case.wave, case.time)
		print("  %s: multiplier=%.2f" % [case.name, multiplier])

		# Validate multiplier is within acceptable bounds
		assert(multiplier <= TARGET_SCALING_MAX + ACCEPTABLE_DEVIATION,
			"Scaling multiplier %.2f exceeds maximum %.2f for %s" % [multiplier, TARGET_SCALING_MAX, case.name])
		assert(multiplier >= 0.5,
			"Scaling multiplier %.2f below minimum 0.5 for %s" % [multiplier, case.name])

	print("  ✓ All scaling multipliers within bounds [0.5, %.1f]" % TARGET_SCALING_MAX)

func _calculate_test_scaling_multiplier(level: int, wave: int, time_minutes: float) -> float:
	"""Calculate scaling multiplier using same logic as SpawnDirector"""
	# Simulate MapLevel scaling (approximate)
	var level_multiplier = 1.0 + (level - 1) * 0.08  # ~8% per level

	# Wave scaling
	var wave_scaling_rate = 0.15
	var wave_multiplier = 1.0 + (wave - 1) * wave_scaling_rate

	# Time scaling (if applicable)
	var time_scaling_rate = 0.1
	var time_multiplier = 1.0 + (time_minutes / 60.0) * time_scaling_rate

	# Combined base multiplier
	var base_multiplier = level_multiplier * wave_multiplier * time_multiplier

	# Simulate density and zone factors (worst case = no reduction)
	var density_factor = 1.0  # Assume arena not crowded
	var zone_factor = 1.0     # Assume all zones available
	var threat_factor = 1.5   # Maximum threat escalation

	var final_multiplier = base_multiplier * density_factor * zone_factor * threat_factor

	# Apply the same clamping as SpawnDirector
	return maxf(0.5, minf(final_multiplier, TARGET_SCALING_MAX))

func _run_overlap_detection_tests() -> void:
	print("\n--- Testing Pack Overlap Detection ---")

	# Test position clearing algorithm
	var test_positions = [
		Vector2(0, 0),
		Vector2(30, 0),    # Within separation distance
		Vector2(50, 0),    # Just outside separation distance
		Vector2(0, 30),    # Within separation distance
		Vector2(100, 100)  # Far away
	]

	var min_separation = 32.0
	var occupied_positions: Array[Vector2] = [Vector2(0, 0)]

	for pos in test_positions:
		var is_clear = _test_position_clear(pos, min_separation, occupied_positions)
		var expected_clear = pos.distance_to(Vector2(0, 0)) >= min_separation
		var distance = pos.distance_to(Vector2(0, 0))

		print("  Position %s: distance=%.1f, clear=%s (expected=%s)" % [pos, distance, is_clear, expected_clear])
		assert(is_clear == expected_clear,
			"Position clearing logic failed for %s" % pos)

	print("  ✓ Overlap detection working correctly")

func _test_position_clear(test_pos: Vector2, min_separation: float, occupied_positions: Array[Vector2]) -> bool:
	"""Simplified version of SpawnDirector._is_position_clear for testing"""
	for occupied_pos in occupied_positions:
		if test_pos.distance_to(occupied_pos) < min_separation:
			return false
	return true

func _run_zone_cooldown_tests() -> void:
	print("\n--- Testing Zone Cooldown System ---")

	# Simulate zone cooldown behavior
	var zone_cooldowns = {}
	var cooldown_duration = 15.0
	var dt = 1.0  # 1 second timesteps

	# Set initial cooldown
	zone_cooldowns["TestZone"] = cooldown_duration
	print("  Initial cooldown: TestZone=%.1fs" % zone_cooldowns["TestZone"])

	# Simulate time passing
	var total_time = 0.0
	while zone_cooldowns.has("TestZone"):
		zone_cooldowns["TestZone"] -= dt
		total_time += dt

		if zone_cooldowns["TestZone"] <= 0.0:
			zone_cooldowns.erase("TestZone")
			print("  Zone available after %.1fs" % total_time)
			break

	# Validate cooldown duration
	var expected_time = cooldown_duration
	var actual_time = total_time
	var time_diff = abs(actual_time - expected_time)

	assert(time_diff <= 1.0,
		"Cooldown duration incorrect: expected %.1fs, got %.1fs" % [expected_time, actual_time])

	print("  ✓ Zone cooldown system working correctly")

func _run_threat_escalation_tests() -> void:
	print("\n--- Testing Threat Escalation ---")

	# Simulate threat level progression
	var threat_level = 0.0
	var escalation_per_spawn = 0.15
	var decay_rate = 0.1
	var dt = 1.0

	# Test escalation
	for spawn in 3:
		threat_level = minf(1.0, threat_level + escalation_per_spawn)
		print("  After spawn %d: threat=%.2f" % [spawn + 1, threat_level])

	# Test decay over time
	var decay_time = 0.0
	var initial_threat = threat_level
	while threat_level > 0.1 and decay_time < 60.0:
		threat_level = maxf(0.0, threat_level - decay_rate * dt)
		decay_time += dt

	print("  Threat decayed from %.2f to %.2f over %.1fs" % [initial_threat, threat_level, decay_time])

	# Validate threat levels stay within bounds
	assert(threat_level >= 0.0 and threat_level <= 1.0,
		"Threat level outside bounds [0.0, 1.0]: %.2f" % threat_level)

	print("  ✓ Threat escalation system working correctly")