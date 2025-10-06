## BaseAbility.gd
## Core Resource class for ability definitions and progression.
##
## This class represents a skill/ability that can be equipped and leveled up.
## Abilities are data-driven Resources (.tres files) that define:
## - Core identity (ID, name, description, icon)
## - Progression system (levels, scaling factors, breakpoints)
## - Tags for categorization and modifier application
## - Base stats (damage, cooldown, etc.)
## - Visual/scene references for activation effects
##
## Design Pattern:
## - Extends Resource for inspector editing and .tres serialization
## - Immutable data with mutable runtime state (ability_level)
## - Tag-based scaling system for flexible progression
## - Virtual activate() method for subclass specialization
##
## Auto-Fire Compatible:
## - activate() is called automatically by ability systems
## - No player input required - abilities fire based on cooldowns/conditions
##
## Usage:
##   var ability: BaseAbility = load("res://data/content/abilities/fireball.tres")
##   ability.level_up(5)  # Apply 5 levels of scaling
##   if ability.has_tag(AbilityTags.FIRE): print("Fire ability!")
##   ability.activate(player, {})  # Auto-fire activation
extends Resource
class_name BaseAbility

# ============================================================================
# CORE IDENTITY
# ============================================================================

@export_group("Core Identity")

## Unique identifier for this ability (e.g., "fireball", "frost_nova")
@export var ability_id: String = ""

## Display name shown in UI
@export var ability_name: String = ""

## Description for tooltips and ability selection UI
@export_multiline var description: String = ""

## Icon texture for UI display
@export var icon: Texture2D

# ============================================================================
# PROGRESSION
# ============================================================================

@export_group("Progression")

## Current level of this ability (modified at runtime)
@export var ability_level: int = 1

## Maximum level this ability can reach
@export var max_level: int = 10

## Damage scaling multiplier per level (multiplicative)
## Example: 1.15 = +15% damage per level
@export var damage_scaling_per_level: float = 1.15

## Cooldown scaling multiplier per level (multiplicative)
## Example: 0.95 = -5% cooldown per level (gets faster)
@export var cooldown_scaling_per_level: float = 0.95

## Level breakpoints for special bonuses (e.g., [5, 10])
## At these levels, _apply_breakpoint_bonus() is called
@export var level_breakpoints: Array[int] = []

## Breakpoint bonus strings (parsed by subclasses)
## Example: ["projectile_count+1", "pierce+1"]
@export var breakpoint_bonuses: Array[String] = []

# ============================================================================
# TAGS
# ============================================================================

@export_group("Tags")

## Ability tags for categorization and modifier matching
## Use AbilityTags constants: [AbilityTags.PROJECTILE, AbilityTags.FIRE]
## Tags determine which tomes/modifiers can apply to this ability
@export var tags: Array[String] = []

# ============================================================================
# BASE STATS (Immutable Baseline)
# ============================================================================

@export_group("Base Stats")

## Base damage dealt by this ability (IMMUTABLE - never modified after level-up)
## This is the baseline value before tome modifiers are applied.
## Use final_damage for actual damage calculations in gameplay.
##
## Design Pattern:
## - base_damage = immutable baseline (set in .tres, scaled by level_up())
## - final_damage = computed value (base_damage × tome modifiers)
## - Rebuild: final_damage recalculated from base_damage when modifiers change
##
## Why Separate Baseline vs Computed:
## When player acquires tomes during gameplay (level-up rewards, chest drops),
## the system must rebuild modifiers from scratch to avoid exponential stacking.
## Example WITHOUT separation (buggy):
##   - Start: base_damage = 15.0
##   - Gain Tome of Power (+15%): base_damage *= 1.15 → 17.25
##   - Gain another: base_damage *= 1.15 → 19.84
##   - If system rebuilds: base_damage *= (1.15^2) → 22.82 (WRONG - exponential bug)
## Example WITH separation (correct):
##   - Start: base_damage = 15.0 (never changes), final_damage = 15.0
##   - Gain Tome of Power (+15%, 1 stack): final_damage = 15.0 * 1.15 = 17.25
##   - Gain another (+15%, 2 stacks): final_damage = 15.0 * (1.15^2) = 19.84
##   - Rebuild always correct: final_damage = base_damage * (1.15^2) = 19.84 ✓
@export var base_damage: float = 10.0

