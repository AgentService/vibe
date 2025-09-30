extends Node

## Isolated test for MetaProgression autoload
## Tests save/load, currency transactions, unlocks, and signals

var test_results: Array[String] = []


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("=== MetaProgression Isolated Test ===")
	print("=".repeat(60) + "\n")
	
	# Wait one frame for autoloads to initialize
	await get_tree().process_frame
	
	# Run test suite
	_run_test_suite()
	
	# Print results summary
	_print_results()
	
	# Exit after short delay
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _run_test_suite() -> void:
	print("Starting test suite...\n")
	
	# Reset to clean state
	MetaProgression.reset()
	
	_test_initial_state()
	_test_rift_fragments_transactions()
	_test_character_unlocks()
	_test_map_unlocks()
	_test_item_discovery_unlock()
	_test_toggler_system()
	_test_achievements()
	_test_save_load_persistence()


func _test_initial_state() -> void:
	print("TEST: Initial State")
	print("-".repeat(40))
	
	# Default character and map should be unlocked
	if MetaProgression.is_character_unlocked("fuchs"):
		_add_result("✓ PASS: Default character 'fuchs' unlocked")
	else:
		_add_result("✗ FAIL: Default character not unlocked")
	
	if MetaProgression.is_map_unlocked("forest"):
		_add_result("✓ PASS: Default map 'forest' unlocked")
	else:
		_add_result("✗ FAIL: Default map not unlocked")
	
	var fragments = MetaProgression.get_rift_fragments()
	if fragments == 0:
		_add_result("✓ PASS: Starting Rift Fragments = 0")
	else:
		_add_result("✗ FAIL: Starting Rift Fragments = %d (expected 0)" % fragments)
	
	print()


func _test_rift_fragments_transactions() -> void:
	print("TEST: Rift Fragments Transactions")
	print("-".repeat(40))
	
	# Earn fragments
	MetaProgression.earn_rift_fragments(100)
	var balance = MetaProgression.get_rift_fragments()
	if balance == 100:
		_add_result("✓ PASS: Earned 100 fragments (balance: %d)" % balance)
	else:
		_add_result("✗ FAIL: Balance incorrect after earning (got %d, expected 100)" % balance)
	
	# Check affordability
	if MetaProgression.can_afford(50):
		_add_result("✓ PASS: Can afford 50 fragments")
	else:
		_add_result("✗ FAIL: Should be able to afford 50 fragments")
	
	if not MetaProgression.can_afford(150):
		_add_result("✓ PASS: Cannot afford 150 fragments (insufficient funds)")
	else:
		_add_result("✗ FAIL: Should not be able to afford 150 fragments")
	
	# Spend fragments
	var success = MetaProgression.spend_rift_fragments(30)
	balance = MetaProgression.get_rift_fragments()
	if success and balance == 70:
		_add_result("✓ PASS: Spent 30 fragments (remaining: %d)" % balance)
	else:
		_add_result("✗ FAIL: Spending failed or balance incorrect (balance: %d)" % balance)
	
	# Attempt overspend
	success = MetaProgression.spend_rift_fragments(100)
	if not success and balance == 70:
		_add_result("✓ PASS: Overspending prevented (balance unchanged: %d)" % balance)
	else:
		_add_result("✗ FAIL: Overspending not prevented correctly")
	
	print()


func _test_character_unlocks() -> void:
	print("TEST: Character Unlocks")
	print("-".repeat(40))
	
	# Unlock new character
	MetaProgression.unlock_character("warrior")
	if MetaProgression.is_character_unlocked("warrior"):
		_add_result("✓ PASS: Character 'warrior' unlocked")
	else:
		_add_result("✗ FAIL: Character unlock failed")
	
	# Check unlocked list
	var unlocked = MetaProgression.get_unlocked_characters()
	if unlocked.size() == 2 and "fuchs" in unlocked and "warrior" in unlocked:
		_add_result("✓ PASS: Unlocked characters list correct (size: %d)" % unlocked.size())
	else:
		_add_result("✗ FAIL: Unlocked characters list incorrect: %s" % str(unlocked))
	
	# Increment run count
	MetaProgression.increment_character_runs("fuchs")
	MetaProgression.increment_character_runs("fuchs")
	var runs = MetaProgression.get_character_runs("fuchs")
	if runs == 2:
		_add_result("✓ PASS: Character run count tracked (fuchs: %d runs)" % runs)
	else:
		_add_result("✗ FAIL: Run count incorrect (got %d, expected 2)" % runs)
	
	print()


