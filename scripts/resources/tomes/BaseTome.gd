## BaseTome.gd
## Item/modifier Resource that enhances abilities and player stats.
##
## Tomes are stackable modifiers (inspired by PoE support gems/items) that can:
## - Modify ability stats (damage, cooldown, projectile count, etc.)
## - Modify player stats (movement speed, HP, luck, XP gain)
## - Apply globally or to specific ability tags
##
## Stacking System:
## - Multiplicative for multipliers: stat * pow(multiplier, stack_count)
## - Additive for flat bonuses: stat + (bonus * stack_count)
##
## Tag Matching (Applicability):
## - Empty applicable_tags = global modifier (applies to ALL abilities)
## - Non-empty tags = applies if ability has ANY of the tags (OR logic)
##
## Example:
##   Tome: "Fire Mastery" - applicable_tags: [AbilityTags.FIRE]
##   - Applies to any ability with FIRE tag
##   - damage_multiplier: 1.25 (25% more damage per stack)
##   - 3 stacks = damage * pow(1.25, 3) = 1.953x damage
##
## Usage:
##   var tome: BaseTome = load("res://data/content/tomes/fire_mastery.tres")
##   if tome.can_apply_to_ability(fireball_ability):
##       tome.apply_to_ability(fireball_ability, 3)  # Apply 3 stacks
extends Resource
class_name BaseTome

# ============================================================================
# TOME MODIFIER DESCRIPTOR
# ============================================================================

## TomeModifier descriptor class for idempotent modifier application.
##
## This class represents a "snapshot" of tome stats that gets stored on
## BaseAbility instances. It enables IDEMPOTENT modifier application:
## when a tome is applied multiple times with different stack counts,
## the old descriptor is replaced (not stacked exponentially).
##
## Design Pattern:
## Instead of mutating ability.base_damage directly (which causes exponential bugs),
## we create a TomeModifier descriptor and pass it to ability.add_modifier().
## The ability then rebuilds final_damage from base_damage + all modifiers.
##
## Why Descriptors vs Direct Mutation:
## Direct mutation (OLD approach):
##   ability.base_damage *= pow(1.15, stack_count)  # Mutates baseline - BUG!
##
## Descriptor pattern (NEW approach):
##   var modifier = TomeModifier.new()
##   modifier.tome_id = "tome_damage"
##   modifier.stack_count = 2
##   modifier.damage_multiplier = 1.15
##   ability.add_modifier(modifier)  # Idempotent - replaces old modifier
##   # ability._recalculate_final_stats() rebuilds from baseline ✓
##
## Example:
##   Player gains Tome of Power (1 stack):
##     - TomeModifier{tome_id="tome_damage", stack=1, dmg_mult=1.15}
##     - ability.final_damage = 15.0 * (1.15^1) = 17.25
##
##   Player gains another Tome of Power (2 stacks total):
##     - TomeModifier{tome_id="tome_damage", stack=2, dmg_mult=1.15}
##     - OLD modifier with tome_id="tome_damage" is REPLACED
##     - ability.final_damage = 15.0 * (1.15^2) = 19.84 ✓ Correct
class TomeModifier:
	## Unique identifier of the tome (e.g., "tome_damage", "tome_speed")
	var tome_id: String

	## Total stack count for this tome (not incremental - absolute count)
	var stack_count: int

	# Ability multipliers (1.0 = no change)
	var damage_multiplier: float = 1.0
	var cooldown_multiplier: float = 1.0
	var range_multiplier: float = 1.0
	var area_multiplier: float = 1.0
	var projectile_speed_multiplier: float = 1.0
	var duration_multiplier: float = 1.0

	# Ability flat bonuses (0 = no change)
	var projectile_count_bonus: int = 0
	var pierce_bonus: int = 0
	var chain_bonus: int = 0

	# Player stat multipliers (1.0 = no change)
	var movement_speed_multiplier: float = 1.0
	var xp_gain_multiplier: float = 1.0
	var pickup_radius_multiplier: float = 1.0

	# Player stat flat bonuses (0 = no change)
	var max_hp_bonus: int = 0
	var luck_bonus: float = 0.0

# ============================================================================
# CORE IDENTITY
# ============================================================================

@export_group("Core Identity")

## Unique identifier for this tome (e.g., "fire_mastery", "swift_casting")
@export var tome_id: String = ""

## Display name shown in UI
@export var tome_name: String = ""

## Description for tooltips and tome selection UI
@export_multiline var description: String = ""

## Icon texture for UI display
@export var icon: Texture2D

## Rarity tier (common, uncommon, rare, legendary)
@export var rarity: String = "common"

# ============================================================================
# STACKING
# ============================================================================

@export_group("Stacking")

## Maximum number of stacks this tome can have
## 0 = infinite stacking, >0 = hard limit
@export var stack_limit: int = 3

# ============================================================================
# APPLICABILITY
# ============================================================================

