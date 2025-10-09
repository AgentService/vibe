## AbilityTags.gd
## Centralized tag system for ability categorization and modifier application.
##
## This class provides StringName constants for ability tags, used for:
## - Categorizing abilities by damage type, delivery method, and scaling behavior
## - Determining which modifiers (tomes) can apply to which abilities
## - Filtering and querying abilities by characteristics
##
## StringName constants (&"tag") are used instead of String for performance:
## - Faster comparisons (pointer equality vs string comparison)
## - Lower memory usage (interned strings)
## - Type safety with static constants
##
## Usage:
##   var ability_tags: Array = [AbilityTags.PROJECTILE, AbilityTags.FIRE]
##   if AbilityTags.is_valid_tag(&"fire"): print("Valid tag")
##   var color: Color = AbilityTags.get_tag_color(&"fire")  # Returns red-orange
extends RefCounted
class_name AbilityTags

# ============================================================================
# DAMAGE CATEGORIES
# Tags that describe the type of damage or effect an ability deals
# ============================================================================

## Base damage-dealing tag - all offensive abilities should have this
const DAMAGE: StringName = &"damage"

## Physical damage type - melee strikes, projectiles without elements
const PHYSICAL: StringName = &"physical"

## Elemental damage type - any elemental effect (fire/cold/lightning)
const ELEMENTAL: StringName = &"elemental"

## Fire damage - burning, ignite, heat-based effects
const FIRE: StringName = &"fire"

## Cold damage - freezing, chilling, ice-based effects
const COLD: StringName = &"cold"

## Lightning damage - shocking, chain, electricity-based effects
const LIGHTNING: StringName = &"lightning"

## Poison damage - toxic, corrosive, nature-based effects
const POISON: StringName = &"poison"

# ============================================================================
# DELIVERY METHODS
# Tags that describe how an ability manifests or is delivered
# ============================================================================

## Projectile delivery - fires one or more projectiles
const PROJECTILE: StringName = &"projectile"

## Area of effect - damages/affects enemies in an area
const AOE: StringName = &"aoe"

## Melee delivery - close-range strikes
const MELEE: StringName = &"melee"

## Buff - positive effect on player or allies
const BUFF: StringName = &"buff"

## Debuff - negative effect on enemies
const DEBUFF: StringName = &"debuff"

## Orbit - projectiles/entities that orbit the player
const ORBIT: StringName = &"orbit"

# ============================================================================
# SCALING CATEGORIES
# Tags that determine which stats can be scaled by leveling/modifiers
# ============================================================================

## Cooldown scaling - ability can have cooldown reduced
const COOLDOWN: StringName = &"cooldown"

## Duration scaling - ability effects can last longer
const DURATION: StringName = &"duration"

## Area scaling - ability area/radius can be increased
const AREA: StringName = &"area"

## Speed scaling - projectile/effect speed can be modified
const SPEED: StringName = &"speed"

## Range scaling - ability range can be extended
const RANGE: StringName = &"range"

## Count scaling - number of projectiles/hits can be increased
const COUNT: StringName = &"count"


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Returns all valid ability tags as an array of StringNames.
## Useful for validation, debugging, and UI generation.
static func get_all_tags() -> Array[StringName]:
	var tags: Array[StringName] = []

	# Damage categories
	tags.append(DAMAGE)
	tags.append(PHYSICAL)
	tags.append(ELEMENTAL)
	tags.append(FIRE)
	tags.append(COLD)
	tags.append(LIGHTNING)
	tags.append(POISON)

	# Delivery methods
	tags.append(PROJECTILE)
	tags.append(AOE)
	tags.append(MELEE)
	tags.append(BUFF)
	tags.append(DEBUFF)
	tags.append(ORBIT)

	# Scaling categories
	tags.append(COOLDOWN)
	tags.append(DURATION)
	tags.append(AREA)
	tags.append(SPEED)
	tags.append(RANGE)
	tags.append(COUNT)

	return tags


## Checks if a given tag is a valid ability tag.
## Returns true if the tag exists in the defined constants, false otherwise.
static func is_valid_tag(tag: StringName) -> bool:
	return get_all_tags().has(tag)


## Returns a human-readable description for a given tag.
## Useful for tooltips, documentation, and debugging.
static func get_tag_description(tag: StringName) -> String:
	match tag:
		# Damage categories
		DAMAGE: return "Deals damage to enemies"
		PHYSICAL: return "Physical damage type"
		ELEMENTAL: return "Elemental damage type"
		FIRE: return "Fire damage - burning effects"
		COLD: return "Cold damage - freezing effects"
		LIGHTNING: return "Lightning damage - shocking effects"
		POISON: return "Poison damage - toxic effects"

		# Delivery methods
		PROJECTILE: return "Fires projectiles"
		AOE: return "Area of effect"
		MELEE: return "Close-range melee"
		BUFF: return "Beneficial effect"
		DEBUFF: return "Negative effect on enemies"
		ORBIT: return "Orbits around player"

		# Scaling categories
		COOLDOWN: return "Cooldown can be reduced"
		DURATION: return "Duration can be extended"
		AREA: return "Area can be increased"
		SPEED: return "Speed can be modified"
		RANGE: return "Range can be extended"
		COUNT: return "Count can be increased"

		_: return "Unknown tag"


## Returns a representative color for a given tag.
## Useful for UI highlighting, visual effects, and debugging displays.
static func get_tag_color(tag: StringName) -> Color:
	match tag:
		# Damage categories - warm colors
		DAMAGE: return Color(0.9, 0.3, 0.3)  # Red
		PHYSICAL: return Color(0.7, 0.7, 0.7)  # Gray
		ELEMENTAL: return Color(0.8, 0.5, 1.0)  # Purple
		FIRE: return Color(1.0, 0.5, 0.1)  # Orange-red
		COLD: return Color(0.3, 0.7, 1.0)  # Cyan
		LIGHTNING: return Color(0.9, 0.9, 0.3)  # Yellow
		POISON: return Color(0.3, 0.8, 0.3)  # Green

		# Delivery methods - neutral colors
		PROJECTILE: return Color(0.6, 0.6, 0.9)  # Light blue
		AOE: return Color(0.9, 0.6, 0.3)  # Orange
		MELEE: return Color(0.8, 0.4, 0.4)  # Dark red
		BUFF: return Color(0.3, 0.9, 0.5)  # Bright green
		DEBUFF: return Color(0.7, 0.3, 0.7)  # Purple
		ORBIT: return Color(0.5, 0.8, 0.9)  # Sky blue

		# Scaling categories - cool colors
		COOLDOWN: return Color(0.4, 0.6, 0.9)  # Blue
		DURATION: return Color(0.6, 0.4, 0.9)  # Violet
		AREA: return Color(0.5, 0.7, 0.6)  # Teal
		SPEED: return Color(0.9, 0.7, 0.3)  # Gold
		RANGE: return Color(0.6, 0.8, 0.5)  # Light green
		COUNT: return Color(0.8, 0.6, 0.8)  # Pink

		_: return Color(0.5, 0.5, 0.5)  # Default gray
