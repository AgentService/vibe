extends Node

## Player progression system autoload.
## Manages player level, experience, and unlock validation.
## Uses .tres resources for data-driven progression curves and unlock requirements.

# Import resource classes
const PlayerXPCurveScript = preload("res://scripts/resources/PlayerXPCurve.gd")
const PlayerUnlocksScript = preload("res://scripts/resources/PlayerUnlocks.gd")

# Current progression state
var level: int = 1
var experience: float = 0.0
var xp_to_next: float = 100.0

# Resource references
var xp_curve: PlayerXPCurveScript
var unlocks: PlayerUnlocksScript

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
	
	Logger.info("PlayerProgression initialized - Level: %d, XP: %.1f, XP to next: %.1f" % [level, experience, xp_to_next], "progression")

func _load_progression_resources() -> void:
	# Load XP curve
	var curve_resource = load("res://data/core/progression-xp-curve.tres")
	if curve_resource and curve_resource.is_valid():
		xp_curve = curve_resource
	else:
		Logger.warn("Failed to load valid XP curve, using fallback", "progression")
		_create_fallback_curve()
	
	# Load unlocks
	var unlocks_resource = load("res://data/content/unlocks.tres")
	if unlocks_resource:
		unlocks = unlocks_resource
	else:
		Logger.warn("Failed to load unlocks resource, creating empty one", "progression")
		unlocks = PlayerUnlocksScript.new()

func _create_fallback_curve() -> void:
	xp_curve = PlayerXPCurveScript.new()
	# Generate fallback curve with configurable parameters
	var fallback_thresholds := xp_curve.generate_fallback_curve(10)
	xp_curve.normal_thresholds = fallback_thresholds

## Gain experience points and handle level-ups
func gain_exp(amount: float) -> void:
	if not _is_initialized:
		Logger.warn("PlayerProgression not initialized, ignoring gain_exp call", "progression")
		return
	
	if _max_level_reached:
		Logger.debug("Max level reached, ignoring XP gain", "progression")
		return
	
	var old_total: float = experience
	experience += amount
	
	Logger.debug("Gained %.1f XP (%.1f -> %.1f), Level: %d" % [amount, old_total, experience, level], "progression")
	
	# Emit XP gained signal
	EventBus.xp_gained.emit(amount, experience)
	
	# Check for level-ups (handle multi-level-ups)
	var level_ups: int = 0
	while not _max_level_reached:
		var next_level_total_xp: int = xp_curve.get_xp_for_level(level + 1)
		 
		# Check if we can level up
		if next_level_total_xp == -1 or experience < float(next_level_total_xp):
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
	if not xp_curve:
		xp_to_next = 100.0  # Emergency fallback if no curve at all
		return
	
	var next_level_total_xp: int = xp_curve.get_xp_for_level(level + 1)
	
	if next_level_total_xp == -1:
		# Max level reached
		xp_to_next = 0.0
		_max_level_reached = true
		Logger.info("Max level reached: %d" % level, "progression")
	else:
		# Calculate XP still needed for next level
		xp_to_next = float(next_level_total_xp) - experience
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
	var old_exp: float = experience
	
	level = profile.get("level", 1)
	experience = profile.get("exp", 0.0)
	
	# Validate loaded data
	if level < 1:
		level = 1
	if experience < 0.0:
		Logger.warn("PlayerProgression: Clamping negative experience %.1f to 0.0" % experience, "progression")
		experience = 0.0
	
	# Update dependent state
	_update_xp_to_next()
	
	Logger.info("Loaded progression from profile - Level: %d, XP: %.1f" % [level, experience], "progression")
	
	# Emit progression changed
	_emit_progression_changed()

## Check if player has a specific unlock
func has_unlock(unlock_id: StringName) -> bool:
	if not unlocks:
		return true  # Default to unlocked if no unlock data
	
	return unlocks.has_unlock(unlock_id, level)

## Get current progression state as dictionary
func get_progression_state() -> Dictionary:
	# Calculate current level progress for proper XP bar display
	var current_level_xp: float = 0.0
	var xp_required_for_current_level: float = 100.0  # Default fallback
	
	if xp_curve:
		if level == 1:
			# Level 1 - show progress toward level 2
			current_level_xp = experience
			var level_2_total_xp: int = xp_curve.get_xp_for_level(2)
			if level_2_total_xp != -1:
				xp_required_for_current_level = float(level_2_total_xp)
			
			# Debug logging for Level 1
			Logger.debug("XP Calc - Level 1, Total XP: %.1f, Need for Level 2: %d" % [experience, level_2_total_xp], "progression")
			Logger.debug("XP Calc - Current Level XP: %.1f, Required: %.1f" % [current_level_xp, xp_required_for_current_level], "progression")
		else:
			# Level 2+ - show progress within current level
			var next_level_total_xp: int = xp_curve.get_xp_for_level(level + 1)  # XP needed for NEXT level
			var current_level_total_xp: int = xp_curve.get_xp_for_level(level)   # XP needed for CURRENT level
			
			if next_level_total_xp != -1:
				# We're not at max level - show progress toward next level
				current_level_xp = experience - float(current_level_total_xp)
				xp_required_for_current_level = float(next_level_total_xp - current_level_total_xp)
				
				# Debug logging
				Logger.debug("XP Calc - Level: %d, Total XP: %.1f, Current Level Total: %d, Next Level Total: %d" % [level, experience, current_level_total_xp, next_level_total_xp], "progression")
				Logger.debug("XP Calc - Current Level XP: %.1f, Required: %.1f" % [current_level_xp, xp_required_for_current_level], "progression")
				
				# Ensure values are non-negative
				if current_level_xp < 0.0:
					current_level_xp = 0.0
			else:
				# Max level reached
				current_level_xp = 0.0
				xp_required_for_current_level = 1.0  # Prevent division by zero
	
	return {
		"level": level,
		"exp": int(current_level_xp),  # Current progress within level (0 to level requirement)
		"xp_to_next": int(xp_required_for_current_level),  # Total XP required for current level
		"total_for_level": int(xp_required_for_current_level),  # For UI compatibility
		"max_level_reached": _max_level_reached
	}

## Export progression state for character saving (total accumulated experience)
func export_state() -> Dictionary:
	return {
		"level": level,
		"exp": experience,  # Total accumulated experience, not current level progress
		"version": 1
	}

## Emit progression changed signal with current state
func _emit_progression_changed() -> void:
	# Create comprehensive progression data for both UI and character saving
	var ui_data = get_progression_state()  # Current level progress for UI
	var save_data = export_state()        # Total accumulated XP for saving
	
	var comprehensive_state = {
		# UI display data (current level progress)
		"level": ui_data.level,
		"exp": ui_data.exp,                    # Current progress within level (0 to level requirement)
		"xp_to_next": ui_data.xp_to_next,      # XP required for current level
		"total_for_level": ui_data.total_for_level,
		"max_level_reached": ui_data.max_level_reached,
		
		# Character saving data (total accumulated experience)
		"save_level": save_data.level,
		"save_exp": save_data.exp,             # Total accumulated experience across all levels
		"save_version": save_data.version
	}
	
	EventBus.progression_changed.emit(comprehensive_state)
