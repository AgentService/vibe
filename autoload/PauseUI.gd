extends CanvasLayer

## PauseUI autoload - persistent pause overlay that works across all scenes.
## Uses component-based PauseMenu scene with MainTheme integration.
## Subscribes to PauseManager events and checks StateManager for pause permissions.

# Scene references
const PAUSE_MENU_SCENE = preload("res://scenes/ui/PauseMenu.tscn")

# UI components
var pause_overlay: ColorRect
var pause_menu_instance: Control
var title_label: Label
var resume_button: Button
var settings_button: Button
var hideout_button: Button
var menu_button: Button

# Theme system
var main_theme: MainTheme

func _ready() -> void:
	# Set up persistent CanvasLayer
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100  # High layer to appear above everything
	
	# Load theme from ThemeManager
	_load_theme_from_manager()
	
	_create_pause_ui()
	_connect_signals()
	_setup_initial_state()
	
	# Register for theme changes
	if ThemeManager:
		ThemeManager.add_theme_listener(_on_theme_changed)
	
	Logger.info("PauseUI initialized with component-based scene", "ui")

func _create_pause_ui() -> void:
	"""Create the pause menu using component-based scene."""
	
	# Semi-transparent overlay for input blocking
	pause_overlay = ColorRect.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.color = Color(0, 0, 0, 0.7)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input to game
	pause_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pause_overlay)
	
	# Instantiate component-based pause menu scene
	pause_menu_instance = PAUSE_MENU_SCENE.instantiate()
	pause_menu_instance.name = "PauseMenuInstance"
	pause_overlay.add_child(pause_menu_instance)
	
	# Get references to UI components
	_get_component_references()
	
	# Apply MainTheme to non-component elements
	_apply_main_theme()
	
	Logger.debug("Component-based pause menu created", "ui")

func _connect_signals() -> void:
	"""Connect button signals and system events."""
	
	# Verify button references exist before connecting
	if not resume_button or not settings_button or not hideout_button or not menu_button:
		Logger.error("Cannot connect signals - button references missing", "ui")
		return
	
	# Button connections
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	hideout_button.pressed.connect(_on_hideout_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	
	# System connections
	EventBus.game_paused_changed.connect(_on_game_paused_changed)
	StateManager.state_changed.connect(_on_state_changed)
	
	Logger.debug("Pause menu signals connected successfully", "ui")

func _setup_initial_state() -> void:
	"""Set up initial UI state."""
	pause_overlay.visible = false

## PUBLIC API METHODS

# toggle_pause() removed - GameOrchestrator now calls PauseManager directly

func show_overlay() -> void:
	"""Show pause overlay."""
	pause_overlay.visible = true
	_update_menu_for_current_state()
	resume_button.grab_focus()

func hide_overlay() -> void:
	"""Hide pause overlay."""
	pause_overlay.visible = false

# ESC handling removed - now centralized in GameOrchestrator

func _on_game_paused_changed(payload) -> void:
	"""Handle pause state changes from PauseManager."""
	var is_paused = payload.is_paused if payload else false
	
	pause_overlay.visible = is_paused
	
	if is_paused:
		_update_menu_for_current_state()
		resume_button.grab_focus()  # Focus on resume for keyboard navigation
		Logger.debug("PauseUI shown", "ui")
	else:
		Logger.debug("PauseUI hidden", "ui")

func _update_menu_for_current_state() -> void:
	"""Update menu buttons based on current game state."""
	var current_state = StateManager.get_current_state()
	
	# Hideout button only shown in arena
	hideout_button.visible = (current_state == StateManager.State.ARENA)
	
	# Settings button always visible for now
	settings_button.visible = true
	
	# Menu button always visible
	menu_button.visible = true

func _on_state_changed(_prev: StateManager.State, _next: StateManager.State, _context: Dictionary) -> void:
	"""Handle state changes to update menu availability."""
	# If pause is no longer allowed, unpause automatically
	if not StateManager.is_pause_allowed() and PauseManager.is_paused():
		PauseManager.pause_game(false)
		Logger.info("Auto-unpaused due to state change to %s" % StateManager.get_current_state_string(), "ui")

## BUTTON HANDLERS

func _on_resume_pressed() -> void:
	"""Handle Resume button press."""
	Logger.info("Resume requested from pause menu", "ui")
	PauseManager.pause_game(false)

func _on_settings_pressed() -> void:
	"""Handle Settings button press."""
	Logger.info("Settings requested from pause menu (placeholder)", "ui")
	# TODO: Implement settings menu
	_show_placeholder_message("Settings menu not yet implemented!")

func _on_hideout_pressed() -> void:
	"""Handle Return to Hideout button press."""
	Logger.info("Return to hideout requested from pause menu", "ui")
	
	# Unpause first
	PauseManager.pause_game(false)
	
	# Return to hideout via StateManager
	StateManager.go_to_hideout({"source": "pause_menu"})

func _on_menu_pressed() -> void:
	"""Handle Return to Menu button press."""
	Logger.info("Return to menu requested from pause menu", "ui")
	
	# Unpause first
	PauseManager.pause_game(false)
	
	# Return to menu via StateManager
	StateManager.return_to_menu(StringName("pause_menu"), {"source": "pause_menu"})

func _get_component_references() -> void:
	"""Get references to UI components from instantiated scene."""
	if not pause_menu_instance:
		Logger.error("Pause menu instance not found", "ui")
		return
	
	# Get component references with error checking
	title_label = pause_menu_instance.get_node("PausePanel/MenuVBox/TitleLabel")
	resume_button = pause_menu_instance.get_node("PausePanel/MenuVBox/ResumeButton")
	settings_button = pause_menu_instance.get_node("PausePanel/MenuVBox/SettingsButton")
	hideout_button = pause_menu_instance.get_node("PausePanel/MenuVBox/HideoutButton")
	menu_button = pause_menu_instance.get_node("PausePanel/MenuVBox/MenuButton")
	
	# Verify all components were found
	var missing_components = []
	if not title_label: missing_components.append("TitleLabel")
	if not resume_button: missing_components.append("ResumeButton")
	if not settings_button: missing_components.append("SettingsButton")
	if not hideout_button: missing_components.append("HideoutButton")
	if not menu_button: missing_components.append("MenuButton")
	
	if not missing_components.is_empty():
		Logger.error("Missing pause menu components: %s" % missing_components, "ui")
		return
	
	Logger.debug("Component references obtained successfully", "ui")

func _load_theme_from_manager() -> void:
	"""Load theme from ThemeManager."""
	if ThemeManager:
		main_theme = ThemeManager.get_theme()
		Logger.debug("MainTheme loaded for PauseUI", "ui")
	else:
		Logger.error("ThemeManager autoload missing - critical UI dependency", "ui")

func _apply_main_theme() -> void:
	"""Apply MainTheme to non-component elements."""
	if not main_theme or not title_label:
		return
	
	# Apply MainTheme to title label (EnhancedButton components handle themselves)
	main_theme.apply_label_theme(title_label, "title")
	title_label.add_theme_font_size_override("font_size", main_theme.font_size_huge)
	
	Logger.debug("MainTheme applied to PauseUI components", "ui")

func _on_theme_changed(new_theme: MainTheme) -> void:
	"""Handle theme changes from ThemeManager."""
	main_theme = new_theme
	_apply_main_theme()
	Logger.debug("PauseUI updated with new theme", "ui")

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

func _exit_tree() -> void:
	"""Clean up theme listener when autoload is removed."""
	if ThemeManager:
		ThemeManager.remove_theme_listener(_on_theme_changed)
