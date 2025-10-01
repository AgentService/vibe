extends "res://scripts/ui_framework/BaseModal.gd"

## RunSetupModal - Character/Map/Tier selection for starting new runs (Task 04)
## Allows player to choose character class, map, and difficulty tier
## Connects to SessionState.start_run() with selected configuration

# UI References
@onready var title_label: Label = $PopupPanel/VBoxContainer/TitleLabel
@onready var character_info_label: Label = $PopupPanel/VBoxContainer/CharacterSection/CharacterInfoLabel
@onready var tier_info_label: Label = $PopupPanel/VBoxContainer/TierSection/TierInfoLabel

# Character buttons
@onready var knight_button: Button = $PopupPanel/VBoxContainer/CharacterSection/CharacterButtons/KnightButton
@onready var ranger_button: Button = $PopupPanel/VBoxContainer/CharacterSection/CharacterButtons/RangerButton

# Map buttons
@onready var arena_button: Button = $PopupPanel/VBoxContainer/MapSection/MapButtons/ArenaButton

# Tier buttons
@onready var tier1_button: Button = $PopupPanel/VBoxContainer/TierSection/TierButtons/Tier1Button
@onready var tier2_button: Button = $PopupPanel/VBoxContainer/TierSection/TierButtons/Tier2Button
@onready var tier3_button: Button = $PopupPanel/VBoxContainer/TierSection/TierButtons/Tier3Button

# Action buttons
@onready var cancel_button: Button = $PopupPanel/VBoxContainer/ButtonContainer/CancelButton
@onready var start_button: Button = $PopupPanel/VBoxContainer/ButtonContainer/StartButton

# Selection state
var selected_character: String = ""
var selected_map: String = "forest_arena"  # Default to forest arena
var selected_tier: int = 1

# Character data (loaded from CharacterTypeDict)
var character_types: Dictionary = {}

# Theme
var main_theme: MainTheme

func _ready() -> void:
	# Configure modal properties
	modal_type = UIManager.ModalType.CHARACTER_SCREEN
	dims_background = true
	pauses_game = false
	closeable_with_escape = true
	keyboard_navigable = true
	default_focus_control = knight_button

	super._ready()  # Initialize BaseModal

	Logger.info("RunSetupModal initialized", "ui")
	_load_character_types()
	_load_theme_from_manager()
	_setup_ui_elements()
	_connect_button_signals()
	_update_start_button_state()

func open_modal(data: Dictionary = {}) -> void:
	"""Override to set mouse filter after UIManager configures the modal."""
	super.open_modal(data)

	# Allow clicks to reach our buttons
	mouse_filter = Control.MOUSE_FILTER_PASS
	Logger.debug("Modal mouse_filter set to PASS, PopupPanel mouse_filter: %d" % $PopupPanel.mouse_filter, "ui")

func _load_character_types() -> void:
	"""Load character types from data file."""
	var character_data = load("res://data/core/character-types.tres")
	if character_data and character_data.character_types:
		character_types = character_data.character_types
		Logger.info("Loaded %d character types" % character_types.size(), "ui")
	else:
		Logger.error("Failed to load character-types.tres", "ui")


func _setup_ui_elements() -> void:
	"""Configure UI elements with theme styling."""

	# Apply MainTheme styling
	if main_theme:
		main_theme.apply_label_theme(title_label, "title")
		main_theme.apply_label_theme(character_info_label, "")
		main_theme.apply_label_theme(tier_info_label, "")
		Logger.debug("Applied MainTheme styling to RunSetupModal", "ui")

	# Set default selections (Tier 1 and Forest Arena)
	selected_tier = 1
	selected_map = "forest_arena"
	_update_tier_selection_ui()
	_update_map_selection_ui()

	# Disable Start button until character is selected
	if start_button:
		start_button.disabled = true

func _connect_button_signals() -> void:
	"""Connect button press signals to handlers."""

	# Character selection - use enhanced_pressed for EnhancedButton
	if knight_button:
		knight_button.enhanced_pressed.connect(_on_knight_selected)
	if ranger_button:
		ranger_button.enhanced_pressed.connect(_on_ranger_selected)

	# Map selection
	if arena_button:
		arena_button.enhanced_pressed.connect(_on_arena_selected)

	# Tier selection
	if tier1_button:
		tier1_button.enhanced_pressed.connect(_on_tier1_selected)
	if tier2_button:
		tier2_button.enhanced_pressed.connect(_on_tier2_selected)
	if tier3_button:
		tier3_button.enhanced_pressed.connect(_on_tier3_selected)

	# Action buttons
	if cancel_button:
		cancel_button.enhanced_pressed.connect(_on_cancel_pressed)
	if start_button:
		start_button.enhanced_pressed.connect(_on_start_pressed)

	Logger.debug("Button signals connected: knight=%s, ranger=%s, start=%s" % [knight_button != null, ranger_button != null, start_button != null], "ui")

