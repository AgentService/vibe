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
- [ ] Add proper effects clearing that preserves permanent visual nodes
- [ ] Test SessionManager functionality in isolation

### Phase 2: Remove Spaghetti Code
- [ ] **Delete entirely** from `DebugSystemControls.gd`:
  - `_legacy_reset_session()` 
  - `_reset_player_state()`
  - `_reset_xp_and_progression()`
  - `_reset_wave_systems()`
  - `_clear_projectiles_and_effects()`
  - `_reset_ui_and_session_data()`
- [ ] **Remove** duplicate cleanup from `GameOrchestrator._on_mode_changed()`
- [ ] **Replace** all reset calls with SessionManager calls

### Phase 3: Fix Core Issues
- [ ] **Lambda capture error**: Replace lambda in DebugPanel kill_player with method reference
- [ ] **Enable SessionManager** in DebugSystemControls (change `if false:` to `if SessionManager:`)
- [ ] **Wire integration points** for death, map transitions, etc.

### Phase 4: Integration Testing
- [ ] Test debug reset button functionality
- [ ] Test MeleeCone persistence after reset
- [ ] Test all reset scenarios (death, map transitions, hideout return)
- [ ] Verify no lambda capture errors

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

## Success Criteria

- [ ] **Single reset system**: Only SessionManager handles resets
- [ ] **No spaghetti code**: All duplicate/fragmented reset logic removed
- [ ] **No errors**: Lambda capture and MeleeCone node errors eliminated
- [ ] **Global integration**: All reset scenarios use SessionManager
- [ ] **Clean architecture**: One system, one API, clear responsibilities

## Related Files

- `autoload/SessionManager.gd`
- `scripts/systems/debug/DebugSystemControls.gd` 
- `scenes/debug/DebugPanel.gd`
- `autoload/GameOrchestrator.gd`
- `scripts/systems/PlayerAttackHandler.gd`

## Notes

This cleanup will eliminate the root cause of both the lambda capture errors and the MeleeCone deletion issues by centralizing all reset logic in a single, well-designed system.