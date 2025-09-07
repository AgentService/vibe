extends Node

## Test StateManager state transitions and core loop flow with autoload access.
## Scene-based test that can access StateManager and other autoloads.

func _ready() -> void:
	print("=== StateManager Transition Tests (Scene-based) ===")
	
	# Run tests with autoload access
	await get_tree().process_frame
	_run_tests()

func _run_tests() -> void:
	var passed = 0
	var total = 0
	
	# Test 1: Initial state and basic functionality
	total += 1
	if _test_basic_functionality():
		passed += 1
		print("✓ Test 1: Basic StateManager functionality")
	else:
		print("✗ Test 1: Basic functionality test failed")
	
	# Test 2: Pause permissions
	total += 1
	if _test_pause_permissions():
		passed += 1
		print("✓ Test 2: Pause permissions work correctly")
	else:
		print("✗ Test 2: Pause permissions test failed")
	
	# Test 3: State string conversion
	total += 1
	if _test_state_strings():
		passed += 1
		print("✓ Test 3: State string conversion works")
	else:
		print("✗ Test 3: State string conversion failed")
	
	# Test 4: Signal emissions
	total += 1
	if await _test_signals():
		passed += 1
		print("✓ Test 4: State signals work correctly")
	else:
		print("✗ Test 4: Signal test failed")
	
	print("\n=== Test Results ===")
	print("Passed: %d/%d tests" % [passed, total])
	
	if passed == total:
		print("✓ All StateManager tests passed!")
	else:
		print("✗ Some StateManager tests failed")
	
	# Auto-quit after tests
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func _test_basic_functionality() -> bool:
	"""Test basic StateManager functionality."""
	
	# Should have a current state
	var current_state = StateManager.get_current_state()
	if current_state < 0:
		print("  Failed: Invalid current state")
		return false
	
	# Should have state string method
	var state_string = StateManager.get_current_state_string()
	if state_string.is_empty():
		print("  Failed: Empty state string")
		return false
	
	return true

func _test_pause_permissions() -> bool:
	"""Test pause permission logic."""
	
	# Test different states manually
	var original_state = StateManager.get_current_state()
	
	# Test ARENA state (should allow pause)
	StateManager.current_state = StateManager.State.ARENA
	if not StateManager.is_pause_allowed():
		print("  Failed: ARENA should allow pause")
		StateManager.current_state = original_state
		return false
	
	# Test MENU state (should not allow pause)
	StateManager.current_state = StateManager.State.MENU
	if StateManager.is_pause_allowed():
		print("  Failed: MENU should not allow pause")
		StateManager.current_state = original_state
		return false
	
	# Test HIDEOUT state (should allow pause)
	StateManager.current_state = StateManager.State.HIDEOUT
	if not StateManager.is_pause_allowed():
		print("  Failed: HIDEOUT should allow pause")
		StateManager.current_state = original_state
		return false
	
	# Restore original state
	StateManager.current_state = original_state
	return true

func _test_state_strings() -> bool:
	"""Test state string conversion."""
	
	var original_state = StateManager.get_current_state()
	
	# Test various states
	var test_cases = [
		{"state": StateManager.State.BOOT, "expected": "BOOT"},
		{"state": StateManager.State.MENU, "expected": "MENU"},
		{"state": StateManager.State.CHARACTER_SELECT, "expected": "CHARACTER_SELECT"},
		{"state": StateManager.State.HIDEOUT, "expected": "HIDEOUT"},
		{"state": StateManager.State.ARENA, "expected": "ARENA"},
		{"state": StateManager.State.RESULTS, "expected": "RESULTS"},
		{"state": StateManager.State.EXIT, "expected": "EXIT"}
	]
	
	for test_case in test_cases:
		StateManager.current_state = test_case.state
		var result = StateManager.get_current_state_string()
		if result != test_case.expected:
			print("  Failed: State %d should be '%s', got '%s'" % [test_case.state, test_case.expected, result])
			StateManager.current_state = original_state
			return false
	
	StateManager.current_state = original_state
	return true

func _test_signals() -> bool:
	"""Test signal emission functionality."""
	
	var signal_received = false
	var signal_data = {}
	
	# Connect to state changed signal
	var connection = StateManager.state_changed.connect(
		func(prev: StateManager.State, next: StateManager.State, context: Dictionary):
			signal_received = true
			signal_data = {"prev": prev, "next": next, "context": context}
	)
	
	# Trigger a state change
	var initial_state = StateManager.get_current_state()
	StateManager.go_to_menu({"test": "signal_test"})
	
	# Wait for signal processing
	await get_tree().process_frame
	
	# Check if signal was received
	if not signal_received:
		print("  Failed: state_changed signal not received")
		if StateManager.state_changed.is_connected(connection):
			StateManager.state_changed.disconnect(connection)
		return false
	
	# Validate signal data
	if signal_data.get("prev") != initial_state:
		print("  Failed: Wrong previous state in signal")
		if StateManager.state_changed.is_connected(connection):
			StateManager.state_changed.disconnect(connection)
		return false
	
	if signal_data.get("context", {}).get("test") != "signal_test":
		print("  Failed: Context not passed correctly")
		if StateManager.state_changed.is_connected(connection):
			StateManager.state_changed.disconnect(connection)
		return false
	
	if StateManager.state_changed.is_connected(connection):
		StateManager.state_changed.disconnect(connection)
	return true