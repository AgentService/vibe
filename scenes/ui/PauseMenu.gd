extends CanvasLayer

## Basic pause menu with Escape key toggle functionality.
## Pauses the game and shows basic menu options.

class_name PauseMenu

@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var options_button: Button = $CenterContainer/VBoxContainer/OptionsButton  
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	# Ensure this menu works even when game is paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	
	# Connect button signals
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	Logger.info("PauseMenu initialized", "ui")

# Input is now handled by Arena to avoid conflicts with card selection

func toggle_pause() -> void:
	visible = !visible
	PauseManager.pause_game(visible)
	
	if visible:
		Logger.info("Game paused via Escape key", "ui")
		# Focus the resume button for gamepad/keyboard navigation
		resume_button.grab_focus()
	else:
		Logger.info("Game resumed via Escape key", "ui")

func _on_resume_pressed() -> void:
	Logger.info("Resume button pressed", "ui")
	toggle_pause()

func _on_quit_pressed() -> void:
	Logger.info("Quit to main menu pressed", "ui") 
	# Resume game first, then return to main menu
	PauseManager.pause_game(false)
	
	# Request transition back to main menu
	EventBus.request_enter_map.emit({
		"map_id": "main_menu",
		"source": "pause_menu_quit"
	})