@export_group("Applicability")

## Tags that determine which abilities this tome can modify
## Empty array = applies to ALL abilities (global modifier)
## Non-empty = applies if ability has ANY of these tags (OR logic)
@export var applicable_tags: Array[String] = []

# ============================================================================
# ABILITY MODIFIERS
# ============================================================================

@export_group("Ability Modifiers")

## Damage multiplier per stack (1.0 = no change, 1.25 = +25% per stack)
@export var damage_multiplier: float = 1.0

## Cooldown multiplier per stack (1.0 = no change, 0.9 = -10% cooldown per stack)
@export var cooldown_multiplier: float = 1.0

## Range multiplier per stack (1.0 = no change, 1.25 = +25% range per stack)
@export var range_multiplier: float = 1.0

## Projectile count bonus (flat addition per stack)
@export var projectile_count_bonus: int = 0

## Area/radius multiplier per stack
@export var area_multiplier: float = 1.0

## Projectile speed multiplier per stack
@export var projectile_speed_multiplier: float = 1.0

## Duration multiplier per stack (for buffs/debuffs/AOE)
@export var duration_multiplier: float = 1.0

## Pierce bonus (flat addition per stack)
@export var pierce_bonus: int = 0

## Chain bonus (flat addition per stack)
@export var chain_bonus: int = 0

# ============================================================================
# PLAYER STAT MODIFIERS
# ============================================================================

@export_group("Player Stat Modifiers")

## Movement speed multiplier per stack
@export var movement_speed_multiplier: float = 1.0

## Max HP bonus (flat addition per stack)
@export var max_hp_bonus: int = 0

## Luck bonus (flat addition per stack) - affects loot/crit
@export var luck_bonus: float = 0.0

## XP gain multiplier per stack
@export var xp_gain_multiplier: float = 1.0

## Pickup radius multiplier per stack
@export var pickup_radius_multiplier: float = 1.0

# ============================================================================
# TAG MATCHING
# ============================================================================

## Checks if this tome can be applied to a given ability.
## Returns true if:
## - applicable_tags is empty (global modifier), OR
## - ability has ANY of the tags in applicable_tags (OR logic)
func can_apply_to_ability(ability: BaseAbility) -> bool:
	if not ability:
		return false

	# Empty applicable_tags = global modifier
	if applicable_tags.is_empty():
		return true

	# Check if ability has ANY of the required tags (OR logic)
	return ability.has_any_tag(applicable_tags)


# ============================================================================
# ABILITY MODIFICATION (Descriptor Pattern)
# ============================================================================

## Applies this tome's modifiers to an ability using the descriptor pattern.
## Creates a TomeModifier descriptor and passes it to ability.add_modifier().
##
## Idempotent Application:
## This method is called with the TOTAL stack count for this tome (not incremental).
## The ability will REPLACE any existing modifier with the same tome_id.
##
## Example Flow:
##   1. Player gains 1st Tome of Power (stack_count=1):
##      - Creates TomeModifier{tome_id="tome_damage", stack=1, dmg_mult=1.15}
##      - ability.add_modifier(modifier)
##      - ability.final_damage = 15.0 * (1.15^1) = 17.25
##
##   2. Player gains 2nd Tome of Power (stack_count=2):
##      - Creates TomeModifier{tome_id="tome_damage", stack=2, dmg_mult=1.15}
##      - ability.add_modifier(modifier) ← REPLACES old modifier (idempotent)
##      - ability.final_damage = 15.0 * (1.15^2) = 19.84 ✓ Correct
##
## Parameters:
##   ability: BaseAbility - The ability instance to modify
##   stack_count: int - TOTAL stack count for this tome (not incremental)
##
## Why Descriptor Pattern:
## Old approach (direct mutation) caused exponential bugs when rebuilding modifiers:
##   ability.base_damage *= pow(1.15, stack_count)  # Mutates baseline - BUG!
##
## New approach (descriptor) enables safe rebuilding from immutable baseline:
##   modifier = TomeModifier{...}
##   ability.add_modifier(modifier)  # Stores descriptor, rebuilds from baseline ✓
func apply_to_ability(ability: BaseAbility, stack_count: int) -> void:
	if not ability or stack_count <= 0:
		return

	# Duck typing: verify ability supports modifiers (DamageAbility, etc.)
	# UtilityAbility (Phase 1 stub) doesn't have add_modifier() yet
	if not ability.has_method("add_modifier"):
		push_warning("Tome '%s' cannot apply to ability '%s' - no add_modifier() method (non-damage ability?)" % [tome_id, ability.ability_id])
		return

	# Clamp to stack limit (0 = infinite)
	var effective_stacks: int = stack_count
	if stack_limit > 0:
		effective_stacks = mini(stack_count, stack_limit)

	# Create TomeModifier descriptor with this tome's stats
	var modifier = TomeModifier.new()
	modifier.tome_id = tome_id
	modifier.stack_count = effective_stacks

	# Copy ability modifiers (duck typing in DamageAbility._recalculate_final_stats)
	# Each ability subclass checks for relevant properties using: "property_name" in modifier
	modifier.damage_multiplier = damage_multiplier
	modifier.cooldown_multiplier = cooldown_multiplier
	modifier.range_multiplier = range_multiplier
	modifier.area_multiplier = area_multiplier
	modifier.projectile_speed_multiplier = projectile_speed_multiplier
	modifier.duration_multiplier = duration_multiplier

	# Copy flat bonuses
	modifier.projectile_count_bonus = projectile_count_bonus
	modifier.pierce_bonus = pierce_bonus
	modifier.chain_bonus = chain_bonus

	# Pass descriptor to ability (triggers idempotent replacement + rebuild)
	# Duck typing: ability.add_modifier() decides which properties to use
	ability.add_modifier(modifier)


