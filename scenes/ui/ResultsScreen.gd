extends Control

## Results screen displayed after a run ends (death or victory).
## Shows as a centered popup over the game background (greyed out).
## Provides options to revive (placeholder), restart, return to hideout, or main menu.

@onready var background: ColorRect = $Background
@onready var popup_panel: Panel = $PopupPanel
@onready var title_label: Label = $PopupPanel/VBoxContainer/TitleLabel
@onready var stats_label: Label = $PopupPanel/VBoxContainer/StatsContainer/StatsLabel
@onready var revive_button: Button = $PopupPanel/VBoxContainer/ButtonContainer/ReviveButton
@onready var restart_button: Button = $PopupPanel/VBoxContainer/ButtonContainer/ButtonRow1/RestartButton
@onready var hideout_button: Button = $PopupPanel/VBoxContainer/ButtonContainer/ButtonRow1/HideoutButton
@onready var menu_button: Button = $PopupPanel/VBoxContainer/ButtonContainer/ButtonRow2/MenuButton

var run_result: Dictionary = {}

func _ready() -> void:
	Logger.info("ResultsScreen initialized", "ui")
	_setup_ui_elements()
	_connect_button_signals()

func _setup_ui_elements() -> void:
	"""Configure UI elements with default styling."""
	
	# Configure popup background overlay (dark semi-transparent)
	background.color = Color(0.0, 0.0, 0.0, 0.7)
	
	# Configure popup panel styling
	popup_panel.add_theme_color_override("panel", Color(0.2, 0.2, 0.2, 0.95))
	
	# Configure title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Configure stats display
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 16)
	stats_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Configure buttons with consistent sizing
	var button_min_size = Vector2(160, 45)
	
	# Revive button (disabled placeholder)
	revive_button.text = "🔄 Revive (Coming Soon)"
	revive_button.custom_minimum_size = Vector2(320, 50)
	revive_button.disabled = true
	revive_button.add_theme_color_override("font_color_disabled", Color(0.6, 0.6, 0.6))
	
	# Action buttons
	restart_button.text = "🔄 Restart Run"
	restart_button.custom_minimum_size = button_min_size
	
	hideout_button.text = "🏠 Return to Hideout"
	hideout_button.custom_minimum_size = button_min_size
	
	menu_button.text = "📱 Return to Menu"
	menu_button.custom_minimum_size = Vector2(200, 45)
	
	# Focus on restart by default (since revive is disabled)
	restart_button.grab_focus()

func _connect_button_signals() -> void:
	"""Connect button press signals to handler functions."""
	
	# Note: revive_button is disabled, no signal connection needed yet
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

func _on_revive_pressed() -> void:
	"""Handle Revive button press (placeholder for future implementation)."""
	Logger.info("Revive requested from results screen (not implemented yet)", "ui")
	
	# TODO: Implement revive system
	# This could:
	# - Consume revive currency/items
	# - Reset player health and position
	# - Resume the current run
	# - Track revive usage for balance

func display_run_results(result: Dictionary) -> void:
	"""Display the run results data in the UI."""
	run_result = result
	
	# Update title based on result type
	var result_type = result.get("result_type", "death")
	match result_type:
		"death":
			title_label.text = "💀 RUN FAILED"
			title_label.modulate = Color(1.0, 0.4, 0.4)  # Light red
			# For death, show revive option more prominently
			revive_button.text = "💖 Revive (Coming Soon)"
		"victory":
			title_label.text = "🎉 RUN COMPLETE!"
			title_label.modulate = Color(0.4, 1.0, 0.4)  # Light green
			# Hide revive button for victories
			revive_button.visible = false
		_:
			title_label.text = "📊 RUN ENDED"
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
