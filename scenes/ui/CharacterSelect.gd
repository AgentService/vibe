extends Control
## CharacterSelect - Character selection screen with visual feedback
## Loads character data and handles selection state before proceeding to map select

# Asset path conventions for filename-based asset loading
const PORTRAIT_PATH = "res://assets/ui/characters/portraits/"
const ABILITY_ICON_PATH = "res://assets/ui/abilities/icons/"
const PASSIVE_ICON_PATH = "res://assets/ui/passives/icons/"
const FALLBACK_PORTRAIT = "res://icon.svg"  # Default Godot icon as fallback
const FALLBACK_ICON = "res://icon.svg"

# Character button template scene
const CharacterButtonScene = preload("res://scenes/ui/components/CharacterSelectButton.tscn")

# Character selection grid (dynamically populated)
@onready var character_grid: GridContainer = $CharacterSelectionPanel/VBoxContainer2/VBoxContainer3/NinePatchRect/MarginContainer/GridContainer

# Character info display (right panel)
@onready var character_name_label: Label = $CharacterInfoPanel/NinePatchRect/VBoxContainer3/MarginContainer/HBoxContainer/VBoxContainer/name
@onready var character_rank_label: Label = $CharacterInfoPanel/NinePatchRect/VBoxContainer3/MarginContainer/HBoxContainer/VBoxContainer/rank
@onready var character_runs_label: Label = $CharacterInfoPanel/NinePatchRect/VBoxContainer3/MarginContainer/HBoxContainer/VBoxContainer/runcount
@onready var character_description_label: Label = $CharacterInfoPanel/NinePatchRect/VBoxContainer3/MarginContainer2/VBoxContainer/Description
@onready var character_icon: TextureRect = $CharacterInfoPanel/NinePatchRect/VBoxContainer3/MarginContainer/HBoxContainer/NinePatchRect/MarginContainer/TextureRect

# Main ability display
@onready var ability_name_label: Label = $CharacterInfoPanel/NinePatchRect/VBoxContainer3/MainAbility/HBoxContainer/VBoxContainer/Label
@onready var ability_description_label: Label = $CharacterInfoPanel/NinePatchRect/VBoxContainer3/MainAbility/HBoxContainer/VBoxContainer/Label3
@onready var ability_icon: TextureRect = $CharacterInfoPanel/NinePatchRect/VBoxContainer3/MainAbility/HBoxContainer/NinePatchRect/MarginContainer/TextureRect

# Main passive display
@onready var passive_name_label: Label = $CharacterInfoPanel/NinePatchRect/VBoxContainer3/MainPassive/HBoxContainer/VBoxContainer/Label
@onready var passive_description_label: Label = $CharacterInfoPanel/NinePatchRect/VBoxContainer3/MainPassive/HBoxContainer/VBoxContainer/Label3
@onready var passive_icon: TextureRect = $CharacterInfoPanel/NinePatchRect/VBoxContainer3/MainPassive/HBoxContainer/NinePatchRect/MarginContainer/TextureRect

# Navigation buttons
@onready var confirm_button: Button = $CharacterInfoPanel/NinePatchRect/VBoxContainer3/MarginContainer6/VBoxContainer/HBoxContainer/confirm
@onready var back_button: Button = $BackButton

# Selection state
var selected_character: String = ""

# Character data (loaded from data/core/character-types.tres)
var character_types: Dictionary = {}

# Texture cache to avoid redundant loading
var _texture_cache: Dictionary = {}  # key: full_path, value: Texture2D

func apply_transition_data(data: Dictionary) -> void:
	"""Receive transition data from SceneTransitionManager.

	Called when returning from MapSelect to restore previous character selection.

	Args:
		data: Transition context, may contain "character" key with previously selected character
	"""
	if data.has("character"):
		var char_id = data.character
		if character_types.has(char_id):
			selected_character = char_id
			_update_character_ui()
			Logger.info("CharacterSelect: Restored character selection: %s" % char_id, "ui")
		else:
			Logger.warn("CharacterSelect: Invalid character in transition data: %s" % char_id, "ui")

