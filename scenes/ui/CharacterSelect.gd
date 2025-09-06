extends Control

## CharacterSelect - Character selection screen with dummy character options.
## Allows player to choose between Knight, Ranger, and Mage classes.

@onready var title_label: Label = $MainContainer/TitleLabel
@onready var knight_button: Button = $MainContainer/CharacterContainer/KnightOption/KnightButton
@onready var knight_label: Label = $MainContainer/CharacterContainer/KnightOption/KnightLabel
@onready var ranger_button: Button = $MainContainer/CharacterContainer/RangerOption/RangerButton
@onready var ranger_label: Label = $MainContainer/CharacterContainer/RangerOption/RangerLabel
@onready var mage_button: Button = $MainContainer/CharacterContainer/MageOption/MageButton
@onready var mage_label: Label = $MainContainer/CharacterContainer/MageOption/MageLabel
@onready var back_button: Button = $MainContainer/BackButton

var selected_character: String = ""

# Character data for future expansion
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
	},
	"mage": {
		"name": "Mage",
		"description": "Magical spellcaster with powerful abilities", 
		"stats": {"hp": 60, "damage": 40, "speed": 0.9}
	}
}

func _ready() -> void:
	Logger.info("CharacterSelect initialized", "charselect")
	_setup_ui_elements()
	_connect_button_signals()
	
	# Set focus to first character option
	knight_button.grab_focus()

func _setup_ui_elements() -> void:
	"""Configure UI elements with character information."""
	
	# Configure title
	title_label.text = "Choose Your Character"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	
	# Configure character buttons and labels
	knight_button.text = "Knight"
	knight_label.text = character_data["knight"]["description"]
	knight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	knight_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	ranger_button.text = "Ranger"
	ranger_label.text = character_data["ranger"]["description"]
	ranger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranger_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	mage_button.text = "Mage"
	mage_label.text = character_data["mage"]["description"]
	mage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Configure buttons
	var button_min_size = Vector2(150, 80)
	knight_button.custom_minimum_size = button_min_size
	ranger_button.custom_minimum_size = button_min_size
	mage_button.custom_minimum_size = button_min_size
	
	back_button.text = "Back to Main Menu"
	back_button.custom_minimum_size = Vector2(200, 40)

func _connect_button_signals() -> void:
	"""Connect button press signals to handler functions."""
	
	knight_button.pressed.connect(_on_character_selected.bind("knight"))
	ranger_button.pressed.connect(_on_character_selected.bind("ranger"))
	mage_button.pressed.connect(_on_character_selected.bind("mage"))
	back_button.pressed.connect(_on_back_pressed)

func _on_character_selected(character_id: String) -> void:
	"""Handle character selection and proceed to hideout."""
	
	selected_character = character_id
	var character_name = character_data[character_id]["name"]
	
	Logger.info("Character selected: " + character_name, "charselect")
	
	# Character selection is passed via transition data to the target scene
	
	# Prepare transition data with character information
	var transition_data = {
		"map_id": "hideout",
		"character_id": character_id,
		"character_data": character_data[character_id],
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
