extends Control
## MainMenu - Primary styled menu (formerly MeasureAtlas)
## Features: Leaderboard, Play flow, Unlocks shop integration
## Reference: MainMenu_reference.tscn contains old menu for comparison

# Asset paths
const PORTRAIT_PATH = "res://assets/ui/characters/portraits/"

# Leaderboard component
@onready var leaderboard: Leaderboard = $Leaderboard

# Menu buttons
@onready var play_button: Button = $MarginContainer_Starter2/MarginContainer/VBoxContainer2/Play
@onready var unlocks_button: Button = $MarginContainer_Starter2/MarginContainer/VBoxContainer2/Play2
@onready var options_button: Button = $MarginContainer_Starter2/MarginContainer/VBoxContainer2/Play3
@onready var quit_button: Button = $MarginContainer_Starter2/MarginContainer/VBoxContainer2/Play4

func _ready() -> void:
	# Connect menu buttons
	play_button.pressed.connect(_on_play_pressed)
	unlocks_button.pressed.connect(_on_unlocks_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Setup leaderboard component with data providers
	leaderboard.setup_data_providers(
		_fetch_global_leaderboard,
		_fetch_friends_leaderboard
	)

	# Listen for leaderboard updates
	EventBus.leaderboard_updated.connect(_on_leaderboard_updated)


func _fetch_global_leaderboard() -> Array[Dictionary]:
	"""Callback for Leaderboard component - provides mock global leaderboard data"""
	# In production, this would be an HTTP request:
	# var response = await http_request.request_completed
	# return _parse_api_response(response)

	var mock_players = [
		{"username": "xXDragonSlayerXx", "kills": 2547893, "character_id": "knight"},
		{"username": "MageSupreme", "kills": 1923456, "character_id": "mage"},
		{"username": "RangerPro_TTV", "kills": 1654321, "character_id": "ranger"},
		{"username": "KnightOfDoom", "kills": 1432109, "character_id": "knight"},
		{"username": "SpeedRunner2025", "kills": 1298765, "character_id": "ranger"},
		{"username": "TheMageKing", "kills": 1087654, "character_id": "mage"},
		{"username": "CasualGamer42", "kills": 987654, "character_id": "knight"},
		{"username": "eSportsLegend", "kills": 876543, "character_id": "ranger"},
		{"username": "NoobMaster69", "kills": 765432, "character_id": "mage"},
		{"username": "ProPlayer_2025", "kills": 654321, "character_id": "knight"}
	]

	# Convert to Leaderboard component format
	var ui_data: Array[Dictionary] = []
	for i in range(mock_players.size()):
		var player = mock_players[i]
		ui_data.append({
			"rank": i + 1,
			"name": player.username,
			"score": _format_number(player.kills),  # Pre-formatted string
			"character_icon": _get_character_icon(player.character_id)
		})

	return ui_data

func _fetch_friends_leaderboard() -> Array[Dictionary]:
	"""Callback for Leaderboard component - provides local player run data"""
	var all_runs: Array[Dictionary] = []

	# Gather all runs from all maps and tiers
	var maps = LocalLeaderboard.get_maps_with_entries()
	for map_id in maps:
		var tiers = LocalLeaderboard.get_tiers_with_entries(map_id)
		for tier in tiers:
			var leaderboard = LocalLeaderboard.get_leaderboard(map_id, tier)
			all_runs.append_array(leaderboard)

	# Sort all runs by kills (descending)
	all_runs.sort_custom(func(a, b): return a.kills > b.kills)

	# Take top 10
	var top_runs = all_runs.slice(0, min(10, all_runs.size()))

	# Convert to Leaderboard component format
	var ui_data: Array[Dictionary] = []
	for i in range(top_runs.size()):
		var entry = top_runs[i]
		ui_data.append({
			"rank": i + 1,
			"name": entry.character_id,  # Character ID as name
			"score": _format_number(entry.kills),  # Pre-formatted string
			"character_icon": _get_character_icon(entry.character_id)
		})

	return ui_data

func _on_leaderboard_updated(_map_id: String, _tier: int, _rank: int) -> void:
	"""Refresh leaderboard when new entry is added"""
	leaderboard.refresh_current_tab()

func _get_character_icon(character_id: String) -> Texture2D:
	"""Load character portrait icon using filename convention"""
	var filename = "%s_portrait" % character_id
	var extensions = [".png", ".svg"]

	for ext in extensions:
		var full_path = PORTRAIT_PATH + filename + ext
		if ResourceLoader.exists(full_path):
			return load(full_path) as Texture2D

	Logger.warn("Character icon not found: %s (tried %s)" % [character_id, PORTRAIT_PATH], "ui")
	return null

func _format_number(value: int) -> String:
	"""Format large numbers with K/M/B suffixes"""
	if value >= 1_000_000_000:
		return "%.1fB" % (value / 1_000_000_000.0)
	elif value >= 1_000_000:
		return "%.1fM" % (value / 1_000_000.0)
	elif value >= 1_000:
		return "%.1fK" % (value / 1_000.0)
	else:
		return str(value)

# ============================================================================
# MENU BUTTON HANDLERS
# ============================================================================

func _on_play_pressed() -> void:
	"""Start game flow - loads CharacterSelect via SceneTransitionManager"""
	Logger.info("Play pressed - loading character select", "ui")
	EventBus.request_enter_map.emit({
		"map_id": "character_select",
		"source": "main_menu"
	})

func _on_unlocks_pressed() -> void:
	"""Open unlocks shop - loads existing shop (temp until new one built)"""
	# TODO: Replace with new styled Shop_New.tscn when ready
	# For now, could open old MainMenu's shop screen or placeholder
	Logger.info("Unlocks pressed - shop not yet implemented in new UI", "ui")

func _on_options_pressed() -> void:
	"""Open options/settings"""
	# TODO: Implement options menu
	Logger.info("Options pressed - not yet implemented", "ui")

func _on_quit_pressed() -> void:
	"""Quit game"""
	Logger.info("Quit pressed", "ui")
	get_tree().quit()