func _ready() -> void:
	_load_character_types()
	_populate_character_grid()  # Dynamically create character buttons
	_connect_signals()
	_auto_select_first_character()  # Select first character by default
	_update_character_ui()  # Initialize UI with first character selected

	Logger.info("CharacterSelect loaded with %d characters" % character_types.size(), "ui")

func _load_character_types() -> void:
	"""Load character types from data file."""
	var character_data = load("res://data/core/character-types.tres")
	if character_data and character_data.character_types:
		character_types = character_data.character_types
		Logger.info("Loaded %d character types" % character_types.size(), "ui")
	else:
		Logger.error("Failed to load character-types.tres", "ui")

func _populate_character_grid() -> void:
	"""Dynamically create character buttons from character_types data."""
	# Clear existing children (Knight/Ranger hardcoded buttons)
	for child in character_grid.get_children():
		child.queue_free()

	# Create button for each character type
	for char_id in character_types.keys():
		var char_type = character_types[char_id]
		var button = _create_character_button(char_id, char_type)
		character_grid.add_child(button)

func _create_character_button(char_id: String, char_type: CharacterType) -> CharacterSelectButton:
	"""Create a character selection button from template scene."""
	# Instantiate the template scene
	var button_instance: CharacterSelectButton = CharacterButtonScene.instantiate()
	button_instance.name = char_id.capitalize()

	# Load portrait texture
	var portrait_texture = _load_texture_from_filename(
		char_type.portrait_icon,
		PORTRAIT_PATH,
		FALLBACK_PORTRAIT
	)

	# Setup the button with character data
	button_instance.setup(char_id, char_type, portrait_texture)

	# Connect to character selection signal
	button_instance.character_selected.connect(_on_character_selected)

	return button_instance

func _connect_signals() -> void:
	"""Connect navigation button signals."""
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _auto_select_first_character() -> void:
	"""Auto-select the first character in the list by default."""
	if character_types.is_empty():
		return

	# Get first character ID from the dictionary
	var first_char_id = character_types.keys()[0]
	selected_character = first_char_id
	Logger.info("Auto-selected first character: %s" % first_char_id, "ui")

func _on_character_selected(character_id: String) -> void:
	"""Handle character button press - update selection state and UI."""
	selected_character = character_id
	_update_character_ui()
	Logger.info("Character selected: %s" % character_id, "ui")

func _update_character_button_states() -> void:
	"""Update button disabled states based on current selection."""
	for child in character_grid.get_children():
		if child is CharacterSelectButton:
			# Use the component's built-in method to update state
			var is_selected = (child.character_id == selected_character)
			child.set_selected(is_selected)

func _update_character_ui() -> void:
	"""Update UI to reflect current selection state."""
	_update_character_button_states()

	if selected_character.is_empty():
		_show_placeholder_ui()
	elif character_types.has(selected_character):
		_show_character_info(character_types[selected_character])
	else:
		_show_error_ui()

func _show_placeholder_ui() -> void:
	"""Display placeholder when no character is selected."""
	_set_character_info("Select a Character", "", "", "Choose your hero")
	_clear_ability_info()
	_clear_passive_info()
	confirm_button.disabled = true

func _show_error_ui() -> void:
	"""Display error state when character data is missing."""
	_set_character_info("Error", "", "", "Character data not found")
	_clear_ability_info()
	_clear_passive_info()
	confirm_button.disabled = true

