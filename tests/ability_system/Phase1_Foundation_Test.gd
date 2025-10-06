## Phase1_Foundation_Test.gd
## Comprehensive integration test for Ability System Phase 1 Foundation.
##
## Tests all components working together:
## - AbilityTags constant accessibility
## - BaseAbility level-up and tag matching
## - ProjectileAbility inheritance and signal emission
## - BaseTome tag matching and stat modification
## - EventBus signal definitions
##
## This test requires EventBus autoload (use .tscn scene execution).
##
## Run with:
##   ../Godot_v4.4.1-stable_win64_console.exe --headless tests/ability_system/Phase1_Foundation_Test.tscn
extends Node

var test_results: Array[bool] = []
var test_names: Array[String] = []


func _ready() -> void:
	print("=== Phase 1.1 Foundation Validation ===\n")

	# Run all integration tests
	_test_ability_tags()
	_test_base_ability()
	_test_projectile_ability()
	_test_base_tome()
	_test_eventbus_signals()

	# Print summary
	_print_summary()

	# Auto-quit in headless mode
	if DisplayServer.get_name() == "headless":
		if test_results.all(func(result): return result):
			get_tree().quit(0)
		else:
			get_tree().quit(1)


# ============================================================================
# TEST 1: AbilityTags System
# ============================================================================

func _test_ability_tags() -> void:
	print("TEST 1: AbilityTags System")

	var passed: bool = true

	# Test constant values
	if AbilityTags.PROJECTILE != &"projectile":
		print("  ✗ PROJECTILE constant incorrect")
		passed = false
	else:
		print("  ✓ PROJECTILE constant: &\"projectile\"")

	if AbilityTags.FIRE != &"fire":
		print("  ✗ FIRE constant incorrect")
		passed = false
	else:
		print("  ✓ FIRE constant: &\"fire\"")

	# Test get_all_tags()
	var all_tags: Array[StringName] = AbilityTags.get_all_tags()
	if all_tags.size() < 15:
		print("  ✗ get_all_tags() returned %d tags (expected: >= 15)" % all_tags.size())
		passed = false
	else:
		print("  ✓ get_all_tags() returned %d tags" % all_tags.size())

	# Test is_valid_tag()
	if not AbilityTags.is_valid_tag(&"fire"):
		print("  ✗ is_valid_tag(&\"fire\") returned false")
		passed = false
	else:
		print("  ✓ is_valid_tag(&\"fire\") = true")

	if AbilityTags.is_valid_tag(&"invalid_tag"):
		print("  ✗ is_valid_tag(&\"invalid_tag\") returned true (should be false)")
		passed = false
	else:
		print("  ✓ is_valid_tag(&\"invalid_tag\") = false")

	# Test get_tag_description()
	var desc: String = AbilityTags.get_tag_description(&"fire")
	if desc.is_empty() or desc == "Unknown tag":
		print("  ✗ get_tag_description(&\"fire\") returned empty/unknown")
		passed = false
	else:
		print("  ✓ get_tag_description(&\"fire\") = \"%s\"" % desc)

	# Test get_tag_color()
	var color: Color = AbilityTags.get_tag_color(&"fire")
	if color == Color(0.5, 0.5, 0.5):  # Default gray
		print("  ✗ get_tag_color(&\"fire\") returned default color")
		passed = false
	else:
		print("  ✓ get_tag_color(&\"fire\") = %s" % color)

	_record_test("AbilityTags System", passed)
	print()


# ============================================================================
# TEST 2: BaseAbility
# ============================================================================

