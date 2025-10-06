## DamageAbility.gd
## Intermediate base class for all damage-dealing abilities.
##
## This class extends BaseAbility to add damage, cooldown, and progression
## properties shared by all abilities that deal damage (projectiles, melee, AOE, etc.).
##
## Subclass Hierarchy:
## - BaseAbility (universal properties)
##   - DamageAbility (damage/cooldown/scaling) ← YOU ARE HERE
##     - ProjectileAbility (projectile-specific)
##     - MeleeAbility (future)
##     - AoEAbility (future)
##
## Designer Experience:
## - Opening a ProjectileAbility .tres shows ~29 relevant properties
## - BaseAbility properties (10) + DamageAbility properties (10) + ProjectileAbility properties (9)
## - No irrelevant buff_duration, orbit_radius, etc.
##
## Modifier System:
## - Tomes and items use duck typing: `"base_damage" in ability`
## - No type checking required: `if ability is DamageAbility`
## - Modifiers recalculate final_damage and final_cooldown automatically
##
extends BaseAbility
class_name DamageAbility

# ============================================================================
# DAMAGE PROPERTIES (100% of damage abilities use these)
# ============================================================================

@export_group("Damage")

## Base damage value before modifiers
@export var base_damage: float = 10.0

## Damage type (physical, spell, etc.) - could be enum in future
@export var damage_type: String = "physical"

## Inherent element (fire, cold, lightning, chaos, or empty for non-elemental)
@export var inherent_element: String = ""

## Final damage after modifiers (computed at runtime)
var final_damage: float = 10.0

# ============================================================================
# COOLDOWN PROPERTIES (100% of damage abilities use these)
# ============================================================================

@export_group("Cooldown")

## Base cooldown in seconds
@export var base_cooldown: float = 1.0

## Final cooldown after modifiers (computed at runtime)
var final_cooldown: float = 1.0

# ============================================================================
# MULTI-HIT PROPERTIES
# ============================================================================

@export_group("Multi-Hit")

## Number of hits/projectiles/strikes per activation
## - ProjectileAbility: number of projectiles fired
## - MeleeAbility (future): number of strikes
## - AoEAbility (future): number of pulses
@export var projectile_count: int = 1

# ============================================================================
# PROGRESSION / SCALING (100% of damage abilities use these)
# ============================================================================

@export_group("Scaling")

## Damage multiplier per level (1.15 = +15% per level)
@export var damage_scaling_per_level: float = 1.15

## Cooldown multiplier per level (0.95 = -5% cooldown per level, faster)
@export var cooldown_scaling_per_level: float = 0.95

## Levels at which breakpoint bonuses trigger [5, 10, 15]
@export var level_breakpoints: Array[int] = []

## Bonus descriptions at breakpoints ["Chains +1", "Damage +50%"]
@export var breakpoint_bonuses: Array[String] = []

# ============================================================================
# MODIFIER SYSTEM (Runtime)
# ============================================================================

## Active modifiers from tomes/items (private - managed via add/remove methods)
var _active_modifiers: Array = []  # Array of TomeModifier descriptors

## Base projectile count before modifiers (for correct modifier removal)
## NOTE: Gets initialized from projectile_count on first _recalculate_final_stats() call
var _base_projectile_count: int = 0  # 0 = uninitialized

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init() -> void:
	# NOTE: Don't call super._init() - Resource doesn't have a callable _init()

	# Ensure DAMAGE tag is always present
	if not has_tag(AbilityTags.DAMAGE):
		tags.append(AbilityTags.DAMAGE)

	# Ensure COOLDOWN tag is present (for tome/modifier compatibility)
	if not has_tag(AbilityTags.COOLDOWN):
		tags.append(AbilityTags.COOLDOWN)

	# Initialize computed stats
	final_damage = base_damage
	final_cooldown = base_cooldown

	# Initialize _base_projectile_count (for abilities created via code, not .tres)
	if _base_projectile_count == 0:
		_base_projectile_count = projectile_count

# ============================================================================
# MODIFIER MANAGEMENT
# ============================================================================

## Adds a tome modifier and recalculates final stats.
## Modifiers are idempotent descriptors - same tome can stack.
##
## Parameters:
##   modifier: TomeModifier descriptor from BaseTome
func add_modifier(modifier) -> void:
	_active_modifiers.append(modifier)
	_recalculate_final_stats()


## Removes a tome modifier and recalculates final stats.
## Matches by tome_id - removes first matching modifier.
##
## Parameters:
##   tome_id: String - Unique tome identifier
func remove_modifier(tome_id: String) -> void:
	for i in range(_active_modifiers.size() - 1, -1, -1):
		if _active_modifiers[i].tome_id == tome_id:
			_active_modifiers.remove_at(i)
			break  # Remove only first match

	_recalculate_final_stats()


