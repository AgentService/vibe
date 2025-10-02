extends Control
## CharacterSelect - Character selection screen with visual feedback
## Loads character data and handles selection state before proceeding to map select

# Character selection buttons
@onready var knight_button: Button = $MarginContainer_CharacterSelect/VBoxContainer2/VBoxContainer3/NinePatchRect/MarginContainer/GridContainer/Knight/NinePatchRect/MarginContainer/Button
@onready var ranger_button: Button = $MarginContainer_CharacterSelect/VBoxContainer2/VBoxContainer3/NinePatchRect/MarginContainer/GridContainer/Ranger/NinePatchRect/MarginContainer/Button

# Character info display (right panel)
@onready var character_name_label: Label = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MarginContainer/HBoxContainer/VBoxContainer/Label
@onready var character_stats_label: Label = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MarginContainer/HBoxContainer/VBoxContainer/Label2
@onready var character_description_label: Label = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MarginContainer/HBoxContainer/VBoxContainer/Label3
@onready var character_icon: TextureRect = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MarginContainer/HBoxContainer/NinePatchRect/MarginContainer/TextureRect

# Navigation buttons
@onready var confirm_button: Button = $MarginContainer_CharacterSelect2/NinePatchRect/VBoxContainer3/MarginContainer6/VBoxContainer/HBoxContainer/confirm
@onready var back_button: Button = $BackButton

# Selection state
var selected_character: String = ""

# Character data (loaded from data/core/character-types.tres)
var character_types: Dictionary = {}

func _ready() -> void:
	_load_character_types()
	_connect_signals()
	_update_character_ui()  # Initialize UI to "no selection" state

	Logger.info("CharacterSelect loaded", "ui")

func _load_character_types() -> void:
	"""Load character types from data file."""
	var character_data = load("res://data/core/character-types.tres")
	if character_data and character_data.character_types:
		character_types = character_data.character_types
		Logger.info("Loaded %d character types" % character_types.size(), "ui")
	else:
		Logger.error("Failed to load character-types.tres", "ui")

func _connect_signals() -> void:
	"""Connect button signals."""
	knight_button.pressed.connect(func(): _on_character_selected("knight"))
	ranger_button.pressed.connect(func(): _on_character_selected("ranger"))
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _on_character_selected(character_id: String) -> void:
	"""Handle character button press - update selection state and UI."""
	selected_character = character_id
	_update_character_ui()
	Logger.info("Character selected: %s" % character_id, "ui")

func _update_character_ui() -> void:
	"""Update UI to reflect current selection state."""
	# Update button states (disable selected button for visual feedback)
	knight_button.disabled = (selected_character == "knight")
	ranger_button.disabled = (selected_character == "ranger")

	# Update character info panel
	if selected_character.is_empty():
		# No selection - show placeholder
		character_name_label.text = "Select a Character"
		character_stats_label.text = ""
		character_description_label.text = "Choose your hero"
		confirm_button.disabled = true
	else:
		# Character selected - show data
		if character_types.has(selected_character):
			var char_type = character_types[selected_character]
			character_name_label.text = char_type.display_name
			character_stats_label.text = "HP: %.0f | DMG: %.0f | SPD: %.1f" % [
				char_type.base_hp,
				char_type.base_damage,
				char_type.base_speed
			]
			character_description_label.text = char_type.description
			confirm_button.disabled = false

			# Update character icon based on selection
			_update_character_icon(selected_character)
		else:
			character_name_label.text = "Error"
			character_stats_label.text = ""
			character_description_label.text = "Character data not found"
			confirm_button.disabled = true

func _update_character_icon(character_id: String) -> void:
	"""Update character icon in the info panel."""
	# TODO: Load actual character icons from assets
	# For now, icons are already set in the scene
	# This can be expanded when character portrait assets are added
	match character_id:
		"knight":
			# character_icon.texture = load("res://assets/characters/knight_portrait.png")
			pass
		"ranger":
			# character_icon.texture = load("res://assets/characters/ranger_portrait.png")
			pass

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
