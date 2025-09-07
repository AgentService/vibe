extends CanvasLayer

## PauseUI autoload - persistent pause overlay that works across all scenes.
## Shows pause menu when game is paused and only allows pausing in valid states.
## Subscribes to PauseManager events and checks StateManager for pause permissions.

var pause_overlay: ColorRect
var pause_menu: Control
var resume_button: Button
var settings_button: Button
var hideout_button: Button
var menu_button: Button

func _ready() -> void:
	# Set up persistent CanvasLayer
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100  # High layer to appear above everything
	
	_create_pause_ui()
	_connect_signals()
	_setup_initial_state()
	
	Logger.info("PauseUI initialized as persistent overlay", "ui")

func _create_pause_ui() -> void:
	"""Create the pause menu UI elements."""
	
	# Semi-transparent overlay
	pause_overlay = ColorRect.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.color = Color(0, 0, 0, 0.7)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input to game
	pause_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED  # Allow processing when paused
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pause_overlay)
	
	# Center container for menu
	pause_menu = Control.new()
	pause_menu.name = "PauseMenu"
	pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED  # Allow processing when paused
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_overlay.add_child(pause_menu)
	
	# VBox container for menu items
	var vbox = VBoxContainer.new()
	vbox.name = "MenuVBox"
	vbox.process_mode = Node.PROCESS_MODE_WHEN_PAUSED  # Allow processing when paused
	vbox.position = Vector2(-100, -150)  # Center the menu
	pause_menu.add_child(vbox)
	
	# Title label
	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "GAME PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)
	
	# Add some spacing
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)
	
	# Resume button
	resume_button = Button.new()
	resume_button.name = "ResumeButton"
	resume_button.text = "Resume"
	resume_button.custom_minimum_size = Vector2(200, 40)
	resume_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED  # Allow processing when paused
	vbox.add_child(resume_button)
	
	# Settings button
	settings_button = Button.new()
	settings_button.name = "SettingsButton"
	settings_button.text = "Settings"
	settings_button.custom_minimum_size = Vector2(200, 40)
	settings_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED  # Allow processing when paused
	vbox.add_child(settings_button)
	
	# Hideout button (only shown in arena)
	hideout_button = Button.new()
	hideout_button.name = "HideoutButton"
	hideout_button.text = "Return to Hideout"
	hideout_button.custom_minimum_size = Vector2(200, 40)
	hideout_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED  # Allow processing when paused
	vbox.add_child(hideout_button)
	
	# Menu button
	menu_button = Button.new()
	menu_button.name = "MenuButton"
	menu_button.text = "Return to Menu"
	menu_button.custom_minimum_size = Vector2(200, 40)
	menu_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED  # Allow processing when paused
	vbox.add_child(menu_button)

func _connect_signals() -> void:
	"""Connect button signals and system events."""
	
	# Button connections
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	hideout_button.pressed.connect(_on_hideout_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	
	# System connections
	EventBus.game_paused_changed.connect(_on_game_paused_changed)
	StateManager.state_changed.connect(_on_state_changed)

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

func _on_state_changed(prev: StateManager.State, next: StateManager.State, context: Dictionary) -> void:
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
