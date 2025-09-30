extends Control

## MainMenu - Simple Character/Map/Tier Selection
## Three screens: Main Menu → Character Select → Map/Tier Select → Arena

# Screen containers
@onready var main_menu_container: Control = $BackgroundPanel/MainMenuContainer
@onready var character_select_container: Control = $BackgroundPanel/CharacterSelectContainer
@onready var map_select_container: Control = $BackgroundPanel/MapSelectContainer

# Main Menu elements
@onready var title_label: Label = $BackgroundPanel/MainMenuContainer/VBoxContainer/TitleLabel
@onready var rift_fragments_value: Label = $BackgroundPanel/MainMenuContainer/VBoxContainer/RiftFragmentsContainer/RiftFragmentsValue
@onready var play_button: Button = $BackgroundPanel/MainMenuContainer/VBoxContainer/PlayButton
@onready var quit_button: Button = $BackgroundPanel/MainMenuContainer/VBoxContainer/QuitButton

# Character Select elements
@onready var char_title: Label = $BackgroundPanel/CharacterSelectContainer/VBoxContainer/CharTitle
@onready var knight_button: Button = $BackgroundPanel/CharacterSelectContainer/VBoxContainer/CharacterButtons/KnightButton
@onready var ranger_button: Button = $BackgroundPanel/CharacterSelectContainer/VBoxContainer/CharacterButtons/RangerButton
@onready var char_info_label: Label = $BackgroundPanel/CharacterSelectContainer/VBoxContainer/CharInfoLabel
@onready var char_confirm_button: Button = $BackgroundPanel/CharacterSelectContainer/VBoxContainer/CharConfirmButton
@onready var char_back_button: Button = $BackgroundPanel/CharacterSelectContainer/VBoxContainer/CharBackButton

# Map Select elements
@onready var map_title: Label = $BackgroundPanel/MapSelectContainer/VBoxContainer/MapTitle
@onready var tier1_button: Button = $BackgroundPanel/MapSelectContainer/VBoxContainer/TierButtons/Tier1Button
@onready var tier2_button: Button = $BackgroundPanel/MapSelectContainer/VBoxContainer/TierButtons/Tier2Button
@onready var tier3_button: Button = $BackgroundPanel/MapSelectContainer/VBoxContainer/TierButtons/Tier3Button
@onready var tier_info_label: Label = $BackgroundPanel/MapSelectContainer/VBoxContainer/TierInfoLabel
@onready var map_start_button: Button = $BackgroundPanel/MapSelectContainer/VBoxContainer/MapStartButton
@onready var map_back_button: Button = $BackgroundPanel/MapSelectContainer/VBoxContainer/MapBackButton

# Leaderboard elements
@onready var leaderboard_list: VBoxContainer = $BackgroundPanel/LeaderboardPanel/VBoxContainer/LeaderboardList

# Selection state
var selected_character: String = ""
var selected_tier: int = 1

# Character data
var character_types: Dictionary = {}

func _ready() -> void:
	Logger.info("MainMenu initialized", "ui")

	_load_character_types()
	_show_main_menu()
	_connect_signals()
	_update_rift_fragments_display()
	_update_leaderboard_display()

	# Connect to EventBus for Rift Fragments updates
	if EventBus:
		EventBus.rift_fragments_changed.connect(_on_rift_fragments_changed)
		EventBus.leaderboard_updated.connect(_on_leaderboard_updated)

func _load_character_types() -> void:
	"""Load character types from data file."""
	var character_data = load("res://data/core/character-types.tres")
	if character_data and character_data.character_types:
		character_types = character_data.character_types
		Logger.info("Loaded %d character types" % character_types.size(), "ui")
	else:
		Logger.error("Failed to load character-types.tres", "ui")

func _connect_signals() -> void:
	"""Connect all button signals."""
	# Main Menu
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Character Select
	knight_button.pressed.connect(func(): _on_character_selected("knight"))
	ranger_button.pressed.connect(func(): _on_character_selected("ranger"))
	char_confirm_button.pressed.connect(_on_char_confirm_pressed)
	char_back_button.pressed.connect(_show_main_menu)

	# Map Select
	tier1_button.pressed.connect(func(): _on_tier_selected(1))
	tier2_button.pressed.connect(func(): _on_tier_selected(2))
	tier3_button.pressed.connect(func(): _on_tier_selected(3))
	map_start_button.pressed.connect(_on_start_run_pressed)
	map_back_button.pressed.connect(_show_character_select)

# ============================================================================
# SCREEN NAVIGATION
# ============================================================================

func _show_main_menu() -> void:
	"""Show main menu, hide other screens."""
	main_menu_container.visible = true
	character_select_container.visible = false
	map_select_container.visible = false
	play_button.grab_focus()
	Logger.debug("Showing main menu", "ui")

func _show_character_select() -> void:
	"""Show character select screen."""
	main_menu_container.visible = false
	character_select_container.visible = true
	map_select_container.visible = false

	# Reset selection
	selected_character = ""
	_update_character_ui()
	knight_button.grab_focus()
	Logger.debug("Showing character select", "ui")

func _show_map_select() -> void:
	"""Show map/tier select screen."""
	main_menu_container.visible = false
	character_select_container.visible = false
	map_select_container.visible = true

	# Default to Tier 1
	selected_tier = 1
	_update_tier_ui()
	tier1_button.grab_focus()
	Logger.debug("Showing map select", "ui")

# ============================================================================
# MAIN MENU HANDLERS
# ============================================================================

func _on_play_pressed() -> void:
	"""Handle Play button - go to character select."""
	Logger.info("Play pressed", "ui")
	_show_character_select()

