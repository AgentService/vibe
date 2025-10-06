## UtilityAbility.gd
## Base class for non-damage utility abilities (shields, movement, buffs).
##
## This class extends BaseAbility for abilities that don't deal direct damage.
## Utility abilities provide defensive, movement, or support effects.
##
## Class Hierarchy:
## - BaseAbility (universal: id, name, icon, tags, level, visuals)
##   - UtilityAbility (utility-specific properties) ← YOU ARE HERE
##     - BuffAbility (player stat buffs)
##     - ShieldAbility (damage absorption)
##     - MovementAbility (dash, teleport)
##
## Designer Experience:
## - Opening a ShieldAbility .tres shows only relevant shield properties
## - No damage/cooldown properties from DamageAbility
## - Clear separation: damage abilities vs utility abilities
##
## Future Implementation:
## - Add duration, cooldown, resource cost properties
## - Add effect strength, radius, target selection
## - Implement activation logic for each utility type
##
extends BaseAbility
class_name UtilityAbility

# ============================================================================
# UTILITY PROPERTIES (STUB - Future Implementation)
# ============================================================================

@export_group("Utility Behavior")

## Duration of utility effect in seconds (0 = instant/permanent)
@export var duration: float = 0.0

## Cooldown in seconds before ability can be used again
@export var base_cooldown: float = 5.0

## Final cooldown after modifiers (computed at runtime)
var final_cooldown: float = 5.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init() -> void:
	# Ensure UTILITY tag is always present
	if not has_tag(AbilityTags.UTILITY):
		tags.append(AbilityTags.UTILITY)

	# Initialize computed stats
	final_cooldown = base_cooldown


# ============================================================================
# ACTIVATION (STUB - Override in Subclasses)
# ============================================================================

## Activates the utility ability.
## Override in subclasses (BuffAbility, ShieldAbility, etc.)
##
## Parameters:
##   player: Node2D - The player node
##   context: Dictionary - Additional context (target, direction, etc.)
func activate(player: Node2D, context: Dictionary) -> void:
	push_warning("UtilityAbility.activate() called for '%s' - should be overridden" % ability_id)


# ============================================================================
# DEBUGGING & VALIDATION
# ============================================================================

## Converts ability data to Dictionary for debugging.
## Extends BaseAbility.to_dict() with UtilityAbility properties.
func to_dict() -> Dictionary:
	var data := super.to_dict()  # Get BaseAbility properties

	data["duration"] = duration
	data["base_cooldown"] = base_cooldown
	data["final_cooldown"] = final_cooldown

	return data


## Validates the ability configuration.
## Extends BaseAbility.validate() with UtilityAbility checks.
func validate() -> Array[String]:
	var errors: Array[String] = super.validate()  # Get BaseAbility errors

	# Duration validation
	if duration < 0:
		errors.append("duration must be >= 0")

	# Cooldown validation
	if base_cooldown <= 0:
		errors.append("base_cooldown must be > 0")

	# Tag validation (should be added by _init)
	if not has_tag(AbilityTags.UTILITY):
		errors.append("UtilityAbility must have UTILITY tag")

	return errors
