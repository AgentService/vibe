extends Control

## CharacterSelect - Enhanced character selection and creation screen.
## Shows existing characters with Play/Delete options, plus Create New functionality.
## Integrates with CharacterManager for persistence and PlayerProgression for per-character data.

@onready var title_label: Label = $MainContainer/TitleLabel
@onready var character_list_container: VBoxContainer = $MainContainer/CharacterListContainer
@onready var create_new_section: VBoxContainer = $MainContainer/CreateNewSection
@onready var name_input: LineEdit = $MainContainer/CreateNewSection/NameContainer/NameInput
@onready var knight_button: Button = $MainContainer/CreateNewSection/CharacterContainer/KnightOption/KnightButton
@onready var knight_label: Label = $MainContainer/CreateNewSection/CharacterContainer/KnightOption/KnightLabel
@onready var ranger_button: Button = $MainContainer/CreateNewSection/CharacterContainer/RangerOption/RangerButton
@onready var ranger_label: Label = $MainContainer/CreateNewSection/CharacterContainer/RangerOption/RangerLabel
@onready var back_button: Button = $MainContainer/BackButton
@onready var create_new_button: Button = $MainContainer/CreateNewButton

var selected_character: String = ""
var is_creation_mode: bool = false
var character_item_buttons: Array[Button] = []

# Character classes loaded from data-driven configuration
var character_data: Dictionary = {}
var character_types: Dictionary = {}

func _ready() -> void:
	Logger.info("CharacterSelect initialized", "charselect")
	_load_character_types()
	_setup_ui_elements()
	_connect_button_signals()
	_load_character_list()
	
	# Start in list mode unless no characters exist
	var characters = CharacterManager.list_characters()
	if characters.is_empty():
		_switch_to_creation_mode()
	else:
		_switch_to_list_mode()

func _load_character_types() -> void:
	"""Load character types from data-driven configuration."""
	var resource_path := "res://data/content/player/character_types.tres"
	
	if not ResourceLoader.exists(resource_path):
		Logger.error("Character types resource not found: %s" % resource_path, "charselect")
		# Fallback to empty data - UI will handle gracefully
		return
	
	var loaded_resource = ResourceLoader.load(resource_path) as CharacterTypeDict
	if not loaded_resource:
		Logger.error("Failed to load character types from: %s" % resource_path, "charselect")
		return
	
	character_types = loaded_resource.character_types
	
	# Convert CharacterType resources to the format expected by existing UI
	character_data = {}
	for type_id in character_types.keys():
		var char_type := character_types[type_id] as CharacterType
		if char_type:
			character_data[type_id] = char_type.get_character_data()
	
	Logger.info("Loaded %d character types from data" % character_data.size(), "charselect")

func _load_character_list() -> void:
	"""Load and display the list of existing characters."""
	var characters = CharacterManager.list_characters()
	
	# Clear existing character list items
	_clear_character_list()
	
	Logger.info("Loading character list: %d characters found" % characters.size(), "charselect")
	
	for character in characters:
		_add_character_list_item(character)

func _clear_character_list() -> void:
	"""Clear all character list items."""
	for child in character_list_container.get_children():
		child.queue_free()
	character_item_buttons.clear()

