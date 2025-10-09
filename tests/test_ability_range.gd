## test_ability_range.gd
## Validation test for per-ability range system
##
## Tests:
## - DamageAbility base_range and final_range properties
## - ProjectileAbility default range override (900px)
## - Range recalculation with tome modifiers
## - Range clamping (50-3000px bounds)
##
## Run: ../Godot_v4.4.1-stable_win64_console.exe --headless --script tests/test_ability_range.gd
extends SceneTree

# Need to preload classes for standalone test
const DamageAbility = preload("res://scripts/resources/abilities/DamageAbility.gd")
const ProjectileAbility = preload("res://scripts/resources/abilities/ProjectileAbility.gd")
const BaseTome = preload("res://scripts/resources/tomes/BaseTome.gd")

func _initialize():
	print("=== Per-Ability Range System Test ===\n")

	var test_passed := true

	# Test 1: DamageAbility default range
	print("[Test 1] DamageAbility default range (800px)")
	var damage_ability = DamageAbility.new()
	if damage_ability.base_range != 800.0:
		print("  ❌ FAILED: base_range should be 800.0, got %.1f" % damage_ability.base_range)
		test_passed = false
	elif damage_ability.final_range != 800.0:
		print("  ❌ FAILED: final_range should be 800.0, got %.1f" % damage_ability.final_range)
		test_passed = false
	else:
		print("  ✅ PASSED: DamageAbility defaults to 800px range\n")

	# Test 2: ProjectileAbility default range override
	print("[Test 2] ProjectileAbility range override (900px)")
	var projectile_ability = ProjectileAbility.new()
	if projectile_ability.base_range != 900.0:
		print("  ❌ FAILED: base_range should be 900.0, got %.1f" % projectile_ability.base_range)
		test_passed = false
	elif projectile_ability.final_range != 900.0:
		print("  ❌ FAILED: final_range should be 900.0, got %.1f" % projectile_ability.final_range)
		test_passed = false
	else:
		print("  ✅ PASSED: ProjectileAbility defaults to 900px range\n")

	# Test 3: Range modifier with tome (1.25x multiplier)
	print("[Test 3] Range modifier with tome (1.25x multiplier)")
	var ability_with_tome = ProjectileAbility.new()
	ability_with_tome.base_range = 600.0
	ability_with_tome._recalculate_final_stats()

	# Create tome modifier
	var tome = BaseTome.new()
	tome.tome_id = "tome_range_test"
	tome.range_multiplier = 1.25

	# Apply 1 stack
	tome.apply_to_ability(ability_with_tome, 1)

	var expected_range := 600.0 * 1.25  # 750.0
	if absf(ability_with_tome.final_range - expected_range) > 0.1:
		print("  ❌ FAILED: final_range should be %.1f, got %.1f" % [expected_range, ability_with_tome.final_range])
		test_passed = false
	else:
		print("  ✅ PASSED: 1 stack = 750px (600 * 1.25)\n")

	# Test 4: Range modifier stacking (2 stacks = 1.25^2)
	print("[Test 4] Range modifier stacking (2 stacks)")
	ability_with_tome.base_range = 600.0
	tome.apply_to_ability(ability_with_tome, 2)

	expected_range = 600.0 * pow(1.25, 2)  # 937.5
	if absf(ability_with_tome.final_range - expected_range) > 0.1:
		print("  ❌ FAILED: final_range should be %.1f, got %.1f" % [expected_range, ability_with_tome.final_range])
		test_passed = false
	else:
		print("  ✅ PASSED: 2 stacks = 937.5px (600 * 1.25^2)\n")

	# Test 5: Range clamping (minimum 50px)
	print("[Test 5] Range clamping - minimum (50px)")
	var ability_min_range = DamageAbility.new()
	ability_min_range.base_range = 10.0  # Below minimum
	ability_min_range._recalculate_final_stats()

	if ability_min_range.final_range != 50.0:
		print("  ❌ FAILED: final_range should be clamped to 50.0, got %.1f" % ability_min_range.final_range)
		test_passed = false
	else:
		print("  ✅ PASSED: Range clamped to minimum 50px\n")

	# Test 6: Range clamping (maximum 3000px)
	print("[Test 6] Range clamping - maximum (3000px)")
	var ability_max_range = DamageAbility.new()
	ability_max_range.base_range = 5000.0  # Above maximum
	ability_max_range._recalculate_final_stats()

	if ability_max_range.final_range != 3000.0:
		print("  ❌ FAILED: final_range should be clamped to 3000.0, got %.1f" % ability_max_range.final_range)
		test_passed = false
	else:
		print("  ✅ PASSED: Range clamped to maximum 3000px\n")

	# Test 7: Validate existing abilities (heartseeker.tres)
	print("[Test 7] Load and validate existing abilities")
	var heartseeker = load("res://data/content/abilities/projectile/heartseeker.tres")
	if not heartseeker:
		print("  ⚠️  WARNING: Could not load heartseeker.tres")
	elif heartseeker.base_range != 900.0:
		print("  ❌ FAILED: heartseeker.tres should have base_range = 900.0, got %.1f" % heartseeker.base_range)
		test_passed = false
	else:
		print("  ✅ PASSED: heartseeker.tres has base_range = 900px")

	var volley = load("res://data/content/abilities/projectile/volley.tres")
	if not volley:
		print("  ⚠️  WARNING: Could not load volley.tres")
	elif volley.base_range != 900.0:
		print("  ❌ FAILED: volley.tres should have base_range = 900.0, got %.1f" % volley.base_range)
		test_passed = false
	else:
		print("  ✅ PASSED: volley.tres has base_range = 900px\n")

	# Test 8: to_dict() includes range values
	print("[Test 8] to_dict() includes range values")
	var ability_dict_test = ProjectileAbility.new()
	ability_dict_test.base_range = 700.0
	ability_dict_test._recalculate_final_stats()
	var dict = ability_dict_test.to_dict()

	if not dict.has("base_range"):
		print("  ❌ FAILED: to_dict() missing 'base_range' key")
		test_passed = false
	elif dict["base_range"] != 700.0:
		print("  ❌ FAILED: to_dict() base_range incorrect")
		test_passed = false
	elif not dict.has("final_range"):
		print("  ❌ FAILED: to_dict() missing 'final_range' key")
		test_passed = false
	elif dict["final_range"] != 700.0:
		print("  ❌ FAILED: to_dict() final_range incorrect")
		test_passed = false
	else:
		print("  ✅ PASSED: to_dict() includes range values\n")

	# Test 9: validate() checks base_range > 0
	print("[Test 9] validate() checks base_range > 0")
	var invalid_ability = DamageAbility.new()
	invalid_ability.base_range = 0.0
	var errors = invalid_ability.validate()

	var has_range_error := false
	for error in errors:
		if "base_range" in error:
			has_range_error = true
			break

	if not has_range_error:
		print("  ❌ FAILED: validate() should catch base_range <= 0")
		test_passed = false
	else:
		print("  ✅ PASSED: validate() catches invalid range\n")

	# Final result
	print("==================================================")
	if test_passed:
		print("✅✅✅ ALL RANGE TESTS PASSED ✅✅✅")
		quit(0)
	else:
		print("❌❌❌ SOME TESTS FAILED ❌❌❌")
		quit(1)
