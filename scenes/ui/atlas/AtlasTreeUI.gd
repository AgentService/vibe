extends Control
class_name AtlasTreeUI

## Atlas Tree UI - Tabbed interface for accessing different event type skill trees.
## MVP implementation with functional breach tree and placeholder tabs for other types.

@onready var tab_container: TabContainer = $TabContainer
@onready var points_panel: Control = $PointsPanel
@onready var points_label: Label = $PointsPanel/VBoxContainer/PointsLabel
@onready var reset_button: Button = $PointsPanel/VBoxContainer/ResetButton
@onready var reset_all_button: Button = $PointsPanel/VBoxContainer/ResetAllButton
@onready var close_button: Button = $PointsPanel/VBoxContainer/CloseButton

# Event skill trees
@onready var breach_tree: EventSkillTree = $TabContainer/Breach/BreachTree

var _mastery_system: Node
var _current_event_type: StringName = "breach"
var _reset_mode: bool = false ## Toggle for reset mode

signal atlas_closed()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_find_mastery_system()
	_connect_signals()
	_setup_initial_visibility()

	Logger.info("AtlasTreeUI initialized", "ui")

func _find_mastery_system() -> void:
	"""Locate the EventMasterySystem autoload"""
	_mastery_system = EventMasterySystem.mastery_system_instance
	if _mastery_system:
		Logger.debug("Found EventMasterySystem autoload", "ui")
	else:
		Logger.error("EventMasterySystem autoload not available", "ui")

func _connect_signals() -> void:
	"""Connect UI signals"""
	if tab_container:
		tab_container.tab_changed.connect(_on_tab_changed)
		Logger.debug("Connected tab_container signals", "ui")

	if reset_button:
		reset_button.pressed.connect(_on_reset_button_pressed)
		Logger.debug("Connected AtlasTreeUI reset button", "ui")
	else:
		Logger.warn("AtlasTreeUI reset_button not found", "ui")

	if reset_all_button:
		reset_all_button.pressed.connect(_on_reset_all_button_pressed)
		Logger.debug("Connected AtlasTreeUI reset all button", "ui")
	else:
		Logger.warn("AtlasTreeUI reset_all_button not found", "ui")

	if close_button:
		close_button.pressed.connect(hide_ui)
		Logger.debug("Connected AtlasTreeUI close button", "ui")
	else:
		Logger.warn("AtlasTreeUI close_button not found", "ui")

	# Connect EventBus signals for real-time updates
	EventBus.mastery_points_earned.connect(_on_mastery_points_earned)
	EventBus.passive_allocated.connect(_on_passive_changed)
	EventBus.passive_deallocated.connect(_on_passive_changed)

func _setup_initial_visibility() -> void:
	"""Set initial visibility - start hidden"""
	visible = false
	# Set initial button text and visuals
	if reset_button:
		reset_button.text = "Reset Skillpoints"

	# Ensure reset mode visuals start in normal state
	_update_reset_mode_visuals(false)

func show_ui() -> void:
	"""Show the atlas tree UI"""
	visible = true
	_refresh_points_display()
	Logger.debug("AtlasTreeUI shown", "ui")

func hide_ui() -> void:
	"""Hide the atlas tree UI"""
	visible = false
	atlas_closed.emit()
	Logger.debug("AtlasTreeUI hidden", "ui")

func _on_tab_changed(tab_index: int) -> void:
	"""Handle tab changes to update current event type"""
	var tab_names = ["breach", "ritual", "pack_hunt", "boss"]
	if tab_index >= 0 and tab_index < tab_names.size():
		_current_event_type = tab_names[tab_index]
		_refresh_points_display()
		Logger.debug("Switched to %s tab" % _current_event_type, "ui")

func _on_reset_button_pressed() -> void:
	"""Toggle reset mode or perform full reset"""
	if not _mastery_system:
		Logger.warn("No mastery system available for reset", "ui")
		return

	if not _reset_mode:
		# Enter reset mode
		_reset_mode = true
		reset_button.text = "Exit Reset Mode"
		_set_reset_mode_active(true)
		_update_reset_mode_visuals(true)
		Logger.info("Entered reset mode for %s - click passives to deallocate levels" % _current_event_type, "events")
	else:
		# Exit reset mode
		_reset_mode = false
		reset_button.text = "Reset Skillpoints"
		_set_reset_mode_active(false)
		_update_reset_mode_visuals(false)
		Logger.info("Exited reset mode", "events")

func _on_reset_all_button_pressed() -> void:
	"""Reset all allocated passives in current event tree"""
	if not _mastery_system:
		Logger.warn("No mastery system available for reset all", "ui")
		return

	# Exit reset mode if active
	if _reset_mode:
		_reset_mode = false
		reset_button.text = "Reset Skillpoints"
		_set_reset_mode_active(false)
		_update_reset_mode_visuals(false)

	# Perform complete reset for current event type
	if _current_event_type == "breach" and breach_tree:
		breach_tree.reset_all_skills()
		Logger.info("Reset all skills for %s event type" % _current_event_type, "events")

	# Refresh UI to show changes
	_refresh_points_display()

func _set_reset_mode_active(active: bool) -> void:
	"""Set reset mode state for all event skill trees"""
	if _current_event_type == "breach" and breach_tree:
		breach_tree.set_reset_mode(active)
	# TODO: Add other event type trees when implemented

func _update_reset_mode_visuals(active: bool) -> void:
	"""Update visual indicators for reset mode"""
	if reset_button:
		if active:
			# Make button red/orange when in reset mode
			reset_button.modulate = Color(1.0, 0.6, 0.6, 1.0)
			Logger.debug("Reset button highlighted for reset mode", "ui")
		else:
			# Return to normal color
			reset_button.modulate = Color.WHITE
			Logger.debug("Reset button returned to normal color", "ui")

func _on_mastery_points_earned(event_type: StringName, points: int) -> void:
	"""Handle mastery points earned"""
	_refresh_points_display()
	Logger.debug("Points earned: %s +%d" % [event_type, points], "ui")

func _on_passive_changed(passive_id: StringName) -> void:
	"""Handle passive allocation/deallocation"""
	_refresh_points_display()

func _refresh_points_display() -> void:
	"""Update the points display for current event type"""
	if not points_label or not _mastery_system:
		return

	var available_points = _mastery_system.mastery_tree.get_points_for_event_type(_current_event_type)
	var allocated_points = _get_allocated_points_for_event_type(_current_event_type)

	points_label.text = "%s Points: %d available, %d allocated" % [
		_current_event_type.capitalize(),
		available_points,
		allocated_points
	]

func _get_allocated_points_for_event_type(event_type: StringName) -> int:
	"""Get allocated points for specific event type"""
	if not _mastery_system:
		return 0

	var allocated_count = 0
	var event_passives = _mastery_system.get_all_passives_for_event_type(event_type)
	for passive_info in event_passives:
		if passive_info.allocated:
			allocated_count += passive_info.cost

	return allocated_count

func _input(event: InputEvent) -> void:
	"""Handle input when UI is visible"""
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		hide_ui()
		get_viewport().set_input_as_handled()
