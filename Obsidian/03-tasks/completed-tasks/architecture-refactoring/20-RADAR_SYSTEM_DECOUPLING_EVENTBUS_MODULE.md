# Radar System Decoupling — EventBus-Driven Module + UI Separation

Status: Ready to Start  
Owner: Solo (Indie)  
Priority: Medium-High  
Type: Architecture Improvement  
Created: 2025-09-07  
Dependencies: BalanceDB (RadarConfigResource), EventBus, StateManager, PauseManager, PlayerState, Arena (WaveDirector)  
Risk: Low–Medium (UI wiring + new system)  
Complexity: 3/10

---

## Problem Summary

Current `EnemyRadar.gd` (UI) pulls domain data by:
- Traversing the scene tree to find `Arena` and dereferencing `arena.wave_director.get_alive_enemies()`.
- Mixing responsibilities (data access + visualization).
- Having no explicit gating by State (ARENA-only) or Pause state.

This violates `.clinerules` and the UI separation plan (Phase 2: Radar System Decoupling) by tightly coupling UI to scene hierarchy and gameplay systems.

---

## Goals & Acceptance Criteria

Functional
- [ ] Introduce `RadarSystem` (module) that owns enemy scanning; UI becomes a pure view.
- [ ] UI no longer performs any scene tree traversal or WaveDirector access.
- [ ] Data-driven styling remains via `BalanceDB` → `RadarConfigResource` (already good).

Integration
- [ ] State gating: scanning only active in `ARENA` (disabled in `MENU/CHARACTER_SELECT/HIDEOUT`).
- [ ] Pause gating: scanning suspended while paused; UI can still render last-known data.
- [ ] Communication: radar data delivered via EventBus signal or system signal (see “Wiring Options”).

Performance/Quality
- [ ] Throttle emissions (e.g., 10 Hz) or emit on change to reduce churn.
- [ ] No per-frame allocations in the hot path; reuse arrays/dicts where possible.
- [ ] All new APIs and signals typed; follow `.clinerules` static typing guidance.

Testing/Docs
- [ ] Isolated tests for `RadarSystem` and view binding for `EnemyRadar`.
- [ ] Architecture docs updated to reflect new ownership and signals.
- [ ] UI separation-of-concerns doc Phase 2 marked satisfied by this task when merged.

---

## Architecture & Flow

Recommended event-driven pipeline:
```
WaveDirector (domain) → RadarSystem (module) → EventBus.radar_data_updated → EnemyRadar (view)
                                     ↑                         ↑
                          StateManager (gate)      PauseManager (gate)
```

- RadarSystem:
  - Subscribes to EventBus `combat_step` (or equivalent tick).
  - Reads domain data via injected references (WaveDirector, PlayerState).
  - Applies gates: StateManager.is_pause_allowed() and ARENA-only logic.
  - Emits `radar_data_updated(payload)` at throttled cadence.

- EnemyRadar (UI):
  - Subscribes to radar data event; updates internal buffers; calls `queue_redraw()`.
  - Remains responsible for drawing only (dot positions/sizes/styling from BalanceDB).
  - No scene tree scans; no WaveDirector or Arena references.

---

## Wiring Options

- Option A (Preferred, decoupled): EventBus transport
  - EventBus signal (typed):  
    `signal radar_data_updated(enemy_positions: Array[Vector2], player_pos: Vector2)`
  - EnemyRadar connects to EventBus; no dependency on RadarSystem instance.

- Option B (Local signal): direct system signal
  - `RadarSystem.radar_data_updated.connect(enemy_radar._on_radar_data_updated)`
  - Requires EnemyRadar to receive a reference to the `RadarSystem` instance (slightly tighter coupling to Arena wiring).

Both are acceptable; choose A for maximal decoupling.

---

## Implementation Plan (Small Phases)

### Phase A — Create RadarSystem (module)
- [ ] File: `scripts/systems/RadarSystem.gd`
- [ ] API and signals (typed):
  ```gdscript
  extends Node
  class_name RadarSystem

  signal radar_data_updated(enemy_positions: Array[Vector2], player_pos: Vector2)

  var _wave_director: WaveDirector
  var _player_pos: Vector2
  var _enemies_buf: Array[Vector2] = []  # reused buffer
  var _enabled: bool = false
  var _throttle_accum: float = 0.0
  var _emit_hz: float = 10.0

  func setup(wave_director: WaveDirector) -> void
  func set_enabled(enabled: bool) -> void
  func set_emit_rate_hz(hz: float) -> void
  ```
- [ ] Connect:
  - `EventBus.combat_step` → internal update (if enabled and not paused).
  - `PlayerState.player_position_changed` → cache `_player_pos`.
  - `BalanceDB.balance_reloaded` → no-op or future tuning hook.
  - `StateManager.state_changed` → set_enabled(true) in ARENA, false otherwise.
  - `PauseManager.game_paused_changed` → suspend recompute while paused (or rely on combat_step suspension if guaranteed).

