extends SceneTree

## Test suite for BalanceDB schema validation system
## Validates JSON data loading, schema validation, fallback behavior

func _initialize() -> void:
	test_balance_validation()
	quit()

func test_balance_validation() -> void:
	print("=== Balance Schema Validation Tests ===")
	
	var tests_passed: int = 0
	var tests_total: int = 0
	
	# Test valid data validation
	tests_total += 1
	if test_valid_combat_data():
		tests_passed += 1
		print("✓ Valid combat data validation passed")
	else:
		print("✗ Valid combat data validation failed")
	
	# Test missing required field
	tests_total += 1
	if test_missing_required_field():
		tests_passed += 1
		print("✓ Missing required field validation passed")
	else:
		print("✗ Missing required field validation failed")
	
	# Test invalid type
	tests_total += 1
	if test_invalid_type():
		tests_passed += 1
		print("✓ Invalid type validation passed")
	else:
		print("✗ Invalid type validation failed")
	
	# Test range validation
	tests_total += 1
	if test_range_validation():
		tests_passed += 1
		print("✓ Range validation passed")
	else:
		print("✗ Range validation failed")
	
	# Test nested structure validation
	tests_total += 1
	if test_nested_validation():
		tests_passed += 1
		print("✓ Nested structure validation passed")
	else:
		print("✗ Nested structure validation failed")
	
	# Test unexpected field warning
	tests_total += 1
	if test_unexpected_field():
		tests_passed += 1
		print("✓ Unexpected field warning passed")
	else:
		print("✗ Unexpected field warning failed")
	
	# Test UI data validation
	tests_total += 1
	if test_ui_validation():
		tests_passed += 1
		print("✓ UI data validation passed")
	else:
		print("✗ UI data validation failed")
	
	# Summary
	print("\n=== Test Results ===")
	print("Passed: " + str(tests_passed) + "/" + str(tests_total))
	
	if tests_passed == tests_total:
		print("✓ ALL TESTS PASSED - Schema validation system working correctly")
	else:
		print("✗ SOME TESTS FAILED - Schema validation system needs fixes")

func test_valid_combat_data() -> bool:
	var valid_data: Dictionary = {
		"projectile_radius": 4.0,
		"enemy_radius": 12.0,
		"base_damage": 1.0,
		"crit_chance": 0.1,
		"crit_multiplier": 2.0,
		"_schema_version": "1.0.0",
		"_description": "Test combat data"
	}
	
	return BalanceDB._validate_data(valid_data, "combat")

func test_missing_required_field() -> bool:
	var invalid_data: Dictionary = {
		"projectile_radius": 4.0,
		"enemy_radius": 12.0,
		"base_damage": 1.0,
		# Missing crit_chance and crit_multiplier
		"_schema_version": "1.0.0"
	}
	
	# Should return false (validation failed)
	return not BalanceDB._validate_data(invalid_data, "combat")

func test_invalid_type() -> bool:
	var invalid_data: Dictionary = {
		"projectile_radius": "invalid_string", # Should be float
		"enemy_radius": 12.0,
		"base_damage": 1.0,
		"crit_chance": 0.1,
		"crit_multiplier": 2.0
	}
	
	# Should return false (validation failed)
	return not BalanceDB._validate_data(invalid_data, "combat")

func test_range_validation() -> bool:
	var invalid_data: Dictionary = {
		"projectile_radius": 4.0,
		"enemy_radius": 12.0,
		"base_damage": 1.0,
		"crit_chance": 2.0, # Out of range (should be 0.0-1.0)
		"crit_multiplier": 2.0
	}
	
	# Should return false (validation failed)
	return not BalanceDB._validate_data(invalid_data, "combat")

func test_nested_validation() -> bool:
	var valid_data: Dictionary = {
		"max_enemies": 500,
		"spawn_interval": 1.0,
		"arena_center": {
			"x": 400.0,
			"y": 300.0
		},
		"spawn_radius": 600.0,
		"enemy_hp": 3.0,
		"enemy_speed_min": 60.0,
		"enemy_speed_max": 120.0,
		"spawn_count_min": 3,
		"spawn_count_max": 6,
		"arena_bounds": 1500.0,
		"target_distance": 20.0
	}
	
	var valid_result: bool = BalanceDB._validate_data(valid_data, "waves")
	
	# Test invalid nested structure
	var invalid_data: Dictionary = {
		"max_enemies": 500,
		"spawn_interval": 1.0,
		"arena_center": {
			"x": "invalid", # Should be float
			"y": 300.0
		},
		"spawn_radius": 600.0,
		"enemy_hp": 3.0,
		"enemy_speed_min": 60.0,
		"enemy_speed_max": 120.0,
		"spawn_count_min": 3,
		"spawn_count_max": 6,
		"arena_bounds": 1500.0,
		"target_distance": 20.0
	}
	
	var invalid_result: bool = not BalanceDB._validate_data(invalid_data, "waves")
	
	return valid_result and invalid_result

func test_unexpected_field() -> bool:
	var data_with_typo: Dictionary = {
		"projectile_radius": 4.0,
		"enemy_radius": 12.0,
		"base_damage": 1.0,
		"crit_chance": 0.1,
		"crit_multiplier": 2.0,
		"typo_field": "this should generate a warning"
	}
	
	# Should still pass validation but generate warning
	return BalanceDB._validate_data(data_with_typo, "combat")

func test_ui_validation() -> bool:
	var valid_radar_data: Dictionary = {
		"radar_size": {"x": 150, "y": 150},
		"radar_range": 1500.0,
		"colors": {
			"background": {"r": 0.1, "g": 0.1, "b": 0.2, "a": 0.7},
			"border": {"r": 0.4, "g": 0.4, "b": 0.6, "a": 1.0},
			"player": {"r": 0.2, "g": 0.8, "b": 0.2, "a": 1.0},
			"enemy": {"r": 0.8, "g": 0.2, "b": 0.2, "a": 1.0}
		},
		"dot_sizes": {
			"player": 4.0,
			"enemy_max": 3.0,
			"enemy_min": 1.5
		}
	}
	
	var valid_result: bool = BalanceDB._validate_data(valid_radar_data, "ui.radar")
	
	# Test invalid radar data
	var invalid_radar_data: Dictionary = {
		"radar_size": {"x": "invalid", "y": 150}, # x should be int
		"radar_range": 1500.0,
		"colors": {},
		"dot_sizes": {}
	}
	
	var invalid_result: bool = not BalanceDB._validate_data(invalid_radar_data, "ui.radar")
	
	return valid_result and invalid_result