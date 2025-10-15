## StatusEffect.gd
## Domain model for status effects (DoT, debuffs, buffs).
##
## Represents a single status effect instance applied to an entity.
## Used by StatusEffectSystem to track active effects and apply ticking damage/debuffs.
##
## Effect Types:
##   - poison: Damage over time (nature damage)
##   - burn: Damage over time (fire damage)
##   - bleed: Damage over time (physical damage)
##   - chill/slow: Movement speed reduction
##   - stun: Disable movement/attacks (future)
##
## Stack Behaviors:
##   - REPLACE: New effect replaces existing (same type from same source)
##   - EXTEND: Add duration to existing effect (keep highest damage)
##   - STACK_DAMAGE: Multiple instances tick independently
extends RefCounted
class_name StatusEffect

## Stack behavior when same effect applied multiple times
enum StackBehavior {
	REPLACE,       ## Replace existing effect with new one
	EXTEND,        ## Add duration to existing, keep highest damage
	STACK_DAMAGE   ## Multiple instances stack (tick independently)
}

# ============================================================================
# EFFECT CONSTANTS
# ============================================================================

## Poison tick interval (used for damage calculations)
const POISON_TICK_INTERVAL: float = 0.5

# ============================================================================
# EFFECT PROPERTIES
# ============================================================================

## Effect type identifier (poison, burn, bleed, chill)
var effect_type: String = ""

## Remaining duration in seconds
var remaining_duration: float = 0.0

## Time between damage/debuff ticks (e.g., 0.5s = 2 ticks per second)
var tick_interval: float = 1.0

## Damage applied per tick (0 for non-damaging effects like slow)
var damage_per_tick: float = 0.0

## Movement speed multiplier for slow effects (0.0 = full stop, 0.5 = 50% speed)
## Only applies to "chill" or "slow" effect types
var slow_mult: float = 1.0

## Source identifier for recursion prevention (e.g., "item_poison", "enemy_venom")
var source: String = ""

## How this effect stacks with other instances of same type
var stack_behavior: StackBehavior = StackBehavior.REPLACE

## Accumulator for partial ticks (tracks time since last tick)
var _tick_accumulator: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

## Constructor for creating status effect instances
func _init(
	p_effect_type: String,
	p_duration: float,
	p_tick_interval: float = 1.0,
	p_damage_per_tick: float = 0.0,
	p_slow_mult: float = 1.0,
	p_source: String = "",
	p_stack_behavior: StackBehavior = StackBehavior.REPLACE
) -> void:
	effect_type = p_effect_type
	remaining_duration = p_duration
	tick_interval = p_tick_interval
	damage_per_tick = p_damage_per_tick
	slow_mult = p_slow_mult
	source = p_source
	stack_behavior = p_stack_behavior


## Factory method for creating poison effects
static func create_poison(duration: float, damage_per_tick: float, source: String = "item_poison") -> StatusEffect:
	return StatusEffect.new(
		"poison",
		duration,
		POISON_TICK_INTERVAL,  # Tick every 0.5 seconds
		damage_per_tick,
		1.0,  # No slow
		source,
		StackBehavior.REPLACE  # Refresh duration on reapplication (prevents infinite stacking)
	)


## Factory method for creating burn effects
static func create_burn(duration: float, damage_per_tick: float, source: String = "item_burn") -> StatusEffect:
	return StatusEffect.new(
		"burn",
		duration,
		0.5,  # Tick every 0.5 seconds
		damage_per_tick,
		1.0,  # No slow
		source,
		StackBehavior.EXTEND  # Extend duration on reapplication
	)


## Factory method for creating chill/slow effects
static func create_chill(duration: float, slow_mult: float, source: String = "item_chill") -> StatusEffect:
	return StatusEffect.new(
		"chill",
		duration,
		0.1,  # Update slow every 0.1s for smooth movement
		0.0,  # No damage
		slow_mult,
		source,
		StackBehavior.REPLACE  # Replace with strongest slow
	)


# ============================================================================
# UPDATE & VALIDATION
# ============================================================================

## Update effect duration and tick accumulator
## Returns number of ticks to apply this frame (handles frame hitches)
func update(delta: float) -> int:
	remaining_duration -= delta
	_tick_accumulator += delta

	# Count how many ticks accumulated (catch up on slow frames)
	var ticks_to_apply: int = 0
	while _tick_accumulator >= tick_interval:
		_tick_accumulator -= tick_interval
		ticks_to_apply += 1

	return ticks_to_apply


## Check if effect has expired
func is_expired() -> bool:
	return remaining_duration <= 0.0


## Validate effect configuration
func is_valid() -> bool:
	return (
		not effect_type.is_empty() and
		tick_interval > 0.0 and
		remaining_duration > 0.0
	)


# ============================================================================
# STACKING & MERGING
# ============================================================================

## Merge with another effect instance based on stack behavior
func merge_with(other: StatusEffect) -> void:
	if effect_type != other.effect_type:
		return  # Cannot merge different effect types

	match stack_behavior:
		StackBehavior.REPLACE:
			# Replace all values with new effect
			remaining_duration = other.remaining_duration
			damage_per_tick = other.damage_per_tick
			slow_mult = other.slow_mult
			_tick_accumulator = 0.0

		StackBehavior.EXTEND:
			# Add duration, keep highest damage/slow
			remaining_duration += other.remaining_duration
			damage_per_tick = max(damage_per_tick, other.damage_per_tick)
			slow_mult = min(slow_mult, other.slow_mult)  # Lower = slower

		StackBehavior.STACK_DAMAGE:
			# No merging - handled by system (multiple independent instances)
			pass


# ============================================================================
# DEBUGGING
# ============================================================================

## Debug representation
func _to_string() -> String:
	return "StatusEffect(%s, dur=%.1fs, dmg=%.1f, tick=%.2fs, src=%s)" % [
		effect_type, remaining_duration, damage_per_tick, tick_interval, source
	]
