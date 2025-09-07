extends SceneTree

## Test XP progression with enhanced fallback configurations
## Validates that XP system uses configurable fallbacks instead of hardcoded values

func _initialize() -> void:
	print("=== Testing XP Progression Fallback Migration ===")
	
	var success_count := 0
	var test_count := 0
	
	# Test 1: PlayerXPCurve fallback configuration loading
	test_count += 1
	print("\nTest 1: XP curve fallback configuration")
	var xp_curve := PlayerXPCurve.new()
	
	# Test default fallback values
	var fallback_xp := xp_curve.get_fallback_xp()
	if fallback_xp == 100.0:
		print("✅ Fallback XP configuration accessible (%.1f XP)" % fallback_xp)
		success_count += 1
	else:
		print("❌ Fallback XP configuration failed. Expected: 100.0, Got: %.1f" % fallback_xp)
	
	# Test 2: Generated fallback curve functionality
	test_count += 1
	print("\nTest 2: Generated fallback curve")
	var fallback_curve := xp_curve.generate_fallback_curve(5)  # Generate 5 levels
	
	if fallback_curve.size() == 5 and fallback_curve[0] == 100:
		var is_increasing := true
		for i in range(1, fallback_curve.size()):
			if fallback_curve[i] <= fallback_curve[i-1]:
				is_increasing = false
				break
		
		if is_increasing:
			print("✅ Fallback curve generates properly (5 levels): ", fallback_curve)
			success_count += 1
		else:
			print("❌ Fallback curve not properly increasing: ", fallback_curve)
	else:
		print("❌ Fallback curve generation failed. Expected size: 5, first value: 100")
		print("Got size: %d, first value: %s" % [fallback_curve.size(), fallback_curve[0] if fallback_curve.size() > 0 else "N/A"])
	
	# Test 3: XP curve resource loading with fallback values
	test_count += 1
	print("\nTest 3: XP curve resource with fallback configuration")
	var resource_path := "res://data/core/progression-xp-curve.tres"
	
	if ResourceLoader.exists(resource_path):
		var loaded_curve = ResourceLoader.load(resource_path) as PlayerXPCurve
		if loaded_curve and loaded_curve.base_xp_required > 0:
			print("✅ XP curve resource loads with fallback config (base_xp: %.1f)" % loaded_curve.base_xp_required)
			success_count += 1
		else:
			print("❌ XP curve resource missing fallback configuration")
	else:
		print("❌ XP curve resource not found at: " + resource_path)
	
	# Test 4: PlayerProgression fallback usage validation
	test_count += 1
	print("\nTest 4: PlayerProgression migration validation")
	var progression_path := "res://autoload/PlayerProgression.gd"
	if FileAccess.file_exists(progression_path):
		var file := FileAccess.open(progression_path, FileAccess.READ)
		var content := file.get_as_text()
		file.close()
		
		# Check that _create_fallback_curve uses configurable approach
		if content.contains("generate_fallback_curve") and content.contains("Emergency fallback"):
			print("✅ PlayerProgression uses configurable fallback approach")
			success_count += 1
		else:
			print("❌ PlayerProgression still uses hardcoded fallback approach")
	else:
		print("❌ PlayerProgression.gd not found")
	
	# Test 5: Edge case - XP scaling validation
	test_count += 1
	print("\nTest 5: XP scaling edge case validation")
	var test_curve := PlayerXPCurve.new()
	test_curve.base_xp_required = 50.0
	test_curve.xp_scaling_factor = 2.0
	test_curve.max_level_xp_required = 500.0
	
	var edge_curve := test_curve.generate_fallback_curve(10)
	
	# Should cap at max_level_xp_required
	var capped_properly := true
	for xp in edge_curve:
		if xp > 500.0:
			capped_properly = false
			break
	
	if capped_properly and edge_curve.size() == 10:
		print("✅ XP scaling respects max level cap: ", edge_curve)
		success_count += 1
	else:
		print("❌ XP scaling cap failed: ", edge_curve)
	
	# Summary
	print("\n=== XP Progression Test Results ===")
	print("Passed: %d/%d tests" % [success_count, test_count])
	
	if success_count == test_count:
		print("✅ All XP progression migration tests PASSED")
	else:
		print("❌ Some XP progression migration tests FAILED")
	
	# Always quit after testing
	quit(0 if success_count == test_count else 1)