func _show_character_info(char_type: CharacterType) -> void:
	"""Display full character information for selected character."""
	# Character info
	_set_character_info(
		char_type.display_name,
		"Rank 1",  # TODO(UI-phase2): Load character rank from MetaProgression autoload
		"0 Runs",  # TODO(UI-phase2): Load run count from LocalLeaderboard for this character
		char_type.description
	)
	_update_character_icon(selected_character)

	# Ability info
	_set_ability_info(
		char_type.main_ability_name,
		char_type.main_ability_description,
		_load_texture_from_filename(char_type.main_ability_icon, ABILITY_ICON_PATH, FALLBACK_ICON)
	)

	# Passive info
	_set_passive_info(
		char_type.main_passive_name,
		char_type.main_passive_description,
		_load_texture_from_filename(char_type.main_passive_icon, PASSIVE_ICON_PATH, FALLBACK_ICON)
	)

	confirm_button.disabled = false

# ============================================================================
# UI HELPER METHODS
# ============================================================================

func _set_character_info(name: String, rank: String, runs: String, description: String) -> void:
	"""Set character info panel text fields."""
	character_name_label.text = name
	character_rank_label.text = rank
	character_runs_label.text = runs
	character_description_label.text = description

func _set_ability_info(name: String, description: String, icon: Texture2D) -> void:
	"""Set ability display fields."""
	ability_name_label.text = name
	ability_description_label.text = description
	ability_icon.texture = icon

func _set_passive_info(name: String, description: String, icon: Texture2D) -> void:
	"""Set passive display fields."""
	passive_name_label.text = name
	passive_description_label.text = description
	passive_icon.texture = icon

func _clear_ability_info() -> void:
	"""Clear ability display."""
	_set_ability_info("", "", null)

func _clear_passive_info() -> void:
	"""Clear passive display."""
	_set_passive_info("", "", null)

func _load_texture_from_filename(filename: String, base_path: String, fallback: String) -> Texture2D:
	"""
	Load texture from filename using convention-based paths.
	Caches loaded textures to avoid redundant loading.

	Args:
		filename: Just the filename (e.g., "sword", "knight_portrait")
		base_path: Base directory path (e.g., ABILITY_ICON_PATH)
		fallback: Fallback texture path if file not found

	Returns:
		Loaded texture or fallback texture
	"""
	if filename.is_empty():
		# Don't cache fallback loads
		return load(fallback) as Texture2D

	# Try .png first, then .svg
	var extensions = [".png", ".svg"]
	for ext in extensions:
		var full_path = base_path + filename + ext

		# Check cache first
		if _texture_cache.has(full_path):
			return _texture_cache[full_path]

		# Load and cache
		if ResourceLoader.exists(full_path):
			var texture = load(full_path) as Texture2D
			_texture_cache[full_path] = texture
			return texture

	# If not found, log warning and use fallback (don't cache)
	Logger.warn("Asset not found: %s (tried %s)" % [filename, base_path], "ui")
	return load(fallback) as Texture2D

func _update_character_icon(character_id: String) -> void:
	"""Update character portrait icon in the info panel."""
	if not character_types.has(character_id):
		return

	var char_type = character_types[character_id]
	if not char_type.portrait_icon.is_empty():
		character_icon.texture = _load_texture_from_filename(
			char_type.portrait_icon,
			PORTRAIT_PATH,
			FALLBACK_PORTRAIT
		)

func _on_confirm_pressed() -> void:
	"""Proceed to map selection after character is chosen."""
	if selected_character.is_empty():
		Logger.warn("Confirm pressed with no character selected", "ui")
		return

	Logger.info("Character confirmed: %s - proceeding to map selection" % selected_character, "ui")

	# Navigate to map select via SceneTransitionManager
	if EventBus:
		EventBus.request_enter_map.emit({
			"map_id": "map_select",
			"source": "character_select",
			"character": selected_character  # Pass selection forward
		})
	else:
		Logger.error("EventBus not available - cannot transition to map select", "ui")

func _on_back_pressed() -> void:
	"""Return to main menu."""
	Logger.info("Back pressed - returning to MainMenu", "ui")

	# Clear selection when going back
	selected_character = ""

	if EventBus:
		EventBus.request_enter_map.emit({
			"map_id": "main_menu",
			"source": "character_select"
		})
	else:
		Logger.error("EventBus not available - cannot return to main menu", "ui")
