# Flow Fix — StateManager Navigation and Pause Gates

Status: Ready to Start  
Owner: Solo (Indie)  
Priority: High  
Type: Bugfix / Flow Integration  
Dependencies: 12-GAME_STATE_MANAGER_CORE_LOOP, 14-HIDEOUT_PHASE_1_MAIN_MENU_AND_CHARACTER_SELECT_INTEGRATION, 15-PAUSE_AND_ESCAPE_MENU, EventBus, GameOrchestrator, CharacterManager, PlayerProgression
Risk: Low–Medium (UI wiring)  
Complexity: 2/10

---

## Problem Summary

Symptoms reported:
- Pause menu works in Arena but not in Hideout.
- After navigating Main Menu → Character Select → Play, pressing E in Hideout to join the map does nothing.
- When starting the game directly into Hideout (debug), pressing E to join the map works.

Observed code:
- `scenes/ui/CharacterSelect.gd` still navigates via `EventBus.request_enter_map.emit({...})` to enter Hideout and to return to Menu.
- `autoload/StateManager.gd` exists and defines states + `is_pause_allowed()`, valid transitions, and `start_run(...)`.
- `autoload/GameOrchestrator.gd` maps `StateManager.state_changed` into EventBus requests (scene loading) and requires StateManager to own the flow.
- `autoload/PauseUI.gd` gates pause via `StateManager.is_pause_allowed()` and expects correct current state.

Root cause:
- Because CharacterSelect emits EventBus directly, `StateManager.current_state` is never set to `HIDEOUT` in the Menu → Character Select → Hideout path. Therefore:
  - `is_pause_allowed()` remains false in Hideout (StateManager thinks we’re still in MENU/CHARACTER_SELECT), so ESC gating blocks pause.
- MapDevice’s `StateManager.start_run(...)` from Hideout becomes an invalid transition if the current state wasn’t set to `HIDEOUT`, so pressing E appears non-functional.
- Secondary: `scenes/core/Hideout.gd` also toggles pause on ESC locally. This duplicates PauseUI’s global ESC handling. Not the immediate bug, but should be cleaned to avoid double toggles.

---

## Goals & Acceptance Criteria

Goals:
- Route all navigation flows via `StateManager` (UI → StateManager API); remove direct EventBus emits from UI screens for scene transitions.
- Ensure state consistency: After Menu → Character Select → Play, `StateManager.current_state == HIDEOUT`.
- Pause gating: ESC in Hideout shows Pause overlay (PauseUI); ESC in Menu/CharacterSelect does nothing.
- MapDevice E works after the menu path: pressing E transitions to Arena via `StateManager.start_run(...)` reliably.
- Optional cleanup: Use PauseUI as the single ESC owner; remove per-scene ESC pause toggles in Hideout.

Acceptance Criteria:
- Path A (normal): Menu → Character Select → Play → Hideout
  - State sequence MENU → CHARACTER_SELECT → HIDEOUT (via StateManager).
  - ESC shows Pause in Hideout; Resume hides it.
  - Interacting with MapDevice (E) transitions to Arena: HIDEOUT → ARENA (valid).
- Path B (debug): Boot directly into Hideout
  - ESC shows Pause; E enters Arena.
- Disallowed:
  - ESC in Menu/CharacterSelect does nothing.
- Tests:
  - `tests/test_debug_boot_modes.gd` passes for both entry paths.
  - `tests/test_scene_swap_teardown.gd` shows no leaks.
  - `tests/test_pause_resume_lag.gd` unchanged.
  - Add/extend a state-flow test for MENU → CHARACTER_SELECT → HIDEOUT → ARENA.

---

## Implementation Plan (Minimal Diffs)

### Step 1 — CharacterSelect.gd: Route navigation via StateManager
Replace EventBus emits with StateManager calls:

- `_on_character_play_pressed(character_id: StringName)`  
  After loading the profile and progression, replace:
  ```
  EventBus.request_enter_map.emit({
    "map_id": "hide",
    "character_id": profile.id,
    "character_data": profile.get_character_data(),
    "spawn_point": "PlayerSpawnPoint",
    "source": "character_select_play"
  })
  ```
  with:
  ```
  StateManager.go_to_hideout({
    "character_id": profile.id,
    "character_data": profile.get_character_data(),
    "spawn_point": "PlayerSpawnPoint",
    "source": "character_select_play"
  })
  ```