func _test_map_unlocks() -> void:
	print("TEST: Map Unlocks")
	print("-".repeat(40))
	
	# Unlock new map
	MetaProgression.unlock_map("desert")
	if MetaProgression.is_map_unlocked("desert"):
		_add_result("✓ PASS: Map 'desert' unlocked")
	else:
		_add_result("✗ FAIL: Map unlock failed")
	
	# Check unlocked list
	var unlocked = MetaProgression.get_unlocked_maps()
	if unlocked.size() == 2 and "forest" in unlocked and "desert" in unlocked:
		_add_result("✓ PASS: Unlocked maps list correct (size: %d)" % unlocked.size())
	else:
		_add_result("✗ FAIL: Unlocked maps list incorrect: %s" % str(unlocked))
	
	print()


func _test_item_discovery_unlock() -> void:
	print("TEST: Item Discovery & Unlock System")
	print("-".repeat(40))
	
	# Discover item
	MetaProgression.discover_item("items", "sword_basic")
	if MetaProgression.is_item_discovered("items", "sword_basic"):
		_add_result("✓ PASS: Item 'sword_basic' discovered")
	else:
		_add_result("✗ FAIL: Item discovery failed")
	
	# Check discovered list
	var discovered = MetaProgression.get_discovered_items("items")
	if discovered.size() == 1 and "sword_basic" in discovered:
		_add_result("✓ PASS: Discovered items list correct")
	else:
		_add_result("✗ FAIL: Discovered items list incorrect: %s" % str(discovered))
	
	# Unlock discovered item
	MetaProgression.unlock_item("items", "sword_basic")
	if MetaProgression.is_item_unlocked("items", "sword_basic"):
		_add_result("✓ PASS: Item 'sword_basic' unlocked")
	else:
		_add_result("✗ FAIL: Item unlock failed")
	
	# Verify moved from discovered to unlocked
	discovered = MetaProgression.get_discovered_items("items")
	var unlocked = MetaProgression.get_unlocked_items("items")
	if discovered.size() == 0 and unlocked.size() == 1 and "sword_basic" in unlocked:
		_add_result("✓ PASS: Item moved from discovered to unlocked")
	else:
		_add_result("✗ FAIL: Item not properly moved (discovered: %s, unlocked: %s)" % [str(discovered), str(unlocked)])
	
	print()


func _test_toggler_system() -> void:
	print("TEST: Toggler System")
	print("-".repeat(40))
	
	# Toggler should NOT be enabled (need 40 unlocks)
	if not MetaProgression.is_toggler_enabled("items"):
		_add_result("✓ PASS: Toggler not enabled (insufficient unlocks)")
	else:
		_add_result("✗ FAIL: Toggler should not be enabled yet")
	
	# Unlock 40 items to enable toggler
	for i in range(40):
		MetaProgression.discover_item("items", "item_%d" % i)
		MetaProgression.unlock_item("items", "item_%d" % i)
	
	# Enable toggler
	MetaProgression.enable_toggler("items")
	if MetaProgression.is_toggler_enabled("items"):
		_add_result("✓ PASS: Toggler enabled after 40 unlocks")
	else:
		_add_result("✗ FAIL: Toggler not enabled")
	
	# Toggle item off
	MetaProgression.toggle_item("items", "item_5", false)
	if MetaProgression.is_item_disabled("items", "item_5"):
		_add_result("✓ PASS: Item disabled via toggler")
	else:
		_add_result("✗ FAIL: Item toggle failed")
	
	# Toggle item back on
	MetaProgression.toggle_item("items", "item_5", true)
	if not MetaProgression.is_item_disabled("items", "item_5"):
		_add_result("✓ PASS: Item re-enabled via toggler")
	else:
		_add_result("✗ FAIL: Item re-enable failed")
	
	print()


