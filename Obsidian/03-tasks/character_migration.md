# Character System Migration Task

**Status:** 📋 Planned (Not Started)

## Goal
Migrate characters from legacy ItemMetadata to unified BaseCharacter resource with shop metadata, following the established pattern from items/tomes/skills.

## Current State
- ✅ **Items**: Unified to BaseItem (single-resource)
- ✅ **Tomes**: Unified to BaseTome (single-resource)
- ✅ **Skills**: Unified to BaseAbility (single-resource)
- ❌ **Characters**: Still using legacy ItemMetadata files

## Migration Steps

### 1. Create BaseCharacter.gd Resource
**Location:** `scripts/resources/characters/BaseCharacter.gd`

**Structure:**
```gdscript
extends Resource
class_name BaseCharacter

# Core Identity
@export_group("Core Identity")
@export var character_id: String = ""
@export var character_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null

# Character Stats (gameplay)
@export_group("Character Stats")
@export var base_max_hp: int = 100
@export var base_movement_speed: float = 200.0
@export var base_damage_mult: float = 1.0
@export var base_pickup_radius: float = 50.0
@export var starting_abilities: Array[String] = []  # ability_ids

# Shop Metadata
@export_group("Shop Metadata")
@export var unlock_cost: int = 100
@export_multiline var discovery_requirement: String = ""
@export var stat_summary: String = ""
@export_multiline var flavor_text: String = ""
@export var rarity: String = "common"

# Compatibility Aliases (for UnlockShop duck typing)
var category: String:
    get: return "characters"

var display_name: String:
    get: return character_name
```

### 2. Create CharacterManager Autoload
**Location:** `autoload/CharacterManager.gd`

**Purpose:**
- Load character definitions from `data/content/characters/*.tres`
- Single-resource pattern (no dual registry)
- Public API: `get_character(character_id: String) -> BaseCharacter`
- Hot-reload support with `ResourceLoader.CACHE_MODE_IGNORE`

**Pattern:** Follow ItemManager.gd structure (single registry, simple loading)

### 3. Migrate Character Files
**Location:** `data/content/characters/`

**Example Migration:**
```tres
# OLD: character_name_metadata.tres (ItemMetadata)
[resource]
script = ExtResource("ItemMetadata")
item_id = "ranger"
display_name = "Ranger"
category = "characters"
...

# NEW: ranger.tres (BaseCharacter)
[resource]
script = ExtResource("BaseCharacter")
character_id = "ranger"
character_name = "Ranger"
description = "Swift archer specializing in rapid projectile attacks"
base_max_hp = 80
base_movement_speed = 220.0
starting_abilities = ["seeking_volley"]
unlock_cost = 150
discovery_requirement = "Reach wave 10 with any character"
stat_summary = "HP: 80\nSpeed: 220\nStarting: Seeking Volley"
flavor_text = "Master of bow and arrow, the Ranger strikes from afar."
rarity = "uncommon"
```

### 4. Update Shop UI (Already Done!)
**Files:** `UnlockShopScene.gd`, `UnlockShop.gd`, `ShopItemCard.gd`, `ShopAdminPanel.gd`

**Status:** ✅ Duck typing already supports any resource type
- ID extraction: Checks for `character_id`, `ability_id`, `tome_id`, `item_id`
- Icon loading: Supports both `icon: Texture2D` and `icon_path: String`
- Category: All unified resources have `.category` alias

**No additional changes needed** - shop UI will automatically work with BaseCharacter!

### 5. Update Character Selection UI
**Files:** Character selection screens, character info panels

**Changes Needed:**
- Replace ItemMetadata references with BaseCharacter
- Use CharacterManager.get_character() instead of legacy loading
- Update character stat displays to use BaseCharacter properties

### 6. Delete Legacy Files
- Remove old character ItemMetadata files after migration
- Update any remaining ItemMetadata references in codebase
- Consider removing ItemMetadata.gd entirely if no longer used

## Estimated Time
- **BaseCharacter.gd creation:** ~30 minutes
- **CharacterManager.gd creation:** ~45 minutes (follow ItemManager pattern)
- **Character file migration:** ~1-2 hours (depends on number of characters)
- **Character selection UI updates:** ~1 hour
- **Testing & verification:** ~30 minutes
- **Total:** ~3.5-4.5 hours

## Architecture Benefits
- **Consistency:** All content types use single-resource pattern
- **Maintainability:** One file per character (not two)
- **Shop Integration:** Unified unlock/discovery system
- **Future-Proof:** Easy to extend with new character fields

## Notes
- Follow minimal .tres pattern (only non-default properties)
- Use compatibility aliases for duck typing (`category`, `display_name`)
- CharacterManager should follow ItemManager/TomeManager patterns
- No need to manually set discovered/unlocked states (default to locked)

## Related Files
- Reference: `scripts/resources/items/BaseItem.gd`
- Reference: `scripts/resources/tomes/BaseTome.gd`
- Reference: `scripts/resources/abilities/BaseAbility.gd`
- Reference: `autoload/ItemManager.gd`
- Reference: `autoload/TomeManager.gd`

---
**When Ready to Start:** Remove from `.tasks/` and add to active TodoWrite list
