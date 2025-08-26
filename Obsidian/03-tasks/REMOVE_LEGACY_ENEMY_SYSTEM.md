# Remove Legacy Enemy System (Decommission Task)

Status: Planned
Owner: Solo (Indie)
Priority: Medium (execute after V2 is proven)
Dependencies:
- Obsidian/03-tasks/ENEMY_V2_MVP_AND_SPAWN_PLAN.md (Completed: MVP + Spawn Plan)
- BalanceDB toggle in place (`use_enemy_v2_system`)
- V2 templates live under `vibe/data/content/enemies_v2/*`
- V2 code under `vibe/scripts/systems/enemy_v2/*`

Risk: Low (toggle protected, isolated folders, single seam removal)
Rollback: Easy (reintroduce seam and restore deleted dirs via Git)

## Purpose

Once Enemy V2 is fully adopted (MVP + Spawn Plan validated), remove the legacy enemy path (legacy registry/selection + legacy EnemyType content) to reduce maintenance and prevent drift. Bosses remain scene-based and are not removed by this task.

## When to do this (Ordering)

Do this AFTER:
1) Enemy V2 MVP is live and used for regular enemies
2) Spawn Plan is adopted in at least one map/arena and validated
3) You have run several sessions confirming parity and performance

This task is the final step in the migration path and should follow the two tasks above.

## Preconditions (must be true before removal)

- [ ] `BalanceDB.use_enemy_v2_system = true` for all spawn groups/maps, or per-group routing selects V2 exclusively
- [ ] Playtest logs show zero legacy spawns for a few sessions
- [ ] Isolated tests pass (determinism, batching sanity, spawn flow)
- [ ] Performance parity confirmed (pooled/MultiMesh unchanged)

Tip: Add a final log marker to the legacy path temporarily:
```gdscript
Logger.info("LEGACY_SPAWN_USED", "waves")
```
Run a session and verify you never see this line.

## What will be removed

A) Code paths
- Legacy spawn decision branch in your spawner (WaveDirector/EnemySystem)
- Legacy enemy selection/registry (e.g., EnemyRegistry, EnemyPicker, or any function that picks EnemyType directly)
- Legacy-only visual generation code (hardcoded shapes/colors) if now superseded by V2 SpawnConfig/VisualPreset equivalents
- Any legacy-only glue or signal handlers no longer referenced

B) Data
- Legacy enemy content resources (EnemyType .tres, etc.) that are not used by bosses
- Legacy enemy weights/tables in BalanceDB (keep only V2 weights)

C) Tests
- Legacy-specific tests (e.g., `test_enemy_registry.*`, tests asserting legacy fields/flows)

D) Documentation
- Remove references to legacy registry/enemy data from ARCHITECTURE.md and CLAUDE.md
- Update `/vibe/data/README.md` to document only V2 schemas
- Update CHANGELOG.md summarizing the removal

## What is NOT removed

- Boss system: boss scenes, controllers, abilities, special effects remain
- Shared systems: RNG, EventBus, BalanceDB, Logger, pools, MultiMesh
- Any utilities still consumed by V2

## Removal Steps (Safe, Step-by-Step)

1) Freeze legacy and prove zero usage
- Ensure all spawn groups route to V2 (toggle on, or per-group routing)
- Add the `LEGACY_SPAWN_USED` log marker in the legacy branch, playtest, confirm no hits
- Remove the temporary log line after confirmation

2) Remove the spawner legacy branch (central seam)
- Open the spawner file where the V2 integration seam was added
- Delete the legacy branch; keep only the V2 call
- Remove the `use_enemy_v2_system` conditional if the toggle is no longer needed

Example seam (for reference):
```gdscript
# Remove the legacy branch and toggle; keep this V2 call:
const EnemyFactory := preload("res://vibe/scripts/systems/enemy_v2/EnemyFactory.gd")
var cfg := EnemyFactory.spawn_from_weights(spawn_request)
return spawn_from_config)
```

3) Remove legacy selection/registry code
- Delete files that implement legacy enemy picking/registry (e.g., EnemyRegistry, EnemyPicker)
- legacy-only visual handlers that V2 no longer needs

4) Remove legacy data
- Delete legacy `EnemyType` resources and any legacy enemy .tres still present and unused by
- Remove legacy weight tables in BalanceDB (retain only V2 weights or V2 balance file)

5) Remove legacy tests
- Delete tests that explicitly verify registry/selection behavior

6) Docs & changelog
- Update ARCHITECTURE.md and CLAUDE.md to reference only V2
- Update `/vibe/data/README.md` schema docs to reflect V2 template/weights
- Add a CHANGELOG.md entry for this week documenting the removal

7) Grep for stragglers
Search in VSCode:
- `script_class="EnemyType"`
- `class_name EnemyType`
- `EnemyRegistry`
- `legacy_spawn` or `spawn_legacy`
- `use_enemy_v2_system` (remove entirely if no longer used)
- Paths under `vibe/data/content/enemies/` (legacy location) if V2 is under `enemies_v2/`

8) Build and run
- Launch an arena; confirm all spawns function via V2
- Sanity check performance and deterministic seed reproduction

## Acceptance Criteria

- No references to legacy enemy registry/selection remain in code
- No legacy enemy .tres remain (except those used by boss scenes)
- BalanceDB contains only V2 weight entries (or a V2 balance file)
- Tests pass, and playtest shows expected spawn behavior with V2
- Docs updated and CHANGELOG.md entry added

## Effort Estimate

- 2–4 hours for removal and validation (for a solo codebase)
- Rollback is trivial via Git: restore the seam code and the deleted directories/files if needed

## Risk & Mitigation

- Risk: Accidental removal of assets needed by bosses
  - Mitigation: Before deleting a resource, use “Find All References” to confirm it’s unused
- Risk: Hidden legacy calls
  - Mitigation: Add a `LEGACY_SPAWN_USED` log marker first; grep for keywords before deletion
- Risk: Toggle dependencies
  - Mitigation: If other systems read the toggle, remove or repoint those reads; grep for `use_enemy_v2_system`

## Task Checklist

- [ ] Confirm preconditions (V2 only, zero legacy logs)
- [ ] Remove spawner legacy branch (central seam)
- [ ] Delete legacy registry/selection code files
- [ ] Delete legacy enemytres (not used by bosses)
- [ ] Remove legacy weight tables from BalanceDB
- [ ] Remove legacy tests (or port if useful)
- [ ] Update ARCHITECTURE.md / CLAUDE.md / data README
- [ ] Add CHANGELOG.md entry
- [ ] Grep for stragglers and clean any remaining references
- [ ] Build and run sanity test (spawn flow, performance)

## Notes

- Keep V2 code/data under `enemy_v2` folders for life; this is now the primary path
- If you later create boss templates, do that in a separate, explicit migration; do not remove boss scenes in this task
