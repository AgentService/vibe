extends Node

## Automated test for ESC toggle functionality

var test_phase: String = "init"
var toggle_count: int = 0

func _ready():
	print("=== Automated ESC Toggle Test ===")
	
	# Set state to ARENA so pause is allowed
	StateManager.current_state = StateManager.State.ARENA
	
	# Connect to pause events to monitor them
	EventBus.game_paused_changed.connect(_on_pause_changed)
	
	print("State: %s (pause allowed: %s)" % [StateManager.get_current_state_string(), StateManager.is_pause_allowed()])
	
	# Start automated test sequence
	_start_automated_test()

func _start_automated_test():
	print("Starting automated ESC toggle test sequence...")
	test_phase = "testing"
	
	# Test 1: First ESC press (should pause)
	await get_tree().create_timer(0.5).timeout
	print("Test 1: Simulating ESC press to pause")
	_simulate_esc_press()
	
	# Wait and then test unpause
	await get_tree().create_timer(1.0).timeout
	print("Test 2: Simulating ESC press to unpause")
	_simulate_esc_press()
	
	# Wait and test one more cycle
	await get_tree().create_timer(1.0).timeout
	print("Test 3: Simulating ESC press to pause again")
	_simulate_esc_press()
	
	await get_tree().create_timer(1.0).timeout
	print("Test 4: Simulating ESC press to unpause again")
	_simulate_esc_press()
	
	await get_tree().create_timer(0.5).timeout
	print("\n=== Test Complete ===")
	print("Expected: 4 pause state changes (pause → unpause → pause → unpause)")
	print("Actual: %d pause state changes" % toggle_count)
	
	if toggle_count == 4:
		print("✓ ESC TOGGLE TEST: PASSED")
	else:
		print("✗ ESC TOGGLE TEST: FAILED")

func _simulate_esc_press():
	"""Simulate an ESC key press."""
	var event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	
	# Send to the tree's input handling
	Input.parse_input_event(event)

func _on_pause_changed(payload):
	var is_paused = payload.is_paused if payload else false
	toggle_count += 1
	
	print("  → Pause state #%d: %s" % [toggle_count, "PAUSED" if is_paused else "UNPAUSED"])
	
	if is_paused:
		print("    Overlay should be VISIBLE")
	else:
		print("    Overlay should be HIDDEN")