# Character Selection Handlers
func _on_knight_selected() -> void:
	selected_character = "knight"
	_update_character_selection_ui()
	Logger.info("Knight selected", "ui")

func _on_ranger_selected() -> void:
	Logger.info("=== RANGER BUTTON CLICKED ===", "ui")
	selected_character = "ranger"
	_update_character_selection_ui()
	Logger.info("Ranger selected", "ui")

func _update_character_selection_ui() -> void:
	"""Update UI to reflect character selection."""
	# Update button visual states (disabled = selected appearance)
	if knight_button:
		knight_button.disabled = (selected_character == "knight")
	if ranger_button:
		ranger_button.disabled = (selected_character == "ranger")

	# Update character info display
	if character_types.has(selected_character):
		var char_type: CharacterType = character_types[selected_character]
		character_info_label.text = "%s\n%s\nHP: %.0f | Damage: %.0f | Speed: %.1f" % [
			char_type.display_name,
			char_type.description,
			char_type.base_hp,
			char_type.base_damage,
			char_type.base_speed
		]
	else:
		character_info_label.text = "Character data not found"

	_update_start_button_state()

# Map Selection Handlers
func _on_arena_selected() -> void:
	selected_map = "forest_arena"
	_update_map_selection_ui()
	Logger.info("Forest Arena selected", "ui")
	_update_start_button_state()

func _update_map_selection_ui() -> void:
	"""Update UI to reflect map selection."""
	# Update button visual state (disabled = selected)
	if arena_button:
		arena_button.disabled = (selected_map == "forest_arena")

# Tier Selection Handlers
func _on_tier1_selected() -> void:
	selected_tier = 1
	_update_tier_selection_ui()
	Logger.info("Tier 1 selected", "ui")

func _on_tier2_selected() -> void:
	selected_tier = 2
	_update_tier_selection_ui()
	Logger.info("Tier 2 selected", "ui")

func _on_tier3_selected() -> void:
	selected_tier = 3
	_update_tier_selection_ui()
	Logger.info("Tier 3 selected", "ui")

func _update_tier_selection_ui() -> void:
	"""Update UI to reflect tier selection."""
	# Update button visual states (disabled = selected)
	if tier1_button:
		tier1_button.disabled = (selected_tier == 1)
	if tier2_button:
		tier2_button.disabled = (selected_tier == 2)
	if tier3_button:
		tier3_button.disabled = (selected_tier == 3)

	# Update tier info text
	match selected_tier:
		1:
			tier_info_label.text = "Normal difficulty - Base Rift Fragments"
		2:
			tier_info_label.text = "Hard difficulty - +10% Rift Fragments"
		3:
			tier_info_label.text = "Expert difficulty - +20% Rift Fragments"

	_update_start_button_state()

# Action Button Handlers
func _on_cancel_pressed() -> void:
	"""Handle Cancel button - close modal."""
	Logger.info("Run setup cancelled", "ui")
	close_modal()

func _on_start_pressed() -> void:
	"""Handle Start button - begin run with selected configuration."""
	if not _validate_selection():
		Logger.warn("Invalid selection - cannot start run", "ui")
		return

	Logger.info("Starting run: %s on %s (Tier %d)" % [selected_character, selected_map, selected_tier], "ui")

	# Close modal first
	close_modal()

	# Start the run in SessionState
	if SessionState:
		SessionState.start_run(selected_character, selected_map, selected_tier)

	# Transition to arena
	if StateManager:
		StateManager.go_to_arena({"character": selected_character, "map": selected_map, "tier": selected_tier})

func _update_start_button_state() -> void:
	"""Enable/disable Start button based on selection completeness."""
	if not start_button:
		return  # Button not ready yet

	var can_start = _validate_selection()
	start_button.disabled = not can_start
	Logger.debug("Start button state: can_start=%s, character='%s', map='%s', tier=%d" % [can_start, selected_character, selected_map, selected_tier], "ui")

func _validate_selection() -> bool:
	"""Check if all required selections are made."""
	var valid = not selected_character.is_empty() and not selected_map.is_empty() and selected_tier > 0
	Logger.debug("Validation: character='%s', map='%s', tier=%d, valid=%s" % [selected_character, selected_map, selected_tier, valid], "ui")
	return valid

func _load_theme_from_manager() -> void:
	"""Load theme from ThemeManager."""
	if ThemeManager:
		main_theme = ThemeManager.get_theme()
		Logger.debug("MainTheme loaded for RunSetupModal", "ui")
	else:
		Logger.error("ThemeManager autoload missing", "ui")
