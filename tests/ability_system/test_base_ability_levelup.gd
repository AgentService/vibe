## test_base_ability_levelup.gd
## Headless test for BaseAbility progression and scaling math.
##
## Tests:
## - Level-up multiplicative scaling (damage, cooldown)
## - Tag helper functions (has_tag, has_all_tags, has_any_tag)
## - Validation logic
## - to_dict() serialization
##
## Run with:
##   ../Godot_v4.4.1-stable_win64_console.exe --headless --script tests/ability_system/test_base_ability_levelup.gd
extends SceneTree

func _initialize() -> void:
	print("=== BaseAbility Level-Up Test ===\n")

	var all_passed: bool = true

	# Test 1: Basic level-up scaling
	all_passed = test_basic_scaling() and all_passed

	# Test 2: Tag helpers
	all_passed = test_tag_helpers() and all_passed

	# Test 3: Validation
	all_passed = test_validation() and all_passed

	# Test 4: to_dict() serialization
	all_passed = test_to_dict() and all_passed

	# Test 5: Max level clamping
	all_passed = test_max_level_clamping() and all_passed

	print("\n==================================================")
	if all_passed:
		print("✓✓✓ ALL TESTS PASSED ✓✓✓")
		quit(0)
	else:
		print("✗✗✗ SOME TESTS FAILED ✗✗✗")
		quit(1)


# ============================================================================
# TEST 1: Basic Scaling Math
# ============================================================================

func test_basic_scaling() -> bool:
	print("TEST 1: Basic level-up scaling")

	var ability: BaseAbility = BaseAbility.new()
	ability.ability_id = "test_fireball"
	ability.base_damage = 10.0
	ability.cooldown = 2.0
	ability.damage_scaling_per_level = 1.15
	ability.cooldown_scaling_per_level = 0.95
	ability.tags = [AbilityTags.DAMAGE, AbilityTags.COOLDOWN]

	print("  Initial: damage=%.2f, cooldown=%.2f" % [ability.base_damage, ability.cooldown])

	# Level up 5 times
	ability.level_up(5)

	# Expected values (compound scaling)
	var expected_damage: float = 10.0 * pow(1.15, 5)  # ≈ 20.11
	var expected_cooldown: float = 2.0 * pow(0.95, 5)  # ≈ 1.55

	print("  After 5 levels: damage=%.2f (expected: %.2f)" % [ability.base_damage, expected_damage])
	print("  After 5 levels: cooldown=%.2f (expected: %.2f)" % [ability.cooldown, expected_cooldown])

	var damage_diff: float = abs(ability.base_damage - expected_damage)
	var cooldown_diff: float = abs(ability.cooldown - expected_cooldown)

	if damage_diff < 0.01 and cooldown_diff < 0.01:
		print("  ✓ Scaling math correct\n")
		return true
	else:
		print("  ✗ Scaling math incorrect (diff: damage=%.4f, cooldown=%.4f)\n" % [damage_diff, cooldown_diff])
		return false


# ============================================================================
# TEST 2: Tag Helper Functions
# ============================================================================

func test_tag_helpers() -> bool:
	print("TEST 2: Tag helper functions")

	var ability: BaseAbility = BaseAbility.new()
	ability.tags = [AbilityTags.PROJECTILE, AbilityTags.FIRE, AbilityTags.DAMAGE]

	# Test has_tag
	var test1: bool = ability.has_tag(AbilityTags.PROJECTILE)
	var test2: bool = ability.has_tag(AbilityTags.FIRE)
	var test3: bool = not ability.has_tag(AbilityTags.COLD)

	# Test has_all_tags
	var test4: bool = ability.has_all_tags([AbilityTags.PROJECTILE, AbilityTags.FIRE])
	var test5: bool = not ability.has_all_tags([AbilityTags.PROJECTILE, AbilityTags.COLD])

	# Test has_any_tag
	var test6: bool = ability.has_any_tag([AbilityTags.FIRE, AbilityTags.COLD])
	var test7: bool = ability.has_any_tag([AbilityTags.COLD, AbilityTags.LIGHTNING])

	var all_tag_tests: bool = test1 and test2 and test3 and test4 and test5 and test6 and not test7

	if all_tag_tests:
		print("  ✓ has_tag: PASS")
		print("  ✓ has_all_tags: PASS")
		print("  ✓ has_any_tag: PASS\n")
		return true
	else:
		print("  ✗ Tag helper tests failed")
		print("    has_tag(PROJECTILE): %s (expected: true)" % test1)
		print("    has_tag(FIRE): %s (expected: true)" % test2)
		print("    has_tag(COLD): %s (expected: false)" % (not test3))
		print("    has_all_tags([PROJECTILE, FIRE]): %s (expected: true)" % test4)
		print("    has_all_tags([PROJECTILE, COLD]): %s (expected: false)" % (not test5))
		print("    has_any_tag([FIRE, COLD]): %s (expected: true)" % test6)
		print("    has_any_tag([COLD, LIGHTNING]): %s (expected: false)" % test7)
		print()
		return false


