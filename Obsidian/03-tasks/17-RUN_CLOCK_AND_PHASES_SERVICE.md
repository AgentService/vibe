# Run Clock & Phases Service

Status: Ready to Start
Owner: Solo (Indie)
Priority: Medium-High
Type: Service Autoload
Dependencies: 12-GAME_STATE_MANAGER_CORE_LOOP, EventBus, Logger, RNG (streams), Arena.gd
Risk: Low
Complexity: 2/10

---

## Purpose
Provide a centralized, deterministic run clock and phase flags (early/mid/late) for systems to subscribe to. Prevent per-system duplicate timers and ensure consistent time/phase decisions across Arena, Waves, scaling, and UI.

---

## Goals & Acceptance Criteria
- [ ] Autoload `RunClock.gd` service:
  - Deterministic elapsed time tracking (seconds)
  - Emits typed signals on tick (at fixed cadence) and on phase changes
- [ ] Phase definition (data-driven via BalanceDB or local config):
  - phases: [{name: "early", start: 0.0, end: 60.0}, {name: "mid", start: 60.0, end: 180.0}, {name: "late", start: 180.0, end: -1}]
- [ ] StateManager integration:
  - On `start_run(...)` → RunClock.reset(run_id, seed, config)
  - On `end_run(...)` → RunClock.freeze()
- [ ] Deterministic cadence:
  - Single 30Hz or 10Hz internal update (configurable), no per-system timers
- [ ] Signals (typed):
  - tick(elapsed_seconds: float)
  - phase_changed(prev: StringName, next: StringName)
- [ ] No per-frame allocations; arrays/dicts reused
- [ ] Tests validate phase transitions and tick cadence

---

## API

`autoload/RunClock.gd`
```
class_name RunClock
extends Node

signal tick(elapsed_seconds: float)
signal phase_changed(prev: StringName, next: StringName)

var elapsed_seconds: float = 0.0
var current_phase: StringName = &"early"
var _phases: Array[Dictionary] = []  # [{name: StringName, start: float, end: float}]
var _accum: float = 0.0
var _tick_rate_hz: float = 10.0

func configure(phases: Array[Dictionary], tick_rate_hz: float = 10.0) -> void
func reset(run_id: StringName, seed: int, context := {}) -> void
func update(delta: float) -> void   # Called by Arena or fixed process owner
func freeze() -> void
func is_between(name: StringName) -> bool
```

Notes:
- Update is invoked from a single owner (e.g., Arena’s fixed loop or GameOrchestrator proxy) to avoid multiple driving clocks.
- `configure` allows BalanceDB-driven phases.

---

## Implementation Plan (Small Phases)

### Phase A — Service Skeleton
- [ ] Create `autoload/RunClock.gd` with API above
- [ ] Default phases (early/mid/late) hardcoded or read from BalanceDB (`balance_config.tres.run_phases` if present)
- [ ] Internal cadence: accumulate delta, emit `tick` at 10Hz by default

### Phase B — StateManager Wiring
- [ ] On `StateManager.start_run(...)`:
  - `RunClock.reset(run_id, seed, context)`
  - Optionally `RunClock.configure(...)` from BalanceDB
- [ ] On `StateManager.end_run(...)`:
  - `RunClock.freeze()`

### Phase C — Single Update Owner
- [ ] Choose a single update driver (prefer Arena.gd fixed loop or GameOrchestrator 30Hz proxy)
- [ ] Call `RunClock.update(delta)` each fixed step
- [ ] Document ownership to avoid multiple updates

### Phase D — Phase Changes
- [ ] Evaluate current phase on each tick
- [ ] Emit `phase_changed(prev, next)` once on boundary crossing

### Phase E — Tests
- [ ] tests/CoreLoop_Isolated.gd:
  - Simulate time progression to cross early→mid→late
  - Assert tick cadence ~10Hz (within tolerance)
  - Assert `phase_changed` fires exactly at boundaries
- [ ] tests/test_arena_boundaries.gd:
  - Single driver invokes update; ensure no double counts

### Phase F — Consumers (Optional examples)
- [ ] WaveDirector uses phases for pool selection weights
- [ ] UI/HUD displays current phase
- [ ] Scaling hooks (EnemyFactory) may read phase/time for multipliers

---

## File Touch List

Code:
- autoload/RunClock.gd (NEW)
- autoload/StateManager.gd (EDIT: call reset/freeze)
- scenes/arena/Arena.gd or autoload/GameOrchestrator.gd (EDIT: call RunClock.update(delta) from single owner)
- autoload/BalanceDB.gd (optional: expose run_phases)

Tests:
- tests/CoreLoop_Isolated.gd (EDIT)
- tests/test_arena_boundaries.gd (EDIT)

Docs:
- docs/ARCHITECTURE_QUICK_REFERENCE.md (update)
- docs/ARCHITECTURE_RULES.md (update: single clock ownership, no per-system timers)

---

## Notes & Guards
- Determinism: relies on fixed-step or consistent delta source; seed used only if future randomness is added for schedule jitter (not now).
- Performance: single 10Hz emit avoids excessive signals.
- No coupling: consumers subscribe to signals; no direct references.

---

## Minimal Milestone
- [ ] A1: RunClock resets on start_run, updates via single owner, emits tick at 10Hz
- [ ] B1: Phase transitions fire correctly at configured boundaries
- [ ] Sanity: CoreLoop_Isolated assertions pass
