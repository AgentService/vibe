extends "res://scripts/ui_framework/BaseModal.gd"

## Results screen displayed after a run ends (death or victory).
## Shows as a modal overlay using BaseModal foundation and MainTheme styling.
## Provides options to revive (placeholder), restart, return to hideout, or main menu.
## 
## Integrated with UIManager for modal behavior and MainTheme for consistent styling.

# Modal configuration set in _ready() - Results screen is a system modal that doesn't pause

@onready var background: ColorRect = $Background
@onready var popup_panel: Panel = $PopupPanel
@onready var title_label: Label = $PopupPanel/VBoxContainer/TitleLabel
@onready var stats_label: Label = $PopupPanel/VBoxContainer/StatsContainer/StatsLabel
@onready var menu_button: Button = $PopupPanel/VBoxContainer/ButtonContainer/MenuButton

var run_result: Dictionary = {}
var main_theme: MainTheme

func _ready() -> void:
	# Configure modal properties
	modal_type = UIManager.ModalType.RESULTS_SCREEN
	dims_background = false  # We manage our own background dimming
	pauses_game = true       # Pause the game when results are shown
	closeable_with_escape = false  # Force user to make a choice
	keyboard_navigable = true
	default_focus_control = menu_button
	
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
	# Load theme from ThemeManager
	_load_theme_from_manager()
	
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

	# Apply MainTheme styling to the popup panel and controls
	_apply_main_theme()

	Logger.info("ResultsScreen UI setup: popup_panel visible=%s, modulate=%s" % [popup_panel.visible, popup_panel.modulate], "ui")

	# Configure title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Configure stats display
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Configure menu button
	menu_button.text = "📱 Return to Menu"
	menu_button.custom_minimum_size = Vector2(200, 45)
	menu_button.focus_mode = Control.FOCUS_ALL
	menu_button.disabled = false

	Logger.debug("ResultsScreen UI elements configured with MainTheme", "ui")

func _connect_button_signals() -> void:
	"""Connect button press signals to handler functions."""
	menu_button.pressed.connect(_on_menu_pressed)

func _on_menu_pressed() -> void:
	"""Handle Return to Menu button press."""
	Logger.info("Return to menu requested from results screen", "ui")

	# Close modal first
	close_modal()

	StateManager.return_to_menu(StringName("user_request"), {"source": "results_screen"})

func display_run_results(result: Dictionary) -> void:
	"""Display the run results data in the UI."""
	run_result = result

	# Update title based on result type
	var result_type = result.get("result_type", "death")
	match result_type:
		"death":
			title_label.text = "💀 RUN FAILED"
			title_label.modulate = Color(1.0, 0.4, 0.4)  # Light red
		"victory":
			title_label.text = "🎉 RUN COMPLETE!"
			title_label.modulate = Color(0.4, 1.0, 0.4)  # Light green
		_:
			title_label.text = "📊 RUN ENDED"
			title_label.modulate = Color.WHITE

	# Build stats summary from SessionState final stats
	var stats_text = ""

	# Character & Map info
	var character_id = result.get("character_id", "Unknown")
	var map_id = result.get("map_id", "Unknown")
	var tier = result.get("tier", 1)
	stats_text += "Character: %s | Map: %s (Tier %d)\n" % [character_id, map_id, tier]
	stats_text += "\n"

	# Time & Level
	var time_survived = result.get("time_survived", 0.0)
	var minutes = int(time_survived / 60)
	var seconds = int(time_survived) % 60
	stats_text += "⏱️ Time Survived: %d:%02d\n" % [minutes, seconds]

	var level_reached = result.get("level_reached", 1)
	stats_text += "📊 Level Reached: %d\n" % level_reached

	var stage_reached = result.get("stage_reached", 1)
	stats_text += "🏆 Stage Reached: %d\n" % stage_reached
	stats_text += "\n"

	# Combat Stats
	var kills = result.get("kills", 0)
	stats_text += "⚔️ Enemies Killed: %d\n" % kills

	var damage_dealt = result.get("damage_dealt", 0)
	stats_text += "💥 Damage Dealt: %s\n" % _format_number(damage_dealt)

	# Boss & Swarm Progress
	var boss_killed = result.get("boss_killed", false)
	if boss_killed:
		var boss_time = result.get("boss_kill_time", 0.0)
		stats_text += "👑 Boss Defeated: %.1fs\n" % boss_time

	var swarm_entered = result.get("final_swarm_entered", false)
	if swarm_entered:
		var swarm_time = result.get("final_swarm_survival_time", 0.0)
		stats_text += "🌀 Final Swarm: Survived %.1fs\n" % swarm_time

	stats_text += "\n"

	# Rewards
	var rift_fragments = result.get("rift_fragments_earned", 0)
	stats_text += "💎 Rift Fragments Earned: %d\n" % rift_fragments

	# Items & Skills collected (if any)
	var collected_items = result.get("collected_items", [])
	if not collected_items.is_empty():
		stats_text += "\n📦 Items Collected: %d\n" % collected_items.size()

	var chosen_skills = result.get("chosen_skills", [])
	if not chosen_skills.is_empty():
		stats_text += "✨ Skills Chosen: %d\n" % chosen_skills.size()

	# Special achievements or notes
	var death_cause = result.get("death_cause", "")
	if not death_cause.is_empty():
		stats_text += "\n💀 Death Cause: %s" % death_cause

	stats_label.text = stats_text

	Logger.info("Displayed run results: %s" % result, "ui")

	# Reapply theme after updating content
	if main_theme:
		_apply_main_theme()

## Helper function to format large numbers with commas
func _format_number(num: int) -> String:
	var num_str = str(num)
	var result = ""
	var count = 0

	# Add commas from right to left
	for i in range(num_str.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = num_str[i] + result
		count += 1

	return result

# Debug signal handlers for session reset monitoring
func _on_session_reset_started(reason: SessionManager.ResetReason, context: Dictionary) -> void:
	"""Monitor session reset start"""
	var reason_name = SessionManager.ResetReason.keys()[reason]
	Logger.info("🔄 SESSION RESET STARTED: %s with context: %s" % [reason_name, context], "ui")

func _on_session_reset_completed(reason: SessionManager.ResetReason, duration_ms: float) -> void:
	"""Monitor session reset completion"""
	var reason_name = SessionManager.ResetReason.keys()[reason]
	Logger.info("✅ SESSION RESET COMPLETED: %s in %.1fms" % [reason_name, duration_ms], "ui")

func _load_theme_from_manager() -> void:
	"""Load theme from ThemeManager."""
	if ThemeManager:
		main_theme = ThemeManager.get_theme()
		Logger.debug("MainTheme loaded for ResultsScreen", "ui")
	else:
		Logger.error("ThemeManager autoload missing - critical UI framework dependency", "ui")

func _apply_main_theme() -> void:
	"""Apply MainTheme styling to ResultsScreen components."""
	if not main_theme:
		Logger.error("MainTheme not available - UI framework dependency missing", "ui")
		return
	
	# Apply MainTheme to labels
	main_theme.apply_label_theme(title_label, "title")
	main_theme.apply_label_theme(stats_label, "")
	
	# EnhancedButton components auto-apply theme via their button_variant settings
	# ThemedPanel component auto-applies theme via auto_theme = true
	
	Logger.debug("MainTheme applied to ResultsScreen components", "ui")
