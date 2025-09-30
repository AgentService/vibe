extends Node

## Player progression system autoload (Simplified for Task 04a cleanup).
## Manages in-run level and experience only - no persistence.
## TODO: New progression - Will be replaced by SessionState (Task 04 Phase 2)

# Current progression state (in-run only)
var level: int = 1
var experience: float = 0.0
var xp_to_next: float = 100.0

# Internal state
var _is_initialized: bool = false
var _max_level: int = 30  # Arbitrary cap for safety

func _ready() -> void:
	Logger.info("PlayerProgression initializing (simplified, in-run only)", "progression")
	process_mode = Node.PROCESS_MODE_ALWAYS

	_is_initialized = true
	_update_xp_to_next()

	Logger.info("PlayerProgression initialized - Level: %d, XP: %.1f, XP to next: %.1f" % [level, experience, xp_to_next], "progression")

## Gain experience points and handle level-ups
func gain_exp(amount: float) -> void:
	if not _is_initialized:
		Logger.warn("PlayerProgression not initialized, ignoring gain_exp call", "progression")
		return

	if level >= _max_level:
		return  # Max level reached

	var old_total: float = experience
	experience += amount

	Logger.debug("Gained %.1f XP (%.1f -> %.1f), Level: %d" % [amount, old_total, experience, level], "progression")

	# Emit XP gained signal
	EventBus.xp_gained.emit(amount, experience)

	# Check for level-ups (handle multi-level-ups)
	var level_ups: int = 0
	while level < _max_level:
		var next_level_total_xp: float = _calculate_xp_for_level(level + 1)

		# Check if we can level up
		if experience < next_level_total_xp:
			break

		_level_up()
		level_ups += 1

		# Safety check to prevent infinite loop
		if level_ups > 15:
			Logger.warn("Too many level-ups in single gain_exp call, breaking", "progression")
			break

	# Always emit progression changed after XP gain
	_emit_progression_changed()

## Handle single level-up
func _level_up() -> void:
	var prev_level: int = level

	# Move to next level
	level += 1

	Logger.info("Level up! %d -> %d (current XP: %.1f)" % [prev_level, level, experience], "progression")

	# Update XP requirement for next level
	_update_xp_to_next()

	# Emit level-up signal
	EventBus.leveled_up.emit(level, prev_level)

## Update XP required for next level
func _update_xp_to_next() -> void:
	if level >= _max_level:
		xp_to_next = 0.0
		return

	var next_level_total_xp: float = _calculate_xp_for_level(level + 1)
	xp_to_next = next_level_total_xp - experience

	# Ensure xp_to_next is never negative
	if xp_to_next < 0.0:
		xp_to_next = 0.0

## Simple XP formula: 100 + (level * 50)
## TODO: Move to BalanceDB in Task 04 Phase 2
func _calculate_xp_for_level(target_level: int) -> float:
	if target_level <= 1:
		return 0.0

	# Calculate cumulative XP for target level
	var total_xp: float = 0.0
	for lvl in range(2, target_level + 1):
		total_xp += 100.0 + ((lvl - 1) * 50.0)

	return total_xp

## Reset progression (called at run start)
func reset() -> void:
	level = 1
	experience = 0.0
	_update_xp_to_next()
	Logger.info("PlayerProgression reset for new run", "progression")
	_emit_progression_changed()

## Get current progression state as dictionary
func get_progression_state() -> Dictionary:
	# Calculate current level progress for proper XP bar display
	var current_level_xp: float = 0.0
	var xp_required_for_current_level: float = 100.0  # Default for level 1

	if level == 1:
		# Level 1 - show progress toward level 2
		current_level_xp = experience
		xp_required_for_current_level = 100.0  # Base XP
	else:
		# Level 2+ - show progress within current level
		var current_level_total_xp: float = _calculate_xp_for_level(level)
		var next_level_total_xp: float = _calculate_xp_for_level(level + 1)

		current_level_xp = experience - current_level_total_xp
		xp_required_for_current_level = next_level_total_xp - current_level_total_xp

		# Ensure values are non-negative
		if current_level_xp < 0.0:
			current_level_xp = 0.0

	return {
		"level": level,
		"exp": int(current_level_xp),  # Current progress within level
		"xp_to_next": int(xp_required_for_current_level),  # Total XP required for current level
		"total_for_level": int(xp_required_for_current_level),
		"max_level_reached": level >= _max_level
	}

## Emit progression changed signal with current state
func _emit_progression_changed() -> void:
	var ui_data = get_progression_state()

	var comprehensive_state = {
		"level": ui_data.level,
		"exp": ui_data.exp,
		"xp_to_next": ui_data.xp_to_next,
		"total_for_level": ui_data.total_for_level,
		"max_level_reached": ui_data.max_level_reached
	}

	EventBus.progression_changed.emit(comprehensive_state)