func _on_quit_pressed() -> void:
	"""Handle Quit button."""
	Logger.info("Quit pressed", "ui")
	get_tree().quit()

# ============================================================================
# CHARACTER SELECT HANDLERS
# ============================================================================

func _on_character_selected(character: String) -> void:
	"""Handle character button press."""
	selected_character = character
	_update_character_ui()
	Logger.info("Character selected: %s" % character, "ui")

func _update_character_ui() -> void:
	"""Update character selection UI."""
	# Update button states
	knight_button.disabled = (selected_character == "knight")
	ranger_button.disabled = (selected_character == "ranger")

	# Update info label
	if selected_character.is_empty():
		char_info_label.text = "Select a character"
		char_confirm_button.disabled = true
	else:
		if character_types.has(selected_character):
			var char_type = character_types[selected_character]
			char_info_label.text = "%s\n%s\nHP: %.0f | Damage: %.0f | Speed: %.1f" % [
				char_type.display_name,
				char_type.description,
				char_type.base_hp,
				char_type.base_damage,
				char_type.base_speed
			]
		else:
			char_info_label.text = "Character data not found"
		char_confirm_button.disabled = false

func _on_char_confirm_pressed() -> void:
	"""Confirm character selection and move to map select."""
	if selected_character.is_empty():
		Logger.warn("No character selected", "ui")
		return

	Logger.info("Character confirmed: %s" % selected_character, "ui")
	_show_map_select()

# ============================================================================
# MAP SELECT HANDLERS
# ============================================================================

func _on_tier_selected(tier: int) -> void:
	"""Handle tier button press."""
	selected_tier = tier
	_update_tier_ui()
	Logger.info("Tier selected: %d" % tier, "ui")

func _update_tier_ui() -> void:
	"""Update tier selection UI."""
	# Update button states
	tier1_button.disabled = (selected_tier == 1)
	tier2_button.disabled = (selected_tier == 2)
	tier3_button.disabled = (selected_tier == 3)

	# Update info label
	match selected_tier:
		1:
			tier_info_label.text = "Tier 1: Normal difficulty\nBase Rift Fragments"
		2:
			tier_info_label.text = "Tier 2: Hard difficulty\n+10% Rift Fragments"
		3:
			tier_info_label.text = "Tier 3: Expert difficulty\n+20% Rift Fragments"

func _on_start_run_pressed() -> void:
	"""Start the run with selected character and tier."""
	if selected_character.is_empty():
		Logger.error("No character selected", "ui")
		return

	Logger.info("Starting run: %s on Tier %d" % [selected_character, selected_tier], "ui")

	# Start run through SessionState
	if SessionState:
		SessionState.start_run(selected_character, "forest_arena", selected_tier)

	# Prepare context like hideout MapDevice does
	var context = {
		"character": selected_character,
		"spawn_point": "PlayerSpawnPoint",
		"source": "main_menu_selection",
		"tier": selected_tier,
		"character_data": {}  # Empty for now, player will spawn fresh
	}

	# Transition to PathAware arena (same as hideout flow)
	if StateManager:
		StateManager.start_run(&"pathgen_arena", context)

# ============================================================================
# RIFT FRAGMENTS DISPLAY
# ============================================================================

func _update_rift_fragments_display() -> void:
	"""Update the Rift Fragments display."""
	if MetaProgression:
		var balance = MetaProgression.get_rift_fragments()
		rift_fragments_value.text = str(balance)
		Logger.debug("Updated Rift Fragments: %d" % balance, "ui")
	else:
		rift_fragments_value.text = "0"

func _on_rift_fragments_changed(new_balance: int) -> void:
	"""Handle Rift Fragments balance changes."""
	rift_fragments_value.text = str(new_balance)
	Logger.debug("Rift Fragments updated to: %d" % new_balance, "ui")

# ============================================================================
# LEADERBOARD DISPLAY
# ============================================================================

func _update_leaderboard_display() -> void:
	"""Update the leaderboard with personal bests for each character."""
	# Clear existing entries
	for child in leaderboard_list.get_children():
		child.queue_free()

	if not LocalLeaderboard:
		Logger.warn("LocalLeaderboard not available", "ui")
		return

	# For each character type, find their personal best across all maps/tiers
	for char_id in character_types.keys():
		var best_kills = _get_character_best_kills(char_id)

		# Create label for this character
		var label = Label.new()
		if best_kills > 0:
			var char_name = character_types[char_id].display_name if character_types.has(char_id) else char_id.capitalize()
			label.text = "%s: %d kills" % [char_name, best_kills]
		else:
			var char_name = character_types[char_id].display_name if character_types.has(char_id) else char_id.capitalize()
			label.text = "%s: No runs yet" % char_name

		leaderboard_list.add_child(label)

	Logger.debug("Leaderboard display updated", "ui")

func _get_character_best_kills(char_id: String) -> int:
	"""Get the highest kill count for a character across all maps and tiers."""
	var best_kills = 0

	# Check all maps
	var maps = LocalLeaderboard.get_maps_with_entries()
	for map_id in maps:
		# Check all tiers for this map
		var tiers = LocalLeaderboard.get_tiers_with_entries(map_id)
		for tier in tiers:
			# Get leaderboard for this map+tier
			var leaderboard = LocalLeaderboard.get_leaderboard(map_id, tier)

			# Find best run for this character
			for entry in leaderboard:
				if entry.character_id == char_id:
					var kills = entry.get("kills", 0)
					if kills > best_kills:
						best_kills = kills

	return best_kills

func _on_leaderboard_updated(_map_id: String, _tier: int, _rank: int) -> void:
	"""Handle leaderboard updates to refresh display."""
	_update_leaderboard_display()
