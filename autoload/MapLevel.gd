extends Node

## Global map level system that provides centralized time-based progression tracking
## Increases every 60 seconds and provides current_level access for systems
## All systems should reference MapLevel.current_level for consistent progression state

class_name MapLevelManager

signal level_increased(new_level: int)
signal level_changed(old_level: int, new_level: int)

# Current map level (starts at 1)
var current_level: int = 1

# Time per level in seconds (10 seconds = 1 level for testing)
var seconds_per_level: float = 10.0

# Internal timer
var _level_timer: float = 0.0

# Whether the system is active
var _is_active: bool = false

func _ready() -> void:
	Logger.info("MapLevel system initialized", "arena")
	set_process(false)  # Don't start until a run begins

	# Connect to StateManager signals for automatic run integration
	if StateManager:
		StateManager.run_started.connect(_on_run_started)
		StateManager.run_ended.connect(_on_run_ended)
		StateManager.state_changed.connect(_on_state_changed)
		Logger.info("MapLevel connected to StateManager signals", "arena")

func _on_run_started(_run_id: StringName, _context: Dictionary) -> void:
	"""Automatically start map level progression when a run begins"""
	start_progression()

func _on_run_ended(_result: Dictionary) -> void:
	"""Stop map level progression when a run ends"""
	stop_progression()

func _on_state_changed(prev_state: StateManager.State, new_state: StateManager.State, _context: Dictionary) -> void:
	"""Additional safety: Stop progression when leaving ARENA state"""
	if new_state != StateManager.State.ARENA and _is_active:
		Logger.info("Map level progression stopped due to state change to %s" % StateManager.State.keys()[new_state], "arena")
		stop_progression()

func start_progression() -> void:
	"""Start the map level progression system"""
	_is_active = true
	current_level = 1
	_level_timer = 0.0
	set_process(true)
	Logger.info("Map level progression started at level %d" % current_level, "arena")

func stop_progression() -> void:
	"""Stop the map level progression system"""
	_is_active = false
	set_process(false)
	Logger.info("Map level progression stopped at level %d" % current_level, "arena")

func reset_progression() -> void:
	"""Reset map level back to 1"""
	var old_level = current_level
	current_level = 1
	_level_timer = 0.0
	level_changed.emit(old_level, current_level)
	Logger.info("Map level reset to %d" % current_level, "arena")

func _process(delta: float) -> void:
	if not _is_active:
		return

	# Additional safety check: Only process during ARENA state
	if StateManager and StateManager.get_current_state() != StateManager.State.ARENA:
		return

	_level_timer += delta

	# Check if we should level up
	if _level_timer >= seconds_per_level:
		_level_timer -= seconds_per_level  # Keep remainder for accuracy
		var old_level = current_level
		current_level += 1

		# Emit signals
		level_increased.emit(current_level)
		level_changed.emit(old_level, current_level)

		Logger.info("Map level increased: %d → %d" % [old_level, current_level], "arena")

func get_level_progress() -> float:
	"""Get progress toward next level (0.0 to 1.0)"""
	if not _is_active:
		return 0.0
	return _level_timer / seconds_per_level

func get_level_time_remaining() -> float:
	"""Get seconds remaining until next level"""
	if not _is_active:
		return 0.0
	return seconds_per_level - _level_timer