- `_on_character_selected(character_id: String)`  
  After creating/loading profile and setting progression, replace:
  ```
  EventBus.request_enter_map.emit({
    "map_id": "hideout",
    "character_id": profile.id,
    "character_data": profile.get_character_data(),
    "spawn_point": "PlayerSpawnPoint",
    "source": "character_select"
  })
  ```
  with:
  ```
  StateManager.go_to_hideout({
    "character_id": profile.id,
    "character_data": profile.get_character_data(),
    "spawn_point": "PlayerSpawnPoint",
    "source": "character_select"
  })
  ```

- `_on_back_pressed()`  
  Replace:
  ```
  EventBus.request_enter_map.emit({
    "map_id": "main_menu",
    "source": "character_select_back"
  })
  ```
  with either:
  ```
  StateManager.go_to_menu({"source": "character_select_back"})
 ```
  or:
  ```
  StateManager.return_to_menu(&"back", {"source": "character_select_back"})
  ```

Rationale: Ensures `StateManager.current_state` is updated to `HIDEOUT`, and then `GameOrchestrator` performs the proper scene swap via EventBus.

### Step 2 — Optional: Hideout ESC cleanup
- In `scenes/core/Hideout.gd`, ESC toggles pause locally. Either remove this handler or guard it behind a flag so PauseUI is the sole ESC owner to avoid double toggles.

### Step 3 — Verify orchestrator mapping (no changes expected)
- `GameOrchestrator._load_scene_for_state(...)` already maps:
  - HIDEOUT `EventBus.request_return_hideout.emit({...})`
  - ARENA → `EventBus.request_enter_map.emit({... "arena_id"...})`
- No changes needed; confirm logs and state.

---

## Test & Verification

Manual checks:
- Menu → Character Select → Play → Hideout:
  - Observe log: state transition MENU → CHARACTER_SELECT → HIDEOUT (StateManager).
  - ESC opens Pause overlay (PauseUI). Resume works.
  - Interact MapDevice; press E → Arena loads.
- Debug start in Hide:
  - ESC opens Pause; E goes to Arena.

Automated:
- Re-run:
  - `tests/test_debug_boot_modes.gd` (menu/hideout)
  - `tests/test_scene_swap_teardown.gd`
  - `tests/test_pause_resume_lag.gd`
- Add/extend a state-flow assertion in `tests/CoreLoop_Isolated.gd` or `tests/test_state_transitions.gd`:
  - Call `StateManager.go_to_menu()` → `go_to_character_select()` → `go_to_hideout()` → `start_run("arena")`
  - Assert state_changed sequence and no invalid transition.

---

## File Touch List

Code:
- `scenes/ui/CharacterSelect.gd` (EDIT: replace EventBus emits with StateManager.go_to_* calls)
-scenes/core/Hideout.gd` (EDIT optional: remove/guard local ESC toggle in favor of PauseUI)

Tests:
- Re-run:
  - `tests/test_debug_boot_modes.gd`
  - `tests/test_scene_swap_teardown.gd`
  - `tests/test_pause_resume_lag.gd`
- Add/extend:
  - `tests/CoreLoop_Isolated.gd` or `tests/test_state_transitions.gd`: assert MENU → CHARACTER_SELECT → HIDEOUT → ARENA path

Docs (cross-linking only):
- Reference: `Obsidian/03-tasks/12-GAME_STATE_MANAGER_CORE_LOOP.md`
- Reference: `Obsidian/03-tasks/14-HIDEOUT_PHASE_1_MAIN_MENU_AND_CHARACTER_SELECT_INTEGRATION.md`
- Reference: `Obsidian/03-tasks/-PAUSE_AND_ESCAPE_MENU.md`
- Reference: `Obsidian/03-tasks/ui-separation-of-concerns.md` (Phase 1: navigation decoupling)

---

## Rollback Plan

- If issues arise, revert `CharacterSelect.gd` navigation handlers to previous EventBus emits. Logs will indicate mismatched states; use Logger categories "state" and "ui" for triage.

---

## Notes & Guards

- Keep UI scenes dumb: UI calls StateManager; EventBus remains the transport for domain events.
- Determinism unaffected. No per-frame allocations; use existing services.
- Pause ownership: Prefer PauseUI as the single ESC handler; avoid per-scene duplication to prevent inconsistent UX.
- Logging: Ensure StateManager logs transitions with context (prev, next, reason/source) to simplify debugging.

---

## Minimal Milestone

- [ ] CharacterSelect routes navigation via StateManager (Play, Create → Hideout; Back → Menu)
- [ ] Pause works in Hideout (ESC shows overlay); disallowed in Menu/CharacterSelect
- [ ] MapDevice E works after Menu → Character Select → Hideout path
- [ ] Optional: Hideout no longer toggles pause locally; PauseUI owns ESC
- [ ] Sanity pass: debug boot modes, teardown, pause tests pass
