# ENTITY TRACKER: Register Goblins (MultiMesh) and Unify Clear-All via Damage Pipeline

Context
- Current “Clear All” via unified DamageService fails on goblins (pooled/multimesh) when they’re not fully registered in EntityTracker.
- Goal: 100% of enemies (goblins + bosses) are tracked in EntityTracker, positions kept in sync, and Clear All uses the same damage pipeline across entity types.

Scope
- Ensure all spawn paths for goblins register with EntityTracker (and DamageService) using a stable string ID scheme ("enemy_{index}").
- Ensure positions/HP sync back to EntityTracker and DamageService on each update.
- Use DebugManager.clear_all_entities() as the single point to clear enemies via DamageService.apply_damage() at large value.
- Keep WaveDirector.clear_all_enemies() as a temporary fallback until verification, then remove or guard.

References
- DebugManager: autoload/DebugManager.gd
- Damage Registry: scripts/systems/damage_v2/DamageRegistry.gd (class DamageRegistryV2 via autoload “DamageService”)
- EntityTracker: scripts/systems/EntityTracker.gd (autoload “EntityTracker”)
- WaveDirector: scripts/systems/WaveDirector.gd
- Bosses: scenes/bosses/AncientLich.gd, DragonLord.gd
- Tests: tests/WaveDirector_Isolated.gd, tests/EnemySystem_Isolated_v2.gd, tests/DamageSystem_Isolated_Clean.gd

Deliverables
- Unified, damage-based clear that reliably removes goblins and bosses.
- All goblins present in EntityTracker during their lifecycle.
- Deterministic tests validating registration and clear-all behavior.

Implementation Plan
1) Audit + Fix Registration
- Verify V2 path: WaveDirector._spawn_from_config_v2 registers goblins with EntityTracker (and DamageService) using entity_id = "enemy_{free_idx}".
- Verify legacy path: WaveDirector._spawn_pooled_enemy does the same (register both services; consistent IDs).
- Ensure “alive: true, hp/max_hp, pos” present on registration for EntityTracker.

2) Ensure Live Position/HP Sync
- Confirm WaveDirector._update_enemies updates both:
  - EntityTracker.update_entity_position(entity_id, enemy.pos)
  - DamageService.update_entity_position(entity_id, enemy.pos)
- On damage sync (EventBus.damage_entity_sync), ensure pooled enemy HP is updated and death flips alive=false and unregisters from EntityTracker.

3) Clear-All via Damage Pipeline
- Keep DebugManager.clear_all_entities() iterating EntityTracker.get_alive_entities() and calling:
  - DamageService.apply_damage(entity_id, 999999, "debug_clear_all", ["debug", "clear_all"])
- Temporarily retain WaveDirector.clear_all_enemies() as fallback for any missed entities during transition; plan removal post-verification.

4) Tests (Deterministic, Isolated)
- tests/WaveDirector_Isolated.gd: Spawn N goblins; assert EntityTracker.get_entities_by_type("enemy").size() == N. Call DebugManager.clear_all_entities(); advance one frame; assert 0 alive enemies, and both EntityTracker/DamageService no longer contain them.
- tests/test_boss_spawning.gd: Spawn boss scene(s); call clear-all; assert death pipeline executes and nodes are freed/unregistered.
- tests/test_signal_cleanup_validation.gd: Ensure no stray connections or leaks post-clear.

5) Observability/Debug
- Temporary debug logs on EntityTracker.register/unregister and DamageService.register/unregister counts for visibility during rollout.
- After verification, reduce log verbosity to normal levels (Logger.is_level_enabled guards).

Acceptance Criteria
- Spawning 10 goblins yields 10 tracked “enemy_*” IDs in EntityTracker; positions update each frame.
- Pressing Clear All kills all goblins and bosses via damage pipeline (no direct queue_free for pooled enemies).
- After one frame, all cleared entities are unregistered from both EntityTracker and DamageService; no leaks.
- No player removal; “player” type is skipped.
- WaveDirector.clear_all_enemies() no longer required for correctness (can be removed or kept behind a debug flag).

Risk Notes
- Mixed legacy spawn paths can miss registration; this plan enforces consistency.
- Index/string ID mapping must be stable; ensure “enemy_{index}” remains correct across pool reuse.

Execution Checklist
- [ ] Audit both WaveDirector spawn paths for EntityTracker + DamageService registration (IDs, fields).
- [ ] Ensure position/HP sync on update and via damage sync path (EntityTracker + DamageService).
- [ ] Confirm death path sets alive=false and unregisters (EntityTracker + DamageService).
- [ ] Keep unified DebugManager.clear_all_entities() damage-based, with temporary fallback to WaveDirector.clear_all_enemies().
- [ ] Add/adjust tests:
  - [ ] WaveDirector_Isolated: goblin registration + clear-all validation
  - [ ] Boss spawning: boss clear-all validation
  - [ ] Signal cleanup validation after clear-all
- [ ] Run tests via tests/cli_test_runner.gd or run_tests.bat; ensure green and fast.
- [ ] Remove/guard fallback after verification; keep unified damage as single source of truth.
- [ ] Update docs/ARCHITECTURE_RULES.md and CHANGELOG with unified clear-all behavior and registration guarantees.

Notes
- This aligns with .clinerules (damage_v2 conventions, autoload usage, event-driven flow).
- Prefer typed payloads via EventBus where; keep logs concise and gated behind debug level checks.