# ============================================================================
# TEST 3: Validation
# ============================================================================

func test_validation() -> bool:
	print("TEST 3: Validation logic")

	# Valid ability
	var valid_ability: BaseAbility = BaseAbility.new()
	valid_ability.ability_id = "valid"
	valid_ability.ability_name = "Valid Ability"
	valid_ability.tags = [AbilityTags.DAMAGE]
	valid_ability.base_damage = 10.0
	valid_ability.cooldown = 1.0

	var valid_errors: Array[String] = valid_ability.validate()

	# Invalid ability (missing required fields)
	var invalid_ability: BaseAbility = BaseAbility.new()
	invalid_ability.ability_id = ""  # Empty ID
	invalid_ability.cooldown = -1.0  # Invalid cooldown
	invalid_ability.tags = ["invalid_tag"]  # Invalid tag

	var invalid_errors: Array[String] = invalid_ability.validate()

	var test1: bool = valid_errors.is_empty()
	var test2: bool = not invalid_errors.is_empty()
	var test3: bool = invalid_errors.size() >= 3  # Should have at least 3 errors

	if test1 and test2 and test3:
		print("  ✓ Valid ability has no errors")
		print("  ✓ Invalid ability detected (%d errors)" % invalid_errors.size())
		print()
		return true
	else:
		print("  ✗ Validation failed")
		print("    Valid ability errors: %d (expected: 0)" % valid_errors.size())
		print("    Invalid ability errors: %d (expected: >= 3)" % invalid_errors.size())
		if not valid_errors.is_empty():
			print("    Unexpected errors in valid ability:")
			for error in valid_errors:
				print("      - %s" % error)
		print()
		return false


# ============================================================================
# TEST 4: to_dict() Serialization
# ============================================================================

func test_to_dict() -> bool:
	print("TEST 4: to_dict() serialization")

	var ability: BaseAbility = BaseAbility.new()
	ability.ability_id = "test_ability"
	ability.ability_name = "Test Ability"
	ability.tags = [AbilityTags.PROJECTILE, AbilityTags.DAMAGE]
	ability.base_damage = 15.0
	ability.cooldown = 1.5
	ability.projectile_speed = 400.0
	ability.projectile_count = 3

	var dict: Dictionary = ability.to_dict()

	var test1: bool = dict.has("ability_id") and dict["ability_id"] == "test_ability"
	var test2: bool = dict.has("base_damage") and abs(dict["base_damage"] - 15.0) < 0.01
	var test3: bool = dict.has("projectile")  # Should include projectile data
	var test4: bool = dict["projectile"].has("count") and dict["projectile"]["count"] == 3

	if test1 and test2 and test3 and test4:
		print("  ✓ to_dict() includes all required fields")
		print("  ✓ Conditional properties (projectile) included\n")
		return true
	else:
		print("  ✗ to_dict() serialization failed")
		print("    Has ability_id: %s" % test1)
		print("    Has base_damage: %s" % test2)
		print("    Has projectile data: %s" % test3)
		print("    Projectile count correct: %s" % test4)
		print()
		return false


# ============================================================================
# TEST 5: Max Level Clamping
# ============================================================================

func test_max_level_clamping() -> bool:
	print("TEST 5: Max level clamping")

	var ability: BaseAbility = BaseAbility.new()
	ability.ability_id = "test"
	ability.ability_level = 1
	ability.max_level = 5
	ability.base_damage = 10.0
	ability.damage_scaling_per_level = 1.15
	ability.tags = [AbilityTags.DAMAGE]

	# Try to level up 10 times (should clamp at max_level)
	ability.level_up(10)

	var test1: bool = ability.ability_level == 5
	var expected_damage: float = 10.0 * pow(1.15, 4)  # Only 4 levels gained (1 → 5)
	var test2: bool = abs(ability.base_damage - expected_damage) < 0.01

	if test1 and test2:
		print("  ✓ Level clamped at max_level (%d)" % ability.max_level)
		print("  ✓ Scaling applied correctly for clamped levels\n")
		return true
	else:
		print("  ✗ Max level clamping failed")
		print("    Final level: %d (expected: 5)" % ability.ability_level)
		print("    Damage: %.2f (expected: %.2f)" % [ability.base_damage, expected_damage])
		print()
		return false
