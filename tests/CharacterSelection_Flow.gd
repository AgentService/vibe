extends Node

## Character Selection Flow Test
## Tests the complete MENU -> CHARACTER_SELECT -> HIDEOUT flow via StateManager
## Validates character creation, selection, and state transitions

var test_results: Dictionary = {
	"state_transitions": [],
	"character_operations": [],
	"errors": []
}

var state_transition_count: int = 0
var test_character_id: StringName
var expected_transitions: Array[String] = ["BOOT->MENU", "MENU->CHARACTER_SELECT", "CHARACTER_SELECT->HIDEOUT"]
var current_test_phase: String = "setup"

func _ready():
	print("=== CharacterSelection_Flow Test Started ===")
	print("Testing: MENU -> CHARACTER_SELECT -> create/select -> HIDEOUT sequence")
	print("Phase: Setup and initialization")
	
	current_test_phase = "setup"
	_run_test()

func _run_test():
	"""Run the complete character selection flow test."""
	
	# Connect to StateManager for monitoring transitions
	StateManager.state_changed.connect(_on_state_changed)
	
	# Clear any existing characters for clean test
	_cleanup_test_characters()
	
	# Start test sequence
	print("\n--- Starting Character Selection Flow Test ---")
	current_test_phase = "test_menu_to_character_select"
	
	# Phase 1: Test MENU -> CHARACTER_SELECT transition
	print("Phase 1: Testing MENU -> CHARACTER_SELECT transition")
	StateManager.go_to_menu({"source": "flow_test"})
	
	# Wait a moment for state change to process
	await get_tree().create_timer(0.1).timeout
	
	# Should now be in MENU state
	if StateManager.get_current_state() != StateManager.State.MENU:
		_log_error("Expected MENU state, got: %s" % StateManager.get_current_state_string())
		_finish_test()
		return
	
	print("✓ Successfully transitioned to MENU")
	
	# Transition to character select
	StateManager.go_to_character_select({"source": "flow_test"})
	await get_tree().create_timer(0.1).timeout
	
	# Should now be in CHARACTER_SELECT state
	if StateManager.get_current_state() != StateManager.State.CHARACTER_SELECT:
		_log_error("Expected CHARACTER_SELECT state, got: %s" % StateManager.get_current_state_string())
		_finish_test()
		return
	
	print("✓ Successfully transitioned to CHARACTER_SELECT")
	
	# Phase 2: Test character creation
	current_test_phase = "test_character_creation"
	print("Phase 2: Testing character creation")
	
	var initial_character_count = CharacterManager.list_characters().size()
	print("Initial character count: %d" % initial_character_count)
	
	# Create a test character
	var test_profile = CharacterManager.create_character("FlowTest Knight", StringName("Knight"))
	if not test_profile:
		_log_error("Failed to create test character")
		_finish_test()
		return
	
	test_character_id = test_profile.id
	_log_character_operation("Created character: %s (ID: %s)" % [test_profile.name, test_character_id])
	print("✓ Successfully created test character: %s" % test_profile.name)
	
	# Verify character was created
	var characters_after_creation = CharacterManager.list_characters()
	if characters_after_creation.size() != initial_character_count + 1:
		_log_error("Character count mismatch. Expected: %d, Got: %d" % [initial_character_count + 1, characters_after_creation.size()])
	
	# Phase 3: Test character loading and transition to hideout
	current_test_phase = "test_character_select_to_hideout"
	print("Phase 3: Testing character selection and HIDEOUT transition")
	
	# Load the character (simulating selection)
	CharacterManager.load_character(test_character_id)
	var loaded_profile = CharacterManager.get_current()
	
	if not loaded_profile or loaded_profile.id != test_character_id:
		_log_error("Failed to load character or wrong character loaded")
		_finish_test()
		return
	
	_log_character_operation("Loaded character: %s" % loaded_profile.name)
	print("✓ Successfully loaded character for selection")
	
	# Load progression
	PlayerProgression.load_from_profile(loaded_profile.progression)
	_log_character_operation("Loaded character progression")
	
	# Transition to hideout
	var context = {
		"character_id": loaded_profile.id,
		"character_data": loaded_profile.get_character_data(),
		"spawn_point": "PlayerSpawnPoint",
		"source": "flow_test_selection"
	}
	
	StateManager.go_to_hideout(context)
	await get_tree().create_timer(0.1).timeout
	
	# Should now be in HIDEOUT state
	if StateManager.get_current_state() != StateManager.State.HIDEOUT:
		_log_error("Expected HIDEOUT state, got: %s" % StateManager.get_current_state_string())
		_finish_test()
		return
	
	print("✓ Successfully transitioned to HIDEOUT")
	
	# Phase 4: Complete test
	current_test_phase = "cleanup"
	print("Phase 4: Test completion and cleanup")
	_finish_test()

func _on_state_changed(prev: StateManager.State, next: StateManager.State, context: Dictionary):
	"""Track state transitions for validation."""
	var transition_string = "%s->%s" % [_state_to_string(prev), _state_to_string(next)]
	test_results.state_transitions.append({
		"transition": transition_string,
		"context": context,
		"phase": current_test_phase
	})
	
	state_transition_count += 1
	print("State transition [%d]: %s (context: %s)" % [state_transition_count, transition_string, context])

func _log_character_operation(message: String):
	"""Log character-related operations."""
	test_results.character_operations.append({
		"message": message,
		"phase": current_test_phase,
		"timestamp": Time.get_unix_time_from_system()
	})

func _log_error(error_message: String):
	"""Log an error during testing."""
	test_results.errors.append({
		"error": error_message,
		"phase": current_test_phase,
		"timestamp": Time.get_unix_time_from_system()
	})
	print("ERROR: %s" % error_message)

func _cleanup_test_characters():
	"""Clean up any test characters from previous runs."""
	var characters = CharacterManager.list_characters()
	for character in characters:
		if character.name.begins_with("FlowTest"):
			CharacterManager.delete_character(character.id)
			print("Cleaned up test character: %s" % character.name)

func _finish_test():
	"""Complete the test and display results."""
	print("\n=== CHARACTER SELECTION FLOW TEST RESULTS ===")
	
	# Display state transitions
	print("\nState Transitions (%d):" % test_results.state_transitions.size())
	for i in range(test_results.state_transitions.size()):
		var transition = test_results.state_transitions[i]
		print("  %d. %s [%s]" % [i + 1, transition.transition, transition.phase])
	
	# Display character operations
	print("\nCharacter Operations (%d):" % test_results.character_operations.size())
	for i in range(test_results.character_operations.size()):
		var op = test_results.character_operations[i]
		print("  %d. %s [%s]" % [i + 1, op.message, op.phase])
	
	# Display errors
	if test_results.errors.size() > 0:
		print("\nERRORS (%d):" % test_results.errors.size())
		for i in range(test_results.errors.size()):
			var error = test_results.errors[i]
			print("  %d. %s [%s]" % [i + 1, error.error, error.phase])
	else:
		print("\n✓ NO ERRORS DETECTED")
	
	# Determine overall success
	var success = test_results.errors.is_empty() and test_results.state_transitions.size() >= 3
	
	print("\n" + "=".repeat(50))
	if success:
		print("✓ CHARACTER SELECTION FLOW TEST: PASSED")
	else:
		print("✗ CHARACTER SELECTION FLOW TEST: FAILED")
	print("=".repeat(50))
	
	# Clean up test character
	if test_character_id:
		CharacterManager.delete_character(test_character_id)
		print("Test character cleaned up")
	
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