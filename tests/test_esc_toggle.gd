extends Node

## Simple test to verify ESC key properly toggles pause menu

func _ready():
	print("=== ESC Toggle Test ===")
	print("This test validates that ESC key properly toggles pause on/off")
	
	# Set state to ARENA so pause is allowed
	StateManager.current_state = StateManager.State.ARENA
	
	# Connect to pause events to monitor them
	EventBus.game_paused_changed.connect(_on_pause_changed)
	
	print("State: %s (pause allowed: %s)" % [StateManager.get_current_state_string(), StateManager.is_pause_allowed()])
	print("Press ESC to toggle pause. Press Q to quit.")
	print("Expected behavior:")
	print("  1. First ESC press → Game pauses, overlay shows")
	print("  2. Second ESC press → Game unpauses, overlay hides")
	print("  3. Repeat as needed")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			print("Exiting test...")
			get_tree().quit()

func _on_pause_changed(payload):
	var is_paused = payload.is_paused if payload else false
	print("Pause state changed: %s" % ("PAUSED" if is_paused else "UNPAUSED"))
	
	if is_paused:
		print("  → Pause overlay should now be VISIBLE")
	else:
		print("  → Pause overlay should now be HIDDEN")