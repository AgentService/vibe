# Card System .tres Migration

**Status**: 📋 **TODO**  
**Priority**: Medium  
**Type**: Content Migration  
**Created**: 2025-08-23  
**Context**: Migrate card pool JSON to .tres resource

## Overview

Convert card pool JSON to .tres resource for better type safety, validation, and Inspector editing of card definitions.

## Files to Migrate

- [ ] `vibe/data/cards/card_pool.json` → `card_pool.tres`

## Implementation Steps

### Phase 1: Create Resource Classes

#### Create CardDefinition Resource
- [ ] Create `CardDefinition.gd` resource class in `scripts/domain/`
- [ ] Add @export properties:
  - card_id (String)
  - description (String) 
  - min_level (int)
  - weight (int)
  - stat_modifiers (Dictionary)

#### Create CardPool Resource  
- [ ] Create `CardPool.gd` resource class in `scripts/domain/`
- [ ] Add @export properties:
  - pool (Array[CardDefinition])

### Phase 2: Convert Data
- [ ] Parse existing card_pool.json
- [ ] Create individual CardDefinition resources for each card
- [ ] Create CardPool resource containing all cards
- [ ] Save as `card_pool.tres`

### Phase 3: Update CardSystem
- [ ] Update `CardSystem.gd` to load .tres instead of JSON
- [ ] Replace JSON parsing with direct resource loading
- [ ] Update `roll_three()` function to work with CardDefinition objects
- [ ] Test card selection still works

### Phase 4: Update UI
- [ ] Update `CardPicker.gd` to work with CardDefinition resources
- [ ] Ensure card descriptions display correctly
- [ ] Test card selection UI

## Systems to Update

- [ ] `scripts/systems/CardSystem.gd` - main card loading logic
- [ ] `scenes/ui/CardPicker.gd` - UI display of cards
- [ ] Any other systems referencing card data

## Current Card Structure Analysis

From card_pool.json, cards have:
- `id`: unique identifier
- `desc`: description text
- `min_level`: optional minimum level requirement
- `stat_mods`: dictionary of stat modifications
- `weight`: selection probability weight

## Testing

- [ ] Verify card pool loads correctly
- [ ] Test card selection (roll_three) 
- [ ] Verify card descriptions show in UI
- [ ] Test stat modifications apply correctly
- [ ] Test level requirements work

## Success Criteria

- ✅ card_pool.json converted to card_pool.tres
- ✅ CardDefinition and CardPool resource classes created
- ✅ CardSystem loads .tres resources
- ✅ Card selection UI works identically
- ✅ JSON parsing code removed
- ✅ Inspector editing available for cards