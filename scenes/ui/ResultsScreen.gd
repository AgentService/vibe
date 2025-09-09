extends Control

## Results screen displayed after a run ends (death or victory).
## Shows run summary and provides options to restart, return to hideout, or main menu.

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var stats_label: Label = $VBoxContainer/StatsContainer/StatsLabel
@onready var restart_button: Button = $VBoxContainer/ButtonContainer/RestartButton
@onready var hideout_button: Button = $VBoxContainer/ButtonContainer/HideoutButton
@onready var menu_button: Button = $VBoxContainer/ButtonContainer/MenuButton

var run_result: Dictionary = {}

func _ready() -> void:
	Logger.info("ResultsScreen initialized", "ui")
	_setup_ui_elements()
	_connect_button_signals()

func _setup_ui_elements() -> void:
	"""Configure UI elements with default styling."""
	
	# Configure title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	
	# Configure stats display
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats_label.add_theme_font_size_override("font_size", 16)
	
	# Configure buttons with consistent sizing
	var button_min_size = Vector2(200, 50)
	restart_button.text = "Restart Run"
	restart_button.custom_minimum_size = button_min_size
	
	hideout_button.text = "Return to Hideout"
	hideout_button.custom_minimum_size = button_min_size
	
	menu_button.text = "Return to Menu"
	menu_button.custom_minimum_size = button_min_size
	
	# Focus on restart by default
	restart_button.grab_focus()

func _connect_button_signals() -> void:
	"""Connect button press signals to handler functions."""
	
	restart_button.pressed.connect(_on_restart_pressed)
	hideout_button.pressed.connect(_on_hideout_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

func _on_restart_pressed() -> void:
	"""Handle Restart Run button press."""
	Logger.info("Restart run requested from results screen", "ui")
	
	# Start a new run with the same arena
	var arena_id = run_result.get("arena_id", StringName("arena"))
	StateManager.start_run(arena_id, {"source": "results_restart"})

func _on_hideout_pressed() -> void:
	"""Handle Return to Hideout button press."""
	Logger.info("Return to hideout requested from results screen", "ui")
	
	StateManager.go_to_hideout({"source": "results_screen"})

func _on_menu_pressed() -> void:
	"""Handle Return to Menu button press."""
	Logger.info("Return to menu requested from results screen", "ui")
	
	StateManager.return_to_menu(StringName("user_request"), {"source": "results_screen"})

func display_run_results(result: Dictionary) -> void:
	"""Display the run results data in the UI."""
	run_result = result
	
	# Update title based on result type
	var result_type = result.get("result_type", "death")
	match result_type:
		"death":
			title_label.text = "RUN FAILED"
			title_label.modulate = Color.RED
		"victory":
			title_label.text = "RUN COMPLETE!"
			title_label.modulate = Color.GREEN
		_:
			title_label.text = "RUN ENDED"
			title_label.modulate = Color.WHITE
	
	# Build stats summary
	var stats_text = ""
	
	# Basic run stats
	var time_survived = result.get("time_survived", 0.0)
	var minutes = int(time_survived / 60)
	var seconds = int(time_survived) % 60
	stats_text += "Time Survived: %d:%02d\n" % [minutes, seconds]
	
	var level_reached = result.get("level_reached", 1)
	stats_text += "Level Reached: %d\n" % level_reached
	
	var enemies_killed = result.get("enemies_killed", 0)
	stats_text += "Enemies Defeated: %d\n" % enemies_killed
	
	var damage_dealt = result.get("damage_dealt", 0)
	stats_text += "Total Damage: %d\n" % damage_dealt
	
	var damage_taken = result.get("damage_taken", 0)
	stats_text += "Damage Taken: %d\n" % damage_taken
	
	# XP and progression
	var xp_gained = result.get("xp_gained", 0)
	stats_text += "XP Gained: %d\n" % xp_gained
	
	# Special achievements or notes
	var death_cause = result.get("death_cause", "")
	if not death_cause.is_empty():
		stats_text += "\nDeath Cause: %s" % death_cause
	
	stats_label.text = stats_text
	
	Logger.info("Displayed run results: %s" % result, "ui")
