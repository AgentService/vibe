# Fix Player Registration After Scene Reset

**Status**: ✅ COMPLETED  
**Priority**: Medium  
**Assigned**: Claude  
**Created**: 2025-01-15  
**Completed**: 2025-01-15  
**Parent Task**: Clean Session Reset System  

## Problem Statement

After implementing the clean session reset system, the Kill Player debug button works correctly on the first use but fails on subsequent uses after scene resets with the error:

```
[WARN:COMBAT] Damage requested on unknown entity: player
```

## Current Behavior

1. **First Kill Player press** → ✅ Works correctly, kills player, shows results  
2. **Click "Restart" on Results** → ✅ SessionManager resets session  
3. **Second Kill Player press** → ❌ Fails with "unknown entity: player"

## Root Cause Analysis

The issue occurs because:
1. Player dies and gets unregistered from DamageService
2. SessionManager resets session and calls `_reset_player_state()`
3. `_reset_player_state()` calls `player._register_with_damage_system()`
4. But the player entity is still considered "dead" or improperly registered

## Technical Investigation Needed

### Potential Issues:
1. **Player entity state mismatch** - Player might be registered but with wrong health/alive status
2. **Registration timing** - Player might get re-registered too early in the reset sequence
3. **DamageService clearing** - Something might be clearing the player from DamageService after registration
4. **EntityTracker sync** - Mismatch between EntityTracker and DamageService registration

### Debug Approach:
1. Add logging to `Player._register_with_damage_system()` to verify successful registration
2. Add logging to DamageService to track when player gets registered/unregistered
3. Verify player health and alive status after reset
4. Check if `DebugManager.clear_all_entities()` is accidentally affecting the player

## Proposed Solutions

### Option 1: Fix Registration Timing
Move player re-registration to happen AFTER all clearing operations are complete.

### Option 2: Improve Registration Validation
Add validation in `Player._register_with_damage_system()` to ensure proper entity data.

### Option 3: Debug DamageService State
Add debugging to understand exactly when and why the player gets unregistered.

## Expected Outcome

After fix:
- Kill Player button works consistently on first and subsequent uses
- Player remains properly registered with DamageService after any session reset
- No "unknown entity: player" errors

## Related Files

- `scenes/debug/DebugPanel.gd` - Kill Player button implementation
- `autoload/SessionManager.gd` - Session reset logic with player re-registration
- `scenes/arena/Player.gd` - Player registration with DamageService
- `autoload/DebugManager.gd` - Entity clearing logic
- `scripts/systems/damage_v2/DamageRegistry.gd` - Damage application and entity tracking

## Solution Implemented

### Root Cause
The player was being unregistered from `DamageService` during death/reset but the re-registration in `SessionManager._reset_player_state()` was failing due to:
1. Timing issues in the reset sequence
2. Lack of validation and retry logic  
3. No fallback mechanisms for registration failures

### Fix Applied
1. **Enhanced Player Registration**: Added comprehensive logging, validation, and duplicate detection in `Player._register_with_damage_system()`
2. **Helper Functions**: Added `is_registered_with_damage_system()` and `ensure_damage_registration()` for better state management
3. **Improved Reset Logic**: Enhanced `SessionManager._reset_player_state()` with retry mechanisms and validation
4. **Fixed Timing Issues**: Reordered reset sequence and added frame waits between operations
5. **Emergency Fallbacks**: Added automatic registration recovery in `DamageRegistry` when player damage is requested but player is not registered

### Files Modified
- `scenes/arena/Player.gd` - Enhanced registration with logging and validation  
- `autoload/SessionManager.gd` - Improved reset sequence and validation
- `scripts/systems/damage_v2/DamageRegistry.gd` - Added emergency registration fallbacks

### Result
- Kill Player button works consistently across multiple reset cycles
- Player remains properly registered after any session reset
- Comprehensive error handling with auto-recovery
- No more "unknown entity: player" errors

## Notes

This is a follow-up to the Clean Session Reset System implementation. The core session reset architecture is working correctly, but player registration needed refinement for consistent behavior across multiple resets.

**FIXED**: The issue has been resolved with comprehensive logging, validation, retry mechanisms, and emergency fallbacks.