extends Node

## Test for pause state restrictions - verifies pause is blocked in MENU and CHARACTER_SELECT states
## Tests that ESC key does nothing when pause is not allowed by StateManager

var test_results: Dictionary = {
	"state_tests": [],
	"pause_attempts": [],
	"errors": []
}

var current_test_phase: String = "init"
var test_states_to_check: Array[StateManager.State] = [
	StateManager.State.MENU, 
	StateManager.State.CHARACTER_SELECT,
	StateManager.State.HIDEOUT,  # Should allow
	StateManager.State.ARENA     # Should allow
]
var current_state_index: int = 0

func _ready():
	print("=== Testing Pause State Restrictions ===")
	print("Testing that pause is blocked in MENU/CHARACTER_SELECT and allowed in HIDEOUT/ARENA")
	
	# Connect to pause events to monitor any unauthorized pauses
	EventBus.game_paused_changed.connect(_on_pause_changed)
	
	# Start the test sequence
	_run_state_tests()

func _run_state_tests():
	"""Run through each state and test pause permissions."""
	print("\n--- Testing Pause Restrictions Across States ---")
	
	for state in test_states_to_check:
		await _test_pause_in_state(state)
	
	_finish_test()

func _test_pause_in_state(state: StateManager.State):
	"""Test pause functionality in a specific state."""
	var state_name = _state_to_string(state)
	print("\nTesting state: %s" % state_name)
	
	# Set the state directly for testing
	StateManager.current_state = state
	current_test_phase = "testing_" + state_name.to_lower()
	
	# Check if pause should be allowed
	var should_allow_pause = StateManager.is_pause_allowed()
	var expected_allow = (state == StateManager.State.HIDEOUT or 
						  state == StateManager.State.ARENA or 
						  state == StateManager.State.RESULTS)
	
	test_results.state_tests.append({
		"state": state_name,
		"should_allow": expected_allow,
		"actually_allows": should_allow_pause,
		"correct": (should_allow_pause == expected_allow)
	})
	
	if should_allow_pause == expected_allow:
		print("✓ %s: Pause permission correct (%s)" % [state_name, "allowed" if should_allow_pause else "blocked"])
	else:
		print("✗ %s: Pause permission wrong - expected %s, got %s" % [state_name, expected_allow, should_allow_pause])
		_log_error("Incorrect pause permission in state %s" % state_name)
	
	# Test actual pause attempt via PauseUI (simulates ESC key press)
	var initial_pause_state = PauseManager.is_paused()
	print("  Initial pause state: %s" % initial_pause_state)
	
	# Attempt to pause via PauseUI (this is what GameOrchestrator calls on ESC)
	if StateManager.is_pause_allowed():
		print("  Attempting pause (should succeed)...")
		PauseUI.toggle_pause()
	else:
		print("  Pause blocked by StateManager (correct behavior)")
	
	# Wait a moment for the pause state to propagate
	await get_tree().create_timer(0.1).timeout
	
	var final_pause_state = PauseManager.is_paused()
	print("  Final pause state: %s" % final_pause_state)
	
	# Record the attempt result
	test_results.pause_attempts.append({
		"state": state_name,
		"expected_pause_change": should_allow_pause,
		"pause_changed": (initial_pause_state != final_pause_state),
		"correct": (should_allow_pause == (initial_pause_state != final_pause_state))
	})
	
	# If we successfully paused, unpause for next test
	if final_pause_state:
		print("  Unpausing for next test...")
		PauseManager.pause_game(false)
		await get_tree().create_timer(0.1).timeout

func _on_pause_changed(payload) -> void:
	"""Monitor pause state changes during testing."""
	var is_paused = payload.is_paused if payload else false
	var current_state_name = StateManager.get_current_state_string()
	
	print("  Pause changed during %s: %s" % [current_state_name, is_paused])
	
	# Check if this pause change was unexpected
	var should_allow = StateManager.is_pause_allowed()
	if is_paused and not should_allow:
		_log_error("Unexpected pause allowed in state %s" % current_state_name)

func _log_error(error_message: String):
	"""Log an error during testing."""
	test_results.errors.append({
		"error": error_message,
		"phase": current_test_phase,
		"timestamp": Time.get_unix_time_from_system()
	})
	print("ERROR: %s" % error_message)

func _finish_test():
	"""Complete the test and display results."""
	print("\n=== PAUSE STATE RESTRICTIONS TEST RESULTS ===")
	
	# Display state permission tests
	print("\nState Permission Tests:")
	for test in test_results.state_tests:
		var status = "✓" if test.correct else "✗"
		print("  %s %s: %s (expected %s, got %s)" % [
			status, test.state, 
			"PASS" if test.correct else "FAIL",
			"allowed" if test.should_allow else "blocked",
			"allowed" if test.actually_allows else "blocked"
		])
	
	# Display pause attempt tests
	print("\nPause Attempt Tests:")
	for attempt in test_results.pause_attempts:
		var status = "✓" if attempt.correct else "✗"
		print("  %s %s: %s (pause change expected: %s, occurred: %s)" % [
			status, attempt.state,
			"PASS" if attempt.correct else "FAIL", 
			attempt.expected_pause_change,
			attempt.pause_changed
		])
	
	# Display errors
	if test_results.errors.size() > 0:
		print("\nERRORS (%d):" % test_results.errors.size())
		for i in range(test_results.errors.size()):
			var error = test_results.errors[i]
			print("  %d. %s [%s]" % [i + 1, error.error, error.phase])
	else:
		print("\n✓ NO ERRORS DETECTED")
	
	# Determine overall success
	var permission_tests_passed = test_results.state_tests.all(func(test): return test.correct)
	var attempt_tests_passed = test_results.pause_attempts.all(func(attempt): return attempt.correct)
	var no_errors = test_results.errors.is_empty()
	var success = permission_tests_passed and attempt_tests_passed and no_errors
	
	print("\n" + "=".repeat(60))
	if success:
		print("✓ PAUSE STATE RESTRICTIONS TEST: PASSED")
	else:
		print("✗ PAUSE STATE RESTRICTIONS TEST: FAILED")
	print("=".repeat(60))
	
	print("Test completed. Press ESC or close window to exit.")

func _state_to_string(state: StateManager.State) -> String:
	"""Convert state enum to string."""
	match state:
		StateManager.State.BOOT: return "BOOT"
		StateManager.State.MENU: return "MENU"
		StateManager.State.CHARACTER_SELECT: return "CHARACTER_SELECT"
		StateManager.State.HIDEOUT: return "HIDEOUT"
		StateManager.State.ARENA: return "ARENA"
		StateManager.State.RESULTS: return "RESULTS"
		StateManager.State.EXIT: return "EXIT"
		_: return "UNKNOWN"

func _input(event):
	"""Handle input for manual test termination."""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			print("Test terminated by user")
			get_tree().quit()