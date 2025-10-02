extends Control
## MainMenu - Primary styled menu (formerly MeasureAtlas)
## Features: Leaderboard, Play flow, Unlocks shop integration
## Reference: MainMenu_reference.tscn contains old menu for comparison

# Leaderboard component
const LeaderboardEntryScene = preload("res://scenes/ui/components/LeaderboardEntry.tscn")

# Asset paths
const PORTRAIT_PATH = "res://assets/ui/characters/portraits/"

# Leaderboard UI
@onready var tab_bar: TabBar = %TabBar
@onready var global_container: VBoxContainer = %VBoxContainer_Global
@onready var friends_container: VBoxContainer = %VBoxContainer_Friends

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

	# Connect tab switching signal
	tab_bar.tab_changed.connect(_on_tab_changed)

	# Listen for leaderboard updates
	EventBus.leaderboard_updated.connect(_on_leaderboard_updated)

	# Initialize with first tab (Global)
	_on_tab_changed(0)

func _on_tab_changed(tab_index: int) -> void:
	"""Switch between Global (future) and Friends (LocalLeaderboard) views"""
	match tab_index:
		0: # Global tab (placeholder for future online leaderboard)
			global_container.visible = true
			friends_container.visible = false
			_load_global_leaderboard()
		1: # Friends tab (LocalLeaderboard - top kills across all maps/tiers)
			global_container.visible = false
			friends_container.visible = true
			_load_local_leaderboard()

func _load_global_leaderboard() -> void:
	"""Mock global leaderboard (simulates API fetch like MEGABONK)"""
	# In production, this would be an HTTP request:
	# HTTPRequest.request("https://api.game.com/leaderboard/global")
	# For now, simulate with mock data

	var mock_global_data = _fetch_mock_global_leaderboard()
	_populate_leaderboard(global_container, mock_global_data)

func _fetch_mock_global_leaderboard() -> Array[Dictionary]:
	"""Simulates API response for global leaderboard (MEGABONK-style)"""
	# In production, this would be async HTTP request handling
	# Example: await http_request.request_completed

	var mock_players = [
		{"username": "xXDragonSlayerXx", "kills": 2547893, "character_id": "knight", "country": "US"},
		{"username": "MageSupreme", "kills": 1923456, "character_id": "mage", "country": "JP"},
		{"username": "RangerPro_TTV", "kills": 1654321, "character_id": "ranger", "country": "DE"},
		{"username": "KnightOfDoom", "kills": 1432109, "character_id": "knight", "country": "UK"},
		{"username": "SpeedRunner2025", "kills": 1298765, "character_id": "ranger", "country": "CA"},
		{"username": "TheMageKing", "kills": 1087654, "character_id": "mage", "country": "FR"},
		{"username": "CasualGamer42", "kills": 987654, "character_id": "knight", "country": "AU"},
		{"username": "eSportsLegend", "kills": 876543, "character_id": "ranger", "country": "KR"},
		{"username": "NoobMaster69", "kills": 765432, "character_id": "mage", "country": "BR"},
		{"username": "ProPlayer_2025", "kills": 654321, "character_id": "knight", "country": "SE"}
	]

	# Convert to UI format
	var ui_data: Array[Dictionary] = []
	for i in range(mock_players.size()):
		var player = mock_players[i]
		ui_data.append({
			"rank": i + 1,
			"name": player.username,
			"kills": player.kills,
			"character_icon": _get_character_icon(player.character_id)
		})

	Logger.info("Mock global leaderboard loaded with %d entries" % ui_data.size(), "ui")
	return ui_data

func _load_local_leaderboard() -> void:
	"""Load top 10 runs by kills across ALL maps and tiers"""
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

	# Convert to UI format
	var ui_data: Array[Dictionary] = []
	for i in range(top_runs.size()):
		var entry = top_runs[i]
		ui_data.append({
			"rank": i + 1,
			"name": entry.character_id,  # Character ID as name
			"kills": entry.kills,
			"character_icon": _get_character_icon(entry.character_id)
		})

	_populate_leaderboard(friends_container, ui_data)

func _on_leaderboard_updated(_map_id: String, _tier: int, _rank: int) -> void:
	"""Refresh leaderboard when new entry is added"""
	_load_local_leaderboard()  # Refresh entire top 10

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

func _populate_leaderboard(container: VBoxContainer, data: Array) -> void:
	"""Populate leaderboard with LeaderboardEntry components"""

	# Clear existing entries
	for child in container.get_children():
		child.queue_free()

	# Create new entries using component template
	for entry_data in data:
		var entry: LeaderboardEntry = LeaderboardEntryScene.instantiate()

		# Get character icon (already loaded as Texture2D)
		var char_icon: Texture2D = entry_data.get("character_icon", null)

		# Setup entry with formatted data
		var score_text = "%s kills" % _format_number(entry_data.kills)
		entry.setup(
			entry_data.rank,
			entry_data.name,
			score_text,
			char_icon
		)

		container.add_child(entry)

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