## Cooldown in seconds between activations (IMMUTABLE baseline)
## Same pattern as base_damage - use final_cooldown for actual cooldown timers.
@export var base_cooldown: float = 1.0

# ============================================================================
# COMPUTED STATS (Recalculated from Baseline + Modifiers)
# ============================================================================

## Final damage after tome modifiers (COMPUTED - read-only in gameplay)
## Recalculated via _recalculate_final_stats() whenever modifiers change.
## ALWAYS use this value for damage calculations, NEVER base_damage.
var final_damage: float = 10.0

## Final cooldown after tome modifiers (COMPUTED - read-only in gameplay)
## Recalculated via _recalculate_final_stats() whenever modifiers change.
## ALWAYS use this value for cooldown timers, NEVER base_cooldown.
var final_cooldown: float = 1.0

# ============================================================================
# MODIFIER TRACKING (Tome System Integration)
# ============================================================================

## Active tome modifiers applied to this ability instance.
## Each TomeModifier descriptor stores:
## - tome_id: Which tome was applied (e.g., "tome_damage")
## - stack_count: How many stacks of this tome
## - Multipliers: damage_multiplier, cooldown_multiplier, etc.
##
## Idempotent Application:
## When a tome is applied with add_modifier(), any existing modifier
## with the same tome_id is REPLACED (not stacked). This prevents
## exponential bugs when rebuilding modifiers.
##
## Example:
##   - Apply Tome of Power (1 stack): _active_modifiers = [{tome_damage, stack=1}]
##   - Apply Tome of Power (2 stacks): _active_modifiers = [{tome_damage, stack=2}]
##   - Modifiers array size = 1 (replaced, not added)
var _active_modifiers: Array = []  # Array[TomeModifier] - typed in Godot 4.2+

# ============================================================================
# DAMAGE TYPE & ELEMENT
# ============================================================================

@export_group("Damage Type")

## Damage type classification (e.g., "physical", "spell", "dot")
@export var damage_type: String = "spell"

## Inherent element for this ability (e.g., "fire", "cold", "lightning")
@export var inherent_element: String = ""

# ============================================================================
# OPTIONAL PROPERTIES (Conditional based on tags)
# ============================================================================

@export_group("Projectile Properties", "projectile_")

## Projectile speed (pixels/second) - only for PROJECTILE tag
@export var projectile_speed: float = 300.0

## Projectile count - only for PROJECTILE tag
@export var projectile_count: int = 1

## Projectile lifetime (seconds) - only for PROJECTILE tag
@export var projectile_lifetime: float = 2.0

@export_group("Buff Properties", "buff_")

## Buff duration (seconds) - only for BUFF tag
@export var buff_duration: float = 5.0

## Buff stat name to modify - only for BUFF tag
@export var buff_stat_name: String = ""

## Buff multiplier - only for BUFF tag
@export var buff_multiplier: float = 1.0

@export_group("AOE Properties", "aoe_")

## AOE radius (pixels) - only for AOE tag
@export var aoe_radius: float = 100.0

## AOE duration (seconds) - only for AOE tag
@export var aoe_duration: float = 0.5

@export_group("Orbit Properties", "orbit_")

## Orbit radius (pixels) - only for ORBIT tag
@export var orbit_radius: float = 80.0

## Orbit rotation speed (radians/second) - only for ORBIT tag
@export var orbit_rotation_speed: float = PI

## Orbit projectile count - only for ORBIT tag
@export var orbit_projectile_count: int = 3

# ============================================================================
# VISUAL REFERENCES
# ============================================================================

@export_group("Visuals")

## Scene to instance for ability visual (projectile, effect, etc.)
@export var visual_scene: PackedScene

