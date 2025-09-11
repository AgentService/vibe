extends Control

## MainMenu - Entry point for the game with navigation to character selection.
## Uses MainTheme system for consistent styling and enhanced button components.

@onready var title_label: Label = $BackgroundPanel/MenuContainer/TitleLabel
@onready var continue_button: Button = $BackgroundPanel/MenuContainer/ContinueButton
@onready var start_game_button: Button = $BackgroundPanel/MenuContainer/StartGameButton
@onready var options_button: Button = $BackgroundPanel/MenuContainer/OptionsButton
@onready var quit_button: Button = $BackgroundPanel/MenuContainer/QuitButton

# Theme system
var main_theme: MainTheme

func _ready() -> void:
	Logger.info("MainMenu initialized", "mainmenu")
	
	# Load theme from ThemeManager
	_load_theme_from_manager()
	
	_setup_ui_elements()
	_connect_button_signals()
	_update_button_visibility()
	
	# Register for theme changes
	if ThemeManager:
		ThemeManager.add_theme_listener(_on_theme_changed)
	
	# Set focus to appropriate button for keyboard navigation
	_set_initial_focus()

func _setup_ui_elements() -> void:
	"""Configure UI elements with MainTheme styling."""
	
	# Configure title with MainTheme
	title_label.text = "VIBE ROGUELIKE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Apply MainTheme styling to title label
	if main_theme:
		main_theme.apply_label_theme(title_label, "title")
		title_label.add_theme_font_size_override("font_size", main_theme.font_size_huge)
		
		Logger.debug("Applied MainTheme styling to MainMenu", "ui")
	else:
		Logger.error("MainTheme not available - UI framework dependency missing", "ui")
	
	# EnhancedButton components handle their own theming via button_variant
	# ThemedPanel background handles its own theming via auto_theme = true

func _connect_button_signals() -> void:
	"""Connect button press signals to handler functions."""
	
	continue_button.pressed.connect(_on_continue_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_continue_pressed() -> void:
	"""Handle Continue button press - load most recent character and go to hideout."""
	
	Logger.info("Continue pressed", "mainmenu")
	
	# Get most recent character
	var characters = CharacterManager.list_characters()
	if characters.is_empty():
		Logger.warn("No characters available for continue", "mainmenu")
		_show_placeholder_message("No characters found. Please create a new character first.")
		return
	
	# Find most recent character by last_played
	var most_recent_character: CharacterProfile = null
	var most_recent_time: String = ""
	
	for character in characters:
		if most_recent_character == null or character.last_played > most_recent_time:
			most_recent_character = character
			most_recent_time = character.last_played
	
	if not most_recent_character:
		Logger.error("Failed to find most recent character", "mainmenu")
		_show_placeholder_message("Error loading character. Please try again.")
		return
	
	Logger.info("Loading most recent character: %s (Level %d)" % [most_recent_character.name, most_recent_character.level], "mainmenu")
	
	# Load character into CharacterManager as current
	CharacterManager.load_character(most_recent_character.id)
	
	# Load character progression into PlayerProgression
	PlayerProgression.load_from_profile(most_recent_character.progression)
	
	# Prepare context for StateManager
	var context = {
		"character_id": most_recent_character.id,
		"character_data": most_recent_character.get_character_data(),
		"spawn_point": "PlayerSpawnPoint",
		"source": "main_menu_continue"
	}
	
	# Use StateManager to transition to hideout
	StateManager.go_to_hideout(context)

func _on_start_game_pressed() -> void:
	"""Handle New Character button press - navigate to character selection."""
	
	Logger.info("New Character pressed", "mainmenu")
	
	# Use StateManager for proper state transition
	StateManager.go_to_character_select({"source": "main_menu"})

func _on_options_pressed() -> void:
	"""Handle Options button press - placeholder for future options menu."""
	
	Logger.info("Options pressed (placeholder)", "mainmenu")
	
	# TODO: Implement options menu
	# For now, just show a simple notification
	_show_placeholder_message("Options menu not yet implemented!")

func _on_quit_pressed() -> void:
	"""Handle Quit button press - exit the game."""
	
	Logger.info("Quit pressed - exiting game", "mainmenu")
	get_tree().quit()

func _show_placeholder_message(message: String) -> void:
	"""Show a temporary placeholder message for unimplemented features."""
	
	# Create a simple popup
	var popup = AcceptDialog.new()
	popup.dialog_text = message
	popup.title = "Info"
	add_child(popup)
	popup.popup_centered()
	
	# Auto-remove after showing
	popup.confirmed.connect(popup.queue_free)
	popup.canceled.connect(popup.queue_free)

func _update_button_visibility() -> void:
	"""Update button visibility and labels based on available characters."""
	
	var characters = CharacterManager.list_characters()
	var has_characters = not characters.is_empty()
	
	# Show/hide Continue button based on whether characters exist
	continue_button.visible = has_characters
	
	if has_characters:
		Logger.debug("Continue button enabled - %d characters available" % characters.size(), "mainmenu")
	else:
		Logger.debug("Continue button hidden - no characters available", "mainmenu")

func _load_theme_from_manager() -> void:
	"""Load theme from ThemeManager."""
	if ThemeManager:
		main_theme = ThemeManager.get_theme()
		Logger.debug("MainTheme loaded from ThemeManager", "ui")
	else:
		Logger.error("ThemeManager autoload missing - critical UI framework dependency", "ui")

func _on_theme_changed(new_theme: MainTheme) -> void:
	"""Handle theme changes from ThemeManager."""
	main_theme = new_theme
	_setup_ui_elements()
	Logger.debug("MainMenu updated with new theme", "ui")

func _set_initial_focus() -> void:
	"""Set initial focus to the most appropriate button."""
	
	# Focus Continue button if available, otherwise New Character button
	if continue_button.visible:
		continue_button.grab_focus()
	else:
		start_game_button.grab_focus()

func _exit_tree() -> void:
	"""Clean up theme listener when node is removed."""
	if ThemeManager:
		ThemeManager.remove_theme_listener(_on_theme_changed)
