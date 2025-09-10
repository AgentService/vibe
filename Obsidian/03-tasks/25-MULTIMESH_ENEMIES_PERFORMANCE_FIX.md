# MultiMesh Enemies Performance Fix

Status: Ready to Start  
Owner: Solo (Indie)  
Priority: Critical  
Type: Performance Improvement (Hotpath)  
Dependencies: MultiMeshManager.gd, EnemyRenderTier.gd, WaveDirector.gd, DebugConfig.gd, tests/test_performance_500_enemies.*  
Risk: Medium–High (touches rendering hotpath)  
Complexity: 5/10

---

## Background & Evidence

Performance with MultiMesh-rendered swarm enemies fails targets; bosses (non-MultiMesh path) pass easily.

- 500 Enemies Test (MultiMesh-heavy):
  - Memory Growth: +127.6 MB (✗ > 50 MB)
  - Frame Time P95: 139.9 ms (✗ > 33.3 ms)
  - FPS Stability: 55.9% (✗)
  - Result: FAILED

- 500 Banana Bosses (non-MultiMesh swarm path):
  - Memory Growth: +48.0 MB (✓ < 50 MB)
  - Frame Time P95: 6.94 ms (✓)
  - FPS Stability: 99.9% (✓)
  - Result: PASSED

Diagnosis summary (from code review):
- EnemyRenderTier.group_enemies_by_tier allocates Arrays + per-enemy Dictionary via `enemy.to_dictionary()` every frame → heavy churn at 500 entities.
- MultiMeshManager.update_enemies:
  - Reassigns `instance_count` every frame for all tiers → frequent buffer resizes.
  - Uses `use_colors = true` and calls `set_instance_color()` per instance per frame → large per-frame buffer uploads.
  - Updates transforms for all instances every frame.
- Bosses avoid these costs due to much lower count and non-MultiMesh updates.

---

## Goals & Acceptance Criteria

Primary goals:
- Eliminate per-frame allocations in enemy tier grouping.
- Minimize MultiMesh buffer churn (instance_count and colors).
- Maintain 500+ enemies with stable frametimes.

Acceptance criteria:
- tests/test_performance_500_enemies: PASSED
  - Memory Growth < 50 MB
  - Time 95th < 33.3 ms
  - FPS Stability > 90%
  - Final enemy count ≥ 500
- No GC spikes observed during phases (visual/log metrics).
- No regressions in boss-only stress test.

---

## Plan (Phased, low-risk first)

### Phase A — Low-risk MultiMesh toggles (fast wins)
Scope: scripts/systems/MultiMeshManager.gd

1) Disable per-instance colors
- Ensure `multimesh.use_colors = false` for projectiles and all enemy tiers.
- Remove `set_instance_color(i, ...)` calls in `_update_tier_multimesh`.
- Set a fixed per-tier color once: `mm_enemies_*.self_modulate = get_tier_debug_color(tier)` for visibility.

2) Avoid instance_count churn
- Only grow:  
  ```
  var prev := mm_instance.multimesh.instance_count
  if count > prev:
      mm_instance.multimesh_count = count
  ```
- Optional shrink policy: shrink rarely (e.g., on phase change or every N seconds) to reduce reallocs.

3) Keep transform updates initially, measure impact
- Continue `set_instance_transform_2d` per instance for now; profile after A/B.

Expected: Reduced buffer traffic and reallocations → lower P frametime, improved stability, modest memory improvement.

### Phase B — Eliminate per-frame allocations in tier grouping
Scope: scripts/systems/EnemyRenderTier.gd, scripts/systems/MultiMeshManager.gd

1) Add light grouping API (no dictionaries):
- New: `group_enemies_by_tier_light(alive: Array[EnemyEntity]) -> Dictionary[Tier, Array[EnemyEntity]]`
- Internally reuse preallocated arrays: keep arrays on the singleton/node, call `.clear()` each frame to avoid realloc; do not create per-enemy dictionaries.

2) Consume EnemyEntity directly
- Update `MultiMeshManager.update_enemies()` to use the light grouping method.
- In `_update_tier_multimesh`, read fields directly (`enemy.position`, `enemy.direction`) instead of `Dictionary` lookups.
- Avoid creating temporary `Transform2D` objects if possible by reusing a local transform or a small per-tier scratch buffer.

Expected: Major drop in allocation rate and GC pauses → improved memory growth and P95 frame times.

### Phase C — Optional visual update decimation
Scope: scripts/systems/MultiMeshManager.gd, DebugConfig.gd/config/debug.tres

- Gate transform updates behind 30 Hz combat step (already present via `EventBus.combat_step`) instead of every frame.
- Guard behind a debug/config flag (e.g., `render.multimesh_update_30hz = true`) for easy A/B.

Expected: Further CPU/GPU savings with minimal visual impact.

### Phase D — Validation & Baseline
- Re-run tests/test_performance_500_enemies.tscn headless.
- Ensure acceptance criteria met; export baselines (already done by test).
- Document results and add CHANGELOG entry.

---

## Implementation Notes (code-level checklist)

MultiMeshManager.gd
- Setup:
  - Ensure `use_colors = false` for all created MultiMeshes (projectiles/swarm/regular/elite/boss).
  - Assign per-tier `self_modulate` once after `.multimesh` assignment.
- Update loop:
  - Replace `instance_count = count` with grow-only logic.
  - Remove `set_instance_color` calls.
  - Keep per-instance transform updates initially; optionally decimate to 30 Hz later.
- Logging: retain periodic instance counts for regression visibility.

EnemyRenderTier.gd
- Add `group_enemies_by_tier_light`:
  - Keep 4 arrays on the node as members; clear them each call; append `EnemyEntity` references (no `to_dictionary()`).
  - Return dictionary keyed by Tier → Array[EnemyEntity].
- Deprecate/avoid the heavy `group_enemies_by_tier` in hotpath (keep for debug if needed).

DebugConfig.gd / config/debug.tres
- Add flags:
  - `render.multimesh_use_colors` (default false)
  - `render.multimesh_update_30hz` (default false)
  - `render.multimesh_shrink_interval_sec` (default 3.0 or disabled)

Tests
- Use existing tests/test_performance_500_enemies and compare baselines.
- Optionally add a toggle run with 30 Hz update to quantify deltas.

---

## Risks & Rollback

- Risk: Visual regression (loss of per-instance tint). Mitigation: Use node `self_modulate` per tier; re-enable colors selectively if truly needed.
- Risk: Transform update decimation may cause minor jitter. Mitigation: Leave behind config flag to A/B.
- Rollback: All changes are localized; revert MultiMeshManager and EnemyRenderTier to previous versions if needed.

---

## File Touch List

- scripts/systems/MultiMeshManager.gd (A, C)
- scripts/systems/EnemyRenderTier.gd (B)
- scripts/domain/DebugConfig.gd and/or config/debug.tres (C, flags)
- tests/test_performance_500_enemies.gd (no changes required; re-run to validate)

---

## Validation Steps

1) Apply Phase A; run stress test:
- Expect P95 frame time and stability to improve; memory growth reduced from +127 MB.

2) Apply Phase B; run stress test:
- Expect memory growth < 50 MB and P95 < 33.3 ms.

3) Optional Phase C; run again:
- Expect additional head if needed.

4) Export baselines; update changelog:
- Add entry under `changelogs/features/` summarizing improvements.

---

## Definition of Done

- 500-enemy stress test passes:
  - Memory Growth < 50 MB
  - Frame Time 95th < 33.3 ms
  - FPS Stability > 90%
  - Final enemies ≥ 500
- No GC spikes during phases.
- New baselines exported and CHANGELOG updated.
