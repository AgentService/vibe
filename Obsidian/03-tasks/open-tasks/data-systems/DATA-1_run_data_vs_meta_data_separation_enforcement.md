# Run Data vs Meta Data Separation Enforcement

Status: Ready to Start
Owner: Solo (Indie)
Priority: High
Type: Architecture Enforcement
Dependencies: 12-GAME_STATE_MANAGER_CORE_LOOP, CharacterManager, PlayerProgression, EventBus, Logger
Risk: Low
Complexity: 3/10

---

## Purpose
Enforce strict separation between per-run data (volatile, reset each run) and meta/character data (persistent across runs). Provide a typed RunData schema, centralize access, and add tests and guards to prevent accidental meta writes during Arena runs.

---

## Goals & Acceptance Criteria
- [ ] Define typed RunData resource and singleton owner:
  - RunData.gd (Resource) schema with fields used during a run
  - RunDataService.gd (autoload) to own lifecycle (create/reset/end)
- [ ] Clear boundaries:
 - No writes to CharacterManager/PlayerProgression meta from Arena state unless via explicit signals at run end
  - Systems read-only access to meta during run; writes prohibited
- [ ] Integration with StateManager:
  - On start_run → RunDataService.reset(run_id, seed, context)
  - On end_run → RunDataService.freeze() and expose result payload
- [ ] Tests:
  - Prevent meta writes during run via boundary test (fails if detected)
  - Validate RunData lifecycle is reset/cleaned properly
- [ ] Docs updated with schema and rules

---

## Data Schemas

### RunData.gd (Resource)
```
extends Resource
class_name RunData

@export var run_id: StringName
@export var seed: int
@export var start_time_msec: int
@export var elapsed_seconds: float
@export var wave_index: int
@export var kills: int
@export var boss_kills: int
@export var cards_picked: Array[StringName] = []
@export var damage_dealt: float
@ var damage_taken: float
@export var meta: Dictionary = {}  # optional, non-persistent run-scoped tags
```

### RunDataService.gd (autoload)
API (typed):
```
class_name RunDataService
var data: RunData

func reset(run_id: StringName, seed: int, context: Dictionary = {}) -> void
func add_kill(count: int = 1) -> void
func add_boss_kill() -> void
func add_damage_dealt(amount: float) -> void
func add_damage_taken(amount: float) -> void
func add_card(card_id: StringName) -> void
func set_wave(index: int) -> void
func tick(delta: float) -> void
func freeze() -> RunData  # snapshot at end_run
func export_summary() -> Dictionary  # for results screen
```

Signals (via EventBus optional):
```
signal run_data_changed(data: Dictionary)
```

---

## Enforcement Rules

- During ARENA state:
  - [ ] PlayerProgression writes are disabled (no level/exp meta writes). Only run-scoped counters update in RunData.
  - [ ] CharacterManager is read-only; no saves until end_run.
  - [ ] Any attempt to call CharacterManager.save_current() is logged as warn and deferred until RESULTS/HIDEOUT.

- On RESULTS/HIDEOUT transitions:
  - [ ] If needed, apply meta deltas (e.g., achievements) via a dedicated handler
  - [ ] CharacterManager.save_current() allowed once

---

## Implementation Plan (Small Phases)

### Phase A — RunData + Service
- [ ] Create `scripts/resources/RunData.gd` (typed Resource)
- [ ] Create `autoload/RunDataService.gd` with API above
- [ ] Hook into StateManager:
  - On `start_run(...)` → `RunDataService.reset(...)`
  - On `end_run(result)` → `RunDataService.freeze()` and include summary in result.meta

### Phase B — Boundary Guards
- [ ] Add guard in PlayerProgression.gd: if StateManager.state == ARENA, prohibit persistent saves (log + no-op)
- [ ] Add guard in CharacterManager.gd: prohibit save_current() in ARENA unless allow_flag set by Results/Hideout flow
- [ ] EventBus-based notifications for violations (for tests)

### Phase C — Integrations
- [ ] Arena.gd call `RunDataService.tick(delta)` and add counters (kills/waves etc.)
- [ ] WaveDirector/Wave systems: `RunDataService.set_wave(wave_index)`
- [ ] Damage/Combat systems: increment dealt/taken

### Phase D — Tests
- [ ] tests/CoreLoop_Isolated.gd: verify RunData reset on start, frozen on end
- [ ] tests/test_arena_boundaries.gd: assert save attempts blocked in ARENA
- [ ] tests/test_scene_swap_teardown.gd: ensure RunDataService references cleared post-run

### Phase E —
- [ ] docs/ARCHITECTURE_RULES.md: RunData vs Meta separation section
- [ ] docs/ARCHITECTURE_QUICK_REFERENCE.md: diagram: StateManager ↔ RunDataService

---

## File Touch List

Code:
- scripts/resources/RunData.gd (NEW)
- autoload/RunDataService.gd (NEW)
- autoload/StateManager.gd (EDIT: call reset/freeze)
- autoload/CharacterManager.gd (EDIT: guard)
- autoload/PlayerProgression.gd (EDIT: guard)
- scenes/arena/Arena.gd (EDIT: integrate counters/tick)

Tests:
- tests/CoreLoop_Isolated.gd (EDIT)
- tests/test_arena_boundaries.gd (EDIT)
- tests/test_scene_swap_teardown.gd (verify)

Docs:
- docs/ARCHITECTURE_RULES.md (update)
- docs/ARCHITECTURE_QUICK_REFERENCE.md (update)

---

## Notes & Guards
- Keep service allocation minimal; reuse RunData instance per run, or pool.
- Determinism preserved; only counters and timestamps.
- Logger: use structured logs for violations (system, method, state).

---

## Minimal Milestone
- [ ] A1: RunDataService resets on start_run and freezes on end_run
- [ ] B1: Boundary guards prevent writes during ARENA
- [ ] Sanity: CoreLoop_Isolated assertions pass
