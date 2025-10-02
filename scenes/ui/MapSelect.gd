extends Control
## MapSelect - Map and tier selection screen
## Receives character selection from CharacterSelect and handles map/tier selection

@onready var back_button: Button = $BackButton
@onready var start_run_button: Button = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MarginContainer6/VBoxContainer/HBoxContainer/startRun

# Selection state (character passed from CharacterSelect)
var selected_character: String = "knight"  # Default fallback
var selected_map: String = "forest_arena"  # Forest map (TODO: make selectable)
var selected_tier: int = 1  # Tier 1 (TODO: make selectable)

func _ready() -> void:
	# Connect navigation buttons
	back_button.pressed.connect(_on_back_pressed)
	start_run_button.pressed.connect(_on_start_run_pressed)

	# Try to receive character from scene transition context
	# Note: This requires SceneTransitionManager to pass context data
	# For now, falls back to default "knight" if not provided
	_check_for_character_context()

	Logger.info("MapSelect loaded (character: %s)" % selected_character, "ui")

func _check_for_character_context() -> void:
	"""Check if character was passed from CharacterSelect via scene context."""
	# TODO: Implement context passing in SceneTransitionManager
	# For now, this is a placeholder for future enhancement
	# The character will be stored in a temporary autoload or passed via signal
	pass

func _on_back_pressed() -> void:
	"""Return to CharacterSelect via SceneTransitionManager"""
	Logger.info("Back pressed - returning to CharacterSelect", "ui")
	EventBus.request_enter_map.emit({
		"map_id": "character_select",
		"source": "map_select"
	})

func _on_start_run_pressed() -> void:
	"""Start the run with selected character, map, and tier (matching MainMenu flow)"""
	Logger.info("Starting run: %s on %s (Tier %d)" % [selected_character, selected_map, selected_tier], "ui")

	# Start run through SessionState
	if SessionState:
		SessionState.start_run(selected_character, selected_map, selected_tier)

	# Prepare context (same as MainMenu and hideout MapDevice)
	var context = {
		"character": selected_character,
		"spawn_point": "PlayerSpawnPoint",
		"source": "map_select_new",
		"tier": selected_tier,
		"character_data": {}  # Empty for now, player spawns fresh
	}

	# Transition to arena
	if StateManager:
		StateManager.start_run(&"pathgen_arena", context)
