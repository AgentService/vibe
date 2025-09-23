# Clean Session Reset System - Spaghetti Code Cleanup

**Status**: In Progress  
**Priority**: High  
**Assigned**: Claude  
**Created**: 2025-01-15  

## Problem Statement

The current session reset system has multiple overlapping implementations creating spaghetti code:

- **SessionManager exists but disabled** (`if false:` in DebugSystemControls)
- **3+ different reset systems** doing overlapping cleanup
- **Fragmented code** spread across DebugSystemControls, GameOrchestrator, DebugPanel
- **Lambda capture errors** from deferred cleanup during resets
- **MeleeCone node deletion** during reset causing visual effect errors

## Current Issues

### 1. Lambda Capture Error
- **Location**: `DebugPanel.gd:953` 
- **Cause**: Lambda function captures variables freed during session reset
- **Error**: "Lambda capture at index 0 was freed. Passed 'null' instead."

### 2. MeleeCone Node Not Found
- **Location**: `PlayerAttackHandler.gd:152`
- **Cause**: Session reset deletes all children of MeleeEffects including permanent visual nodes
- **Root**: `DebugSystemControls._clear_projectiles_and_effects()` line 246-247

### 3. Spaghetti Architecture
- **DebugSystemControls**: `_legacy_reset_session()` with 6 different reset steps
- **SessionManager**: Proper design but disabled due to integration issues
- **GameOrchestrator**: Scene transition cleanup in `_on_mode_changed()`
- **DebugPanel**: Direct calls to DebugSystemControls

## Solution Architecture

### Single Source of Truth: SessionManager

Make SessionManager the **ONLY** system that handles resets. All other systems call SessionManager methods.

### Clean Reset Scenarios
```gdscript
// All scenarios route through SessionManager:
- Debug reset button → SessionManager.reset_debug() 
- Player death → SessionManager.reset_player_death()
- Map transitions → SessionManager.reset_map_transition()
- Hideout return → SessionManager.reset_hideout_return() 
- Menu transitions → SessionManager.reset_session()
```

### Clean Reset Sequence
1. **Stop all systems** (WaveDirector, spawning, combat)
2. **Clear all entities** (enemies, bosses, projectiles) 
3. **Reset player state** (position, health)
4. **Reset progression** (conditionally based on scenario)
5. **Clear visual effects** (preserve permanent nodes like MeleeCone)
6. **Emit completion signal** for other systems to react

## Implementation Plan

### Phase 1: Fix and Enable SessionManager ✅
- [x] Fix unused parameter warnings in SessionManager
- [x] Add proper effects clearing that preserves permanent visual nodes
- [x] Test SessionManager functionality in isolation

### Phase 2: Remove Spaghetti Code ✅
- [x] **Delete entirely** from `DebugSystemControls.gd`:
  - `_legacy_reset_session()` 
  - `_reset_player_state()`
  - `_reset_xp_and_progression()`
  - `_reset_wave_systems()`
  - `_clear_projectiles_and_effects()`
  - `_reset_ui_and_session_data()`
- [x] **Remove** duplicate cleanup from `GameOrchestrator._on_mode_changed()`
- [x] **Replace** all reset calls with SessionManager calls

### Phase 3: Fix Core Issues ✅
- [x] **Lambda capture error**: Replace lambda in DebugPanel kill_player with method reference
- [x] **Enable SessionManager** in DebugSystemControls (change `if false:` to `if SessionManager:`)
- [x] **Wire integration points** for death, map transitions, etc.

### Phase 4: Integration Testing ✅
- [x] Test debug reset button functionality
- [x] Test MeleeCone persistence after reset
- [x] Test all reset scenarios (death, map transitions, hideout return)
- [x] Verify no lambda capture errors

### Phase 5: Fix Kill Player Button ✅
- [x] **Identified bug**: WaveDirector._on_player_died() immediately cleared enemies
- [x] **Fixed death flow**: Preserve enemies until results screen, clear only on state transition
- [x] **Proper sequence**: Kill Player → Death → Results (enemies visible) → User action → Reset

## Files to Modify

### Core Changes
- `autoload/SessionManager.gd` - Add effects clearing method, fix integration
- `scripts/systems/debug/DebugSystemControls.gd` - Remove legacy code, enable SessionManager
- `scenes/debug/DebugPanel.gd` - Fix lambda capture, call SessionManager directly
- `autoload/GameOrchestrator.gd` - Remove duplicate cleanup, delegate to SessionManager

### Integration Points
- Death handlers → `SessionManager.reset_player_death()`
- Map transition handlers → `SessionManager.reset_map_transition()`
- Hideout return → `SessionManager.reset_hideout_return()`

## Success Criteria ✅

- [x] **Single reset system**: Only SessionManager handles resets
- [x] **No spaghetti code**: All duplicate/fragmented reset logic removed
- [x] **No errors**: Lambda capture and MeleeCone node errors eliminated
- [x] **Global integration**: All reset scenarios use SessionManager
- [x] **Clean architecture**: One system, one API, clear responsibilities
- [x] **Correct death flow**: Kill Player button preserves enemies until user transitions from results screen

## Related Files

- `autoload/SessionManager.gd`
- `scripts/systems/debug/DebugSystemControls.gd` 
- `scenes/debug/DebugPanel.gd`
- `autoload/GameOrchestrator.gd`
- `scripts/systems/PlayerAttackHandler.gd`

## Final Results ✅

**COMPLETED**: Clean centralized session reset system successfully implemented!

### Issues Eliminated
- ✅ **Lambda capture errors** when pressing Reset Session button
- ✅ **MeleeCone node deletion** causing visual effect errors after reset  
- ✅ **Spaghetti code** with 3+ overlapping reset systems
- ✅ **Kill Player button bug** immediately clearing enemies

### Architecture Achieved
- **Single Source of Truth**: SessionManager handles ALL resets
- **Clean State Flow**: StateManager → SessionManager integration via async calls
- **Proper Death Sequence**: Kill Player → Death → Results (enemies preserved) → User action → Reset
- **Smart Effect Clearing**: Temporary effects cleared, permanent nodes (MeleeCone) preserved

### Technical Implementation
- Removed 150+ lines of duplicate reset logic from DebugSystemControls
- Fixed lambda capture with proper method reference pattern
- Enhanced SessionManager with `_clear_temporary_effects()` for selective cleanup
- Wired StateManager transitions to trigger appropriate SessionManager resets
- Fixed WaveDirector to preserve enemies on player death until results screen transition

### Result
Clean global reset system working for all scenarios: debug reset, player death, map transitions, hideout returns, and menu changes. No more lambda errors, no more node reference issues, no more spaghetti code!