# Balance System .tres Migration

**Status**: 📋 **TODO**  
**Priority**: Medium  
**Type**: Balance Migration  
**Created**: 2025-08-23  
**Context**: Migrate balance JSON files to .tres resources

## Overview

Convert all balance tuning JSON files to .tres resources for type safety and Inspector editing while maintaining the BalanceDB pattern.

## Files to Migrate

- [ ] `vibe/data/balance/combat.json` → `combat_balance.tres`
- [ ] `vibe/data/balance/abilities.json` → `abilities_balance.tres`
- [ ] `vibe/data/balance/melee.json` → `melee_balance.tres`
- [ ] `vibe/data/balance/waves.json` → `waves_balance.tres`
- [ ] `vibe/data/balance/player.json` → `player_balance.tres`

## Implementation Steps

### Phase 1: Create Balance Resource Classes

#### Create CombatBalance Resource
- [ ] Create `CombatBalance.gd` resource class in `scripts/domain/`
- [ ] Add @export properties:
  - projectile_radius (float)
  - enemy_radius (float)
  - base_damage (float)
  - crit_chance (float)
  - crit_multiplier (float)

#### Create AbilitiesBalance Resource
- [ ] Create `AbilitiesBalance.gd` resource class
- [ ] Add properties for:
  - max_projectiles (int)
  - projectile_speed (float)
  - projectile_ttl (float)
  - arena_bounds (float)

#### Create MeleeBalance Resource
- [ ] Create `MeleeBalance.gd` resource class
- [ ] Add properties based on melee.json structure

#### Create WavesBalance Resource
- [ ] Create `WavesBalance.gd` resource class
- [ ] Add properties for:
  - max_enemies (int)
  - spawn_interval (float)
  - arena_center (Vector2)
  - spawn_radius (float)
  - enemy_speed_min/max (float)
  - spawn_count_min/max (int)
  - arena_bounds (float)
  - target_distance (float)

#### Create PlayerBalance Resource
- [ ] Create `PlayerBalance.gd` resource class
- [ ] Add properties based on player.json structure

### Phase 2: Convert Balance Files
- [ ] Convert each JSON to corresponding .tres resource
- [ ] Verify all numeric values transfer correctly
- [ ] Test resource loading in Inspector

### Phase 3: Update BalanceDB System
- [ ] Update BalanceDB autoload to load .tres resources
- [ ] Maintain the same API for accessing balance values
- [ ] Update balance loading to use ResourceLoader
- [ ] Keep hot-reload capability if possible

### Phase 4: Update Dependent Systems
- [ ] Update all systems that use BalanceDB
- [ ] Ensure combat calculations remain identical  
- [ ] Verify wave spawning uses correct values
- [ ] Test ability system with new balance resources

## Systems to Update

### BalanceDB Autoload
- [ ] Update to load .tres resources instead of JSON
- [ ] Maintain existing get() API
- [ ] Keep balance value caching if present

### Systems Using Balance Values
- [ ] Combat systems reading combat balance
- [ ] Wave spawning reading waves balance
- [ ] Ability systems reading abilities balance
- [ ] Player systems reading player balance
- [ ] Melee systems reading melee balance

## Testing Strategy

### Validation Testing
- [ ] Compare balance values before/after migration
- [ ] Run balance validation tests if they exist
- [ ] Verify no numerical precision lost

### Gameplay Testing  
- [ ] Test combat damage calculations
- [ ] Test wave spawning rates/counts
- [ ] Test ability cooldowns/ranges
- [ ] Test player stats/progression
- [ ] Test melee combat values

### Performance Testing
- [ ] Ensure balance loading performance unchanged
- [ ] Test hot-reload if implemented
- [ ] Verify memory usage reasonable

## Migration Notes

### Maintain BalanceDB Pattern
- Keep the centralized balance access pattern
- Don't change the API that systems use to get balance values
- Preserve any hot-reload functionality

### Inspector Benefits
- Add helpful descriptions to @export properties
- Use appropriate editor hints (ranges, enums)
- Group related properties logically

## Success Criteria

- ✅ All 5 balance files converted to .tres
- ✅ Balance resource classes with proper @export properties
- ✅ BalanceDB loads .tres resources instead of JSON
- ✅ All balance values accessible via same API
- ✅ Gameplay behavior identical to JSON version
- ✅ Inspector editing provides better UX than JSON
- ✅ JSON parsing code removed