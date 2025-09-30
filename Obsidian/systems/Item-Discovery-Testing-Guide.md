# Item Discovery & Unlock System - Testing Guide

## Overview
Phase 9 implements MEGABONK/ROR2-style item discovery where items found in runs can be purchased with Rift Fragments and then appear in future run drop pools.

## Architecture

### MetaProgression API
- `discover_item(category, item_id)` - Add item to discovered list (found in run)
- `unlock_item(category, item_id)` - Move item from discovered → unlocked
- `get_discovered_items(category)` - Get items waiting to be purchased
- `get_unlocked_items(category)` - Get items available in drop pools
- `add_rift_fragments(amount)` - Award currency
- `spend_rift_fragments(cost)` - Purchase items

### Categories
- **"items"** - Passive stat items (Cheese, Clover, Feather)
- **"tomes"** - Skill modifiers (not yet implemented)
- **"skills"** - Active abilities (not yet implemented)

### Item Metadata
Items defined in `data/content/items/*.tres`:
- **Cheese** - +10% Max HP (50 fragments, Common)
- **Clover** - +10% Luck (75 fragments, Uncommon)
- **Feather** - +15% Move Speed (100 fragments, Rare)

## Debug Commands

Open LimboConsole (F2) and use these commands:

### 1. Give Rift Fragments
```
give_fragments 500
```
Awards 500 Rift Fragments for testing purchases.

### 2. Discover Items
```
discover_item items cheese
discover_item items clover
discover_item items feather
```
Simulates finding items in a run. Items move to "discovered" list.

### 3. Check Progression State
```
progression_info
```
Shows current Rift Fragment balance and discovered/unlocked counts.

## Testing Flow

### Test 1: Basic Discovery & Purchase
1. Start Godot, open MainMenu scene
2. Open console (F2): `give_fragments 500`
3. Console: `discover_item items cheese`
4. Click "SHOP" button on main menu
5. Verify "Cheese" appears in shop with unlock button
6. Click "UNLOCK" button (costs 50 fragments)
7. Verify item disappears from shop (moved to unlocked)
8. Console: `progression_info` - verify cheese in unlocked list

### Test 2: Cannot Afford Item
1. Console: `give_fragments 50` (not enough for Clover at 75)
2. Console: `discover_item items clover`
3. Open shop
4. Verify "UNLOCK" button is disabled (grayed out)

### Test 3: Multiple Items
1. Console: `give_fragments 1000`
2. Console: `discover_item items cheese`
3. Console: `discover_item items clover`
4. Console: `discover_item items feather`
5. Open shop
6. Verify all 3 items appear in list
7. Purchase all 3 sequentially
8. Verify shop shows "No items discovered yet" message

### Test 4: Category Switching
1. Discover items in multiple categories
2. Open shop
3. Click "TOMES" tab - verify empty state message
4. Click "SKILLS" tab - verify empty state message
5. Click "ITEMS" tab - verify items reappear

### Test 5: Rift Fragment Display
1. Console: `give_fragments 1234`
2. Open shop
3. Verify top-right shows "1234 💎"
4. Purchase an item
5. Verify balance updates immediately

## Expected Behavior

✅ **Discovery Flow**:
- Items discovered in runs appear in shop "discovered" list
- Items show name, description, stat summary, unlock cost
- Unlock button disabled if not enough fragments

✅ **Purchase Flow**:
- Click UNLOCK → fragments deducted → item moves to unlocked
- Shop refreshes immediately after purchase
- Empty state message when no discovered items

✅ **Persistence**:
- Rift Fragments persist via user://meta_progression.tres
- Discovered/unlocked items persist across sessions
- F5 reload preserves state

## Known Limitations (Phase 9 Scope)

❌ **Not Yet Implemented**:
- In-game item discovery notifications ("New Item Discovered!" popup)
- End-of-run summary showing discovered items
- Drop table integration (unlocked items don't spawn yet)
- Tome and Skill categories (empty)
- Item icons (only text descriptions)

## Next Steps (Post-Phase 9)

1. **In-Game Discovery**: Enemy drops trigger `MetaProgression.discover_item()`
2. **Discovery Popup**: Show "New Item Discovered!" with item info
3. **Results Integration**: Display discovered items on ResultsScreen
4. **Drop Tables**: Only spawn items from `get_unlocked_items()` pool
5. **Item Effects**: Apply stat modifiers when items picked up in runs
6. **Additional Content**: Create tome and skill items

## File References

- **Shop UI**: `scenes/ui/MainMenu.tscn` (lines 215-281)
- **Shop Logic**: `scenes/ui/MainMenu.gd` (lines 362-482)
- **Debug Commands**: `autoload/DebugManager.gd` (lines 614-667)
- **MetaProgression API**: `autoload/MetaProgression.gd` (lines 181-283)
- **Item Resources**: `data/content/items/*.tres`
- **Item Metadata Class**: `scripts/resources/ItemMetadata.gd`