func _test_base_ability() -> void:
	print("TEST 2: BaseAbility")

	var passed: bool = true

	# Create a test ability
	var ability: BaseAbility = BaseAbility.new()
	ability.ability_id = "test_fireball"
	ability.ability_name = "Test Fireball"
	ability.tags = [AbilityTags.DAMAGE, AbilityTags.COOLDOWN]
	ability.base_damage = 10.0
	ability.base_cooldown = 2.0
	ability.damage_scaling_per_level = 1.15
	ability.cooldown_scaling_per_level = 0.95

	# Test level-up scaling (should modify base_damage AND final_damage)
	ability.level_up(5)
	var expected_damage: float = 10.0 * pow(1.15, 5)
	var expected_cooldown: float = 2.0 * pow(0.95, 5)

	if abs(ability.base_damage - expected_damage) < 0.01:
		print("  ✓ Level-up base_damage scaling correct (%.2f)" % ability.base_damage)
	else:
		print("  ✗ Level-up base_damage scaling incorrect (%.2f != %.2f)" % [ability.base_damage, expected_damage])
		passed = false

	if abs(ability.final_damage - expected_damage) < 0.01:
		print("  ✓ Level-up final_damage matches base_damage (%.2f)" % ability.final_damage)
	else:
		print("  ✗ Level-up final_damage incorrect (%.2f != %.2f)" % [ability.final_damage, expected_damage])
		passed = false

	if abs(ability.base_cooldown - expected_cooldown) < 0.01:
		print("  ✓ Level-up base_cooldown scaling correct (%.2f)" % ability.base_cooldown)
	else:
		print("  ✗ Level-up base_cooldown scaling incorrect (%.2f != %.2f)" % [ability.base_cooldown, expected_cooldown])
		passed = false

	if abs(ability.final_cooldown - expected_cooldown) < 0.01:
		print("  ✓ Level-up final_cooldown matches base_cooldown (%.2f)" % ability.final_cooldown)
	else:
		print("  ✗ Level-up final_cooldown incorrect (%.2f != %.2f)" % [ability.final_cooldown, expected_cooldown])
		passed = false

	# Test tag helpers
	if ability.has_tag(AbilityTags.DAMAGE):
		print("  ✓ has_tag(DAMAGE) = true")
	else:
		print("  ✗ has_tag(DAMAGE) = false (should be true)")
		passed = false

	if ability.has_all_tags([AbilityTags.DAMAGE, AbilityTags.COOLDOWN]):
		print("  ✓ has_all_tags([DAMAGE, COOLDOWN]) = true")
	else:
		print("  ✗ has_all_tags failed")
		passed = false

	if ability.has_any_tag([AbilityTags.FIRE, AbilityTags.DAMAGE]):
		print("  ✓ has_any_tag([FIRE, DAMAGE]) = true")
	else:
		print("  ✗ has_any_tag failed")
		passed = false

	# Test validation
	var errors: Array[String] = ability.validate()
	if errors.is_empty():
		print("  ✓ Validation passed (no errors)")
	else:
		print("  ✗ Validation failed: %d errors" % errors.size())
		for error in errors:
			print("    - %s" % error)
		passed = false

	_record_test("BaseAbility", passed)
	print()


# ============================================================================
# TEST 3: ProjectileAbility
# ============================================================================

