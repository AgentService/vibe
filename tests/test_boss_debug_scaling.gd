extends SceneTree

## Test boss debug scaling with configurable values
## Validates that DebugManager uses BossScaling resource instead of hardcoded multipliers

func _initialize() -> void:
	print("=== Testing Boss Debug Scaling Migration ===")
	
	var success_count := 0
	var test_count := 0
	
	# Test 1: BossScaling resource class functionality
	test_count += 1
	print("\nTest 1: BossScaling resource class")
	var boss_scaling := BossScaling.new()
	boss_scaling.health_multiplier = 2.5
	boss_scaling.damage_multiplier = 1.8
	boss_scaling.speed_multiplier = 1.1
	boss_scaling.size_multiplier = 1.3
	
	# Mock boss config to test scaling application
	var mock_config := {
		"health": 100.0,
		"damage": 50.0,
		"speed": 1.0,
		"size_scale": 1.0
	}
	
	boss_scaling.apply_scaling(mock_config)
	
	if mock_config["health"] == 250.0 and mock_config["damage"] == 90.0:
		print("✅ BossScaling.apply_scaling() works correctly")
		print("Applied scaling: health=%.1f, damage=%.1f" % [mock_config["health"], mock_config["damage"]])
		success_count += 1
	else:
		print("❌ BossScaling.apply_scaling() failed")
		print("Expected: health=250.0, damage=90.0")
		print("Got: health=%.1f, damage=%.1f" % [mock_config["health"], mock_config["damage"]])
	
	# Test 2: BossScaling resource file loading
	test_count += 1
	print("\nTest 2: BossScaling resource loading")
	var resource_path := "res://data/core/boss-scaling.tres"
	
	if ResourceLoader.exists(resource_path):
		var loaded_scaling = ResourceLoader.load(resource_path) as BossScaling
		if loaded_scaling and loaded_scaling.health_multiplier > 0:
			print("✅ Boss scaling resource loads successfully")
			print("Config: health_mult=%.1f, damage_mult=%.1f" % [loaded_scaling.health_multiplier, loaded_scaling.damage_multiplier])
			success_count += 1
		else:
			print("❌ Boss scaling resource invalid format")
	else:
		print("❌ Boss scaling resource not found at: " + resource_path)
	
	# Test 3: DebugManager migration validation
	test_count += 1
	print("\nTest 3: DebugManager migration validation")
	var debug_manager_path := "res://autoload/DebugManager.gd"
	if FileAccess.file_exists(debug_manager_path):
		var file := FileAccess.open(debug_manager_path, FileAccess.READ)
		var content := file.get_as_text()
		file.close()
		
		# Check that hardcoded values are replaced with configurable approach
		if content.contains("boss_scaling.apply_scaling") and content.contains("_load_boss_scaling"):
			print("✅ DebugManager uses configurable boss scaling")
			success_count += 1
		else:
			print("❌ DebugManager still uses hardcoded boss scaling")
	else:
		print("❌ DebugManager.gd not found")
	
	# Test 4: Fallback behavior validation
	test_count += 1
	print("\nTest 4: Fallback behavior when resource missing")
	var fallback_scaling := BossScaling.new()  # Uses default values
	
	var fallback_config := {
		"health": 100.0,
		"damage": 50.0,
		"size_scale": 1.0
	}
	
	fallback_scaling.apply_scaling(fallback_config)
	
	# Should use default multipliers (3.0, 1.5, 1.2)
	if fallback_config["health"] == 300.0 and fallback_config["damage"] == 75.0:
		print("✅ Fallback scaling uses correct default values")
		print("Fallback scaling: health=%.1f, damage=%.1f" % [fallback_config["health"], fallback_config["damage"]])
		success_count += 1
	else:
		print("❌ Fallback scaling incorrect")
		print("Expected: health=300.0, damage=75.0")
		print("Got: health=%.1f, damage=%.1f" % [fallback_config["health"], fallback_config["damage"]])
	
	# Test 5: Configuration consistency validation
	test_count += 1
	print("\nTest 5: Configuration consistency validation")
	if ResourceLoader.exists(resource_path):
		var loaded_scaling = ResourceLoader.load(resource_path) as BossScaling
		if loaded_scaling:
			# Verify the resource file contains expected default values from audit
			if loaded_scaling.health_multiplier == 3.0 and loaded_scaling.damage_multiplier == 1.5:
				print("✅ Boss scaling configuration matches audit requirements")
				success_count += 1
			else:
				print("❌ Boss scaling configuration doesn't match audit requirements")
				print("Expected: health=3.0, damage=1.5")
				print("Got: health=%.1f, damage=%.1f" % [loaded_scaling.health_multiplier, loaded_scaling.damage_multiplier])
		else:
			print("❌ Could not validate boss scaling resource format")
	else:
		print("❌ Boss scaling resource not available for consistency check")
	
	# Summary
	print("\n=== Boss Debug Scaling Test Results ===")
	print("Passed: %d/%d tests" % [success_count, test_count])
	
	if success_count == test_count:
		print("✅ All boss debug scaling migration tests PASSED")
	else:
		print("❌ Some boss debug scaling migration tests FAILED")
	
	# Always quit after testing
	quit(0 if success_count == test_count else 1)