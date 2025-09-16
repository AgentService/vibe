extends Node

## Global map level system that provides centralized difficulty progression
## Increases every 60 seconds and replaces scattered time-based calculations
## All systems should reference MapLevel.current_level instead of tracking their own timers

class_name MapLevelManager

signal level_increased(new_level: int)
signal level_changed(old_level: int, new_level: int)

# Current map level (starts at 1)
var current_level: int = 1

# Time per level in seconds (60 seconds = 1 level)
var seconds_per_level: float = 60.0

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
		Logger.info("MapLevel connected to StateManager signals", "arena")

func _on_run_started(_run_id: StringName, _context: Dictionary) -> void:
	"""Automatically start map level progression when a run begins"""
	start_progression()

func _on_run_ended(_result: Dictionary) -> void:
	"""Stop map level progression when a run ends"""
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

func get_scaling_factor(base_rate: float = 0.1) -> float:
	"""Get a scaling factor based on current level
	base_rate: How much each level increases difficulty (0.1 = 10% per level)"""
	return 1.0 + (base_rate * (current_level - 1))

func get_exponential_scaling(base_rate: float = 0.05, cap: float = 3.0) -> float:
	"""Get exponential scaling with a cap
	base_rate: Base exponential growth rate
	cap: Maximum scaling multiplier"""
	var raw_scaling = 1.0 + (base_rate * pow(current_level, 1.2))
	return minf(raw_scaling, cap)

# Convenience methods for common scaling patterns
func get_spawn_rate_scaling() -> float:
	"""Standard scaling for enemy spawn rates"""
	return get_scaling_factor(0.08)  # 8% faster spawning per level

func get_health_scaling() -> float:
	"""Standard scaling for enemy health"""
	return get_scaling_factor(0.12)  # 12% more health per level

func get_damage_scaling() -> float:
	"""Standard scaling for enemy damage"""
	return get_scaling_factor(0.10)  # 10% more damage per level

func get_pack_size_scaling() -> float:
	"""Standard scaling for pack sizes"""
	return get_scaling_factor(0.15)  # 15% larger packs per level