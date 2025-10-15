## ScalingCalculator.gd
## Unified scaling system for items, enemies, and map progression.
##
## Provides predictable, data-driven scaling formulas with Inspector-friendly configuration.
## All formulas are hot-reloadable via .tres resource files.
##
## Architecture (2025-10-15):
##   - Static utility class (no instantiation)
##   - Separate methods for flat/additive vs multiplicative scaling
##   - Three scaling types: LINEAR, EXPONENTIAL, HYPERBOLIC
##   - Designer-friendly parameters (per_stack, cap, k)
##
## Usage Examples:
##   # Linear HP scaling: 25, 50, 75, 100 HP
##   var hp = ScalingCalculator.calculate_flat(25.0, 3, ScalingType.LINEAR)
##
##   # Exponential damage: 1.2x, 1.44x, 1.728x
##   var dmg = ScalingCalculator.calculate_multiplier(0.2, 3, ScalingType.EXPONENTIAL)
##
##   # Hyperbolic capped damage: approaches 3.0x at infinite stacks
##   var dmg = ScalingCalculator.calculate_multiplier(0.2, 10, ScalingType.HYPERBOLIC, 3.0, 5.0)

class_name ScalingCalculator

# ============================================================================
# SCALING TYPES
# ============================================================================

enum ScalingType {
	LINEAR,        ## Flat growth: value = per_stack * stacks
	EXPONENTIAL,   ## Compound growth: value = (1 + per_stack)^stacks
	HYPERBOLIC,    ## Diminishing returns: asymptotically approaches cap
	SPECIAL,       ## Reserved for custom per-item logic (fallback to LINEAR)
}

# ============================================================================
# FLAT/ADDITIVE SCALING (HP, Flat Damage, Crit %)
# ============================================================================

## Calculate flat/additive stat scaling.
## Used for: max_hp_bonus, crit_chance_bonus, flat damage bonuses
##
## Parameters:
##   per_stack: Base value added per stack
##   stack_count: Number of stacks (usually item count)
##   scaling_type: LINEAR or HYPERBOLIC
##   cap: Maximum value at infinite stacks (HYPERBOLIC only)
##   k: Half-cap point - at k stacks, value = cap/2 (HYPERBOLIC only)
##
## Returns:
##   Calculated flat value (e.g., 75 HP, 0.15 crit chance)
##
## Examples:
##   # Rump Steak: 25 HP per stack (linear)
##   calculate_flat(25.0, 3, LINEAR) → 75.0
##
##   # Capped HP: approaches 500 HP max
##   calculate_flat(50.0, 10, HYPERBOLIC, 500.0, 5.0) → 333.33 HP
static func calculate_flat(
	per_stack: float,
	stack_count: int,
	scaling_type: ScalingType,
	cap: float = 0.0,
	k: float = 1.0
) -> float:
	match scaling_type:
		ScalingType.LINEAR:
			# Formula: per_stack * stacks
			# Example: 25 * 3 = 75 HP
			return per_stack * float(stack_count)

		ScalingType.HYPERBOLIC:
			# Formula: cap * stacks / (stacks + k)
			# Example: 500 * 10 / (10 + 5) = 333.33 HP
			# At k stacks: cap * k / (k + k) = cap / 2
			# At infinite stacks: approaches cap
			var stacks_f := float(stack_count)
			return cap * stacks_f / (stacks_f + k)

		ScalingType.EXPONENTIAL:
			Logger.warn("EXPONENTIAL not supported for flat scaling, using LINEAR", "scaling")
			return per_stack * float(stack_count)

		ScalingType.SPECIAL:
			Logger.warn("SPECIAL scaling not implemented, using LINEAR", "scaling")
			return per_stack * float(stack_count)

		_:
			Logger.warn("Unknown scaling type, using LINEAR", "scaling")
			return per_stack * float(stack_count)


# ============================================================================
# MULTIPLIER SCALING (Damage, Speed, Radius)
# ============================================================================

