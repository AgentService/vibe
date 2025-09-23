# Hideout Scene Swap Teardown — Prevent Enemy Leakage (Best Practices Task)

Status: Not Started
Owner: Solo (Indie)
Priority: High
Dependencies: GameOrchestrator, EventBus, DebugManager, Arena.gd, WaveDirector, EnemyFactory, EntityTracker, RNG, Logger
Risk: Medium (touches scene flow and registries)
Complexity: 4/10 (structural cleanup + contracts)

---

## Problem Statement

When spawning enemies in Arena and then returning to Hideout with H, enemies follow into the Hideout. This indicates scene-leakage: gameplay nodes and/or their timers/signals survive scene transitions, or Hideout is loaded additively without freeing Arena.

---

## Root Cause Hypotheses

- Leaked ownership: enemies parented outside Arena root (e.g., under Main or an autoload).
- Additive load: Hideout instanced without freeing or replacing Arena (both scenes active).
- Sticky registries/services: WaveDirector/EnemyFactory/EntityTracker keep Node references and/or active timers after scene swap.
- Unclean signals: EventBus connections not disconnected in teardown.
- Missing groups/layers isolation: enemies still process and chase in Hideout.

---

## Goals & Acceptance Criteria

Functional
- [ ] Press H to swap Arena → Hideout performs a full teardown: Arena tree is freed.
- [ ] After swap, get_tree().get_nodes_in_group("enemies").size() == 0.
- [ ] No enemy/projectile/multimesh or wave timers exist in Hideout scene tree.
- [ ] WaveDirector.is_running == false and EnemyFactory.active_count == 0 after swap.
- [ ] No dangling EventBus connections from Arena subsystems.

Architecture & Ownership
- [ ] All arena gameplay nodes are owned by an ArenaRoot under Arena.tscn; never parented to autoloads.
- [ ] Registries/services store IDs or WeakRefs, not hard node references; provide reset() and auto-purge on node tree_exited.
- [ ] Single-scene swap: change_scene_to_file or explicit replace current_scene; no additive instancing.

Safety Nets
- [ ] Global purge of "arena_owned" and "enemies" groups on mode change.
- [ ] Physics layers/masks ensure hideout cannot interact with any leaked enemy if one slipped through.

Observability
- [ ] Logger emits structured summaries on mode changes (counts before/after).
- [ ] Debug overlay (optional) can show active counts per system post-swap.

---

## Implementation Plan (Phased, small commits)

Phase A — Ownership Audit & Grouping
- [ ] Ensure all enemy/projectile/timer spawns parent to %ArenaRoot (scene-owned).
- [ ] Tag arena gameplay nodes with "arena_owned" and enemies with "enemies" groups.
- [ ] Add asserts in Arena.gd during spawn path to enforce parent is %ArenaRoot.

Phase B — Single-Scene Swap via Orchestrator
- [ ] Add GameOrchestrator.go_to_hideout():
  - Stop combat (pause WaveDirector, stop spawners).
  - Call current_scene.on_teardown() if exists (deferred).
  - await one frame; get_tree().change_scene_to_file("res://scenes/core/Hideout.tscn").
- [ ] Ensure DebugManager H routes to GameOrchestrator.go_to_hideout(), not manual instancing.

Phase C — Arena Teardown Contract
- [ ] Arena.gd: implement on_teardown() and call in _exit_tree():
  - Disconnect EventBus signals.
  - WaveDirector.stop(); EnemyFactory.reset(); EntityTracker.clear("enemies").
  - Kill/stop timers/tweens owned by Arena.
  - queue_free all children of %ArenaRoot (belt and suspenders).
- [ ] Add guard in enemy AI _process/_physics_process to early return if !is_instance_valid(get_tree().current_scene) or missing %ArenaRoot.

Phase D — Registry/Service Hygiene
- [ ] EnemyFactory.gd: reset() to clear caches/pools; avoid storing strong Node references; attach to node.tree_exited if needed.
- [ ] WaveDirector.gd: stop() cancels timers, disconnects from EventBus, clears schedules.
- [ ] EntityTracker.gd: add clear(group: String) and reset(); purge dead refs.