- [ ] Logic:
  - On tick, gather alive enemy positions via `_wave_director.get_alive_enemies()`.
  - Fill `_enemies_buf` (reused), throttle to 10 Hz, then emit `radar_data_updated(_enemies_buf, _player_pos)`.

### Phase B — Arena Wiring
- [ ] In `scenes/arena/Arena.gd` (or an injection point), create/ a `RadarSystem` node.
- [ ] Call `radar_system.setup(wave_director)`.
- [ ] Ensure single owner; free on arena teardown.

### Phase C — EnemyRadar (UI) Refactor
- [ ] File: `scenes/ui/EnemyRadar.gd`:
  - Remove `_update_enemy_positions()` and scene tree traversal.
  - Remove `_on_combat_step` direct handler.
  - Add handler:
    ```gdscript
    func _on_radar_data_updated(enemies: Array[Vector2], player_pos: Vector2) -> void:
        enemy_positions = enemies  # consider copying if buffer reuse needed
        player_position = player_pos
        queue_redraw()
    ```
  - Subscribe to either `EventBus.radar_data_updated` (Option A) or `RadarSystem.radar_data_updated` (Option B).
  - Keep BalanceDB-driven styling.

### Phase D — State/Pause Gates
- [ ] RadarSystem listens to StateManager and PauseManager to control `_enabled`.
- [ ] EnemyRadar may hide/idle in non-ARENA states (optional; driven by HUD/screen logic or by lack of events).

### Phase E — Optimization (optional, if needed)
- [ ] Only emit when positions changed beyond a small epsilon.
- [ ] Adjust `_emit_hz` from BalanceDB ui.radar settings if desired.

### Phase F — EventBus Extension (if Option A)
- [ ] Add typed signal in `autoload/EventBus.gd`:
  ```gdscript
  signal radar_data_updated(enemy_positions: Array[Vector2], player_pos: Vector2)
  ```
- [ ] RadarSystem emits through EventBus rather than its own signal.

### Phase G — Tests
- [ ] `tests/RadarSystem_Isolated.tscn/.gd`:
  - Stub WaveDirector returning known positions; simulate `combat_step`; assert event fired with expected payload.
  - When paused or state != ARENA → no events fired.
- [ ] `tests/EnemyRadar_View_Isolated.tscn/.gd`:
  - On receiving `radar_data_updated`, updates buffers and sets a flag that `queue_redraw()` was called.
  - Static analysis/boundary test: no scene tree traversal (no `get_parent()` climbing).
- [ ] Integration:
  - In ARENA, verify radar works; in HIDEOUT/MENU, no radar events (or UI hidden).
  - Re-run boundary tests to ensure no violations.

### Phase H — Docs
- [ ] Update `docs/ARCHITECTURE_RULES.md`: Add section “Radar — ownership and EventBus wiring”.
- [ ] Update `docs/ARCHITECTURE_QUICK_REFERENCE.md`: Short diagram of flow.
- [ ] Update `Obsidian/03-tasks/ui-separation-of-concerns.md`: Mark Phase 2 (Radar) satisfied by this task upon completion.

---

## File Touch List

New
- `scripts/systems/RadarSystem.gd` (module)

Edited
- `scenes/ui/EnemyRadar.gd` (remove scene traversal; subscribe to radar data)
- `autoload/EventBus.gd` (add `radar_data_updated` signal if choosing Option A)
- `scenes/arena/Arena.gd` (own + setup `RadarSystem`)

Tests
- `tests/RadarSystem_Isolated.tscn/gd` (NEW)
- `tests/EnemyRadar_View_Isolated.tscn/gd` (NEW)
- Ensure `tests/test_architecture_boundaries.gd` continues to pass (and flags any traversal left behind)

Docs
- `docs/ARCHITECTURE_RULES.md` (update)
- `docs/ARCHITECTURE_QUICK_REFERENCE.md` (update)
- `Obsidian/03-tasks/ui-separation-of-concerns.md` (cross-link and mark Phase 2 done when merged)

---

## Minimal Milestone (Ship Small)

- [ ] A1: Create `RadarSystem`, hook to `combat_step`, gather positions from WaveDirector.
- [ ] C1: EnemyRadar subscribes to `radar_data_updated` and renders; remove traversal.
- [ ] G1: Add `RadarSystem_Isolated` and `EnemyRadar_View_Isolated` basic tests.
- [ ] Sanity: Radar works in ARENA; does nothing in MENU/HIDEOUT; no leaks.

---

## Notes & Guards

- Follow `.clinerules`:
  - Static typing; no UI → domain reach-ins; use signals/services.
  - Reuse buffers; avoid per-frame allocations.
  - Connect signals in `_ready()`; disconnect on teardown to prevent leaks.

- State/Pause behavior:
  - Gate in `RadarSystem` using StateManager and PauseManager to ensure consistent control.
  - UI stays passive, rendering latest payload when available.

- Option A vs B:
  - Prefer EventBus-based publishing for maximal decoupling and testability.

---

## Rollback Plan

- If regressions occur, temporarily restore EnemyRadar’s previous enemy-fetch path behind a debug flag while keeping the new system off. Log deprecation warnings to ensure migration completes.
