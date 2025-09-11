extends "res://scripts/ui_framework/BaseModal.gd"

## Results screen displayed after a run ends (death or victory).
## Shows as a modal overlay over the arena background (dimmed).
## Provides options to revive (placeholder), restart, return to hideout, or main menu.
## 
## Integrated with UIManager for unified modal behavior and StateManager for scene transitions.

# Modal configuration set in _ready() - Results screen is a system modal that doesn't pause

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
	# Configure modal properties
	modal_type = UIManager.ModalType.RESULTS_SCREEN
	dims_background = false  # We manage our own background dimming
	pauses_game = true       # Pause the game when results are shown
	closeable_with_escape = false  # Force user to make a choice
	keyboard_navigable = true
	default_focus_control = restart_button
	
	super._ready()  # Initialize BaseModal
	
	# Connect to session manager signals for debugging
	if SessionManager:
		SessionManager.session_reset_started.connect(_on_session_reset_started)
		SessionManager.session_reset_completed.connect(_on_session_reset_completed)
	
	Logger.info("ResultsScreen modal initialized", "ui")
	_setup_ui_elements()
	_connect_button_signals()

func _initialize_modal_content(data: Dictionary) -> void:
	"""Initialize modal with run result data - defer until nodes are ready"""
	if data.has("run_result"):
		# Defer the display until @onready nodes are available
		call_deferred("display_run_results", data.run_result)
	else:
		Logger.warn("ResultsScreen initialized without run_result data", "ui")

func _setup_ui_elements() -> void:
	"""Configure UI elements with modal theme styling."""
	
	# Hide our own background since UIManager handles dimming
	background.visible = false
	
	# Ensure popup panel is visible and properly positioned
	popup_panel.visible = true
	popup_panel.modulate = Color.WHITE  # Ensure not transparent
	
	# Apply modal theme to the popup panel and controls
	apply_modal_theme()
	
	Logger.info("ResultsScreen UI setup: popup_panel visible=%s, modulate=%s" % [popup_panel.visible, popup_panel.modulate], "ui")
	
	# Configure title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Configure stats display
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Configure buttons with consistent sizing
	var button_min_size = Vector2(160, 45)
	
	# Revive button (disabled placeholder) - would respawn in current run state
	revive_button.text = "💖 Revive Here (Coming Soon)"
	revive_button.custom_minimum_size = Vector2(320, 50)
	revive_button.disabled = true
	
	# Action buttons
	restart_button.text = "🔄 Restart Fresh"  # Make it clear this resets everything
	restart_button.custom_minimum_size = button_min_size
	restart_button.focus_mode = Control.FOCUS_ALL  # Ensure focusable
	restart_button.disabled = false  # Ensure enabled
	
	hideout_button.text = "🏠 Return to Hideout"
	hideout_button.custom_minimum_size = button_min_size
	hideout_button.focus_mode = Control.FOCUS_ALL  # Ensure focusable
	hideout_button.disabled = false  # Ensure enabled
	
	menu_button.text = "📱 Return to Menu"
	menu_button.custom_minimum_size = Vector2(200, 45)
	menu_button.focus_mode = Control.FOCUS_ALL  # Ensure focusable
	menu_button.disabled = false  # Ensure enabled
	
	Logger.debug("ResultsScreen UI elements configured with modal theme", "ui")

func _connect_button_signals() -> void:
	"""Connect button press signals to handler functions."""
	
	# Note: revive_button is disabled, no signal connection needed yet
	restart_button.pressed.connect(_on_restart_pressed)
	hideout_button.pressed.connect(_on_hideout_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

func _on_restart_pressed() -> void:
	"""Handle Restart Run button press - resets entire session and starts fresh."""
	Logger.info("🔄 RESTART BUTTON PRESSED - Signal received!", "ui")
	Logger.info("Restart run requested from results screen (full session reset)", "ui")
	
	# Close modal first
	close_modal()
	
	# Debug: Show what's getting reset
	Logger.info("RESTART DEBUG: preserve_progression=false, forcing fresh start", "ui")
	
	# Start a completely fresh run with session reset (level, XP, upgrades all reset)
	var arena_id = run_result.get("arena_id", StringName("arena"))
	StateManager.start_run(arena_id, {
		"source": "results_restart",
		"preserve_progression": false,  # CRITICAL: Force full reset
		"reset_type": "fresh_start"
	})

func _on_hideout_pressed() -> void:
	"""Handle Return to Hideout button press."""
	Logger.info("Return to hideout requested from results screen", "ui")
	
	# Close modal first
	close_modal()
	
	StateManager.go_to_hideout({"source": "results_screen"})

func _on_menu_pressed() -> void:
	"""Handle Return to Menu button press."""
	Logger.info("Return to menu requested from results screen", "ui")
	
	# Close modal first
	close_modal()
	
	StateManager.return_to_menu(StringName("user_request"), {"source": "results_screen"})

func _on_revive_pressed() -> void:
	"""Handle Revive button press - respawn in current run state without resetting progress."""
	Logger.info("Revive requested from results screen", "ui")
	
	# Close modal first
	close_modal()
	
	# TODO: Implement revive system
	# This should:
	# - Consume revive currency/items  
	# - Reset player health to full
	# - Reset player position to safe location
	# - Resume the current run (keep level, XP, upgrades, enemy spawns)
	# - Track revive usage for balance
	# 
	# For now, just unpause and let player continue (placeholder)
	Logger.warn("Revive system not implemented yet - resuming game", "ui")

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
			revive_button.text = "💖 Revive Here (Coming Soon)"
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

# Debug signal handlers for session reset monitoring
func _on_session_reset_started(reason: SessionManager.ResetReason, context: Dictionary) -> void:
	"""Monitor session reset start"""
	var reason_name = SessionManager.ResetReason.keys()[reason]
	Logger.info("🔄 SESSION RESET STARTED: %s with context: %s" % [reason_name, context], "ui")

func _on_session_reset_completed(reason: SessionManager.ResetReason, duration_ms: float) -> void:
	"""Monitor session reset completion"""
	var reason_name = SessionManager.ResetReason.keys()[reason]
	Logger.info("✅ SESSION RESET COMPLETED: %s in %.1fms" % [reason_name, duration_ms], "ui")
