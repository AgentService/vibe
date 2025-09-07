extends Control
class_name XPBarUI

## XP Bar UI stub for progression system integration.
## Subscribes to progression changes but has no visual rendering yet.

var current_xp: float = 0.0
var needed_xp: float = 100.0
var current_level: int = 1

func _ready() -> void:
	# Connect to progression signals
	EventBus.progression_changed.connect(_on_progression_changed)
	EventBus.xp_gained.connect(_on_xp_gained)
	EventBus.leveled_up.connect(_on_leveled_up)
	
	Logger.debug("XPBarUI initialized and listening for progression changes", "ui")

func _exit_tree() -> void:
	# Clean up signal connections
	if EventBus.progression_changed.is_connected(_on_progression_changed):
		EventBus.progression_changed.disconnect(_on_progression_changed)
	if EventBus.xp_gained.is_connected(_on_xp_gained):
		EventBus.xp_gained.disconnect(_on_xp_gained)
	if EventBus.leveled_up.is_connected(_on_leveled_up):
		EventBus.leveled_up.disconnect(_on_leveled_up)

func _on_progression_changed(state: Dictionary) -> void:
	# Update internal state for future UI rendering
	current_level = state.get("level", 1)
	current_xp = state.get("exp", 0.0)
	needed_xp = state.get("xp_to_next", 100.0)
	
	Logger.debug("XPBarUI progression update: Level %d, XP %.1f/%.1f" % [current_level, current_xp, needed_xp], "ui")
	
	# TODO: Update visual XP bar when implemented
	# - Progress bar fill
	# - Level text
	# - XP numbers

func _on_xp_gained(amount: float, new_total: float) -> void:
	Logger.debug("XPBarUI XP gained: +%.1f (total: %.1f)" % [amount, new_total], "ui")
	
	# TODO: Animate XP gain when visual components exist
	# - Smooth progress bar animation
	# - XP gain number popup
	# - Flash effect

func _on_leveled_up(new_level: int, prev_level: int) -> void:
	Logger.info("XPBarUI level up: %d -> %d" % [prev_level, new_level], "ui")
	
	# TODO: Animate level up when visual components exist
	# - Level up celebration effect
	# - Progress bar reset animation
	# - Level number update