## Impact effect scene (particles, flash, etc.)
@export var impact_effect: PackedScene


# ============================================================================
# PROGRESSION METHODS
# ============================================================================

## Levels up the ability by the specified number of levels.
## Applies multiplicative scaling to base_damage and cooldown based on tags.
## Checks for breakpoints and applies bonuses.
##
## Scaling formula:
##   new_value = base_value * pow(scaling_factor, levels)
##
## Example:
##   base_damage = 10.0, scaling = 1.15, levels = 5
##   result = 10.0 * pow(1.15, 5) ≈ 20.11
func level_up(levels: int = 1) -> void:
	# Clamp to max level
	var levels_to_add: int = mini(levels, max_level - ability_level)
	if levels_to_add <= 0:
		return

	# Apply scaling based on tags (modifies BASELINE stats only)
	if has_tag(AbilityTags.DAMAGE):
		base_damage *= pow(damage_scaling_per_level, levels_to_add)

	if has_tag(AbilityTags.COOLDOWN):
		base_cooldown *= pow(cooldown_scaling_per_level, levels_to_add)

	# Recalculate final stats from new baseline
	_recalculate_final_stats()

	# Update level
	var old_level: int = ability_level
	ability_level += levels_to_add

	# Check for breakpoint bonuses
	for i in range(old_level + 1, ability_level + 1):
		if level_breakpoints.has(i):
			var breakpoint_index: int = level_breakpoints.find(i)
			if breakpoint_index < breakpoint_bonuses.size():
				_apply_breakpoint_bonus(breakpoint_bonuses[breakpoint_index])


## Applies a breakpoint bonus to the ability.
## Bonuses are string-encoded (e.g., "projectile_count+1", "aoe_radius*1.5").
## Subclasses can override for custom bonus parsing.
##
## Phase 1 Note: Basic parsing only. Expand in later phases.
func _apply_breakpoint_bonus(bonus: String) -> void:
	# Basic parsing: "property_name+value" or "property_name*value"
	if "+" in bonus:
		var parts: PackedStringArray = bonus.split("+")
		if parts.size() == 2:
			var property_name: String = parts[0]
			var value: float = parts[1].to_float()
			_apply_additive_bonus(property_name, value)
	elif "*" in bonus:
		var parts: PackedStringArray = bonus.split("*")
		if parts.size() == 2:
			var property_name: String = parts[0]
			var multiplier: float = parts[1].to_float()
			_apply_multiplicative_bonus(property_name, multiplier)


## Applies an additive bonus to a property.
func _apply_additive_bonus(property_name: String, value: float) -> void:
	match property_name:
		"projectile_count":
			projectile_count += int(value)
		"orbit_projectile_count":
			orbit_projectile_count += int(value)
		"aoe_radius":
			aoe_radius += value
		"base_damage":
			base_damage += value


## Applies a multiplicative bonus to a property.
func _apply_multiplicative_bonus(property_name: String, multiplier: float) -> void:
	match property_name:
		"base_damage":
			base_damage *= multiplier
		"base_cooldown":
			base_cooldown *= multiplier
		"aoe_radius":
			aoe_radius *= multiplier
		"projectile_speed":
			projectile_speed *= multiplier


# ============================================================================
# MODIFIER SYSTEM (Tome Integration)
# ============================================================================

