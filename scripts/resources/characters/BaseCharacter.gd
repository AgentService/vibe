extends Resource
class_name BaseCharacter

## BaseCharacter.gd
## Unified character resource combining gameplay stats and shop metadata.
##
## This class contains character identity, base stats, and shop integration.
## Follows the single-resource pattern established by BaseItem, BaseTome, and BaseAbility.
##
## Usage:
##   var character = CharacterManager.get_character("ranger")
##   print(character.character_name)  # "Ranger"
##   print(character.base_max_hp)     # 80

# ============================================================================
# CORE IDENTITY
# ============================================================================

@export_group("Core Identity")

## Unique identifier for this character (e.g., "ranger", "mage", "warrior")
@export var character_id: String = ""

## Display name shown in UI
@export var character_name: String = ""

## Description for character selection and shop UI
@export_multiline var description: String = ""

## Icon texture for UI display
@export var icon: Texture2D = null

# ============================================================================
# CHARACTER STATS (Gameplay)
# ============================================================================

@export_group("Character Stats")

## Base maximum health points
@export var base_max_hp: int = 100

## Base movement speed (pixels per second)
@export var base_movement_speed: float = 200.0

## Base damage multiplier (affects all damage dealt)
@export var base_damage_mult: float = 1.0

## Base pickup radius for XP orbs and items (pixels)
@export var base_pickup_radius: float = 50.0

## Starting abilities (ability_ids) - character begins with these
@export var starting_abilities: Array[String] = []

# ============================================================================
# SHOP METADATA (Optional - for UnlockShop integration)
# ============================================================================

@export_group("Shop Metadata")

## Cost in Rift Fragments to unlock this character (0 = default/starting character)
@export var unlock_cost: int = 100

## Achievement/quest requirement to discover this character
@export_multiline var discovery_requirement: String = ""

## Stat summary displayed in shop UI (e.g., "HP: 80\nSpeed: 220\nDamage: +20%")
@export var stat_summary: String = ""

## Flavor text for lore/atmosphere
@export_multiline var flavor_text: String = ""

## Rarity tier for UI color coding ("common", "uncommon", "rare", "epic", "legendary")
@export var rarity: String = "common"

# ============================================================================
# UI PLACEHOLDERS (Optional - for CharacterSelect legacy compatibility)
# ============================================================================

@export_group("UI Placeholders (Optional)")

## Ability name displayed in character select UI
@export var main_ability_name: String = ""

## Ability description displayed in character select UI
@export_multiline var main_ability_description: String = ""

## Ability icon filename (e.g., "seeking_volley", "whirlwind")
@export var main_ability_icon: String = ""

## Passive name displayed in character select UI
@export var main_passive_name: String = ""

## Passive description displayed in character select UI
@export_multiline var main_passive_description: String = ""

## Passive icon filename (e.g., "speed_boost", "armor")
@export var main_passive_icon: String = ""

# ============================================================================
# COMPATIBILITY ALIASES (for UnlockShop duck typing)
# ============================================================================

## Category for UnlockShop integration (always "characters")
var category: String:
	get:
		return "characters"

## Display name alias for UI consistency
var display_name: String:
	get:
		return character_name


# ============================================================================
# VALIDATION
# ============================================================================

## Validates the character configuration
## Returns an array of error strings. Empty array = valid
func validate() -> Array[String]:
	var errors: Array[String] = []

	# Core identity validation
	if character_id.is_empty():
		errors.append("character_id cannot be empty")

	if character_name.is_empty():
		errors.append("character_name cannot be empty")

	# Character stats validation
	if base_max_hp <= 0:
		errors.append("base_max_hp must be > 0")

	if base_movement_speed <= 0:
		errors.append("base_movement_speed must be > 0")

	if base_damage_mult < 0:
		errors.append("base_damage_mult must be >= 0")

	if base_pickup_radius < 0:
		errors.append("base_pickup_radius must be >= 0")

	# Shop metadata validation
	if unlock_cost < 0:
		errors.append("unlock_cost must be >= 0")

	if not rarity in ["common", "uncommon", "rare", "epic", "legendary"]:
		errors.append("rarity must be one of: common, uncommon, rare, epic, legendary")

	return errors


# ============================================================================
# DEBUGGING
# ============================================================================

## Converts character data to Dictionary for debugging
func to_dict() -> Dictionary:
	return {
		"character_id": character_id,
		"character_name": character_name,
		"description": description,
		"base_max_hp": base_max_hp,
		"base_movement_speed": base_movement_speed,
		"base_damage_mult": base_damage_mult,
		"base_pickup_radius": base_pickup_radius,
		"starting_abilities": starting_abilities,
		"unlock_cost": unlock_cost,
		"rarity": rarity
	}
