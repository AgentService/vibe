## test_scaling_calculator.gd
## Headless test for ScalingCalculator formulas
##
## Validates LINEAR, EXPONENTIAL, and HYPERBOLIC scaling with known outputs.
##
## Run with:
##   ../Godot_v4.4.1-stable_win64_console.exe --headless --script tests/test_scaling_calculator.gd

extends SceneTree

const EPSILON := 0.01  # Floating point tolerance

var _tests_passed := 0
var _tests_failed := 0

func _initialize() -> void:
	print("=" * 60)
	print("SCALING CALCULATOR TEST SUITE")
	print("=" * 60)

	# Test LINEAR flat scaling
	test_linear_flat()

	# Test LINEAR multiplier scaling
	test_linear_multiplier()

	# Test EXPONENTIAL multiplier scaling
	test_exponential_multiplier()

	# Test HYPERBOLIC flat scaling
	test_hyperbolic_flat()

	# Test HYPERBOLIC multiplier scaling
	test_hyperbolic_multiplier()

	# Test formula descriptions
	test_formula_descriptions()

	# Test validation
	test_parameter_validation()

	# Print results
	print("")
	print("=" * 60)
	print("RESULTS: %d passed, %d failed" % [_tests_passed, _tests_failed])
	print("=" * 60)

	# Exit with status code
	quit(_tests_failed)


# ============================================================================
# LINEAR SCALING TESTS
# ============================================================================

func test_linear_flat() -> void:
	print("\n[TEST] LINEAR Flat Scaling (Rump Steak: +25 HP per stack)")

	# Test: 1 stack = 25 HP
	var result := ScalingCalculator.calculate_flat(25.0, 1, ScalingCalculator.ScalingType.LINEAR)
	assert_equal(result, 25.0, "1 stack should give 25 HP")

	# Test: 3 stacks = 75 HP
	result = ScalingCalculator.calculate_flat(25.0, 3, ScalingCalculator.ScalingType.LINEAR)
	assert_equal(result, 75.0, "3 stacks should give 75 HP")

	# Test: 10 stacks = 250 HP
	result = ScalingCalculator.calculate_flat(25.0, 10, ScalingCalculator.ScalingType.LINEAR)
	assert_equal(result, 250.0, "10 stacks should give 250 HP")


func test_linear_multiplier() -> void:
	print("\n[TEST] LINEAR Multiplier Scaling (Focus Stone: +20% per stack)")

	# Test: 1 stack = 1.2x damage
	var result := ScalingCalculator.calculate_multiplier(0.2, 1, ScalingCalculator.ScalingType.LINEAR)
	assert_equal(result, 1.2, "1 stack should give 1.2x damage")

	# Test: 3 stacks = 1.6x damage
	result = ScalingCalculator.calculate_multiplier(0.2, 3, ScalingCalculator.ScalingType.LINEAR)
	assert_equal(result, 1.6, "3 stacks should give 1.6x damage")

	# Test: 10 stacks = 3.0x damage
	result = ScalingCalculator.calculate_multiplier(0.2, 10, ScalingCalculator.ScalingType.LINEAR)
	assert_equal(result, 3.0, "10 stacks should give 3.0x damage")


# ============================================================================
# EXPONENTIAL SCALING TESTS
# ============================================================================

func test_exponential_multiplier() -> void:
	print("\n[TEST] EXPONENTIAL Multiplier Scaling (Feather: +15% per stack, compound)")

	# Test: 1 stack = 1.15x speed
	var result := ScalingCalculator.calculate_multiplier(0.15, 1, ScalingCalculator.ScalingType.EXPONENTIAL)
	assert_equal(result, 1.15, "1 stack should give 1.15x speed")

	# Test: 3 stacks = 1.52x speed (1.15^3 = 1.520875)
	result = ScalingCalculator.calculate_multiplier(0.15, 3, ScalingCalculator.ScalingType.EXPONENTIAL)
	assert_equal(result, 1.520875, "3 stacks should give 1.52x speed (compound)")

	# Test: 10 stacks = 4.05x speed (1.15^10 = 4.0456)
	result = ScalingCalculator.calculate_multiplier(0.15, 10, ScalingCalculator.ScalingType.EXPONENTIAL)
	assert_approx(result, 4.0456, "10 stacks should give ~4.05x speed (compound)")


# ============================================================================
# HYPERBOLIC SCALING TESTS
# ============================================================================

func test_hyperbolic_flat() -> void:
	print("\n[TEST] HYPERBOLIC Flat Scaling (Capped HP: approaches 500 max)")

	# Formula: cap * stacks / (stacks + k)
	# cap = 500, k = 5

	# Test: 1 stack = 500 * 1 / 6 = 83.33 HP
	var result := ScalingCalculator.calculate_flat(50.0, 1, ScalingCalculator.ScalingType.HYPERBOLIC, 500.0, 5.0)
	assert_approx(result, 83.33, "1 stack should give ~83 HP")

	# Test: 5 stacks = 500 * 5 / 10 = 250 HP (half-cap)
	result = ScalingCalculator.calculate_flat(50.0, 5, ScalingCalculator.ScalingType.HYPERBOLIC, 500.0, 5.0)
	assert_equal(result, 250.0, "5 stacks (k=5) should give 250 HP (half-cap)")

	# Test: 10 stacks = 500 * 10 / 15 = 333.33 HP
	result = ScalingCalculator.calculate_flat(50.0, 10, ScalingCalculator.ScalingType.HYPERBOLIC, 500.0, 5.0)
	assert_approx(result, 333.33, "10 stacks should give ~333 HP")

	# Test: 100 stacks = 500 * 100 / 105 = 476.19 HP (approaching cap)
	result = ScalingCalculator.calculate_flat(50.0, 100, ScalingCalculator.ScalingType.HYPERBOLIC, 500.0, 5.0)
	assert_approx(result, 476.19, "100 stacks should approach 500 HP cap (~476 HP)")


