# Game State Manager — Core Loop Foundation (Menu → Hideout → Arena → Results → Menu)

Status: Updated — Adopt thin StateManager facade + global Pause gates
Owner: Solo (Indie)
Priority: Highest
Type: System Architecture
Dependencies: EventBus, GameOrchestrator, CharacterManager (Complete), Hideout Phase 0 (Complete), PauseManager
Risk: Low–Medium (additive orchestration layer)
Complexity: 3/10

---

## Design Decision
- Adopt a thin StateManager autoload facade for all scene transitions and run state changes.
- Keep EventBus as the backbone for decoupled signaling; StateManager delegates to GameOrchestrator/EventBus.
- UI scenes call StateManager methods (not EventBus) to improve clarity, testability, and enforce flow rules.
- Global Pause: gate Escape via `StateManager.is_pause_allowed()`; a PauseUI autoload owns the overlay and subscribes to PauseManager/EventBus.

## Purpose

Establish a centralized, strongly-typed, decoupled state orchestration layer for the core loop:
Menu → Character Select → Hideout → Arena (Run) → Results → Menu. All scene transitions go through this module. No tight coupling; signals- and data-driven; deterministic.

---

## Goals & Acceptance Criteria

- [ ] StateManager autoload with explicit states:
  - enum State { BOOT, MENU, CHARACTER_SELECT, HIDEOUT, ARENA, RESULTS, EXIT }
- [ ] Typed signals:
  - state_changed(prev: State, next: State, context: Dictionary)
  - run_started(run_id: StringName, context: Dictionary)
  - run_ended(result: Dictionary)
- [ ] Public API (no scene knowledge required by callers):
  - go_to_menu(context := {})
  - go_to_character_select(context := {})
  - go_to_hideout(context := {})
  - start_run(arena_id: StringName, context := {})
  - end_run(result: Dictionary)
  - return_to_menu(reason: StringName, context := {})
  - is_pause_allowed() -> bool  # true only in HIDEOUT, ARENA, RESULTS
- [ ] Integrate with GameOrchestrator: all swaps routed through StateManager; remove ad-hoc transitions
- [ ] Debug boot compatibility via config/debug.tres (menu | hideout | arena)
- [ ] Determinism preserved; no per-frame allocations; event-driven transitions only
- [ ] Tests: CoreLoop_Isolated validates transitions and teardown ordering
- [ ] Docs updated (ARCHITECTURE_QUICK_REFERENCE.md, ARCHITECTURE_RULES.md)

---

## Implementation Plan (Small Phases)

### Phase A — Autoload StateManager
- [ ] Create autoload/StateManager.gd (Node)
- [ ] Define enum State, current_state: State = BOOT, and last_state: State
- [ ] Signals:
  ```
  signal state_changed(prev: int, next: int, context: Dictionary)
  signal run_started(run_id: StringName, context: Dictionary)
  signal run_ended(result: Dictionary)
  ```
- [ ] API methods implement guardrails (ignore if same state; log transitions; emit signals)
- [ ] Use Logger for info/warn; EventBus for cross-module notifications as needed

### Phase B — GameOrchestrator Integration
- [ ] Subscribe to StateManager.state_changed; perform deferred scene loading per target state
- [ ] Replace direct scene swaps in GameOrchestrator with StateManager API calls
- [ ] Ensure proper teardown (disconnect signals, free nodes) before loading next scene
- [ ] Keep debug hooks intact (B key, etc.) but route flow through StateManager

### Phase C — Results Screen Seam (Minimal)
- [ ] Add stub UI: scenes/ui/ResultsScreen.tscn + .gd
  - Shows basic run summary (time survived, level, kills)
  - Buttons: “Restart Run”, “Return to Hideout”, “Return to Menu”
  - Emits EventBus.ui_action or calls StateManager.end_run()/go_to_*
- [ ] Wire Arena end-of-run (death or victory) to StateManager.end_run(result)

### Phase D — Debug Boot Modes
- [ ] Read config/debug.tres for boot_mode: menu | hideout | arena, and optional starting_arena_id
- [ ] Route initial state accordingly via StateManager API
- [ ] Validate with tests/test_debug_boot_modes.gd; ensure no regressions

### Phase E — Tests & Docs
- [ ] tests/CoreLoop_Isolated.tscn/gd:
  - Assert sequence: MENU → HIDEOUT → ARENA → RESULTS → MENU via API
  - Verify signals fire with correct payloads
  - Verify no leaks (test_scene_swap_teardown.gd)
- [ ] Update docs:
  - docs/ARCHITECTURE_QUICK_REFERENCE.md: Add StateManager section diagram
  - docs/ARCHITECTURE_RULES.md: “All flow transitions must go through StateManager”

---

## File Touch List

Code:
- autoload/StateManager.gd (NEW)
- autoload/GameOrchestrator.gd (EDIT: route transitions through StateManager)
- autoload/EventBus.gd (EDIT optional: add any UI actions if used)
- autoload/PauseManager.gd (No change; verify compatibility)

UI:
- scenes/ui/ResultsScreen.tscn (NEW)
- scenes/ui/ResultsScreen.gd (NEW)

Tests:
- tests/CoreLoop_Isolated.gd/.tscn (NEW)
- tests/test_debug_boot_modes.gd (verify)
- tests/test_scene_swap_teardown.gd (verify)

Docs:
- docs/ARCHITECTURE_QUICK_REFERENCE.md (update)
- docs/ARCHITECTURE_RULES.md (update)

---

## Notes & Guards
- Centralize Escape handling (e.g., in GameOrchestrator) and call PauseUI.toggle_pause() only when `StateManager.is_pause_allowed()` returns true.
- PauseUI is an autoload CanvasLayer; overlay persists across scene swaps; PauseManager remains single source of truth for `get_tree().paused`.

- Strong modular boundaries. No scene code calls scene methods across modules; use StateManager API + EventBus.
- Determinism unaffected — StateManager does orchestration only (no RNG).
- Use Logger for structured context on transitions (prev, next, reason, run_id).
- Avoid per-frame processing; transitions are event-triggered.

---

## Prioritized Roadmap (Next Small Tasks)

1) 12-GAME_STATE_MANAGER_CORE_LOOP (this task)
2) 13-RUN_RESULTS_AND_RESTART_FLOW
   - Results payload schema, restart seam to Arena, return-to-hideout/menu decisions
3) 14-HIDEOUT_PHASE_1_MAIN_MENU_AND_CHARACTER_SELECT_INTEGRATION
   - Integrate CharacterManager (complete) with flow; minimal menu screens
4) 15-PAUSE_AND_ESCAPE_MENU
   - Pause overlay; route “Return to Menu/Hideout” via StateManager
5) 16-RUN_DATA_VS_META_DATA_SEPARATION_ENFORCEMENT
   - Define RunData schema; ensure no meta writes during runs
6) 17-RUN_CLOCK_AND_PHASES_SERVICE
   - Centralized run clock; early/mid/late flags; expose to systems via EventBus
7) 18-ABILITY_SYSTEM_EXTRACTION_PHASE_1_IMPLEMENTATION
   - Align with 03-ABILITY_SYSTEM_MODULE.md; skeleton module + one ranged projectile

---

## Acceptance Tests (Summary)

- Starting in MENU, selecting options transitions to HIDEOUT, starting a run transitions to ARENA.
- On death/victory, end_run(result) → RESULTS; selecting options returns to MENU or HIDEOUT.
- Debug boot paths enter directly to selected state without bypassing StateManager.
- No regressions in test_scene_swap_teardown; no dangling signals; no memory leaks.
