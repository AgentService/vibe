extends Control

## MainMenu - Simplified placeholder for Task 04a cleanup.
## TODO: New progression - Will rebuild with MEGABONK-style modal flow (Task 04)
## Future flow: SHOW MODAL > SELECT CHAR > PLAY (all in main menu scene)

@onready var title_label: Label = $BackgroundPanel/CenterContainer/MenuContainer/TitleLabel
@onready var start_game_button: Button = $BackgroundPanel/CenterContainer/MenuContainer/StartGameButton
@onready var options_button: Button = $BackgroundPanel/CenterContainer/MenuContainer/OptionsButton
@onready var quit_button: Button = $BackgroundPanel/CenterContainer/MenuContainer/QuitButton

# Theme system
var main_theme: MainTheme

func _ready() -> void:
	Logger.info("MainMenu initialized (simplified)", "ui")

	# Load theme from ThemeManager
	_load_theme_from_manager()

	_setup_ui_elements()
	_connect_button_signals()

	# Register for theme changes
	if ThemeManager:
		ThemeManager.add_theme_listener(_on_theme_changed)

	# Set focus to Start Game button
	start_game_button.grab_focus()

func _setup_ui_elements() -> void:
	"""Configure UI elements with MainTheme styling."""

	# Configure title
	title_label.text = "VIBE ROGUELIKE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Apply MainTheme styling
	if main_theme:
		main_theme.apply_label_theme(title_label, "title")
		title_label.add_theme_font_size_override("font_size", main_theme.font_size_huge)
		Logger.debug("Applied MainTheme styling to MainMenu", "ui")
	else:
		Logger.warn("MainTheme not available", "ui")

func _connect_button_signals() -> void:
	"""Connect button press signals to handler functions."""

	start_game_button.pressed.connect(_on_start_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_game_pressed() -> void:
	"""Handle Start Game button - show placeholder message."""

	Logger.info("Start Game pressed", "ui")

	# TODO: New progression - Will show character select modal here (Task 04)
	_show_placeholder_message("Character selection coming soon!\nUse debug mode (arena start_mode) to play.")

func _on_options_pressed() -> void:
	"""Handle Options button press - show placeholder."""

	Logger.info("Options pressed", "ui")
	# TODO: New progression - Will implement settings modal (Task 04)
	_show_placeholder_message("Settings coming soon!")

func _on_quit_pressed() -> void:
	"""Handle Quit button press - exit game."""

	Logger.info("Quit pressed", "ui")
	get_tree().quit()

func _show_placeholder_message(message: String) -> void:
	"""Show a simple placeholder message (temporary)."""
	Logger.info("Placeholder: %s" % message, "ui")
	# TODO: Show actual modal when UI system is ready

func _load_theme_from_manager() -> void:
	"""Load theme from ThemeManager autoload."""
	if ThemeManager and ThemeManager.current_theme:
		main_theme = ThemeManager.current_theme
		Logger.debug("MainTheme loaded from ThemeManager", "ui")
	else:
		Logger.warn("ThemeManager or current_theme not available", "ui")

func _on_theme_changed() -> void:
	"""Handle theme changes from ThemeManager."""
	_load_theme_from_manager()
	_setup_ui_elements()
