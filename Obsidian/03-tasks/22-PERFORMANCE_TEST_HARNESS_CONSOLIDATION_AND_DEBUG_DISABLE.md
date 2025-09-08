# Performance Test Harness Consolidation & Debug Disable (Headless)

Status: Ready to Start  
Owner: Solo (Indie)  
Priority: High  
Type: Perf/Architecture Fix  
Dependencies: Arena.tscn, WaveDirector, EventBus, DebugManager, RNG, PerformanceMetrics  
Risk: Low-Medium  
Complexity: 3/10

---

## Problem Summary

Headless perf runs showed:
- Missing autoload detection (Engine.has_singleton used incorrectly), causing "DebugManager/CheatSystem/PlayerState not available" logs.
- DebugManager enables debug mode and UI by default (noise, spawn interference).
- Some perf scenes use placeholder nodes rather than the real Arena wiring.
- Inconsistent entry (full game vs subscene) increases variance.

Goal: A single, reproducible, headless harness that loads Arena as subscene, disables debug/UI deterministically, and drives WaveDirector to 500+ enemies with robust metrics.

Relevant: Obsidian/03-tasks/architecture-performance-stress-test.md

---

## Goals & Acceptance Criteria

- [ ] Single authoritative harness: tests/test_performance_500_enemies.tscn/gd remains the only source of truth for perf CI.
- [ ] Load real Arena scene: Arena.tscn instantiated as a subscene (no full game boot) to keep runs deterministic and minimal.
- [ ] Disable debug systems/UI: DebugManager never enters debug mode during perf; no overlays, no spawn interference.
- [ ] Correct autoload access: Replace Engine.has_singleton checks with safe scene-tree lookups for autoload nodes.
- [ ] Direct WaveDirector control: Programmatically set max_enemies=500, spawn intervals, and pool init; support gradual and burst phases.
- [ ] CLI flags supported: --no-debug disables DebugManager (and any debug UI) on startup in headless mode.
- [ ] Determinism: Stable RNG usage (seed/streams), low logging noise, consistent timings.
- [ ] Pass-fail gates: ≥30 FPS at 500+ enemies for ≥30s, 95th frame time <33.3ms, memory growth <50MB.
- [ ] CI-ready command documented and verified.

---

## Implementation Plan

### Phase A — Harness Autoload Access & Arena Subscene
- [ ] tests/test_performance_500_enemies.gd:
  - Replace Engine.has_singleton(...) with:
    ```
 var root := get_tree().get_root()
    var DebugManagerNode := root.get_node_or_null("DebugManager")
    var CheatSystemNode := root.get_node_or_null("CheatSystem")
    var PlayerStateNode := root.get_node_or_null("PlayerState")
    ```
  - Instance Arena: 
    ```
    var arena := load("res://scenes/arena/Arena.tscn").instantiate()
    add_child(arena)
    arena_root = arena
    ```
  - Discover WaveDirector/MultiMesh nodes from arena or keep current placeholders as fallback.
  - Ensure WaveDirector max_enemies=500, reinit pool, wire dependencies.

### Phase B — Debug Disable
- [ ] autoload/DebugManager.gd:
  - Early in _ready(): parse OS.get_cmdline_args() for "--no-debug".
  - When present, set debug_enabled = false and skip _initialize_debug_mode (do not show UI, no auto-clear).
  - Ensure _exit_debug_mode() handles being called early and is idempotent.
- [ ] tests/test_performance_500_enemies.gd:
  - If DebugManagerNode exists: set debug_enabled=false and call _exit_debug_mode() defensively before spawning.

### Phase C — Perf Determinism & Noise Reduction
- [ ] tests/test_performance_500_enemies.gd:
  - Seed RNG deterministically if RNG autoload exists (or use local RandomNumberGenerator).
  - Reduce logs to essential progress + metrics only.
  - Keep phases: gradual → burst → combat_stress → mixed_tier (already present).
  - Keep metrics export to tests/baselines with timestamp.

### Phase D — Validation & CLI
- [ ] Validate headless command (Windows):
  ```
  "./Godot_v4.4.1-stable_win64_console.exe" --headless tests/test_performance_500_enemies.tscn --quit-after 60 --no-debug
  ```
- [ ] Ensure no Debug UI prints appear and spawning is not blocked.

### Phase E — Docs/Notes
- [ ] Update Obsidian/03-tasks/architecture-performance-stress-test.md (link this fix and the run command).
- [ ] Note: MCP scene creation is not used in perf runs (keep headless harness for reproducibility).
- [ ] CHANGELOG entry if required by sprint workflow.

---

## File Touch List

- EDIT: tests/test_performance_500_enemies.gd
- (Optional EDIT): tests/test_performance_500_enemies.tscn (only if wiring via arena discovery requires removing placeholder nodes)
- EDIT: autoload/DebugManager.gd (CLI flag handling: --no-debug)
- (Docs) EDIT: Obsidian/03-tasks/architecture-performance-stress-test.md (link and command)

---

## Validation

- Command:
  ```
  "./Godot_v4.4.1-stable_win64_console.exe" --headless tests/test_performance_500_enemies.tscn --quit-after 60 --no-debug
  ```
- Expected logs:
  - ✓ Arena scene loaded as subscene successfully
  - ✓ Debug disabled (no debug UI shown)
  - ✓ WaveDirector configured for 500 enemy capacity and pool reinitialized
  - Phased progress with enemy counts + FPS
  - Final metrics with pass/fail breakdown

---

## Best Practices / Decisions

- Do not use MCP for perf runs; headless GDScript harness is faster, simpler, and more reproducible.
- Spawn directly in Arena (no main menu/game orchestration).
- Keep harness resilient: if autoloads are missing in isolated headless runs, continue with sensible defaults and log warnings.

---

## Success Metrics

- ≥30 FPS average at 500+ enemies for ≥30s window
- 95th percentile frame time <33.3ms
- Memory growth <50MB during the 60s run
- Deterministic enemy count evolution across runs with fixed seeds

---

## Minimal Milestone

- [ ] A1: Harness loads Arena as subscene and disables DebugManager via CLI flag
- [ ] B1: WaveDirector reliably reaches 500 enemies (burst gradual)
- [ ] C1: Metrics export and pass/fail gates print in console
- [ ] Sanity: one successful headless run meeting targets
