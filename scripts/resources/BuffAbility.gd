## BuffAbility.gd
## Buff-based utility ability for player stat modifications.
##
## This class extends UtilityAbility for abilities that buff player stats.
## Buffs provide temporary stat increases (attack speed, movement speed, etc.).
##
## Class Hierarchy:
## - BaseAbility (universal: id, name, icon, tags, level, visuals)
##   - UtilityAbility (duration, cooldown)
##     - BuffAbility (stat modifications) ← YOU ARE HERE
##
## Designer Experience:
## - Opening a BuffAbility .tres shows buff-specific properties
## - Clear stat modification targets and multipliers
## - Duration and cooldown from UtilityAbility parent
##
## Future Implementation:
## - Add stat target enum (attack_speed, movement_speed, damage, etc.)
## - Add multiplier/flat bonus properties
## - Implement buff application and removal logic
## - Integrate with player stat system
##
extends UtilityAbility
class_name BuffAbility

# ============================================================================
# BUFF PROPERTIES (STUB - Future Implementation)
# ============================================================================

@export_group("Buff Stats")

## Target stat to modify (e.g., "attack_speed", "movement_speed", "damage")
## Future: Could be enum for type safety
@export var stat_target: String = "movement_speed"

## Multiplier applied to stat (1.5 = +50%)
@export var stat_multiplier: float = 1.5

## Flat bonus added to stat (additive)
@export var flat_bonus: float = 0.0

## Can buff stack with itself?
@export var can_stack: bool = false

## Maximum stack count if stacking enabled
@export var max_stacks: int = 3

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init() -> void:
	super._init()  # Initialize UtilityAbility (UTILITY tag, cooldown)

	# Ensure BUFF tag is always present
	if not has_tag(AbilityTags.BUFF):
		tags.append(AbilityTags.BUFF)


# ============================================================================
# ACTIVATION (STUB - Future Implementation)
# ============================================================================

## Activates the buff ability.
## Applies stat modification to player for duration.
##
## Parameters:
##   player: Node2D - The player node (needs stat system)
##   context: Dictionary - Additional context
func activate(player: Node2D, context: Dictionary) -> void:
	push_warning("BuffAbility.activate() not yet implemented for '%s'" % ability_id)
	# Future: Apply buff to player stat system
	# EventBus.buff_applied.emit(player_id, stat_target, stat_multiplier, duration)


# ============================================================================
# DEBUGGING & VALIDATION
# ============================================================================

## Converts ability data to Dictionary for debugging.
## Extends UtilityAbility.to_dict() with BuffAbility properties.
func to_dict() -> Dictionary:
	var data := super.to_dict()  # Get UtilityAbility properties

	data["stat_target"] = stat_target
	data["stat_multiplier"] = stat_multiplier
	data["flat_bonus"] = flat_bonus
	data["can_stack"] = can_stack
	data["max_stacks"] = max_stacks

	return data


## Validates the ability configuration.
## Extends UtilityAbility.validate() with BuffAbility checks.
func validate() -> Array[String]:
	var errors: Array[String] = super.validate()  # Get UtilityAbility errors

	# Stat validation
	if stat_target.is_empty():
		errors.append("stat_target cannot be empty")

	if stat_multiplier <= 0:
		errors.append("stat_multiplier must be > 0")

	# Stack validation
	if can_stack and max_stacks < 1:
		errors.append("max_stacks must be >= 1 when can_stack is true")

	# Tag validation (should be added by _init)
	if not has_tag(AbilityTags.BUFF):
		errors.append("BuffAbility must have BUFF tag")

	return errors