# ============================================================================
# PLAYER MODIFICATION
# ============================================================================

## Applies this tome's player stat modifiers with given stack count.
## Modifies player stats in-place (movement speed, HP, luck, XP gain).
##
## Expected player properties:
##   - movement_speed: float
##   - max_hp: int (or float)
##   - luck: float
##   - xp_multiplier: float
##   - pickup_radius: float
##
## Phase 1 Note: Player stat application is a stub for future phases.
## The actual player node structure will determine exact property names.
func apply_to_player(player: Node2D, stack_count: int) -> void:
	if not player or stack_count <= 0:
		return

	# Clamp to stack limit (0 = infinite)
	var effective_stacks: int = stack_count
	if stack_limit > 0:
		effective_stacks = mini(stack_count, stack_limit)

	# Apply multiplicative modifiers
	if movement_speed_multiplier != 1.0 and player.has("movement_speed"):
		player.movement_speed *= pow(movement_speed_multiplier, effective_stacks)

	if xp_gain_multiplier != 1.0 and player.has("xp_multiplier"):
		player.xp_multiplier *= pow(xp_gain_multiplier, effective_stacks)

	if pickup_radius_multiplier != 1.0 and player.has("pickup_radius"):
		player.pickup_radius *= pow(pickup_radius_multiplier, effective_stacks)

	# Apply additive bonuses
	if max_hp_bonus != 0 and player.has("max_hp"):
		player.max_hp += max_hp_bonus * effective_stacks

	if luck_bonus != 0.0 and player.has("luck"):
		player.luck += luck_bonus * effective_stacks


# ============================================================================
# DEBUGGING & VALIDATION
# ============================================================================

## Converts tome data to a Dictionary for debugging and serialization.
func to_dict() -> Dictionary:
	return {
		"tome_id": tome_id,
		"tome_name": tome_name,
		"description": description,
		"rarity": rarity,
		"stack_limit": stack_limit,
		"applicable_tags": applicable_tags.duplicate(),
		"ability_modifiers": {
			"damage_multiplier": damage_multiplier,
			"cooldown_multiplier": cooldown_multiplier,
			"range_multiplier": range_multiplier,
			"projectile_count_bonus": projectile_count_bonus,
			"area_multiplier": area_multiplier,
			"projectile_speed_multiplier": projectile_speed_multiplier,
			"duration_multiplier": duration_multiplier,
			"pierce_bonus": pierce_bonus,
			"chain_bonus": chain_bonus
		},
		"player_modifiers": {
			"movement_speed_multiplier": movement_speed_multiplier,
			"max_hp_bonus": max_hp_bonus,
			"luck_bonus": luck_bonus,
			"xp_gain_multiplier": xp_gain_multiplier,
			"pickup_radius_multiplier": pickup_radius_multiplier
		}
	}


## Validates tome configuration.
## Returns an array of error strings. Empty array = valid.
func validate() -> Array[String]:
	var errors: Array[String] = []

	# Core identity validation
	if tome_id.is_empty():
		errors.append("tome_id cannot be empty")

	if tome_name.is_empty():
		errors.append("tome_name cannot be empty")

	# Stack limit validation
	if stack_limit < 0:
		errors.append("stack_limit must be >= 0 (0 = infinite)")

	# Tag validation
	for tag in applicable_tags:
		var tag_as_stringname: StringName = StringName(tag)
		if not AbilityTags.is_valid_tag(tag_as_stringname):
			errors.append("invalid tag in applicable_tags: '%s'" % tag)

	# Modifier validation (ensure multipliers are reasonable)
	if damage_multiplier < 0:
		errors.append("damage_multiplier must be >= 0")

	if cooldown_multiplier < 0:
		errors.append("cooldown_multiplier must be >= 0")

	if range_multiplier < 0:
		errors.append("range_multiplier must be >= 0")

	if area_multiplier < 0:
		errors.append("area_multiplier must be >= 0")

	if projectile_speed_multiplier < 0:
		errors.append("projectile_speed_multiplier must be >= 0")

	return errors
