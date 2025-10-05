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

@onready var back_button: Button = %BackButton
@onready var start_run_button: Button = %StartButton
@onready var map_details_panel: MarginContainer = %MapDetailsPanel

# Map button components (MapSelectButton)
@onready var forest_button: MapSelectButton = $MapSelectionPanel/MarginContainer/VBoxContainer3/VBoxContainer/MapListScroll/MapList/MapSelectButton
@onready var underworld_button: MapSelectButton = $MapSelectionPanel/MarginContainer/VBoxContainer3/VBoxContainer/MapListScroll/MapList/MapSelectButton2

# Selection state (character passed from CharacterSelect)
var selected_character: String = "knight"  # Default fallback
var selected_map: String = "forest_arena"  # TODO(UI-phase2): Add map selection UI with thumbnails
var selected_tier: int = 1  # TODO(UI-phase2): Add tier selection buttons (T1-T5)

func _ready() -> void:
	# Connect navigation buttons
	back_button.pressed.connect(_on_back_pressed)
	start_run_button.pressed.connect(_on_start_run_pressed)

	# Connect map selection button signals
	forest_button.pressed.connect(_on_map_selected)
	underworld_button.pressed.connect(_on_map_selected)

	# Initialize panel with default map (Forest)
	_update_map_details(selected_map)

	# Set Forest as visually selected by default
	forest_button.set_selected(true)

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

func _on_map_selected(map_id: String) -> void:
	"""Map button selected - update details panel with LocalLeaderboard data"""
	selected_map = map_id
	Logger.info("Map selected: %s" % selected_map, "ui")

	# Update visual selection state
	_update_selection_state(map_id)

	# Update details panel with selected map data
	_update_map_details(selected_map)
	map_details_panel.visible = true

func _update_selection_state(map_id: String) -> void:
	"""Update which button shows the focus/selected state"""
	# Deselect all buttons first
	forest_button.set_selected(false)
	underworld_button.set_selected(false)

	# Select the chosen button
	if map_id == "forest_arena":
		forest_button.set_selected(true)
	elif map_id == "underworld_arena":
		underworld_button.set_selected(true)

func _update_map_details(map_id: String) -> void:
	"""Update the details panel with map-specific data"""
	var map_title = %MapTitle
	var map_runs = %MapRuns
	var best_depth = %BestDepth
	var best_score = %BestScore

	# Get map stats from LocalLeaderboard
	if LocalLeaderboard:
		var total_runs = LocalLeaderboard.get_total_runs_for_map(map_id)
		var best_run = LocalLeaderboard.get_best_run_for_map(map_id)

		# Update runs count
		map_runs.text = str(total_runs) + " Runs"

		# Update best stats if available
		if best_run and not best_run.is_empty():
			best_depth.get_node("Value").text = str(best_run.get("stage_reached", "-"))
			best_score.get_node("Value").text = str(best_run.get("rift_fragments_earned", "-"))
		else:
			best_depth.get_node("Value").text = "-"
			best_score.get_node("Value").text = "-"
	else:
		map_runs.text = "0 Runs"
		best_depth.get_node("Value").text = "-"
		best_score.get_node("Value").text = "-"

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
