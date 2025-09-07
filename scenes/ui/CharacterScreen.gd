extends Control
class_name CharacterScreen

## Character screen UI stub for progression system integration.
## Subscribes to progression changes but has no UI rendering yet.

var last_progression_state: Dictionary = {}

func _ready() -> void:
	# Connect to progression signals
	EventBus.progression_changed.connect(_on_progression_changed)
	
	Logger.debug("CharacterScreen initialized and listening for progression changes", "ui")

func _exit_tree() -> void:
	# Clean up signal connections
	if EventBus.progression_changed.is_connected(_on_progression_changed):
		EventBus.progression_changed.disconnect(_on_progression_changed)

func _on_progression_changed(state: Dictionary) -> void:
	# Store state for future UI rendering
	last_progression_state = state.duplicate()
	
	Logger.debug("CharacterScreen received progression update: Level %d, XP %.1f/%.1f" % [
		state.get("level", 1),
		state.get("exp", 0.0),
		state.get("xp_to_next", 100.0)
	], "ui")
	
	# TODO: Update UI elements when character screen is implemented
	# - Level display
	# - XP bar
	# - Unlock indicators