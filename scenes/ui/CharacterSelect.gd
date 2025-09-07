extends Control

## CharacterSelect - Character creation and selection screen.
## Allows player to create new characters with chosen name and class (Knight/Ranger).
## Integrates with CharacterManager for persistence and PlayerProgression for per-character data.

@onready var title_label: Label = $MainContainer/TitleLabel
@onready var name_input: LineEdit = $MainContainer/NameContainer/NameInput
@onready var knight_button: Button = $MainContainer/CharacterContainer/KnightOption/KnightButton
@onready var knight_label: Label = $MainContainer/CharacterContainer/KnightOption/KnightLabel
@onready var ranger_button: Button = $MainContainer/CharacterContainer/RangerOption/RangerButton
@onready var ranger_label: Label = $MainContainer/CharacterContainer/RangerOption/RangerLabel
@onready var back_button: Button = $MainContainer/BackButton

var selected_character: String = ""

# Character classes available for creation
var character_data = {
	"knight": {
		"name": "Knight",
		"description": "Sturdy melee fighter with high defense",
		"stats": {"hp": 100, "damage": 25, "speed": 1.0}
	},
	"ranger": {
		"name": "Ranger", 
		"description": "Agile ranged combatant with quick attacks",
		"stats": {"hp": 75, "damage": 30, "speed": 1.2}
	}
}

func _ready() -> void:
	Logger.info("CharacterSelect initialized", "charselect")
	_setup_ui_elements()
	_connect_button_signals()
	_check_existing_characters()
	
	# Focus name input for character creation
	name_input.grab_focus()

func _check_existing_characters() -> void:
	"""Check if characters exist and offer to continue with most recent (MVP scope)."""
	var characters = CharacterManager.list_characters()
	
	if characters.size() > 0:
		var most_recent = characters[0]  # Already sorted by last_played in CharacterManager
		Logger.info("Found %d existing characters, most recent: %s (%s) Level %d" % [characters.size(), most_recent.name, most_recent.clazz, most_recent.level], "charselect")
		
		# Update title to show option to continue
		title_label.text = "Continue with %s (Level %d) or Create New Character" % [most_recent.name, most_recent.level]
		
		# Add a "Continue" button above the creation section
		_add_continue_button(most_recent)
	else:
		Logger.info("No existing characters found, showing character creation", "charselect")
		title_label.text = "Create Your Character"

func _add_continue_button(character: CharacterProfile) -> void:
	"""Add a simple Continue button for the most recent character (MVP scope)."""
	var continue_button = Button.new()
	continue_button.text = "Continue with %s" % character.name
	continue_button.custom_minimum_size = Vector2(300, 60)
	continue_button.pressed.connect(_continue_with_character.bind(character.id))
	
	# Insert before NameContainer
	var main_container = $MainContainer
	var name_container_index = 0
	for i in range(main_container.get_child_count()):
		if main_container.get_child(i).name == "NameContainer":
			name_container_index = i
			break
	
	main_container.add_child(continue_button)
	main_container.move_child(continue_button, name_container_index)
	
	# Focus the continue button instead of name input
	continue_button.grab_focus()

func _continue_with_character(character_id: StringName) -> void:
	"""Continue playing with an existing character (MVP scope)."""
	Logger.info("Continuing with existing character: %s" % character_id, "charselect")
	
	# Load character into CharacterManager as current
	CharacterManager.load_character(character_id)
	
	# Get the profile to load progression
	var profile := CharacterManager.get_current()
	if not profile:
		Logger.error("Failed to load character profile", "charselect")
		_show_error_message("Failed to load character. Please create a new one.")
		return
	
	# Load character progression into PlayerProgression
	PlayerProgression.load_from_profile(profile.progression)
	
	Logger.info("Character loaded: %s (ID: %s) Level: %d XP: %.1f" % [profile.name, profile.id, profile.level, profile.exp], "charselect")
	
	# Prepare transition data
	var transition_data = {
		"map_id": "hideout",
		"character_id": profile.id,
		"character_data": profile.get_character_data(),
		"spawn_point": "PlayerSpawnPoint",
		"source": "character_select_continue"
	}
	
	# Request transition to hideout
	EventBus.request_enter_map.emit(transition_data)

func _setup_ui_elements() -> void:
	"""Configure UI elements with character information."""
	
	# Configure title
	title_label.text = "Create Your Character"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	
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
	
	back_button.text = "Back to Main Menu"
	back_button.custom_minimum_size = Vector2(200, 40)

func _connect_button_signals() -> void:
	"""Connect button press signals to handler functions."""
	
	knight_button.pressed.connect(_on_character_selected.bind("knight"))
	ranger_button.pressed.connect(_on_character_selected.bind("ranger"))
	back_button.pressed.connect(_on_back_pressed)

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
	
	# Prepare transition data with character information
	var transition_data = {
		"map_id": "hideout",
		"character_id": profile.id,
		"character_data": profile.get_character_data(),
		"spawn_point": "PlayerSpawnPoint",
		"source": "character_select"
	}
	
	# Request transition to hideout
	EventBus.request_enter_map.emit(transition_data)

func _on_back_pressed() -> void:
	"""Handle back button - return to main menu."""
	
	Logger.info("Back to main menu pressed", "charselect")
	
	# Request transition back to main menu
	EventBus.request_enter_map.emit({
		"map_id": "main_menu",
		"source": "character_select_back"
	})

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
