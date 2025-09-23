# Fix Production Dependency on Debug Systems

**Status**: To Do  
**Priority**: 🚨 **CRITICAL** - Production Breaking  
**Assigned**: Claude  
**Created**: 2025-01-15  
**Category**: Architecture / Production Safety  

## Problem Statement

🚨 **CRITICAL PRODUCTION BUG**: Core game functionality (scene transitions, death, session resets) depends on `DebugManager.clear_all_entities()`, which is fundamentally wrong for production builds.

### Current Broken Dependencies:
- `SessionManager._clear_entities()` → **requires** `DebugManager.clear_all_entities()`
- `WaveDirector.clear_all_enemies()` → **routes through** `DebugManager.clear_all_entities()`  
- **All production reset scenarios depend on debug code**
- **XP orbs and transient objects have no cleanup system**

### Impact:
- 🚨 If DebugManager is disabled/removed for production builds, **the game will break**
- 🚨 Scene transitions will fail silently
- 🚨 Death sequences won't clear entities properly
- 🚨 Memory leaks from uncleaned XP orbs, future items

## Root Cause

The entity clearing functionality was incorrectly placed in `DebugManager` instead of a production system. This violates the basic principle that **debug systems should be optional overlays**, not required infrastructure.

## Technical Investigation

### Current Call Chain:
1. Player dies or requests hideout return
2. `SessionManager._clear_entities()`
3. **Requires** `DebugManager.clear_all_entities()`
4. If DebugManager unavailable → **FAILS**

### Files Affected:
- `autoload/SessionManager.gd:169-173` - Hard dependency on DebugManager
- `scripts/systems/WaveDirector.gd:677-682` - Routes through DebugManager
- `autoload/DebugManager.gd:148-174` - Contains production logic
- **All test files** - Depend on DebugManager for core functionality

## Proposed Solution

### 1. Create EntityClearingService (Production Autoload)
**New production autoload for entity management:**
```gdscript
# autoload/EntityClearingService.gd
extends Node

func clear_all_entities() -> void:
    # Clear via damage system (triggers proper death sequence)
    var entities = EntityTracker.get_alive_entities()
    for entity_id in entities:
        DamageService.apply_damage(entity_id, 999999, "system_clear", ["clear"])
    
func clear_transient_objects() -> void:
    # Clear XP orbs, items, projectiles, etc.
    var transients = get_tree().get_nodes_in_group("transient")
    for obj in transients:
        obj.queue_free()
    
func clear_all_world_objects() -> void:
    # Combined clear for complete reset
    clear_all_entities()
    await get_tree().process_frame  # Let death events process
    clear_transient_objects()
```

### 2. Remove DebugManager Dependencies
**Update SessionManager:**
```gdscript
# In SessionManager._clear_entities()
func _clear_entities() -> void:
    if EntityClearingService:
        EntityClearingService.clear_all_world_objects()
    else:
        Logger.error("EntityClearingService not available!", "session")
```

### 3. Convert DebugManager to Optional Overlay
**DebugManager becomes pure debug wrapper:**
```gdscript
# DebugManager.clear_all_entities() becomes optional wrapper
func clear_all_entities() -> void:
    Logger.debug("Debug: Triggering entity clear via production system", "debug")
    if EntityClearingService:
        EntityClearingService.clear_all_world_objects()
```

### 4. Add Unified Transient Object System
**Auto-register transient objects for cleanup:**
```gdscript
# In XpSystem._spawn_xp_orb() and future item/drop systems
func _spawn_xp_orb(pos: Vector2, xp_value: int) -> void:
    var orb: XPOrb = XP_ORB_SCENE.instantiate()
    orb.add_to_group("transient")  # Auto-register for cleanup
    _arena_node.add_child(orb)
```

## Implementation Plan

### Phase 1: Create Production System ⚠️ **CRITICAL**
1. Create `autoload/EntityClearingService.gd`
2. Add to `project.godot` autoload list
3. Implement `clear_all_entities()` and `clear_transient_objects()` methods

### Phase 2: Remove Debug Dependencies ⚠️ **CRITICAL**  
1. Update `SessionManager._clear_entities()` to use EntityClearingService
2. Update `WaveDirector.clear_all_enemies()` to use production system
3. Test all reset scenarios (death, hideout return, debug reset)

### Phase 3: Fix Transient Objects
1. Enhance `XpSystem` to auto-register XP orbs as "transient"
2. Update future item/drop systems to use same pattern
3. Test XP orb cleanup during resets

### Phase 4: Convert Debug to Overlay
1. Make `DebugManager.clear_all_entities()` optional wrapper
2. Update all test files to use EntityClearingService
3. Ensure DebugManager can be safely disabled

## Success Criteria

### Critical Requirements:
- ✅ **Game functions without DebugManager** - Can disable debug systems safely
- ✅ **Single clear call works** - `EntityClearingService.clear_all_world_objects()` 
- ✅ **XP orbs get cleared** - No more persistent orbs after reset
- ✅ **Proper death sequence** - Entities die → XP orbs spawn → cleanup
- ✅ **All reset scenarios work** - Death, hideout return, debug reset

### Test Validation:
- Scene transitions work with DebugManager disabled
- XP orbs don't persist across resets
- Enemy clearing still triggers proper death events
- All existing functionality preserved

## Risk Assessment

**Risk**: HIGH - Core production functionality  
**Impact**: Game-breaking in production builds  
**Mitigation**: Thorough testing of all reset scenarios

## Related Systems

- **SessionManager** - Primary consumer of clearing functionality
- **WaveDirector** - Enemy spawning and clearing
- **XpSystem** - Transient object spawning  
- **EntityTracker/DamageService** - Entity management
- **Future ItemSystem** - Will need same transient pattern

## Notes

This is a **critical architecture fix** that should be prioritized over features. The current system is a production time bomb - if DebugManager gets disabled or removed, core game functionality breaks silently.

The fix maintains all current behavior while making the architecture production-safe and extensible for future transient objects (items, power-ups, etc.).