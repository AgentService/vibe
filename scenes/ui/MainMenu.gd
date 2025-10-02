extends Control
## MainMenu - Primary styled menu (formerly MeasureAtlas)
## Features: Leaderboard, Play flow, Unlocks shop integration
## Reference: MainMenu_reference.tscn contains old menu for comparison

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
	"""Placeholder for future global/online leaderboard"""
	# TODO: Implement online leaderboard when networking is added
	pass

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
			"icon_path": _get_character_icon(entry.character_id)
		})

	_populate_leaderboard(friends_container, ui_data)

func _on_leaderboard_updated(_map_id: String, _tier: int, _rank: int) -> void:
	"""Refresh leaderboard when new entry is added"""
	_load_local_leaderboard()  # Refresh entire top 10

func _get_character_icon(character_id: String) -> String:
	"""Get icon path for character - customize based on your character system"""
	# TODO: Connect to your character icon mapping
	# For now, use placeholder icons
	match character_id:
		"warrior":
			return "res://assets/ui/tile048.png"
		"mage":
			return "res://assets/ui/tile038.png"
		_:
			return "res://assets/ui/tile048.png"  # Default icon

func _populate_leaderboard(container: VBoxContainer, data: Array) -> void:
	"""Populate leaderboard with local data - updates existing entries"""

	# Get existing entry nodes
	var entries = container.get_children()

	# Update existing entries or hide if no data
	for i in range(max(entries.size(), data.size())):
		if i < entries.size() and i < data.size():
			# Update existing entry with new data
			var entry = entries[i]
			var entry_data = data[i]

			entry.visible = true
			entry.get_node("NinePatchRect/MarginContainer/HboxEntry/playerRank").text = "#%d" % entry_data.rank
			entry.get_node("NinePatchRect/MarginContainer/HboxEntry/playerName").text = entry_data.name
			entry.get_node("NinePatchRect/MarginContainer/HboxEntry/Kills/playerKillcount").text = _format_number(entry_data.kills)

			# Load icon if path provided
			if entry_data.has("icon_path"):
				var icon_node = entry.get_node("NinePatchRect/MarginContainer/HboxEntry/Kills/playerChar")
				icon_node.texture = load(entry_data.icon_path)

		elif i < entries.size():
			# Hide unused entries
			entries[i].visible = false

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
