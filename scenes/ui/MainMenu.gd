extends Control

## MainMenu - Entry point for the game with navigation to character selection.
## Provides basic menu options: Start Game, Options, and Quit.

@onready var title_label: Label = $MenuContainer/TitleLabel
@onready var start_game_button: Button = $MenuContainer/StartGameButton
@onready var options_button: Button = $MenuContainer/OptionsButton
@onready var quit_button: Button = $MenuContainer/QuitButton

func _ready() -> void:
	Logger.info("MainMenu initialized", "mainmenu")
	_setup_ui_elements()
	_connect_button_signals()
	
	# Set focus to start game button for keyboard navigation
	start_game_button.grab_focus()

func _setup_ui_elements() -> void:
	"""Configure UI elements with appropriate text and styling."""
	
	# Configure title
	title_label.text = "VIBE ROGUELIKE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	
	# Configure buttons
	start_game_button.text = "Start Game"
	options_button.text = "Options"
	quit_button.text = "Quit"
	
	# Set button sizes for consistency
	var button_min_size = Vector2(200, 50)
	start_game_button.custom_minimum_size = button_min_size
	options_button.custom_minimum_size = button_min_size
	quit_button.custom_minimum_size = button_min_size

func _connect_button_signals() -> void:
	"""Connect button press signals to handler functions."""
	
	start_game_button.pressed.connect(_on_start_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_game_pressed() -> void:
	"""Handle Start Game button press - navigate to character selection."""
	
	Logger.info("Start Game pressed", "mainmenu")
	
	# Request scene transition to character selection
	EventBus.request_enter_map.emit({
		"map_id": "character_select",
		"source": "main_menu"
	})

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