extends Control
## Map and Tier selection screen
##
## Flow: CharacterSelect → **MapSelect** → Arena
##
## Features:
## - Receives character selection via apply_transition_data()
## - Map selection UI (TODO: UI-phase2 - currently hardcoded to forest_arena)
## - Tier selection UI (TODO: UI-phase2 - currently defaults to T1)
## - Starts run via SessionState before arena transition
##
## Architecture:
## - Uses EventBus.request_enter_map for navigation
## - Integrates with SessionState.start_run() for run lifecycle
## - Uses StateManager.start_run() for arena transition with full context
##
## TODO: Phase 2 - Add map thumbnails and tier buttons (1-5)

@onready var back_button: Button = $BackButton
@onready var start_run_button: Button = $MarginContainer_CharacterSelect2/NinePatchRect/MarginContainer7/VBoxContainer3/MarginContainer6/VBoxContainer/HBoxContainer/startRun

# Selection state (character passed from CharacterSelect)
var selected_character: String = "knight"  # Default fallback
var selected_map: String = "forest_arena"  # TODO(UI-phase2): Add map selection UI with thumbnails
var selected_tier: int = 1  # TODO(UI-phase2): Add tier selection buttons (T1-T5)

func _ready() -> void:
	# Connect navigation buttons
	back_button.pressed.connect(_on_back_pressed)
	start_run_button.pressed.connect(_on_start_run_pressed)

	Logger.info("MapSelect loaded (character: %s)" % selected_character, "ui")

func apply_transition_data(data: Dictionary) -> void:
	"""Receive transition data from SceneTransitionManager."""
	if data.has("character"):
		selected_character = data.character
		Logger.info("MapSelect: Character selection received: %s" % selected_character, "ui")

	# TODO(UI-phase2): Handle tier/map preferences from LocalLeaderboard last-played data
	# For now, defaults to forest_arena T1

func _on_back_pressed() -> void:
	"""Return to CharacterSelect via SceneTransitionManager"""
	Logger.info("Back pressed - returning to CharacterSelect", "ui")

	if EventBus:
		EventBus.request_enter_map.emit({
			"map_id": "character_select",
			"source": "map_select",
			"character": selected_character  # Pass character back for restoration
		})
	else:
		Logger.error("EventBus not available - cannot return to character select", "ui")

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