func _add_character_list_item(character: CharacterProfile) -> void:
	"""Add a character item to the list with Play/Delete buttons."""
	var item_container = HBoxContainer.new()
	item_container.custom_minimum_size = Vector2(0, 60)
	
	# Character info label
	var info_label = Label.new()
	info_label.text = "%s (%s) - Level %d" % [character.name, character.clazz, character.level]
	info_label.custom_minimum_size = Vector2(300, 0)
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_container.add_child(info_label)
	
	# Last played label
	var date_label = Label.new()
	date_label.text = "Last played: %s" % character.last_played
	date_label.custom_minimum_size = Vector2(150, 0)
	date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	date_label.add_theme_font_size_override("font_size", 12)
	item_container.add_child(date_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_container.add_child(spacer)
	
	# Play button
	var play_button = Button.new()
	play_button.text = "Play"
	play_button.custom_minimum_size = Vector2(80, 40)
	play_button.pressed.connect(_on_character_play_pressed.bind(character.id))
	item_container.add_child(play_button)
	character_item_buttons.append(play_button)
	
	# Delete button
	var delete_button = Button.new()
	delete_button.text = "Delete"
	delete_button.custom_minimum_size = Vector2(80, 40)
	delete_button.pressed.connect(_on_character_delete_pressed.bind(character.id, character.name))
	item_container.add_child(delete_button)
	
	character_list_container.add_child(item_container)

func _on_character_play_pressed(character_id: StringName) -> void:
	"""Play with the selected character."""
	Logger.info("Playing character: %s" % character_id, "charselect")
	
	# Load character into CharacterManager as current
	CharacterManager.load_character(character_id)
	
	# Get the profile to load progression
	var profile := CharacterManager.get_current()
	if not profile:
		Logger.error("Failed to load character profile", "charselect")
		_show_error_message("Failed to load character. Please try again.")
		return
	
	# Load character progression into PlayerProgression
	PlayerProgression.load_from_profile(profile.progression)
	
	Logger.info("Character loaded: %s (ID: %s) Level: %d XP: %.1f" % [profile.name, profile.id, profile.level, profile.exp], "charselect")
	
	# Prepare context for StateManager
	var context = {
		"character_id": profile.id,
		"character_data": profile.get_character_data(),
		"spawn_point": "PlayerSpawnPoint",
		"source": "character_select_play"
	}
	
	# Use StateManager to transition to hideout
	StateManager.go_to_hideout(context)

func _on_character_delete_pressed(character_id: StringName, character_name: String) -> void:
	"""Show confirmation dialog before deleting character."""
	var confirmation = ConfirmationDialog.new()
	confirmation.dialog_text = "Delete character '%s'? This action cannot be undone." % character_name
	confirmation.title = "Confirm Deletion"
	add_child(confirmation)
	confirmation.popup_centered()
	
	# Connect to deletion confirmation
	confirmation.confirmed.connect(_confirm_character_deletion.bind(character_id))
	confirmation.confirmed.connect(confirmation.queue_free)
	confirmation.canceled.connect(confirmation.queue_free)

func _confirm_character_deletion(character_id: StringName) -> void:
	"""Actually delete the character after confirmation."""
	Logger.info("Deleting character: %s" % character_id, "charselect")
	CharacterManager.delete_character(character_id)
	
	# Reload the character list
	_load_character_list()
	
	# Check if no characters left
	var characters = CharacterManager.list_characters()
	if characters.is_empty():
		Logger.info("No characters remaining, switching to creation mode", "charselect")
		_switch_to_creation_mode()

func _switch_to_list_mode() -> void:
	"""Switch to character list mode."""
	is_creation_mode = false
	title_label.text = "Select Character"
	
	# Show character list and create new button, hide creation section
	character_list_container.visible = true
	create_new_button.visible = true
	create_new_section.visible = false
	
	# Focus first character if any
	if not character_item_buttons.is_empty():
		character_item_buttons[0].grab_focus()
	else:
		create_new_button.grab_focus()

func _switch_to_creation_mode() -> void:
	"""Switch to character creation mode."""
	is_creation_mode = true
	title_label.text = "Create New Character"
	
	# Hide character list and create new button, show creation section
	character_list_container.visible = false
	create_new_button.visible = false
	create_new_section.visible = true
	
	# Focus name input
	name_input.grab_focus()
	name_input.text = ""  # Clear previous input

func _setup_ui_elements() -> void:
	"""Configure UI elements with character information."""
	
	# Configure title
	title_label.text = "Character Select"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	
	# Configure create new button
	create_new_button.text = "Create New Character"
	create_new_button.custom_minimum_size = Vector2(300, 50)
	
	# Configure name input
	if name_input:
		name_input.placeholder_text = "Enter character name"
		name_input.max_length = 50
		name_input.clear_button_enabled = true
	
	# Configure character buttons and labels
	knight_button.text = "Knight"
	knight_label.text = character_data["knight"]["description"]
	knight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	knight_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	ranger_button.text = "Ranger"
	ranger_label.text = character_data["ranger"]["description"]
	ranger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranger_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Configure buttons
	var button_min_size = Vector2(150, 80)
	knight_button.custom_minimum_size = button_min_size
	ranger_button.custom_minimum_size = button_min_size
	
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(120, 40)

func _connect_button_signals() -> void:
	"""Connect button press signals to handler functions."""
	
	create_new_button.pressed.connect(_on_create_new_pressed)
	knight_button.pressed.connect(_on_character_selected.bind("knight"))
	ranger_button.pressed.connect(_on_character_selected.bind("ranger"))
	back_button.pressed.connect(_on_back_pressed)

func _on_create_new_pressed() -> void:
	"""Switch to character creation mode."""
	Logger.info("Create new character button pressed", "charselect")
	_switch_to_creation_mode()

func _on_character_selected(character_id: String) -> void:
	"""Handle character creation and selection, then proceed to hideout."""
	
	# Get character name from input field
	var character_name := name_input.text.strip_edges() if name_input else ""
	if character_name.is_empty():
		character_name = "Hero"  # Default fallback name
	
	selected_character = character_id
	var character_class := StringName(character_id.capitalize())
	
	Logger.info("Creating character: %s (%s)" % [character_name, character_class], "charselect")
	
	# Create character profile via CharacterManager
	var profile := CharacterManager.create_character(character_name, character_class)
	if not profile:
		Logger.error("Failed to create character profile", "charselect")
		_show_error_message("Failed to create character. Please try again.")
		return
	
	# Load character into CharacterManager as current
	CharacterManager.load_character(profile.id)
	
	# Load character progression into PlayerProgression
	PlayerProgression.load_from_profile(profile.progression)
	
	Logger.info("Character created and loaded: %s (ID: %s)" % [profile.name, profile.id], "charselect")
	
	# Prepare context for StateManager
	var context = {
		"character_id": profile.id,
		"character_data": profile.get_character_data(),
		"spawn_point": "PlayerSpawnPoint",
		"source": "character_select"
	}
	
	# Use StateManager to transition to hideout
	StateManager.go_to_hideout(context)

func _on_back_pressed() -> void:
	"""Handle back button - context-sensitive navigation."""
	
	if is_creation_mode:
		# Go back to character list if there are characters, otherwise main menu
		var characters = CharacterManager.list_characters()
		if not characters.is_empty():
			Logger.info("Back to character list from creation", "charselect")
			_switch_to_list_mode()
			return
	
	# Go back to main menu
	Logger.info("Back to main menu pressed", "charselect")
	StateManager.go_to_menu({"source": "character_select_back"})

func get_selected_character() -> String:
	"""Returns the currently selected character ID."""
	return selected_character

func get_character_data(character_id: String) -> Dictionary:
	"""Returns character data for the specified character."""
	return character_data.get(character_id, {})

func _show_error_message(message: String) -> void:
	"""Show an error message popup to the user."""
	var popup := AcceptDialog.new()
	popup.dialog_text = message
	popup.title = "Error"
	add_child(popup)
	popup.popup_centered()
	
	# Auto-remove after showing
	popup.confirmed.connect(popup.queue_free)
	popup.canceled.connect(popup.queue_free)