func _test_projectile_ability() -> void:
	print("TEST 3: ProjectileAbility")

	var passed: bool = true

	# Create a test projectile ability
	var proj_ability: ProjectileAbility = ProjectileAbility.new()
	proj_ability.ability_id = "test_projectile"
	proj_ability.ability_name = "Test Projectile"
	proj_ability.base_damage = 15.0
	proj_ability.base_cooldown = 1.0
	proj_ability.projectile_speed = 400.0
	proj_ability.projectile_count = 3
	proj_ability.fire_mode = ProjectileAbility.FireMode.RANDOM
	proj_ability._recalculate_final_stats()  # Initialize final stats

	# Test tag auto-addition (_init should add PROJECTILE, COOLDOWN, DAMAGE tags)
	if proj_ability.has_tag(AbilityTags.PROJECTILE):
		print("  ✓ PROJECTILE tag auto-added")
	else:
		print("  ✗ PROJECTILE tag missing (should be auto-added in _init)")
		passed = false

	if proj_ability.has_tag(AbilityTags.DAMAGE):
		print("  ✓ DAMAGE tag auto-added")
	else:
		print("  ✗ DAMAGE tag missing")
		passed = false

	# Test signal emission
	var signal_emitted: bool = false
	var received_data: Dictionary = {}

	# Connect to EventBus signal
	var _connection = EventBus.ability_projectile_requested.connect(
		func(projectile_data: Dictionary):
			signal_emitted = true
			received_data = projectile_data
	)

	# Create a mock player node
	var mock_player: Node2D = Node2D.new()
	mock_player.global_position = Vector2(100, 100)

	# Activate ability
	proj_ability.activate(mock_player, {})

	# Check if signal was emitted
	await get_tree().process_frame  # Give time for signal processing

	if signal_emitted:
		print("  ✓ ability_projectile_requested signal emitted")
	else:
		print("  ✗ Signal not emitted")
		passed = false

	# Validate payload structure
	if received_data.has("ability_id") and received_data["ability_id"] == "test_projectile":
		print("  ✓ Payload contains correct ability_id")
	else:
		print("  ✗ Payload missing or incorrect ability_id")
		passed = false

	if received_data.has("damage") and abs(received_data["damage"] - 15.0) < 0.01:
		print("  ✓ Payload contains correct damage")
	else:
		print("  ✗ Payload missing or incorrect damage")
		passed = false

	if received_data.has("direction") and received_data["direction"] is Vector2:
		print("  ✓ Payload contains direction vector")
	else:
		print("  ✗ Payload missing direction")
		passed = false

	# Cleanup
	mock_player.queue_free()

	_record_test("ProjectileAbility", passed)
	print()


# ============================================================================
# TEST 4: BaseTome
# ============================================================================

func _test_base_tome() -> void:
	print("TEST 4: BaseTome (Descriptor Pattern)")

	var passed: bool = true

	# Create a test ability with baseline stats
	var ability: BaseAbility = BaseAbility.new()
	ability.ability_id = "test_ability"
	ability.tags = [AbilityTags.PROJECTILE, AbilityTags.FIRE]
	ability.base_damage = 10.0
	ability.base_cooldown = 1.0
	ability._recalculate_final_stats()  # Initialize final stats

	# Create a tome with specific tag applicability
	var tome: BaseTome = BaseTome.new()
	tome.tome_id = "fire_mastery"
	tome.tome_name = "Fire Mastery"
	tome.applicable_tags = [AbilityTags.FIRE]
	tome.damage_multiplier = 1.25
	tome.cooldown_multiplier = 0.9

	# Test can_apply_to_ability (should match on FIRE tag)
	if tome.can_apply_to_ability(ability):
		print("  ✓ can_apply_to_ability() = true (matches FIRE tag)")
	else:
		print("  ✗ can_apply_to_ability() = false (should match FIRE tag)")
		passed = false

	# Test global applicability (empty tags = applies to all)
	var global_tome: BaseTome = BaseTome.new()
	global_tome.tome_id = "universal_power"
	global_tome.applicable_tags = []  # Empty = global
	global_tome.damage_multiplier = 1.1

	if global_tome.can_apply_to_ability(ability):
		print("  ✓ Global tome (empty tags) applies to all abilities")
	else:
		print("  ✗ Global tome failed to apply")
		passed = false

	# Test descriptor pattern with stacking (idempotent application)
	print("  Testing descriptor pattern with idempotent replacement:")

	# Apply 2 stacks of fire_mastery
	tome.apply_to_ability(ability, 2)

	var expected_damage: float = 10.0 * pow(1.25, 2)  # 10 * 1.5625 = 15.625
	var expected_cooldown: float = 1.0 * pow(0.9, 2)  # 1.0 * 0.81 = 0.81

	# Check that base_damage is UNCHANGED (immutable baseline)
	if abs(ability.base_damage - 10.0) < 0.01:
		print("  ✓ base_damage unchanged (immutable baseline: %.2f)" % ability.base_damage)
	else:
		print("  ✗ base_damage was modified (should stay at 10.0, got %.2f)" % ability.base_damage)
		passed = false

	# Check that final_damage is COMPUTED correctly
	if abs(ability.final_damage - expected_damage) < 0.01:
		print("  ✓ final_damage computed correctly (%.2f)" % ability.final_damage)
	else:
		print("  ✗ final_damage incorrect (%.2f != %.2f)" % [ability.final_damage, expected_damage])
		passed = false

	if abs(ability.final_cooldown - expected_cooldown) < 0.01:
		print("  ✓ final_cooldown computed correctly (%.2f)" % ability.final_cooldown)
	else:
		print("  ✗ final_cooldown incorrect (%.2f != %.2f)" % [ability.final_cooldown, expected_cooldown])
		passed = false

	# Test idempotent replacement (apply same tome again with different stack)
	print("  Testing idempotent replacement (reapply with 3 stacks):")
	tome.apply_to_ability(ability, 3)  # Reapply with 3 stacks (should REPLACE 2 stacks)

	var expected_damage_3stacks: float = 10.0 * pow(1.25, 3)  # 10 * 1.953125 = 19.53125

	if abs(ability.final_damage - expected_damage_3stacks) < 0.01:
		print("  ✓ Idempotent replacement works (%.2f = 10 * 1.25^3)" % ability.final_damage)
	else:
		print("  ✗ Idempotent replacement failed (%.2f != %.2f)" % [ability.final_damage, expected_damage_3stacks])
		passed = false

	# Verify base_damage STILL unchanged
	if abs(ability.base_damage - 10.0) < 0.01:
		print("  ✓ base_damage still unchanged after reapplication (%.2f)" % ability.base_damage)
	else:
		print("  ✗ base_damage was modified during reapplication" )
		passed = false

	_record_test("BaseTome (Descriptor Pattern)", passed)
	print()


