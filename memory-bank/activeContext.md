# Active Context

Current focus, recent changes, next steps, and active decisions for ongoing development. This is the living state for day-to-day work.

## Current Focus (Now)
- Establish and maintain Memory Bank as single source of truth for session resets.
- Keep architecture matrix clean (pre-commit/CI) and boundaries enforced.
- Consolidate Damage v2 as the only damage path (entities routed via registry/service).
- Maintain data-driven workflow using typed .tres resources with hot-reload.
- Prep UI/scene refactors: decompose Arena, introduce GameManager, add generic modal overlay.

## Recent Changes (Week 34 In Progress)
- Hybrid Enemy Spawning System: WaveDirector routes pooled vs scene-based bosses; public spawn APIs; special bosses excluded from weighted waves; proper signal integration.
- Player stats migration to .tres (PlayerType, default_player.tres with validation).
- EnemyBehaviorSystem removed; AI now handled by WaveDirector.
- Boundary check enhancement: allow pure Resource config imports.
- Unified Damage System v2 COMPLETE: DamageRegistry + DamageService autoload; single pipeline/signals; entity synchronization; auto-registration; legacy disabled.
- Limbo Console v0.4.1 integrated (F1) for runtime commands/tuning.
- Universal .tres hot-reload: BalanceDB monitors resources; scenes use @export; systems use ResourceLoader with CACHE_MODE_IGNORE.
- Obsidian docs updated (EnemyEntity migration, typed flows).
- Config migration JSON → typed .tres (log_config, radar_config, xp_curves, balance/content).
- Boss UI component: BossHealthBar (ProgressBar + theme) added; bosses call update_health(current, max) directly; logs via Logger; slated to migrate to EventBus-driven health change signal.
- Boss hit feedback shader added (shaders/boss_flash.gdshader + material), integrated for boss damage feedback.

## Next Steps (Plan)
1. UI/Scene Architecture
   - Extract UI responsibilities from Arena; enforce CanvasLayer layering and z-order.
   - Implement GameManager scene (entry, transitions, pause/options stubs).
   - Build generic Modal Overlay System (CardPicker precedent) with pause-aware layering.
   - Integrate BossHealthBar into HUD/GameManager; migrate updates to an EventBus-driven entity_health_changed flow; add an isolated scene test.
2. Testing & Enforcement
   - Ensure autoload-dependent systems have isolated scene tests; expand cli_test_runner coverage.
   - Keep test_architecture_boundaries.gd green; add regression tests for allowed Resource config imports.
3. Performance & Rendering
   - Phase upgrades for tier rendering (opt paths per SWARM/REGULAR/ELITE/BOSS).
   - Validate pooled transforms cache sizing vs max_enemies; monitor allocations.
4. Content & Balance
   - Add more typed content resources (.tres) via registry without code changes.
   - Incremental balance passes using hot-reload + Limbo Console for runtime tuning.
5. Documentation & Workflow
   - Keep Obsidian systems and Memory Bank in sync after each change.
   - Update CHANGELOG weekly; record learnings in LESSONS_LEARNED.md when new patterns emerge.

## Active Decisions and Considerations
- Determinism: 30 Hz fixed-step logic; RNG named streams only; no direct randi/randf.
- Boundaries: Scenes→Systems/Autoload only; Systems→Domain/Autoload; Domain stays pure.
- Damage: Single pipeline via DamageService/Registry; IDs are strings; no take_damage() calls on nodes.
- Data: All tunables in data/* as typed .tres; validate with safe fallbacks; hot-reload everywhere practical.
- Logging: Logger autoload only in game code; tests may use print.
- Boss UI coupling (temporary): BossHealthBar updates via direct boss.update_health(); allowed within scene ownership; migrate to EventBus entity_health_changed for decoupled UI.

## Important Patterns and Preferences
- Typed payload classes accessed via EventBus preloads; connect in _ready(), disconnect in _exit_tree().
- Pooled objects and MultiMesh for enemy rendering; use_colors true; white base texture modulation.
- Cache Transform2D arrays sized to max_enemies; avoid per-frame allocations.
- Scene ownership governs lifecycle; communicate via signals; avoid get_node() for cross-layer access.

## Learnings and Insights (Pointers to LESSONS_LEARNED.md)
- Godot 4 signal connection syntax; typed arrays from dicts; signal declarations single-line.
- Use Panel for custom-drawn UI backgrounds; Control is invisible without style.
- EventBus signals must be declared prior to emission; typed payload classes improve IDE support.
