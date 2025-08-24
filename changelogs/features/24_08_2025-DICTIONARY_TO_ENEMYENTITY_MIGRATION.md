# Dictionary to EnemyEntity Migration
**Date:** 2025-08-24  
**Type:** Architecture Refactor  
**Impact:** High - Complete enemy system type safety improvement

## Summary
Completed migration from legacy JSON Dictionary-based enemy system to typed EnemyEntity objects throughout the runtime systems while maintaining rendering compatibility.

## Technical Changes

### Core Migration
- **WaveDirector**: Changed from `Array[Dictionary]` to `Array[EnemyEntity]`
- **Enemy Access Pattern**: Updated from `enemy["property"]` to `enemy.property` throughout codebase
- **Type Safety**: All enemy operations now use typed EnemyEntity objects instead of untyped Dictionaries

### System Updates
- **DamageSystem**: Updated collision detection and damage application to work with EnemyEntity objects
- **MeleeSystem**: Added WaveDirector reference for proper enemy pool index resolution
- **EnemyRadar**: Updated to handle `Array[EnemyEntity]` input instead of `Array[Dictionary]`
- **Arena.gd**: Updated signal connections and enemy data flow

### Critical Fixes
- **Dead Enemy Damage Warnings**: Fixed issue where damage requests were sent to already-dead enemies
- **Pool Index Resolution**: Improved enemy pool index finding using object identity instead of position comparison
- **Collision Safety**: Added runtime checks to prevent processing dead enemies during collision detection

### Rendering Compatibility
- **Dictionary Conversion**: Maintained MultiMesh compatibility via `enemy.to_dictionary()` method
- **Performance**: Preserved rendering performance while gaining runtime type safety
- **EnemyRenderTier**: Updated to handle EnemyEntity → Dictionary conversion for tier-based rendering

## Architecture Benefits

### Before (Dictionary-based)
```gdscript
var enemies: Array[Dictionary] = []
enemy["pos"] = new_position
if enemy["alive"]:
    enemy["hp"] -= damage
```

### After (EnemyEntity-based)
```gdscript
var enemies: Array[EnemyEntity] = []
enemy.pos = new_position
if enemy.alive:
    enemy.hp -= damage
```

### Hybrid Approach
- **Runtime Logic**: Uses typed `EnemyEntity` objects for type safety and IDE support
- **Rendering**: Uses `Dictionary` snapshots via `enemy.to_dictionary()` for MultiMesh compatibility
- **Best of Both**: Type safety + performance + compatibility

## Performance Impact
- **Positive**: Better memory layout with typed objects
- **Neutral**: Rendering performance maintained via Dictionary conversion
- **Positive**: Eliminated runtime type checking and casting overhead

## Signal Architecture
- **EventBus.enemies_updated**: Now emits `Array[EnemyEntity]` instead of `Array[Dictionary]`
- **Arena collision systems**: Updated to handle typed enemy objects
- **Damage request flow**: Uses proper pool indices from full enemy pool

## Testing Results
- **Compilation**: Clean compilation with no script errors
- **Runtime**: No more "dead enemy damage" warnings
- **Combat**: Proper enemy death detection and cleanup
- **Rendering**: Enemies visible and properly tiered in MultiMesh system

## Migration Notes
This completes the transition away from the legacy JSON-based Dictionary system that was a holdover from the original file-based configuration approach. The system now uses modern Godot Resource (.tres) files for content definition and typed objects for runtime logic.

## Related Systems
- **EnemyType Resource System**: `.tres` files define enemy characteristics
- **BalanceDB**: JSON-based balance values (separate from content)
- **ContentDB**: Resource-based content loading
- **MultiMesh Rendering**: Dictionary-based bulk rendering for performance

## Future Considerations
- All new enemy-related features should use EnemyEntity objects
- Dictionary access patterns are now deprecated in favor of typed properties
- The `enemy.to_dictionary()` method provides backward compatibility for any remaining Dictionary-dependent code