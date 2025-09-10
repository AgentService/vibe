# Run Results & Restart Flow

Status: Ready to Start
Owner: Solo (Indie)
Priority: High
Type: System Integration
Dependencies: 12-GAME_STATE_MANAGER_CORE_LOOP, EventBus, GameOrchestrator, Arena.gd, PlayerProgression, CharacterManager
Risk: Low
Complexity: 3/10

---

## Purpose

Add a clean, modular end-of-run flow with a minimal Results screen that supports:
- Restart Run (same arena/context)
- Return to Hideout
- Return to Menu

Decoupled via StateManager API + EventBus. No tight coupling between scenes.

---

## Goals & Acceptance Criteria

- [ ] Define a typed RunResult payload schema
  - result: StringName ("victory" | "defeat" | "abort")
  - run_id: StringName
  - duration_seconds: float
  - level_reached: int
  - kills: int
  - meta: Dictionary (optional: drops, bosses, etc.)
- [ ] Arena reports end-of-run deterministically:
  - On death/victory: calls `StateManager.end_run(result_dict)`
- [ ] ResultsScreen minimal UI:
  - Shows duration, level, kills, result
  - Buttons: Restart, Hideout, Menu
- [ ] Actions route via StateManager:
  - Restart → `StateManager.start_run(previous_arena_id, previous_context)`
  - Hideout → `StateManager.go_to_hideout({reason: "run_finished"})`
  - Menu → `StateManager.go_to_menu({reason: "run_finished"})`
- [ ] No leaks: teardown validated with test_scene_swap_teardown
- [ ] Tests cover transition sequence and payload integrity

---

## Implementation Plan (Small Phases)

### Phase A — Result Payload and Arena Hook
- [ ] Create scripts/resources/RunResult.gd (Resource, editor-friendly)
  ```
  extends Resource
  class_name RunResult
  @export var result: StringName
  @export var run_id: StringName
  @export var duration_seconds: float
  @export var level_reached: int
  @export var kills: int
  @export var meta: Dictionary = {}
  ```
- [ ] Arena.gd: On end condition (death/victory), build result Dictionary or Resource and call:
  - `StateManager.end_run(result_dict)`
- [ ] StateManager: store `last_run_context` + `last_run_result` for restart logic

### Phase B — Results Screen (Minimal)
- [ ] scenes/ui/ResultsScreen.tscn + .gd
  - Labels for summary (bound to payload)
  - Buttons: Restart / Hideout / Menu
- [ ] Glue:
  - On enter Results state, GameOrchestrator instantiates ResultsScreen and passes `StateManager.last_run_result` for display
  - Button callbacks call StateManager public API

### Phase C — Restart Semantics
- [ ] StateManager retains:
  - `last_run_arena_id: StringName`
  - `last_run_context: Dictionary` (seed/run_id/scaling flags)
- [ ] `start_run(last_run_arena_id, last_run_context)` on Restart button

### Phase D — Tests
- [ ] tests/CoreLoop_Isolated.gd:
  - Simulate MENU → ARENA → end_run(defeat) → RESULTS → Restart → ARENA
  - Validate state sequence and payload
- [ ] tests/test_scene_swap_teardown.gd:
  - Ensure no dangling signals upon transitions
- [ ] tests/test_debug_boot_modes.gd:
  - Boot directly into ARENA → end_run → RESULTS → Menu/Hideout

### Phase E — Docs
- [ ] docs/ARCHITECTURE_QUICK_REFERENCE.md: Add Results flow diagram
- [ ] docs/ARCHITECTURE_RULES.md: Results actions must go through StateManager

---

## File Touch List

Code:
- scripts/resources/RunResult.gd (NEW)
- autoload/StateManager.gd (EDIT: last_run_* fields, end_run behavior)
- autoload/GameOrchestrator.gd (EDIT: instantiate ResultsScreen on RESULTS state)
- scenes/arena/Arena.gd (EDIT: hook to call end_run)

UI:
- scenes/ui/ResultsScreen.tscn (NEW)
- scenes/ui/ResultsScreen.gd (NEW)

Tests:
- tests/CoreLoop_Isolated.gd/.tscn (EDIT/NEW)
- tests/test_scene_swap_teardown.gd (verify)
- tests/test_debug_boot_modes.gd (verify)

Docs:
- docs/ARCHITECTURE_QUICK_REFERENCE.md (update)
- docs/ARCHITECTURE_RULES.md (update)

---

## Notes & Guards

- Determinism: Results payload derived from tracked run clock and counters; no RNG.
- No tight coupling: ResultsScreen calls only StateManager public API.
- Logging: Use Logger with structured fields (run_id, duration, result) on end_run.

---

## Minimal Milestone

- [ ] A1: Arena emits end_run with minimal payload (result, run_id, duration)
- [ ] B1: ResultsScreen shows summary + Restart/Hideout/Menu buttons
- [ ] C1: Restart re-enters Arena with same context, Menu/Hideout work
- [ ] Sanity test: Full flow manual + CoreLoop_Isolated passes
