# Progress

What works, what's left, current status, known issues, and the evolution of decisions. This document is the single snapshot of progress state.

## Status Summary
- Core architecture in place and enforced by automated checks (pre-commit + CI).
- Deterministic combat loop (30 Hz) with named RNG streams.
- Unified Damage System v2 fully integrated across entity types.
- Data-driven via typed .tres resources with universal hot-reload patterns.
- Hybrid enemy spawning (pooled + scene bosses) operational.
- Memory Bank established as source of truth for resets and onboarding.
- Boss UI component integrated (BossHealthBar) with themed ProgressBar; bosses update via direct call; logs via Logger.
- Boss damage feedback shader/material integrated for boss hit flashes.

## What Works (Validated)
- Fixed-step RunManager with EventBus.combat_step cadence.
- RNG: named streams (crit, loot, waves, ai, craft) seeded per run.
- Layered boundaries: Scenes → Systems/Autoload, Systems → Domain/Autoload, Domain → Domain only.
- Automated boundary tooling: check_architecture.bat, tests/test_architecture_boundaries.gd, CI gate.
- Unified Damage v2: DamageService + DamageRegistry; damage_requested → damage_applied/dealt → damage_taken; entity_killed routed centrally; string-based entity IDs.
- Hybrid Spawning: WaveDirector routes pooled vs scene-based bosses; public spawn APIs; special bosses excluded from weighted waves.
- Data/Config: Migration to typed .tres (log_config, radar_config, xp_curves, balance, content); BalanceDB monitoring + @export for scene configs; ResourceLoader + CACHE_MODE_IGNORE for systems.
- Logging: Central Logger autoload with categories; print avoided in game code (allowed in tests).
- Dev Console: Limbo Console integrated (F1) for runtime commands/tuning.
- Documentation: Obsidian systems updated for typed EnemyEntity and signals; Memory Bank core created.
- Boss UI: BossHealthBar component (ProgressBar + themed) works; bosses call update_health(current, max); logs via Logger.
- Boss hit feedback shader/material applied for boss damage flashes.

## What's Left (Planned)
- UI/Scene Architecture:
  - Decompose Arena responsibilities; enforce CanvasLayer layering/z-order.
  - Introduce GameManager entry scene; main/pause/options stubs.
  - Generalize Modal Overlay System (CardPicker precedent), pause-aware layers.
  - Integrate BossHealthBar into HUD/GameManager; migrate updates to EventBus entity_health_changed; add an isolated scene test.
- Testing & Enforcement:
  - Expand isolated scene tests for autoload-dependent systems; broaden cli_test_runner usage.
  - Regression tests for allowed pure Resource config imports in boundary checker.
- Rendering & Performance:
  - Phase optimization paths per render tier (SWARM/REGULAR/ELITE/BOSS).
  - Validate/cap allocations (Transform2D caches sized to max_enemies).
- Content & Balance:
  - Add more typed resources via registry without code changes.
  - Incremental balance passes via hot-reload + console.
- Documentation:
  - Keep Memory Bank + Obsidian in sync; maintain weekly changelog entries.

## Known Issues/Risks
- Arena.gd remains monolithic; risk of accidental boundary leaks without ongoing refactor.
- Rendering tiers are foundational; advanced optimizations still pending.
- Hot-reload correctness depends on comprehensive validate() in resources.
- Ensure all signals are declared in EventBus before emission to avoid runtime errors.
- Boss UI currently direct-coupled (BossHealthBar.update_health); migrate to EventBus for decoupling and testability.

## Decision Evolution (Highlights)
- Damage v2 consolidated all damage paths; entity lifecycle centralized (registry-owned).
- Migration from JSON → typed .tres for configs/content to align with inspector editing and type safety.
- Boundary checker updated to allow pure Resource config imports for scenes (exception codified).
- Enemy system re-centered on typed EnemyEntity with MultiMesh baseline rendering.

## Recent Milestones (Week 34 In Progress)
- Hybrid Enemy Spawning System (pooled + scene bosses) with signals.
- Player stats migrated to PlayerType .tres with validation.
- EnemyBehaviorSystem removed (AI handled by WaveDirector).
- Limbo Console integration; universal .tres hot-reload via BalanceDB and @export patterns.
- Unified Damage System v2 complete across entity types.
- Memory Bank established (projectbrief, productContext, systemPatterns, techContext, activeContext, progress).
- Boss UI component added (BossHealthBar.tscn/.gd) with themed ProgressBar and Logger-driven updates.
- Boss hit feedback shader (shaders/boss_flash.gdshader) and material integrated for boss damage feedback.

## Next Actions (Short List)
- Extract UI from Arena; set up GameManager scene and modal overlay scaffolding.
- Add/expand isolated scene tests for systems with autoload dependencies.
- Insert regression test coverage for boundary rule exception (pure Resource configs).
- Start tier-specific rendering optimizations and verify allocation profiles.
