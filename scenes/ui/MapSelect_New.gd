extends Control
## NEW Map Selection - Styled replacement for map/tier selection flow
## Work in progress - building styled UI with real map data

@onready var back_button: Button = $BackButton
@onready var start_run_button: Button = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MarginContainer6/VBoxContainer/HBoxContainer/startRun

# Placeholder selections (TODO: wire to actual UI selections)
var selected_character: String = "knight"  # Default character
var selected_map: String = "forest_arena"  # Forest map
var selected_tier: int = 1  # Tier 1

func _ready() -> void:
	# Connect navigation buttons
	back_button.pressed.connect(_on_back_pressed)
	start_run_button.pressed.connect(_on_start_run_pressed)

	Logger.info("MapSelect_New loaded", "ui")

func _on_back_pressed() -> void:
	"""Return to CharacterSelect_New via SceneTransitionManager"""
	Logger.info("Back pressed - returning to CharacterSelect_New", "ui")
	EventBus.request_enter_map.emit({
		"map_id": "character_select_new",
		"source": "map_select_new"
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