## Calculate multiplicative stat scaling.
## Used for: damage_mult, movement_speed_mult, pickup_radius_mult
##
## Parameters:
##   per_stack: Percentage bonus per stack (0.2 = 20%)
##   stack_count: Number of stacks
##   scaling_type: LINEAR, EXPONENTIAL, or HYPERBOLIC
##   cap: Maximum multiplier at infinite stacks (HYPERBOLIC only)
##   k: Half-cap point (HYPERBOLIC only)
##
## Returns:
##   Calculated multiplier (e.g., 1.6x damage, 2.0x speed)
##
## Examples:
##   # Focus Stone: 20% damage per stack (linear)
##   calculate_multiplier(0.2, 3, LINEAR) → 1.6x
##
##   # Feather: 15% speed per stack (exponential)
##   calculate_multiplier(0.15, 3, EXPONENTIAL) → 1.52x
##
##   # Capped damage: approaches 3.0x max
##   calculate_multiplier(0.2, 10, HYPERBOLIC, 3.0, 5.0) → 2.33x
static func calculate_multiplier(
	per_stack: float,
	stack_count: int,
	scaling_type: ScalingType,
	cap: float = 0.0,
	k: float = 1.0
) -> float:
	match scaling_type:
		ScalingType.LINEAR:
			# Formula: 1 + (per_stack * stacks)
			# Example: 1 + (0.2 * 3) = 1.6x damage
			# Stacks additively: 20%, 40%, 60%, 80%...
			return 1.0 + (per_stack * float(stack_count))

		ScalingType.EXPONENTIAL:
			# Formula: (1 + per_stack)^stacks
			# Example: 1.2^3 = 1.728x damage
			# Stacks multiplicatively: 20%, 44%, 72.8%, 107%...
			# CURRENT DEFAULT for damage_mult, movement_speed_mult
			return pow(1.0 + per_stack, float(stack_count))

		ScalingType.HYPERBOLIC:
			# Formula: 1 + (cap - 1) * stacks / (stacks + k)
			# Example: 1 + (3 - 1) * 10 / (10 + 5) = 2.33x damage
			# At k stacks: 1 + (cap - 1) / 2 (halfway to cap)
			# At infinite stacks: approaches cap
			# RECOMMENDED for proc items to prevent runaway scaling
			var stacks_f := float(stack_count)
			return 1.0 + (cap - 1.0) * (stacks_f / (stacks_f + k))

		ScalingType.SPECIAL:
			Logger.warn("SPECIAL scaling not implemented, using LINEAR", "scaling")
			return 1.0 + (per_stack * float(stack_count))

		_:
			Logger.warn("Unknown scaling type, using LINEAR", "scaling")
			return 1.0 + (per_stack * float(stack_count))


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Get human-readable description of scaling formula.
## Useful for tooltips and stat summaries.
static func get_formula_description(
	scaling_type: ScalingType,
	per_stack: float,
	is_multiplier: bool = false,
	cap: float = 0.0,
	k: float = 1.0
) -> String:
	match scaling_type:
		ScalingType.LINEAR:
			if is_multiplier:
				return "+%.0f%% per stack (linear)" % (per_stack * 100.0)
			else:
				return "+%.0f per stack (linear)" % per_stack

		ScalingType.EXPONENTIAL:
			return "+%.0f%% per stack (exponential)" % (per_stack * 100.0)

		ScalingType.HYPERBOLIC:
			if is_multiplier:
				return "+%.0f%% per stack (max %.1fx at ∞)" % [per_stack * 100.0, cap]
			else:
				return "+%.0f per stack (max %.0f at ∞)" % [per_stack, cap]

		ScalingType.SPECIAL:
			return "Special scaling (see item description)"

		_:
			return "Unknown scaling"


## Calculate value at specific stack count for preview/testing.
## Returns formatted string like "3 stacks: 1.6x damage"
static func preview_scaling(
	per_stack: float,
	stack_count: int,
	scaling_type: ScalingType,
	is_multiplier: bool = false,
	cap: float = 0.0,
	k: float = 1.0
) -> String:
	var value: float
	if is_multiplier:
		value = calculate_multiplier(per_stack, stack_count, scaling_type, cap, k)
		return "%d stacks: %.2fx" % [stack_count, value]
	else:
		value = calculate_flat(per_stack, stack_count, scaling_type, cap, k)
		return "%d stacks: %.0f" % [stack_count, value]


# ============================================================================
# DEBUGGING & VALIDATION
# ============================================================================

## Validate scaling parameters for common errors.
## Returns array of warning strings (empty = valid)
static func validate_parameters(
	scaling_type: ScalingType,
	per_stack: float,
	cap: float = 0.0,
	k: float = 1.0
) -> Array[String]:
	var warnings: Array[String] = []

	if per_stack <= 0.0:
		warnings.append("per_stack should be > 0.0")

	if scaling_type == ScalingType.HYPERBOLIC:
		if cap <= 0.0:
			warnings.append("HYPERBOLIC requires cap > 0.0")
		if k <= 0.0:
			warnings.append("HYPERBOLIC requires k > 0.0")

	if scaling_type == ScalingType.EXPONENTIAL and per_stack > 1.0:
		warnings.append("EXPONENTIAL with per_stack > 1.0 causes extreme growth (did you mean 0.2 instead of 1.2?)")

	return warnings