## Adds or replaces a tome modifier on this ability instance.
## This method implements IDEMPOTENT application - if a modifier with the
## same tome_id already exists, it is REPLACED (not stacked).
##
## Design Pattern:
## When player acquires tomes during gameplay, this method is called with
## the TOTAL stack count for that tome (not incremental). The system then
## rebuilds all final stats from baseline + all active modifiers.
##
## Example:
##   - Player gains Tome of Power (1 stack):
##     add_modifier(TomeModifier{tome_id="tome_damage", stack=1, dmg_mult=1.15})
##     → _active_modifiers = [{tome_damage, stack=1}]
##     → final_damage = 15.0 * (1.15^1) = 17.25
##
##   - Player gains another Tome of Power (now 2 stacks total):
##     add_modifier(TomeModifier{tome_id="tome_damage", stack=2, dmg_mult=1.15})
##     → _active_modifiers = [{tome_damage, stack=2}]  ← REPLACED old entry
##     → final_damage = 15.0 * (1.15^2) = 19.84 ✓ Correct
##
## Parameters:
##   modifier: TomeModifier descriptor with tome_id, stack_count, multipliers
func add_modifier(modifier) -> void:  # modifier: TomeModifier (defined in BaseTome)
	# Remove any existing modifier with the same tome_id (idempotent)
	_active_modifiers = _active_modifiers.filter(
		func(m): return m.tome_id != modifier.tome_id
	)

	# Add new modifier
	_active_modifiers.append(modifier)

	# Rebuild final stats from baseline + all modifiers
	_recalculate_final_stats()


## Removes a tome modifier from this ability instance.
## Used when player loses/unequips a tome (rare, but supported).
##
## Parameters:
##   tome_id: String identifier of the tome to remove (e.g., "tome_damage")
func remove_modifier(tome_id: String) -> void:
	_active_modifiers = _active_modifiers.filter(
		func(m): return m.tome_id != tome_id
	)

	# Rebuild final stats without removed modifier
	_recalculate_final_stats()


## Recalculates final stats from baseline values + all active modifiers.
## This method ALWAYS starts from immutable baseline (base_damage, base_cooldown)
## and applies ALL modifiers multiplicatively.
##
## Formula (per stat):
##   final_stat = base_stat * product(modifier.multiplier ^ modifier.stack_count)
##
## Example with 2 tomes:
##   - Tome of Power (damage +15%, 2 stacks)
##   - Tome of Swiftness (cooldown -10%, 1 stack)
##
##   final_damage = base_damage * (1.15^2)
##                = 15.0 * 1.3225
##                = 19.84
##
##   final_cooldown = base_cooldown * (0.9^1)
##                  = 1.0 * 0.9
##                  = 0.9
##
## Called automatically by:
##   - add_modifier() when tome is applied
##   - remove_modifier() when tome is removed
##   - level_up() when baseline stats change
func _recalculate_final_stats() -> void:
	# Start from immutable baseline
	final_damage = base_damage
	final_cooldown = base_cooldown

	# Apply all tome modifiers multiplicatively
	for modifier in _active_modifiers:
		# Damage multiplier (e.g., Tome of Power: 1.15^stack_count)
		if modifier.damage_multiplier != 1.0:
			final_damage *= pow(modifier.damage_multiplier, modifier.stack_count)

		# Cooldown multiplier (e.g., Tome of Haste: 0.9^stack_count)
		if modifier.cooldown_multiplier != 1.0:
			final_cooldown *= pow(modifier.cooldown_multiplier, modifier.stack_count)

		# Future: Add more stat multipliers here (projectile_speed, aoe_radius, etc.)


## Returns a list of all active tome modifiers on this ability.
## Useful for debugging displays and save systems.
##
## Returns: Array[TomeModifier] - All active modifiers
func get_active_modifiers() -> Array:
	return _active_modifiers.duplicate()


## Returns the stack count for a specific tome on this ability.
## Returns 0 if the tome is not currently applied.
##
## Parameters:
##   tome_id: String identifier of the tome (e.g., "tome_damage")
##
## Returns: int - Stack count (0 if not applied)
func get_modifier_stack_count(tome_id: String) -> int:
	for modifier in _active_modifiers:
		if modifier.tome_id == tome_id:
			return modifier.stack_count
	return 0


# ============================================================================
# TAG HELPER METHODS
# ============================================================================

## Checks if this ability has a specific tag.
func has_tag(tag: StringName) -> bool:
	return tags.has(tag) or tags.has(str(tag))


## Checks if this ability has ALL of the specified tags.
func has_all_tags(required_tags: Array) -> bool:
	for tag in required_tags:
		if not has_tag(tag):
			return false
	return true


