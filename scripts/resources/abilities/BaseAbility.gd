## BaseAbility.gd
## Ultra-minimal base class for ALL ability types.
##
## This class contains ONLY properties used by 100% of abilities:
## - Core identity (ID, name, description, icon, tags)
## - Basic progression (level tracking only)
## - Visual references (scene/effects - can be null)
##
## Subclass Hierarchy:
## - DamageAbility → Adds damage stats, cooldown, scaling (most abilities)
##   - ProjectileAbility → Adds projectile-specific properties
##   - MeleeAbility → Adds melee-specific properties
##   - AoEAbility → Adds AOE-specific properties
## - UtilityAbility → Non-damage abilities (buffs, shields, utility)
##   - BuffAbility → Player buffs
##   - ShieldAbility → Damage absorption
##
## Design Philosophy:
## - BaseAbility is TRULY minimal - only universal properties
## - Type-specific properties live in subclasses for clear .tres files
## - Designer opens ranger_arrow.tres → sees ONLY relevant properties
extends Resource
class_name BaseAbility

# ============================================================================
# CORE IDENTITY (100% of abilities use these)
# ============================================================================

@export_group("Core Identity")

## Unique identifier for this ability (e.g., "ranger_arrow", "fireball")
@export var ability_id: String = ""

## Display name shown in UI
@export var ability_name: String = ""

## Description for tooltips and ability selection UI
@export_multiline var description: String = ""

## Icon texture for UI display (can be null)
@export var icon: Texture2D

# ============================================================================
# TAGS (100% of abilities use these)
# ============================================================================

@export_group("Tags")

## Ability tags for categorization and modifier matching
## Use AbilityTags constants: ["projectile", "damage", "fire"]
## Tags determine which tomes/modifiers can apply to this ability
@export var tags: Array[String] = []

# ============================================================================
# PROGRESSION (100% of abilities use these)
# ============================================================================

@export_group("Progression")

## Current level of this ability (modified at runtime)
@export var ability_level: int = 1

## Maximum level this ability can reach
@export var max_level: int = 20

# ============================================================================
# VISUAL REFERENCES (Optional - can be null)
# ============================================================================

@export_group("Visuals")

## Scene to instance for ability visual (projectile, effect, etc.)
## Can be null if no visual representation needed
@export var visual_scene: PackedScene

## Impact effect scene (particles, flash, etc.)
## Can be null if no impact effect needed
@export var impact_effect: PackedScene

# ============================================================================
# SHOP METADATA (Optional - for UnlockShop integration)
# ============================================================================

@export_group("Shop Metadata")

## Cost in Rift Fragments to unlock this ability (0 = default/starting ability)
@export var unlock_cost: int = 100

## Achievement/quest requirement to discover this ability
@export_multiline var discovery_requirement: String = ""

## Stat summary displayed in shop UI (e.g., "Damage: 25\nCooldown: 1.5s")
@export var stat_summary: String = ""

## Flavor text for lore/atmosphere
@export_multiline var flavor_text: String = ""

## Rarity tier for UI color coding ("common", "uncommon", "rare", "epic", "legendary")
@export var rarity: String = "common"

# ============================================================================
# COMPATIBILITY ALIASES (for UnlockShop duck typing)
# ============================================================================

## Category for UnlockShop integration (always "skills")
var category: String:
	get:
		return "skills"

## Display name alias for UI consistency
var display_name: String:
	get:
		return ability_name

## Description alias for UI consistency
var description_text: String:
	get:
		return description


# ============================================================================
# TAG HELPER METHODS
# ============================================================================

## Checks if this ability has a specific tag
func has_tag(tag: StringName) -> bool:
	return tags.has(tag) or tags.has(str(tag))


## Checks if this ability has ALL of the specified tags
func has_all_tags(required_tags: Array) -> bool:
	for tag in required_tags:
		if not has_tag(tag):
			return false
	return true


## Checks if this ability has ANY of the specified tags
func has_any_tag(possible_tags: Array) -> bool:
	for tag in possible_tags:
		if has_tag(tag):
			return true
	return false


# ============================================================================
# ACTIVATION (Virtual method - override in subclasses)
# ============================================================================

## Activates the ability (auto-fire compatible)
## Called automatically by ability systems when cooldown is ready
##
## Parameters:
##   player: Node2D - The player node (for position, context)
##   context: Dictionary - Additional context (target_enemy, etc.)
##
## This is a virtual method meant to be overridden by subclasses
func activate(player: Node2D, context: Dictionary) -> void:
	push_warning("BaseAbility.activate() called for '%s' - should be overridden" % ability_id)


# ============================================================================
# DEBUGGING & VALIDATION
# ============================================================================

## Converts ability data to Dictionary for debugging
## Includes only BaseAbility properties (subclasses extend this)
func to_dict() -> Dictionary:
	return {
		"ability_id": ability_id,
		"ability_name": ability_name,
		"description": description,
		"level": ability_level,
		"max_level": max_level,
		"tags": tags
	}


## Validates the ability configuration
## Returns an array of error strings. Empty array = valid
##
## Checks only BaseAbility properties (subclasses extend validation)
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

	# Tag validation
	if tags.is_empty():
		errors.append("abilities should have at least one tag")

	for tag in tags:
		var tag_as_stringname: StringName = StringName(tag)
		if not AbilityTags.is_valid_tag(tag_as_stringname):
			errors.append("invalid tag: '%s'" % tag)

	return errors
