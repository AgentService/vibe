# Tome System - Resource Architecture

## Overview
The tome system uses **two parallel resource types** for different purposes:

### 1. ItemMetadata (Meta-Progression)
- **Purpose**: Unlock shop display, discovery tracking, unlock cost
- **Location**: `data/content/tomes/*_tome.tres`
- **Used by**: `UnlockShopScene`, `MetaProgression`
- **Key field**: `item_id` (used for unlock tracking)

### 2. BaseTome (Gameplay)
- **Purpose**: In-game stat modifications, ability modifiers
- **Location**: `data/content/tomes/tome_*.tres`
- **Used by**: `TomeManager`, `AbilityController`
- **Key field**: `tome_id` (used for tome effects)

## File Mapping

| ItemMetadata File | item_id | BaseTome File | tome_id | Status |
|---|---|---|---|---|
| `agility_tome.tres` | agility_tome | `tome_agility.tres` | agility_tome | ✓ Linked |
| `damage_tome.tres` | damage_tome | `tome_damage.tres` | tome_damage | ⚠️ Mismatch |
| `projectiles_tome.tres` | tome_projectiles | `tome_projectiles.tres` | tome_projectiles | ✓ Linked |
| `speed_tome.tres` | tome_speed | `tome_speed.tres` | tome_speed | ✓ Linked |

## Adding New Tomes

When adding a new tome, you must create **BOTH** resource files:

### 1. Create ItemMetadata (Unlock Shop)
```gdscript
# File: data/content/tomes/mytome_tome.tres
[gd_resource type="Resource" script_class="ItemMetadata"]
[resource]
item_id = "tome_mytome"  # Must match BaseTome tome_id!
display_name = "Tome of MyEffect"
description = "What the tome does"
category = "tomes"
icon_path = "res://assets/ui/tomes/icons/my_icon.png"
unlock_cost = 100
rarity = 1  # 0=Common, 1=Uncommon, 2=Rare, 3=Epic, 4=Legendary
discovery_requirement = "Achievement description"
stat_summary = "Effect summary for UI"
```

### 2. Create BaseTome (In-Game)
```gdscript
# File: data/content/tomes/tome_mytome.tres
[gd_resource type="Resource" script_class="BaseTome"]
[resource]
tome_id = "tome_mytome"  # Must match ItemMetadata item_id!
tome_name = "Tome of MyEffect"
description = "In-game description"
# ... set modifiers as needed ...
```

## ID Linking Convention

**IMPORTANT**: For proper integration, `item_id` in ItemMetadata should match `tome_id` in BaseTome.

**Naming Convention**:
- ItemMetadata files: `{name}_tome.tres` (e.g., `speed_tome.tres`)
- BaseTome files: `tome_{name}.tres` (e.g., `tome_speed.tres`)
- Both should use: `item_id = "tome_{name}"` and `tome_id = "tome_{name}"`

**Legacy Mismatch**:
- `damage_tome.tres` (item_id="damage_tome") vs `tome_damage.tres` (tome_id="tome_damage")
- This pre-existing mismatch is preserved for backward compatibility with save files
- New tomes should follow the proper convention above

## Testing

After adding new tome files:
1. **UnlockShop Test**: Open the unlock shop, navigate to Tomes tab, verify new tome appears
2. **In-Game Test**: Use AbilityTestingPopup (debug panel) to equip and test the tome
3. **Unlock Test**: Use ShopAdminPanel to discover/unlock, verify tome becomes usable

## Architecture Notes

- **UnlockShop** loads ItemMetadata files to populate the shop UI
- **TomeManager** loads BaseTome files for gameplay mechanics
- **AbilityTestingPopup** bypasses unlock checks (debug tool)
- **MetaProgression** tracks unlock state by item_id from ItemMetadata
- No direct code links item_id → tome_id currently, but matching IDs enables future integration