## Recalculates final stats from base values + all active modifiers.
## Called automatically after add_modifier() or remove_modifier().
##
## Modifier Application Order:
## 1. Reset to base values
## 2. Apply all additive bonuses (projectile_count)
## 3. Apply all multiplicative bonuses (damage, cooldown)
##
## Duck Typing:
## - Uses `"property_name" in modifier` instead of type checks
## - Modifiers can apply to any ability with matching properties
func _recalculate_final_stats() -> void:
	# Initialize _base_projectile_count from .tres file on first call
	# (Godot doesn't call _init() when loading Resources from files)
	if _base_projectile_count == 0:
		_base_projectile_count = projectile_count

	# Reset to base values
	final_damage = base_damage
	final_cooldown = base_cooldown
	projectile_count = _base_projectile_count

	# Apply all active modifiers
	for modifier in _active_modifiers:
		# Damage (multiplicative)
		if "damage_multiplier" in modifier:
			var mult: float = modifier.damage_multiplier
			# Apply stack_count as power: (1.2)^3 for 3 stacks
			if "stack_count" in modifier:
				mult = pow(mult, modifier.stack_count)
			final_damage *= mult

		# Cooldown (multiplicative)
		if "cooldown_multiplier" in modifier:
			var mult: float = modifier.cooldown_multiplier
			if "stack_count" in modifier:
				mult = pow(mult, modifier.stack_count)
			final_cooldown *= mult

		# Projectile count (additive per stack)
		if "projectile_count_bonus" in modifier:
			var bonus: int = modifier.projectile_count_bonus
			if "stack_count" in modifier:
				bonus *= modifier.stack_count
			projectile_count += bonus

# ============================================================================
# PROGRESSION
# ============================================================================

## Levels up the ability by specified levels and applies breakpoint bonuses if triggered.
## Returns true if any breakpoint was triggered, false otherwise.
##
## Parameters:
##   levels: int - Number of levels to increase (default 1)
func level_up(levels: int = 1) -> bool:
	if ability_level >= max_level:
		return false

	var any_breakpoint_triggered := false

	# Level up multiple times if requested
	for i in range(levels):
		if ability_level >= max_level:
			break

		ability_level += 1

		# Apply level-based scaling
		final_damage = base_damage * pow(damage_scaling_per_level, ability_level - 1)
		final_cooldown = base_cooldown * pow(cooldown_scaling_per_level, ability_level - 1)

		# Check for breakpoint bonuses
		if level_breakpoints.has(ability_level):
			any_breakpoint_triggered = true
			_apply_breakpoint_bonus(ability_level)

	return any_breakpoint_triggered


## Applies a breakpoint bonus at the specified level.
## Breakpoint bonuses are permanent upgrades to base stats.
##
## Parameters:
##   level: int - The level at which the breakpoint triggered
##
## Example breakpoint_bonuses:
##   ["Chains +1", "Damage +50%", "Projectiles +1"]
func _apply_breakpoint_bonus(level: int) -> void:
	var breakpoint_index := level_breakpoints.find(level)
	if breakpoint_index < 0 or breakpoint_index >= breakpoint_bonuses.size():
		return

	var bonus_desc: String = breakpoint_bonuses[breakpoint_index]

	# Parse bonus description (simple string matching for now)
	# Future: Could use regex or structured data
	if "Chains" in bonus_desc:
		# Handle in ProjectileAbility override
		pass
	elif "Damage" in bonus_desc:
		# Extract percentage and apply to base_damage
		# Example: "Damage +50%" → base_damage *= 1.5
		if "%" in bonus_desc:
			var parts := bonus_desc.split("+")
			if parts.size() > 1:
				var percent_str := parts[1].replace("%", "").strip_edges()
				var percent := float(percent_str) / 100.0
				base_damage *= (1.0 + percent)
				_recalculate_final_stats()
	elif "Projectiles" in bonus_desc:
		# Extract count and apply to _base_projectile_count
		# Example: "Projectiles +1" → _base_projectile_count += 1
		if "+" in bonus_desc:
			var parts := bonus_desc.split("+")
			if parts.size() > 1:
				var count_str := parts[1].strip_edges()
				var count := int(count_str)
				_base_projectile_count += count
				_recalculate_final_stats()

# ============================================================================
# DEBUGGING & VALIDATION
# ============================================================================

## Converts ability data to Dictionary for debugging.
## Extends BaseAbility.to_dict() with DamageAbility properties.
func to_dict() -> Dictionary:
	var data := super.to_dict()  # Get BaseAbility properties

	data["base_damage"] = base_damage
	data["final_damage"] = final_damage
	data["damage_type"] = damage_type
	data["inherent_element"] = inherent_element
	data["base_cooldown"] = base_cooldown
	data["final_cooldown"] = final_cooldown
	data["projectile_count"] = projectile_count
	data["damage_scaling"] = damage_scaling_per_level
	data["cooldown_scaling"] = cooldown_scaling_per_level
	data["active_modifiers"] = _active_modifiers.size()

	return data


## Validates the ability configuration.
## Extends BaseAbility.validate() with DamageAbility checks.
func validate() -> Array[String]:
	var errors: Array[String] = super.validate()  # Get BaseAbility errors

	# Damage validation
	if base_damage <= 0:
		errors.append("base_damage must be > 0")

	if damage_type.is_empty():
		errors.append("damage_type cannot be empty")

	# Cooldown validation
	if base_cooldown <= 0:
		errors.append("base_cooldown must be > 0")

	# Multi-hit validation
	if projectile_count < 1:
		errors.append("projectile_count must be >= 1")

	# Scaling validation
	if damage_scaling_per_level <= 0:
		errors.append("damage_scaling_per_level must be > 0")

	if cooldown_scaling_per_level <= 0:
		errors.append("cooldown_scaling_per_level must be > 0")

	# Breakpoint validation
	if level_breakpoints.size() != breakpoint_bonuses.size():
		errors.append("level_breakpoints and breakpoint_bonuses must have same size")

	for bp_level in level_breakpoints:
		if bp_level < 1 or bp_level > max_level:
			errors.append("breakpoint level %d outside valid range [1, %d]" % [bp_level, max_level])

	# Tag validation (should be added by _init)
	if not has_tag(AbilityTags.DAMAGE):
		errors.append("DamageAbility must have DAMAGE tag")

	return errors
