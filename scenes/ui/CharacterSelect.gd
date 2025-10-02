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
@onready var character_grid: GridContainer = $MarginContainer_CharacterSelect/VBoxContainer2/VBoxContainer3/NinePatchRect/MarginContainer/GridContainer

# Character info display (right panel)
@onready var character_name_label: Label = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MarginContainer/HBoxContainer/VBoxContainer/name
@onready var character_rank_label: Label = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MarginContainer/HBoxContainer/VBoxContainer/rank
@onready var character_runs_label: Label = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MarginContainer/HBoxContainer/VBoxContainer/runcount
@onready var character_description_label: Label = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MarginContainer2/VBoxContainer/Description
@onready var character_icon: TextureRect = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MarginContainer/HBoxContainer/NinePatchRect/MarginContainer/TextureRect

# Main ability display
@onready var ability_name_label: Label = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MainAbility/HBoxContainer/VBoxContainer/Label
@onready var ability_description_label: Label = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MainAbility/HBoxContainer/VBoxContainer/Label3
@onready var ability_icon: TextureRect = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MainAbility/HBoxContainer/NinePatchRect/MarginContainer/TextureRect

# Main passive display
@onready var passive_name_label: Label = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MainPassive/HBoxContainer/VBoxContainer/Label
@onready var passive_description_label: Label = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MainPassive/HBoxContainer/VBoxContainer/Label3
@onready var passive_icon: TextureRect = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MainPassive/HBoxContainer/NinePatchRect/MarginContainer/TextureRect

# Navigation buttons
@onready var confirm_button: Button = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MarginContainer6/VBoxContainer/HBoxContainer/confirm
@onready var back_button: Button = $BackButton

# Selection state
var selected_character: String = ""

# Character data (loaded from data/core/character-types.tres)
var character_types: Dictionary = {}

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
	# Update button states (disable selected button for visual feedback)
	_update_character_button_states()

	# Update character info panel
	if selected_character.is_empty():
		# No selection - show placeholder
		character_name_label.text = "Select a Character"
		character_rank_label.text = ""
		character_runs_label.text = ""
		character_description_label.text = "Choose your hero"
		ability_name_label.text = ""
		ability_description_label.text = ""
		passive_name_label.text = ""
		passive_description_label.text = ""
		confirm_button.disabled = true
	else:
		# Character selected - show data
		if character_types.has(selected_character):
			var char_type = character_types[selected_character]
			character_name_label.text = char_type.display_name

			# Rank and runs placeholders (TODO: Replace with actual progression data)
			character_rank_label.text = "Rank 1"  # Placeholder - load from progression system
			character_runs_label.text = "0 Runs"  # Placeholder - load from progression system

			# Description from character data
			character_description_label.text = char_type.description

			# Main ability display
			ability_name_label.text = char_type.main_ability_name
			ability_description_label.text = char_type.main_ability_description
			ability_icon.texture = _load_texture_from_filename(
				char_type.main_ability_icon,
				ABILITY_ICON_PATH,
				FALLBACK_ICON
			)

			# Main passive display
			passive_name_label.text = char_type.main_passive_name
			passive_description_label.text = char_type.main_passive_description
			passive_icon.texture = _load_texture_from_filename(
				char_type.main_passive_icon,
				PASSIVE_ICON_PATH,
				FALLBACK_ICON
			)

			confirm_button.disabled = false

			# Update character icon based on selection
			_update_character_icon(selected_character)
		else:
			character_name_label.text = "Error"
			character_rank_label.text = ""
			character_runs_label.text = ""
			character_description_label.text = "Character data not found"
			ability_name_label.text = ""
			ability_description_label.text = ""
			passive_name_label.text = ""
			passive_description_label.text = ""
			confirm_button.disabled = true

func _load_texture_from_filename(filename: String, base_path: String, fallback: String) -> Texture2D:
	"""
	Load texture from filename using convention-based paths.

	Args:
		filename: Just the filename (e.g., "sword", "knight_portrait")
		base_path: Base directory path (e.g., ABILITY_ICON_PATH)
		fallback: Fallback texture path if file not found

	Returns:
		Loaded texture or fallback texture
	"""
	if filename.is_empty():
		return load(fallback) as Texture2D

	# Try .png first, then .svg
	var extensions = [".png", ".svg"]
	for ext in extensions:
		var full_path = base_path + filename + ext
		if ResourceLoader.exists(full_path):
			return load(full_path) as Texture2D

	# If not found, log warning and use fallback
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
	EventBus.request_enter_map.emit({
		"map_id": "map_select",
		"source": "character_select",
		"character": selected_character  # Pass selection forward
	})

func _on_back_pressed() -> void:
	"""Return to main menu."""
	Logger.info("Back pressed - returning to MainMenu", "ui")

	# Clear selection when going back
	selected_character = ""

	EventBus.request_enter_map.emit({
		"map_id": "main_menu",
		"source": "character_select"
	})