func test_hyperbolic_multiplier() -> void:
	print("\n[TEST] HYPERBOLIC Multiplier Scaling (Capped damage: approaches 3.0x max)")

	# Formula: 1 + (cap - 1) * stacks / (stacks + k)
	# cap = 3.0, k = 5

	# Test: 1 stack = 1 + 2.0 * 1/6 = 1.33x damage
	var result := ScalingCalculator.calculate_multiplier(0.2, 1, ScalingCalculator.ScalingType.HYPERBOLIC, 3.0, 5.0)
	assert_approx(result, 1.33, "1 stack should give ~1.33x damage")

	# Test: 5 stacks = 1 + 2.0 * 5/10 = 2.0x damage (half-cap)
	result = ScalingCalculator.calculate_multiplier(0.2, 5, ScalingCalculator.ScalingType.HYPERBOLIC, 3.0, 5.0)
	assert_equal(result, 2.0, "5 stacks (k=5) should give 2.0x damage (half-cap)")

	# Test: 10 stacks = 1 + 2.0 * 10/15 = 2.33x damage
	result = ScalingCalculator.calculate_multiplier(0.2, 10, ScalingCalculator.ScalingType.HYPERBOLIC, 3.0, 5.0)
	assert_approx(result, 2.33, "10 stacks should give ~2.33x damage")

	# Test: 100 stacks = 1 + 2.0 * 100/105 = 2.90x damage (approaching cap)
	result = ScalingCalculator.calculate_multiplier(0.2, 100, ScalingCalculator.ScalingType.HYPERBOLIC, 3.0, 5.0)
	assert_approx(result, 2.90, "100 stacks should approach 3.0x cap (~2.90x)")


# ============================================================================
# HELPER FUNCTION TESTS
# ============================================================================

func test_formula_descriptions() -> void:
	print("\n[TEST] Formula Descriptions")

	var desc := ScalingCalculator.get_formula_description(ScalingCalculator.ScalingType.LINEAR, 0.2, true)
	assert_contains(desc, "20%", "LINEAR multiplier should mention 20%")
	assert_contains(desc, "linear", "LINEAR should mention scaling type")

	desc = ScalingCalculator.get_formula_description(ScalingCalculator.ScalingType.EXPONENTIAL, 0.15, true)
	assert_contains(desc, "15%", "EXPONENTIAL should mention 15%")
	assert_contains(desc, "exponential", "EXPONENTIAL should mention scaling type")

	desc = ScalingCalculator.get_formula_description(ScalingCalculator.ScalingType.HYPERBOLIC, 0.2, true, 3.0)
	assert_contains(desc, "3.0x", "HYPERBOLIC should mention cap")


func test_parameter_validation() -> void:
	print("\n[TEST] Parameter Validation")

	# Test: per_stack <= 0 should warn
	var warnings := ScalingCalculator.validate_parameters(ScalingCalculator.ScalingType.LINEAR, 0.0)
	assert_true(not warnings.is_empty(), "per_stack = 0.0 should produce warnings")

	# Test: HYPERBOLIC with cap = 0 should warn
	warnings = ScalingCalculator.validate_parameters(ScalingCalculator.ScalingType.HYPERBOLIC, 0.2, 0.0, 5.0)
	assert_true(not warnings.is_empty(), "HYPERBOLIC with cap=0 should produce warnings")

	# Test: EXPONENTIAL with per_stack > 1.0 should warn (common mistake: 1.2 instead of 0.2)
	warnings = ScalingCalculator.validate_parameters(ScalingCalculator.ScalingType.EXPONENTIAL, 1.2)
	assert_true(not warnings.is_empty(), "EXPONENTIAL with per_stack > 1.0 should warn")

	# Test: Valid parameters should pass
	warnings = ScalingCalculator.validate_parameters(ScalingCalculator.ScalingType.LINEAR, 25.0)
	assert_true(warnings.is_empty(), "Valid LINEAR parameters should pass")


# ============================================================================
# ASSERTION HELPERS
# ============================================================================

func assert_equal(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) < EPSILON:
		print("  ✓ PASS: %s (%.2f)" % [message, actual])
		_tests_passed += 1
	else:
		print("  ✗ FAIL: %s (expected %.2f, got %.2f)" % [message, expected, actual])
		_tests_failed += 1


func assert_approx(actual: float, expected: float, message: String) -> void:
	var tolerance := 0.1  # Larger tolerance for approximate tests
	if abs(actual - expected) < tolerance:
		print("  ✓ PASS: %s (%.2f ≈ %.2f)" % [message, actual, expected])
		_tests_passed += 1
	else:
		print("  ✗ FAIL: %s (expected ~%.2f, got %.2f)" % [message, expected, actual])
		_tests_failed += 1


func assert_true(condition: bool, message: String) -> void:
	if condition:
		print("  ✓ PASS: %s" % message)
		_tests_passed += 1
	else:
		print("  ✗ FAIL: %s" % message)
		_tests_failed += 1


func assert_contains(text: String, substring: String, message: String) -> void:
	if substring in text:
		print("  ✓ PASS: %s" % message)
		_tests_passed += 1
	else:
		print("  ✗ FAIL: %s (text: '%s')" % [message, text])
		_tests_failed += 1
