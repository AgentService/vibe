## AbilityManager_test.gd
## Tests AbilityManager singleton functionality.
##
## Tests:
## - Autoload availability
## - Ability registry loading
## - Definition retrieval
## - Instance creation and independence
##
## Run with:
##   ../Godot_v4.4.1-stable_win64_console.exe --headless tests/ability_system/AbilityManager_test.tscn
extends Node

func _ready() -> void:
	print("=== AbilityManager Test ===")

	# Wait for autoload to load abilities
	await get_tree().create_timer(0.1).timeout

	# Test 1: Autoload availability
	_test_autoload_available()

	# Test 2: Ability loading (will be empty until Phase 1.3 creates ranger_arrow.tres)
	_test_ability_loading()

	# Test 3: Instance independence (if abilities exist)
	_test_instance_independence()

	print("\n=== AbilityManager Test Complete ===")

	if DisplayServer.get_name() == "headless":
		get_tree().quit()


func _test_autoload_available() -> void:
	print("\n--- Test 1: Autoload Availability ---")

	if AbilityManager:
		print("✓ AbilityManager autoload available")
	else:
		print("✗ AbilityManager autoload NOT available")


func _test_ability_loading() -> void:
	print("\n--- Test 2: Ability Loading ---")

	var ability_count := AbilityManager._ability_registry.size()
	print("Loaded abilities: %d" % ability_count)

	if ability_count == 0:
		print("ℹ No abilities loaded yet (expected until Phase 1.3)")
		print("  Abilities will be loaded from: res://data/content/abilities/")
		return

	# If abilities exist, print them
	print("\nRegistered abilities:")
	for ability_id in AbilityManager.get_all_ability_ids():
		var definition := AbilityManager.get_definition(ability_id) as BaseAbility
		var category: String = AbilityManager._ability_categories.get(ability_id, "unknown")
		print("  - %s: %s (category: %s)" % [ability_id, definition.ability_name, category])


func _test_instance_independence() -> void:
	print("\n--- Test 3: Instance Independence ---")

	# This test requires at least one ability to exist
	var ability_ids := AbilityManager.get_all_ability_ids()

	if ability_ids.is_empty():
		print("ℹ Skipping (no abilities loaded yet)")
		return

	# Use first available ability for testing
	var test_ability_id := ability_ids[0]
	print("Testing with ability: %s" % test_ability_id)

	var definition := AbilityManager.get_definition(test_ability_id)
	var instance1 := AbilityManager.create_ability_instance(test_ability_id)
	var instance2 := AbilityManager.create_ability_instance(test_ability_id)

	if not definition or not instance1 or not instance2:
		print("✗ Failed to create instances")
		return

	# Test baseline vs computed stats separation (Phase 1.1 architecture)
	# Baseline (base_damage) is immutable, computed (final_damage) includes modifiers
	var original_base_damage := definition.base_damage

	instance1.base_damage = 999.0  # Modify instance1 baseline
	instance1._recalculate_final_stats()

	print("Instance 1 base_damage: %.2f" % instance1.base_damage)    # 999.0
	print("Instance 1 final_damage: %.2f" % instance1.final_damage)  # 999.0 (no modifiers)
	print("Instance 2 base_damage: %.2f" % instance2.base_damage)    # Original value
	print("Definition base_damage: %.2f" % definition.base_damage)   # Original value

	# Test that instances are independent (modifying instance1 doesn't affect instance2 or definition)
	if instance2.base_damage != instance1.base_damage and definition.base_damage == original_base_damage:
		print("✓ Instances are independent")
	else:
		print("✗ Instances are NOT independent - duplicate() failed")
		print("  instance2.base_damage: %.2f (expected: %.2f)" % [instance2.base_damage, original_base_damage])
		print("  definition.base_damage: %.2f (expected: %.2f)" % [definition.base_damage, original_base_damage])
