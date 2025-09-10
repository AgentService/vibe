extends Node

## Test BossUpdateManager registration system and array-backed registry
## Validates O(1) swap-remove, registration/unregistration, and basic functionality

var boss_manager: Node
var test_boss_nodes: Array[CharacterBody2D] = []

func _ready() -> void:
	print("=== BossUpdateManager Registration System Test ===")
	
	# Wait for autoloads to initialize
	await get_tree().create_timer(0.1).timeout
	
	# Get the autoloaded BossUpdateManager
	boss_manager = BossUpdateManager
	if not boss_manager:
		print("FAIL: BossUpdateManager autoload not found")
		get_tree().quit(1)
		return
	
	# Run test suite
	if not test_registration_basic():
		get_tree().quit(1)
		return
	
	if not test_swap_remove_functionality():
		get_tree().quit(1)
		return
	
	if not test_duplicate_registration():
		get_tree().quit(1)
		return
	
	if not test_missing_boss_unregistration():
		get_tree().quit(1)
		return
	
	print("SUCCESS: All BossUpdateManager registration tests passed!")
	print("=== Test Complete ===")
	get_tree().quit(0)

## Test basic registration and unregistration
func test_registration_basic() -> bool:
	print("\n--- Test: Basic Registration ---")
	
	# Create test boss nodes
	var boss1 = CharacterBody2D.new()
	var boss2 = CharacterBody2D.new()
	test_boss_nodes = [boss1, boss2]
	
	# Test initial state
	var debug_info = boss_manager.get_debug_info()
	if debug_info.registered_bosses != 0:
		print("FAIL: Expected 0 registered bosses, got %d" % debug_info.registered_bosses)
		return false
	
	# Register bosses
	boss_manager.register_boss(boss1, "boss_test_1")
	boss_manager.register_boss(boss2, "boss_test_2")
	
	# Verify registration
	debug_info = boss_manager.get_debug_info()
	if debug_info.registered_bosses != 2:
		print("FAIL: Expected 2 registered bosses, got %d" % debug_info.registered_bosses)
		return false
	
	if debug_info.boss_ids.size() != 2:
		print("FAIL: Expected 2 boss IDs, got %d" % debug_info.boss_ids.size())
		return false
	
	if not debug_info.boss_ids.has("boss_test_1") or not debug_info.boss_ids.has("boss_test_2"):
		print("FAIL: Boss IDs not found in registry")
		return false
	
	# Unregister one boss
	boss_manager.unregister_boss("boss_test_1")
	
	# Verify unregistration
	debug_info = boss_manager.get_debug_info()
	if debug_info.registered_bosses != 1:
		print("FAIL: Expected 1 registered boss after unregistration, got %d" % debug_info.registered_bosses)
		return false
	
	if debug_info.boss_ids.has("boss_test_1"):
		print("FAIL: boss_test_1 should not be in registry after unregistration")
		return false
	
	if not debug_info.boss_ids.has("boss_test_2"):
		print("FAIL: boss_test_2 should still be in registry")
		return false
	
	print("PASS: Basic registration/unregistration working")
	return true

## Test swap-remove functionality maintains array integrity
func test_swap_remove_functionality() -> bool:
	print("\n--- Test: Swap-Remove Functionality ---")
	
	# Clean slate
	boss_manager.unregister_boss("boss_test_2")
	
	# Create multiple bosses to test swap-remove
	var bosses: Array[CharacterBody2D] = []
	for i in range(5):
		var boss = CharacterBody2D.new()
		bosses.append(boss)
		boss_manager.register_boss(boss, "boss_swap_%d" % i)
	
	# Verify all registered
	var debug_info = boss_manager.get_debug_info()
	if debug_info.registered_bosses != 5:
		print("FAIL: Expected 5 bosses, got %d" % debug_info.registered_bosses)
		return false
	
	# Remove middle boss (should trigger swap with last)
	boss_manager.unregister_boss("boss_swap_2")
	
	# Verify count reduced
	debug_info = boss_manager.get_debug_info()
	if debug_info.registered_bosses != 4:
		print("FAIL: Expected 4 bosses after middle removal, got %d" % debug_info.registered_bosses)
		return false
	
	# Verify boss_swap_2 is gone
	if debug_info.boss_ids.has("boss_swap_2"):
		print("FAIL: boss_swap_2 should be removed")
		return false
	
	# Verify other bosses still exist
	for i in [0, 1, 3, 4]:
		if not debug_info.boss_ids.has("boss_swap_%d" % i):
			print("FAIL: boss_swap_%d should still exist" % i)
			return false
	
	# Clean up remaining bosses
	for i in [0, 1, 3, 4]:
		boss_manager.unregister_boss("boss_swap_%d" % i)
	
	# Verify empty
	debug_info = boss_manager.get_debug_info()
	if debug_info.registered_bosses != 0:
		print("FAIL: Expected 0 bosses after cleanup, got %d" % debug_info.registered_bosses)
		return false
	
	print("PASS: Swap-remove functionality working correctly")
	return true

## Test duplicate registration handling
func test_duplicate_registration() -> bool:
	print("\n--- Test: Duplicate Registration Handling ---")
	
	var boss = CharacterBody2D.new()
	
	# Register boss
	boss_manager.register_boss(boss, "boss_duplicate")
	
	# Try to register same ID again
	boss_manager.register_boss(boss, "boss_duplicate")
	
	# Should still have only 1 boss
	var debug_info = boss_manager.get_debug_info()
	if debug_info.registered_bosses != 1:
		print("FAIL: Expected 1 boss after duplicate registration, got %d" % debug_info.registered_bosses)
		return false
	
	# Clean up
	boss_manager.unregister_boss("boss_duplicate")
	
	print("PASS: Duplicate registration handled correctly")
	return true

## Test unregistering missing boss
func test_missing_boss_unregistration() -> bool:
	print("\n--- Test: Missing Boss Unregistration ---")
	
	# Try to unregister non-existent boss (should not crash)
	boss_manager.unregister_boss("boss_nonexistent")
	
	# Verify still empty
	var debug_info = boss_manager.get_debug_info()
	if debug_info.registered_bosses != 0:
		print("FAIL: Expected 0 bosses, got %d" % debug_info.registered_bosses)
		return false
	
	print("PASS: Missing boss unregistration handled gracefully")
	return true