# ============================================================================
# TEST 5: EventBus Signals
# ============================================================================

func _test_eventbus_signals() -> void:
	print("TEST 5: EventBus Signals")

	var passed: bool = true

	# Test that all ability system signals exist and can be emitted
	var signals_to_test: Array[String] = [
		"ability_activated",
		"ability_projectile_requested",
		"ability_acquired",
		"ability_leveled_up",
		"tome_acquired",
		"gold_gained",
		"gold_spent",
		"chest_spawned",
		"chest_opened",
		"item_acquired"
	]

	for signal_name in signals_to_test:
		if EventBus.has_signal(signal_name):
			print("  ✓ Signal '%s' exists" % signal_name)
		else:
			print("  ✗ Signal '%s' missing" % signal_name)
			passed = false

	# Test signal emission (ability_activated)
	var signal_received: bool = false
	var _connection = EventBus.ability_activated.connect(
		func(ability_id: String):
			signal_received = true
	)

	EventBus.ability_activated.emit("test_ability")
	await get_tree().process_frame

	if signal_received:
		print("  ✓ ability_activated signal emitted successfully")
	else:
		print("  ✗ ability_activated signal not received")
		passed = false

	_record_test("EventBus Signals", passed)
	print()


# ============================================================================
# SUMMARY
# ============================================================================

func _record_test(test_name: String, passed: bool) -> void:
	test_names.append(test_name)
	test_results.append(passed)


func _print_summary() -> void:
	print("==================================================")
	print("TEST SUMMARY")
	print("==================================================")

	var passed_count: int = 0
	for i in range(test_names.size()):
		var status: String = "✓" if test_results[i] else "✗"
		print("%s %s" % [status, test_names[i]])
		if test_results[i]:
			passed_count += 1

	print()
	print("Total: %d/%d tests passed" % [passed_count, test_names.size()])
	print()

	if test_results.all(func(result): return result):
		print("✓✓✓ ALL PHASE 1.1 TESTS PASSED ✓✓✓")
	else:
		print("✗✗✗ SOME TESTS FAILED ✗✗✗")