## Checks if this ability has ANY of the specified tags.
func has_any_tag(possible_tags: Array) -> bool:
	for tag in possible_tags:
		if has_tag(tag):
			return true
	return false


# ============================================================================
# ACTIVATION (Auto-Fire Compatible)
# ============================================================================

## Activates the ability (auto-fire compatible).
## Called automatically by ability systems when cooldown is ready.
##
## Parameters:
##   player: Node2D - The player node (for position, context)
##   context: Dictionary - Additional context (target_enemy, etc.)
##
## This is a virtual method meant to be overridden by subclasses.
## Base implementation emits a warning.
func activate(player: Node2D, context: Dictionary) -> void:
	push_warning("BaseAbility.activate() called directly for '%s' - should be overridden by subclass" % ability_id)


# ============================================================================
# DEBUGGING & VALIDATION
# ============================================================================

## Converts ability data to a Dictionary for debugging and serialization.
## Useful for save systems, debugging displays, and logging.
## Includes both baseline stats (base_*) and computed stats (final_*).
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"ability_id": ability_id,
		"ability_name": ability_name,
		"description": description,
		"level": ability_level,
		"max_level": max_level,
		"tags": tags,
		"base_damage": base_damage,
		"base_cooldown": base_cooldown,
		"final_damage": final_damage,
		"final_cooldown": final_cooldown,
		"damage_type": damage_type,
		"inherent_element": inherent_element,
		"scaling": {
			"damage_per_level": damage_scaling_per_level,
			"cooldown_per_level": cooldown_scaling_per_level
		},
		"active_modifiers": _active_modifiers.size()
	}

	# Add conditional properties if relevant tags exist
	if has_tag(AbilityTags.PROJECTILE):
		data["projectile"] = {
			"speed": projectile_speed,
			"count": projectile_count,
			"lifetime": projectile_lifetime
		}

	if has_tag(AbilityTags.AOE):
		data["aoe"] = {
			"radius": aoe_radius,
			"duration": aoe_duration
		}

	if has_tag(AbilityTags.ORBIT):
		data["orbit"] = {
			"radius": orbit_radius,
			"rotation_speed": orbit_rotation_speed,
			"projectile_count": orbit_projectile_count
		}

	return data


## Validates the ability configuration.
## Returns an array of error strings. Empty array = valid.
##
## Checks:
## - Required fields are not empty
## - Numeric values are in valid ranges
## - Tags are valid AbilityTags constants
## - Required properties for tags are set
func validate() -> Array[String]:
	var errors: Array[String] = []

	# Core identity validation
	if ability_id.is_empty():
		errors.append("ability_id cannot be empty")

	if ability_name.is_empty():
		errors.append("ability_name cannot be empty")

	# Progression validation
	if ability_level < 0:
		errors.append("ability_level must be >= 0")

	if max_level <= 0:
		errors.append("max_level must be > 0")

	if ability_level > max_level:
		errors.append("ability_level (%d) exceeds max_level (%d)" % [ability_level, max_level])

	# Stats validation
	if base_damage < 0:
		errors.append("base_damage must be >= 0")

	if base_cooldown <= 0:
		errors.append("base_cooldown must be > 0")

	# Tag validation
	if tags.is_empty():
		errors.append("abilities should have at least one tag")

	for tag in tags:
		var tag_as_stringname: StringName = StringName(tag)
		if not AbilityTags.is_valid_tag(tag_as_stringname):
			errors.append("invalid tag: '%s'" % tag)

	# Conditional property validation
	if has_tag(AbilityTags.PROJECTILE):
		if projectile_speed <= 0:
			errors.append("projectile_speed must be > 0 for PROJECTILE abilities")
		if projectile_count < 1:
			errors.append("projectile_count must be >= 1 for PROJECTILE abilities")

	if has_tag(AbilityTags.AOE):
		if aoe_radius <= 0:
			errors.append("aoe_radius must be > 0 for AOE abilities")

	return errors
