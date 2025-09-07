extends Node

## Player progression system autoload.
## Manages player level, experience, and unlock validation.
## Uses .tres resources for data-driven progression curves and unlock requirements.

# Import resource classes
const PlayerXPCurve = preload("res://scripts/resources/PlayerXPCurve.gd")
const PlayerUnlocks = preload("res://scripts/resources/PlayerUnlocks.gd")

# Current progression state
var level: int = 1
var exp: float = 0.0
var xp_to_next: float = 100.0

# Resource references
var xp_curve: PlayerXPCurve
var unlocks: PlayerUnlocks

# Internal state
var _is_initialized: bool = false
var _max_level_reached: bool = false

func _ready() -> void:
	Logger.info("PlayerProgression initializing", "progression")
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Load progression resources
	_load_progression_resources()
	
	# Update initial state
	_update_xp_to_next()
	_is_initialized = true
	
	Logger.info("PlayerProgression initialized - Level: %d, XP: %.1f, XP to next: %.1f" % [level, exp, xp_to_next], "progression")

func _load_progression_resources() -> void:
	# Load XP curve
	var curve_resource = load("res://data/progression/xp_curve.tres")
	if curve_resource and curve_resource.is_valid():
		xp_curve = curve_resource
	else:
		Logger.warn("Failed to load valid XP curve, using fallback", "progression")
		_create_fallback_curve()
	
	# Load unlocks
	var unlocks_resource = load("res://data/progression/unlocks.tres")
	if unlocks_resource:
		unlocks = unlocks_resource
	else:
		Logger.warn("Failed to load unlocks resource, creating empty one", "progression")
		unlocks = PlayerUnlocks.new()

func _create_fallback_curve() -> void:
	xp_curve = PlayerXPCurve.new()
	# Fallback: 10 levels with simple progression (using normal curve defaults)

## Gain experience points and handle level-ups
func gain_exp(amount: float) -> void:
	if not _is_initialized:
		Logger.warn("PlayerProgression not initialized, ignoring gain_exp call", "progression")
		return
	
	if _max_level_reached:
		Logger.debug("Max level reached, ignoring XP gain", "progression")
		return
	
	var old_total: float = exp
	exp += amount
	
	print("PlayerProgression: Gained %.1f XP (%.1f -> %.1f), Level: %d, XP to next: %.1f" % [amount, old_total, exp, level, xp_to_next])
	Logger.debug("Gained %.1f XP (%.1f -> %.1f)" % [amount, old_total, exp], "progression")
	
	# Emit XP gained signal
	EventBus.xp_gained.emit(amount, exp)
	
	# Check for level-ups (handle multi-level-ups)
	var level_ups: int = 0
	while not _max_level_reached:
		var next_level_total_xp: int = xp_curve.get_xp_for_level(level + 1)
		
		# Check if we can level up
		if next_level_total_xp == -1 or exp < float(next_level_total_xp):
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
	
	print("PlayerProgression: LEVEL UP! %d -> %d (current XP: %.1f)" % [prev_level, level, exp])
	Logger.info("Level up! %d -> %d (current XP: %.1f)" % [prev_level, level, exp], "progression")
	
	# Update XP requirement for next level
	_update_xp_to_next()
	
	# Emit level-up signal
	EventBus.leveled_up.emit(level, prev_level)

## Update XP required for next level
func _update_xp_to_next() -> void:
	if not xp_curve:
		xp_to_next = 100.0  # Fallback
		return
	
	var next_level_total_xp: int = xp_curve.get_xp_for_level(level + 1)
	
	if next_level_total_xp == -1:
		# Max level reached
		xp_to_next = 0.0
		_max_level_reached = true
		Logger.info("Max level reached: %d" % level, "progression")
	else:
		# Calculate XP still needed for next level
		xp_to_next = float(next_level_total_xp) - exp
		_max_level_reached = false
		
		# Ensure xp_to_next is never negative
		if xp_to_next < 0.0:
			xp_to_next = 0.0

## Load progression state from save profile
func load_from_profile(profile: Dictionary) -> void:
	if not _is_initialized:
		Logger.warn("PlayerProgression not initialized, deferring profile load", "progression")
		call_deferred("load_from_profile", profile)
		return
	
	var old_level: int = level
	var old_exp: float = exp
	
	level = profile.get("level", 1)
	exp = profile.get("exp", 0.0)
	
	# Validate loaded data
	if level < 1:
		level = 1
	if exp < 0.0:
		exp = 0.0
	
	# Update dependent state
	_update_xp_to_next()
	
	Logger.info("Loaded progression from profile - Level: %d (was %d), XP: %.1f (was %.1f)" % [level, old_level, exp, old_exp], "progression")
	
	# Emit progression changed
	_emit_progression_changed()

## Export progression state for saving
func export_state() -> Dictionary:
	return {
		"level": level,
		"exp": exp,
		"version": 1  # For future migration compatibility
	}

## Check if player has a specific unlock
func has_unlock(unlock_id: StringName) -> bool:
	if not unlocks:
		return true  # Default to unlocked if no unlock data
	
	return unlocks.has_unlock(unlock_id, level)

## Get current progression state as dictionary
func get_progression_state() -> Dictionary:
	return {
		"level": level,
		"exp": exp,
		"xp_to_next": xp_to_next,
		"total_for_level": xp_to_next,  # For UI compatibility
		"max_level_reached": _max_level_reached
	}

## Emit progression changed signal with current state
func _emit_progression_changed() -> void:
	EventBus.progression_changed.emit(get_progression_state())