Phase E — Safety Nets & Isolation
- [ ] On EventBus.mode_changed("hideout"), global purge: iterate "arena_owned" and "enemies" groups and queue_free().
- [ ] Physics: Hideout scene ignores enemy layers (masks); enemies ignore hideout layers.

Phase F — Diagnostics & Tests
- [ ] Add debug assertions after swap: size of "enemies" == 0; WaveDirector.is_running == false.
- [ ] tests/test_scene_swap_teardown.gd (isolated): spawn enemies → trigger swap → assert zero leaks.
- [ ] Optional: add metric counters to Logger summaries.

---

## File Touch List

Code
- autoload/GameOrchestrator.gd (NEW go_to_hideout/go_to_arena flow, emit mode_changed)
- autoload/DebugManager.gd (route H to Orchestrator)
- autoload/EventBus.gd (ADD: signal mode_changed(mode: StringName))
- scenes/arena/Arena.gd (on_teardown(), _exit_tree teardown, enforce %ArenaRoot parenting)
- scripts/systems/enemy_v2/EnemyFactory.gd (reset(), avoid strong Node refs)
- scripts/systems/WaveDirector.gd (stop(), reset(), disconnect)
- scripts/systems/EntityTracker.gd (clear(group), reset(), tree_exited purge hooks)
- Enemy AI scripts (optional early-return guard)

Scenes/Data
- scenes/core/Hideout.tscn (confirm layer/mask isolation)
- scenes/arena/Arena.tscn (ensure ArenaRoot node present)
- config/debug.tres/json (ensure H routes correctly in debug)

Tests
- tests/test_scene_swap_teardown.gd (NEW)
- tests/test_arena_boundaries.gd (extend assertions post-swap)

Docs/Changelogs
- docs/ARCHITECTURE_RULES.md (scene ownership & teardown rule)
- docs/ARCHITECTURE_QUICK_REFERENCE.md (mode change flow)
- changelogs/features/YYYY_MM_DD-hideout_teardown_fix.md

---

## Teardown Checklist (runtime, debug build)

- [ ] No nodes in group "enemies" after swap
- [ ] No children under %ArenaRoot (Arena no longer in tree)
- [ ] WaveDirector timers == 0; is_running == false
- [ ] EnemyFactory.active_count == 0; pools cleared
- [ ] No EventBus connections referencing Arena/Enemy instances
- [ ] Logger summary:
  - before: {enemies: N, timers: T}
  - after: {enemies: 0, timers: 0}

---

## Best-Practice Guardrails

- Never parent gameplay nodes to autoloads. Services own data, not nodes.
- Consumers connect to providers, and disconnect on teardown (no cross-module dangling references).
- Use groups "arena_owned"/"enemies" consistently; they are your broom.
- Prefer change_scene_to_file over additive instancing for mode switches.
- Await at least one process frame between teardown and load to prevent race re-entrancy.

---

## Test Plan

- Manual: Spawn 20 enemies, press H; verify silence in Hideout (no pursuit, no physics overlap).
- Automated (headless): tests/test_scene_swap_teardown.gd
  - Arrange: load Arena, spawn N enemies
  - Act: EventBus.emit("request_mode_change", "hideout") → Orchestrator swap
  - Assert: groups empty, systems stopped, no leaks
- Regression: Repeat swap back and forth 5 times; memory/active counts stable.

---

## Timeline & Rollout

- A–C: 1.5–2.0 hours (audit + teardown + orchestrator swap)
- D: 45–60 min (registry hygiene)
- E: 30 min (safety nets & layers)
- F: 45 min (tests & logs)
Total: ~4 hours incremental, 5–6 small commits.

---

## Success Metrics

- Zero leaked enemies across 10 repeated swaps (Arena ↔ Hideout).
- Post-swap diagnostic: enemies=0, timers=0, pools cleared in <1 frame.
- No crash or dangling signals detected by test_signal_cleanup_validation.gd.