func _test_achievements() -> void:
	print("TEST: Achievement System")
	print("-".repeat(40))
	
	# Unlock global achievement
	MetaProgression.unlock_achievement("first_boss_kill")
	if MetaProgression.has_achievement("first_boss_kill"):
		_add_result("✓ PASS: Global achievement unlocked")
	else:
		_add_result("✗ FAIL: Global achievement unlock failed")
	
	# Unlock character achievement
	MetaProgression.unlock_character_achievement("fuchs", "kills_1000")
	if MetaProgression.has_character_achievement("fuchs", "kills_1000"):
		_add_result("✓ PASS: Character achievement unlocked")
	else:
		_add_result("✗ FAIL: Character achievement unlock failed")
	
	# Unlock skin
	MetaProgression.unlock_skin("fuchs", "blue")
	var skins = MetaProgression.get_unlocked_skins("fuchs")
	if "blue" in skins:
		_add_result("✓ PASS: Character skin unlocked")
	else:
		_add_result("✗ FAIL: Skin unlock failed (skins: %s)" % str(skins))
	
	print()


func _test_save_load_persistence() -> void:
	print("TEST: Save/Load Persistence")
	print("-".repeat(40))

	# Save current state
	var state_before = MetaProgression.get_state()
	MetaProgression.save()
	_add_result("✓ INFO: State saved to disk")

	# Verify save file exists
	var save_path = "user://meta_progression.tres"
	if FileAccess.file_exists(save_path):
		_add_result("✓ PASS: Save file created at %s" % save_path)
	else:
		_add_result("✗ FAIL: Save file not created")
		return

	# Load save file directly to verify persistence
	var loaded_data = ResourceLoader.load(save_path)
	if loaded_data != null:
		_add_result("✓ PASS: Save file loaded successfully")
	else:
		_add_result("✗ FAIL: Failed to load save file")
		return

	# Verify saved data matches current state
	if loaded_data.rift_fragments == state_before.rift_fragments:
		_add_result("✓ PASS: Rift Fragments persisted correctly (%d)" % loaded_data.rift_fragments)
	else:
		_add_result("✗ FAIL: Rift Fragments not persisted (expected: %d, got: %d)" %
			[state_before.rift_fragments, loaded_data.rift_fragments])

	# Verify character unlocks persisted
	if "warrior" in loaded_data.unlocked_characters:
		_add_result("✓ PASS: Character unlocks persisted")
	else:
		_add_result("✗ FAIL: Character unlocks not persisted (chars: %s)" % str(loaded_data.unlocked_characters))

	# Verify item unlocks persisted
	if loaded_data.unlocked_items.size() >= 40:
		_add_result("✓ PASS: Item unlocks persisted (count: %d)" % loaded_data.unlocked_items.size())
	else:
		_add_result("✗ FAIL: Item unlocks not persisted (count: %d)" % loaded_data.unlocked_items.size())

	print()


func _add_result(result: String) -> void:
	test_results.append(result)
	print("  " + result)


func _print_results() -> void:
	print("\n" + "=".repeat(60))
	print("=== Test Results Summary ===")
	print("=".repeat(60))
	
	var passes = test_results.filter(func(r): return r.begins_with("✓ PASS")).size()
	var fails = test_results.filter(func(r): return r.begins_with("✗ FAIL")).size()
	var infos = test_results.filter(func(r): return r.begins_with("✓ INFO")).size()
	
	print("\nPASSED: %d" % passes)
	print("FAILED: %d" % fails)
	print("INFO:   %d" % infos)
	
	if fails == 0:
		print("\n🎉 ALL TESTS PASSED! 🎉")
	else:
		print("\n⚠️  SOME TESTS FAILED")
	
	print("=".repeat(60) + "\n")